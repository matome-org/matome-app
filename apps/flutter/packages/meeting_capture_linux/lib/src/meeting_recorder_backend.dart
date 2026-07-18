// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meeting_capture/meeting_capture.dart';

import 'meeting_loopback_source.dart';

typedef FfmpegSpawner =
    Future<Process> Function(String executable, List<String> arguments);
typedef MeetingStagingPreparer = Future<void> Function(String path);

Future<Process> _defaultFfmpegSpawner(
  String executable,
  List<String> arguments,
) => Process.start(executable, arguments);

Future<void> _defaultPrepareStaging(String path) async {
  final directory = File(path).parent.path;
  final secureDirectory = await runBoundedCommand('chmod', ['700', directory]);
  if (secureDirectory.exitCode != 0) {
    throw FileSystemException('Could not secure meeting directory', directory);
  }
  await File(path).create(exclusive: true);
  final chmod = await runBoundedCommand('chmod', ['600', path]);
  if (chmod.exitCode != 0) {
    throw FileSystemException('Could not secure meeting staging file', path);
  }
}

class MeetingRecorderBackend implements MeetingCaptureBackend {
  MeetingRecorderBackend({
    MeetingLoopbackSource? loopback,
    FfmpegSpawner spawn = _defaultFfmpegSpawner,
    MeetingStagingPreparer prepareStaging = _defaultPrepareStaging,
    Duration startupGrace = const Duration(seconds: 5),
    Duration stopGrace = const Duration(seconds: 5),
    Duration devicePollInterval = const Duration(seconds: 2),
  }) : _loopback = loopback ?? const MeetingLoopbackSource(),
       _spawn = spawn,
       _prepareStaging = prepareStaging,
       _startupGrace = startupGrace,
       _stopGrace = stopGrace,
       _devicePollInterval = devicePollInterval;

  final MeetingLoopbackSource _loopback;
  final FfmpegSpawner _spawn;
  final MeetingStagingPreparer _prepareStaging;
  final Duration _startupGrace;
  final Duration _stopGrace;
  final Duration _devicePollInterval;
  final _events = StreamController<MeetingCaptureEvent>.broadcast();

  Process? _process;
  MeetingCaptureRequest? _request;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<void>? _stdoutDone;
  Completer<void>? _stderrDone;
  bool _terminationExpected = false;
  bool _disposed = false;
  final List<String> _diagnostics = [];
  Timer? _deviceTimer;
  Future<void>? _devicePollInFlight;
  LinuxMeetingDevices? _devices;
  bool _deviceLossReported = false;

  @override
  String get backendId => 'linux-ffmpeg-pulse';

  @override
  Stream<MeetingCaptureEvent> get events => _events.stream;

  @override
  Future<MeetingCaptureCapability> probe() async {
    final result = await _loopback.probe();
    if (result.supported) {
      return MeetingCaptureCapability.supported(backendId: backendId);
    }
    return MeetingCaptureCapability.unsupported(
      backendId: backendId,
      reason: result.reason ?? 'probe-failed',
    );
  }

  @override
  Future<MeetingCapturePermission> requestPermission() async =>
      MeetingCapturePermission.granted;

