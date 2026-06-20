import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:record/record.dart';

import '../../core/observability/app_log.dart';
import 'meeting_loopback_source.dart';
import 'recorder_backend.dart';

/// Spawns ffmpeg. Injectable so the backend's lifecycle (start → stop, cancel,
/// args) is unit-testable without a real ffmpeg / live audio. Mirrors the
/// `Process.run`/`which fmedia` subprocess idiom already in the codebase, but
/// uses [Process.start] because ffmpeg is a long-running capture, not a
/// one-shot command.
typedef FfmpegSpawner = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<Process> _defaultFfmpegSpawner(
  String executable,
  List<String> arguments,
) =>
    Process.start(executable, arguments);

/// [RecorderBackend] that captures the **system output (loopback) mixed with
/// the microphone into ONE WAV file** via an ffmpeg subprocess — the desktop
/// meeting recorder (MVP **Linux**).
///
/// ---------------------------------------------------------------------------
/// WHY ffmpeg-subprocess (not the `record` native backend)
/// ---------------------------------------------------------------------------
/// The default [RecordRecorderBackend] captures the microphone only. A meeting
/// also needs the *remote participants*, whose audio comes out of the speakers
/// and is otherwise lost. On Linux (PipeWire/PulseAudio) every output sink
/// exposes a `<sink>.monitor` loopback source; ffmpeg can open that monitor AND
/// the default mic as two `-f pulse` inputs and `amix` them into a single WAV.
/// This stays true to the "dumb client" philosophy: we only capture + hand the
/// finished WAV to the existing F4 upload pipeline; Core does the transcription.
///
/// The produced file is a normal single-file WAV, so the existing
/// [AudioRecordingService] single-file model and the F4 upload pipeline accept
/// it unchanged (`wav` is already an accepted audio extension in
/// `inbox_upload.mediaTypeForPath`).
///
/// ---------------------------------------------------------------------------
/// PAUSE/RESUME
/// ---------------------------------------------------------------------------
/// A raw capture subprocess has no lossless mid-stream pause the way the native
/// recorder does, and meetings are recorded straight through, so this MVP
/// backend is **start → stop** only. [pause]/[resume] throw
/// [UnsupportedError] rather than silently dropping audio — the meeting UI does
/// not surface pause. (A future enhancement could segment + concat via ffmpeg.)
///
/// ---------------------------------------------------------------------------
/// PER-OS SEAM
/// ---------------------------------------------------------------------------
/// Linux only for this increment. Windows (WASAPI loopback) and macOS (virtual
/// device / ScreenCaptureKit — ffmpeg avfoundation can't tap output) are out of
/// scope; the capability gate ([MeetingLoopbackSource.isSupported]) reports
/// unsupported off Linux so those backends can slot in later behind the same
/// [RecorderBackend] seam.
class MeetingRecorderBackend implements RecorderBackend {
  MeetingRecorderBackend({
    MeetingLoopbackSource? loopback,
    FfmpegSpawner spawn = _defaultFfmpegSpawner,
    bool Function()? hasMicPermission,
    Duration stopGrace = const Duration(seconds: 5),
  })  : _loopback = loopback ?? const MeetingLoopbackSource(),
        // ignore: prefer_initializing_formals
        _spawn = spawn,
        // ignore: prefer_initializing_formals
        _hasMicPermission = hasMicPermission,
        // ignore: prefer_initializing_formals
        _stopGrace = stopGrace;

  final MeetingLoopbackSource _loopback;
  final FfmpegSpawner _spawn;
  final bool Function()? _hasMicPermission;

  /// Per-step grace before the stop() escalation moves on (SIGINT → SIGKILL →
  /// give-up). Short by default; injectable so tests can drive the escalation
  /// without waiting real seconds.
  final Duration _stopGrace;

  /// The running ffmpeg capture, or null when idle.
  Process? _process;

  /// Output WAV path of the active capture.
  String? _outputPath;

  /// Drains ffmpeg's stderr (progress/diagnostics) so the pipe never blocks the
  /// subprocess; the tail is kept for a diagnosable failure message.
  final List<String> _stderrTail = <String>[];
  StreamSubscription<List<int>>? _stderrSub;

  final _stateCtrl = StreamController<RecordState>.broadcast();

  @override
  Future<bool> hasPermission() async {
    // On Linux there is no per-app mic permission prompt (PipeWire/Pulse grant
    // at the session level), so capture is permitted by default. The hook is
    // injectable for tests / future OSes.
    final probe = _hasMicPermission;
    if (probe != null) return probe();
    return true;
  }