  @override
  Future<void> start(MeetingCaptureRequest request) async {
    if (_disposed) throw StateError('Meeting backend is disposed');
    if (_process != null) throw StateError('Meeting capture is already active');
    final devices = await _loopback.resolveDevices();
    if (devices == null) {
      throw const MeetingCaptureUnsupportedError('audio-devices-unavailable');
    }
    await _prepareStaging(request.stagingPath);
    final process = await _spawn(
      'ffmpeg',
      buildFfmpegArgs(
        request: request,
        monitorSource: devices.monitorSource,
        microphoneSource: devices.microphoneSource,
      ),
    );
    _process = process;
    _request = request;
    _devices = devices;
    _deviceLossReported = false;
    _terminationExpected = false;
    _diagnostics.clear();
    _stdoutDone = Completer<void>();
    _stderrDone = Completer<void>();
    final systemReady = Completer<void>();
    final microphoneReady = Completer<void>();
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {}, onDone: _stdoutDone!.complete);
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _handleFfmpegLine(line, systemReady, microphoneReady),
          onDone: _stderrDone!.complete,
        );
    unawaited(_watchUnexpectedExit(process));
    try {
      await Future.any<void>([
        Future.wait([
          systemReady.future,
          microphoneReady.future,
        ]).then<void>((_) {}),
        process.exitCode.then<void>((code) {
          throw MeetingCaptureProcessError(
            'ffmpeg exited during start: $code ${_diagnostics.join(' ')}',
          );
        }),
      ]).timeout(_startupGrace);
    } catch (error) {
      await _terminate(allowGraceful: false);
      if (error is TimeoutException) {
        throw MeetingCaptureProcessError(
          'ffmpeg input readiness timed out '
          '(system=${systemReady.isCompleted}, '
          'microphone=${microphoneReady.isCompleted}): '
          '${_diagnostics.join(' ')}',
        );
      }
      rethrow;
    }
    _events.add(const MeetingCaptureEvent.state(MeetingCaptureState.recording));
    _deviceTimer = Timer.periodic(_devicePollInterval, (_) {
      if (_devicePollInFlight != null) return;
      final poll = _pollDevices();
      _devicePollInFlight = poll;
      unawaited(poll.whenComplete(() => _devicePollInFlight = null));
    });
  }

  @override
  Future<MeetingCaptureCandidate> stop() async {
    final request = _request;
    if (_process == null || request == null) {
      throw StateError('No meeting capture is active');
    }
    final forced = await _terminate(allowGraceful: true);
    if (forced) {
      throw const MeetingCaptureProcessError(
        'ffmpeg required SIGKILL and may not have finalized the artifact',
      );
    }
    _events.add(const MeetingCaptureEvent.state(MeetingCaptureState.completed));
    return MeetingCaptureCandidate(path: request.stagingPath);
  }

  @override
  Future<void> cancel() async {
    if (_process != null) await _terminate(allowGraceful: false);
    _events.add(const MeetingCaptureEvent.state(MeetingCaptureState.cancelled));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_process != null) await _terminate(allowGraceful: false);
    _disposed = true;
    await _events.close();
  }

  Future<bool> _terminate({required bool allowGraceful}) async {
    final process = _process;
    if (process == null) return false;
    _terminationExpected = true;
    _deviceTimer?.cancel();
    _deviceTimer = null;
    try {
      await _devicePollInFlight?.timeout(_stopGrace);
    } on TimeoutException {
      // Process termination remains authoritative if a device probe is wedged.
    }
    var forced = false;
    int? exitCode;
    if (allowGraceful) {
      process.kill(ProcessSignal.sigint);
      exitCode = await _awaitExit(process, _stopGrace);
    }
    if (exitCode == null) {
      process.kill(ProcessSignal.sigterm);
      exitCode = await _awaitExit(process, _stopGrace);
    }
    if (exitCode == null) {
      forced = true;
      process.kill(ProcessSignal.sigkill);
      exitCode = await _awaitExit(process, _stopGrace);
    }
    if (exitCode == null) {
      throw const MeetingCaptureProcessError(
        'ffmpeg termination could not be confirmed',
      );
    }
    await Future.wait([
      _stdoutDone?.future ?? Future<void>.value(),
      _stderrDone?.future ?? Future<void>.value(),
    ]).timeout(_stopGrace);
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _stdoutDone = null;
    _stderrDone = null;
    _process = null;
    _request = null;
    _devices = null;
    if (allowGraceful && !forced && exitCode != 0 && exitCode != 255) {
      throw MeetingCaptureProcessError('ffmpeg exited $exitCode');
    }
    return forced;
  }

  Future<int?> _awaitExit(Process process, Duration timeout) async {
    try {
      return await process.exitCode.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _watchUnexpectedExit(Process process) async {
    final code = await process.exitCode;
    if (_terminationExpected || _process != process || _disposed) return;
    _events.add(MeetingCaptureEvent.failed(message: 'ffmpeg-exited:$code'));
  }

  Future<void> _pollDevices() async {
    final devices = _devices;
    if (devices == null || _terminationExpected || _deviceLossReported) return;
    final availability = await _loopback.availability(devices);
    if (_terminationExpected || _devices != devices || _deviceLossReported) {
      return;
    }
    if (availability == null) {
      _deviceLossReported = true;
      _events.add(
        const MeetingCaptureEvent.failed(message: 'device-probe-failed'),
      );
      return;
    }
    if (!availability.system) {
      _deviceLossReported = true;
      _events.add(
        const MeetingCaptureEvent.unavailable(
          source: MeetingCaptureSource.system,
          message: 'system-device-lost',
        ),
      );
    }
    if (!availability.microphone) {
      _deviceLossReported = true;
      _events.add(
        const MeetingCaptureEvent.unavailable(
          source: MeetingCaptureSource.microphone,
          message: 'microphone-device-lost',
        ),
      );
    }
  }

  void _handleFfmpegLine(
    String line,
    Completer<void> systemReady,
    Completer<void> microphoneReady,
  ) {
    final source = line.contains('[ebur128@system ')
        ? MeetingCaptureSource.system
        : line.contains('[ebur128@microphone ')
        ? MeetingCaptureSource.microphone
        : null;
    final level = parseMeterLevel(line);
    if (source == null || level == null) {
      if (line.trim().isNotEmpty) {
        _diagnostics.add(line.trim());
        if (_diagnostics.length > 20) _diagnostics.removeAt(0);
      }
      return;
    }
    final ready = source == MeetingCaptureSource.system
        ? systemReady
        : microphoneReady;
    if (!ready.isCompleted) ready.complete();
    _events.add(MeetingCaptureEvent.level(source: source, levelDb: level));
  }

  static double? parseMeterLevel(String line) {
    const prefix = 'lavfi.astats.Overall.RMS_level=';
    final index = line.indexOf(prefix);
    final raw = index >= 0
        ? line.substring(index + prefix.length).trim()
        : RegExp(
            r'\bM:\s*(-?(?:\d+(?:\.\d+)?|inf))',
          ).firstMatch(line)?.group(1);
    if (raw == null) return null;
    if (raw == '-inf') return -160;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) return null;
    return value.clamp(-160, 0).toDouble();
  }

  static List<String> buildFfmpegArgs({
    required MeetingCaptureRequest request,
    required String monitorSource,
    required String microphoneSource,
  }) {
    final filter = buildAudioFilter(request);
    return [
      '-hide_banner',
      '-loglevel',
      'info',
      '-nostats',
      '-y',
      '-thread_queue_size',
      '512',
      '-f',
      'pulse',
      '-i',
      monitorSource,
      '-thread_queue_size',
      '512',
      '-f',
      'pulse',
      '-i',
      microphoneSource,
      '-filter_complex',
      filter,
      '-map',
      '[mixed]',
      '-vn',
      '-sn',
      '-dn',
      '-ac',
      request.channels.toString(),
      '-ar',
      request.sampleRate.toString(),
      '-c:a',
      'aac',
      '-profile:a',
      'aac_low',
      '-b:a',
      request.bitrate.toString(),
      '-movflags',
      '+faststart',
      '-f',
      'ipod',
      request.stagingPath,
    ];
  }

  static String buildAudioFilter(MeetingCaptureRequest request) {
    final systemGain = request.mix.systemGainDb;
    final microphoneGain = request.mix.microphoneGainDb;
    final limiter = _dbToLinear(request.mix.limiterCeilingDb);
    return '[0:a]aresample=${request.sampleRate}:async=1:first_pts=0,'
        'aformat=sample_fmts=fltp:channel_layouts=mono,'
        'asplit=2[sysmix][sysmeter];'
        '[1:a]aresample=${request.sampleRate}:async=1:first_pts=0,'
        'aformat=sample_fmts=fltp:channel_layouts=mono,'
        'asplit=2[micmix][micmeter];'
        '[sysmeter]ebur128@system=peak=true,anullsink;'
        '[micmeter]ebur128@microphone=peak=true,anullsink;'
        '[sysmix]volume=${systemGain}dB[sysgain];'
        '[micmix]volume=${microphoneGain}dB[micgain];'
        '[sysgain][micgain]amix=inputs=2:duration=longest:'
        'dropout_transition=0:normalize=0,'
        'alimiter=limit=$limiter:level=disabled[mixed]';
  }

  static String _dbToLinear(double db) {
    if (db == -1) return '0.891250938';
    throw ArgumentError.value(
      db,
      'limiterCeilingDb',
      'Only -1 dB is supported',
    );
  }
}

class MeetingCaptureProcessError implements Exception {
  const MeetingCaptureProcessError(this.reason);
  final String reason;

  @override
  String toString() => 'MeetingCaptureProcessError: $reason';
}