  /// Start the mixed loopback + mic capture, writing a single WAV to [path].
  /// The [encoder] arg is ignored — the meeting backend always produces WAV
  /// (pcm_s16le); it exists only to satisfy the [RecorderBackend] contract.
  @override
  Future<void> start(String path, {AudioEncoder encoder = AudioEncoder.wav}) async {
    if (_process != null) {
      throw StateError('MeetingRecorderBackend: capture already in progress');
    }

    final monitor = await _loopback.resolveMonitorSource();
    if (monitor == null) {
      throw const MeetingCaptureUnsupportedError(
        'no system-output monitor source available (loopback unsupported)',
      );
    }

    final args = buildFfmpegArgs(monitorSource: monitor, outputPath: path);
    final Process process;
    try {
      process = await _spawn('ffmpeg', args);
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'start: failed to launch ffmpeg',
        e,
        st,
      );
      throw MeetingCaptureUnsupportedError('failed to launch ffmpeg: $e');
    }

    _process = process;
    _outputPath = path;
    _stderrTail.clear();
    _stderrSub = process.stderr.listen((chunk) {
      // ffmpeg stderr is UTF-8; decode tolerantly so a chunk that splits a
      // multi-byte sequence at the buffer boundary never throws.
      final text = utf8.decode(chunk, allowMalformed: true);
      _stderrTail.add(text);
      // Bound the buffer — capture can run for the length of a meeting.
      if (_stderrTail.length > 50) _stderrTail.removeAt(0);
    });

    _stateCtrl.add(RecordState.record);
    AppLog.event(
      LogCat.action,
      'start: meeting capture started (monitor=$monitor)',
    );
  }

  /// Not supported — see class doc. A meeting is captured straight through.
  @override
  Future<void> pause() async {
    throw UnsupportedError(
      'MeetingRecorderBackend does not support pause (single-pass capture).',
    );
  }

  /// Not supported — see class doc.
  @override
  Future<void> resume() async {
    throw UnsupportedError(
      'MeetingRecorderBackend does not support resume (single-pass capture).',
    );
  }

  /// Stop the capture gracefully: ask ffmpeg to finalize the WAV (flush the
  /// header so the file is valid), then return the path.
  ///
  /// Escalation (so stop() ALWAYS returns — audit #828 warning #1): a bare
  /// `await exitCode` could hang forever if ffmpeg, spawned without a TTY, never
  /// reads the `q` from stdin. We instead try `q`, then race exit against a
  /// timeout and escalate SIGINT → SIGKILL, awaiting exit at each step under the
  /// same bounded race. The final SIGKILL await is also time-boxed so a wedged
  /// process can never pin the modal in "processing".
  @override
  Future<String?> stop() async {
    final process = _process;
    final path = _outputPath;
    if (process == null || path == null) {
      throw StateError('MeetingRecorderBackend: no capture in progress');
    }

    // `q` on stdin asks ffmpeg to stop cleanly and flush the container so the
    // WAV is well-formed.
    try {
      process.stdin.write('q');
      await process.stdin.flush();
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'stop: ffmpeg stdin q write failed (escalation will handle)',
        e,
        st,
      );
      // stdin already closed / unavailable — escalation below handles it.
    }

    // ffmpeg exits 0 on a clean `q` finalize; 255 is its conventional code for
    // an interrupted-but-finalized capture. Treat both as success. Once we have
    // to send a signal, the exit code reflects OUR intervention (e.g. 137 for
    // SIGKILL), not ffmpeg's own status — so [escalated] makes the on-disk file
    // the source of truth instead of the code.
    var escalated = false;
    var exitCode = await _awaitExitWithin(process, _stopGrace);
    if (exitCode == null) {
      // No clean exit on `q` — interrupt, give it the same grace, then SIGKILL.
      escalated = true;
      process.kill(ProcessSignal.sigint);
      exitCode = await _awaitExitWithin(process, _stopGrace);
    }
    if (exitCode == null) {
      process.kill(ProcessSignal.sigkill);
      exitCode = await _awaitExitWithin(process, _stopGrace);
    }
    await _teardown();

    final file = File(path);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    final exitLabel = exitCode?.toString() ?? 'timed-out';
    if (!exists || size == 0) {
      throw MeetingCaptureFailedError(
        'ffmpeg produced no audio (exit $exitLabel). ${_diagnostic()}',
      );
    }
    // Only fail on a *known* clean-path bad exit code. If we had to escalate
    // (SIGINT/SIGKILL), the process had already written a non-empty WAV, so we
    // accept the file rather than discard a real capture over a signal-derived
    // exit code (the alternative is the hang this escalation exists to kill).
    if (!escalated && exitCode != null && exitCode != 0 && exitCode != 255) {
      throw MeetingCaptureFailedError(
        'ffmpeg exited $exitCode. ${_diagnostic()}',
      );
    }
    _stateCtrl.add(RecordState.stop);
    AppLog.event(
      LogCat.action,
      'stop: meeting capture finalized (exit $exitLabel, escalated=$escalated, '
      '${size}B)',
    );
    return path;
  }

  /// Await [process] exit, but no longer than [grace]; returns the exit code, or
  /// null if the process had not exited within the window. Bounds every step of
  /// the stop() escalation so a wedged ffmpeg can never block the caller.
  Future<int?> _awaitExitWithin(Process process, Duration grace) async {
    try {
      return await process.exitCode.timeout(grace);
    } on TimeoutException {
      return null;
    }
  }

  /// Cancel + discard: kill ffmpeg and delete the partial WAV.
  @override
  Future<void> cancel() async {
    final process = _process;
    final path = _outputPath;
    AppLog.event(LogCat.action, 'cancel: kill ffmpeg + discard partial');
    if (process != null) {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode;
      } catch (e, st) {
        AppLog.error(
          LogCat.error,
          'cancel: awaiting ffmpeg exit failed',
          e,
          st,
        );
        // best effort
      }
    }
    await _teardown();
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e, st) {
        AppLog.error(
          LogCat.error,
          'cancel: deleting partial WAV failed',
          e,
          st,
        );
        // best effort
      }
    }
    _stateCtrl.add(RecordState.stop);
  }

  /// ffmpeg does not stream amplitude back cheaply; emit a steady mid-level
  /// value so the existing waveform UI animates without faking peaks. The
  /// meeting UI treats the waveform as a "capturing" liveness indicator.
  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    return Stream<Amplitude>.periodic(
      interval,
      (i) {
        if (_process == null) return Amplitude(current: -160, max: 0);
        // Gentle deterministic oscillation (-30..-15 dBFS) for a live look.
        final db = -30.0 + 7.5 * (1 + sin(i / 3));
        return Amplitude(current: db, max: 0);
      },
    );
  }

  @override
  Stream<RecordState> onStateChanged() => _stateCtrl.stream;

  @override
  Future<void> dispose() async {
    if (_process != null) {
      try {
        await cancel();
      } catch (e, st) {
        AppLog.error(LogCat.error, 'dispose: cancel failed', e, st);
        // best effort
      }
    }
    await _stateCtrl.close();
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  Future<void> _teardown() async {
    await _stderrSub?.cancel();
    _stderrSub = null;
    _process = null;
    _outputPath = null;
  }

  String _diagnostic() {
    final tail = _stderrTail.join().trim();
    if (tail.isEmpty) return '';
    final lines = tail.split('\n');
    final last = lines.length > 3 ? lines.sublist(lines.length - 3) : lines;
    return last.join(' ').trim();
  }

  /// Build the ffmpeg argument vector that mixes the [monitorSource] (system
  /// output / loopback) with the default microphone into a single WAV at
  /// [outputPath]. Pure + static so the exact capture command is unit-testable.
  ///
  ///   ffmpeg -y
  ///     -f pulse -i `<sink>.monitor`   # loopback (remote participants)
  ///     -f pulse -i default            # microphone (me)
  ///     -filter_complex amix=inputs=2:duration=longest:normalize=0
  ///     -ac 1 -ar 48000 -c:a pcm_s16le
  ///     `<outputPath>`
  ///
  /// `normalize=0` keeps each source at unity gain (no auto-attenuation when one
  /// side is silent), so neither voice is dimmed. `duration=longest` keeps the
  /// capture running until stop, not until the shorter input ends.
  static List<String> buildFfmpegArgs({
    required String monitorSource,
    required String outputPath,
    String micSource = 'default',
  }) {
    return [
      '-hide_banner',
      '-y',
      '-f', 'pulse', '-i', monitorSource,
      '-f', 'pulse', '-i', micSource,
      '-filter_complex', 'amix=inputs=2:duration=longest:normalize=0',
      // Mono: the mix is for transcription, not stereo playback — halves the WAV
      // size with no transcription-relevant loss (both sources collapse to one
      // channel that Core ingests identically).
      '-ac', '1',
      '-ar', '48000',
      '-c:a', 'pcm_s16le',
      outputPath,
    ];
  }
}

/// Thrown when the host cannot do loopback meeting capture (off Linux, no
/// monitor source, ffmpeg missing/failed to launch). Parallels
/// [AudioCaptureUnsupportedError] for the mic-only path.
class MeetingCaptureUnsupportedError implements Exception {
  const MeetingCaptureUnsupportedError([this.reason]);
  final String? reason;
  @override
  String toString() => 'MeetingCaptureUnsupportedError: '
      'loopback meeting capture is not available on this host'
      '${reason == null ? '' : ' ($reason)'}.';
}

/// Thrown when ffmpeg ran but failed to produce a usable WAV.
class MeetingCaptureFailedError implements Exception {
  const MeetingCaptureFailedError(this.reason);
  final String reason;
  @override
  String toString() => 'MeetingCaptureFailedError: $reason';
}
