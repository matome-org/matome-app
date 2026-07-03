import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:record/record.dart';

import '../../core/audio/audio_playback.dart';
import '../../core/db/daos/recording_drafts_dao.dart';
import '../../core/observability/app_log.dart';
import '../../core/storage/app_storage.dart';
import 'recorder_backend.dart';

/// Direct port of `apps/mobile/services/audioRecordingService.ts` (1070 lines)
/// onto Flutter's [AudioRecorder] (`record` package). It proves the F3 de-risk:
/// a single native recorder with a true pause()/resume() cycle yields ONE
/// continuous file per session (no audio lost on pause), with durable segment
/// snapshots + a Drift draft for crash recovery.
///
/// ---------------------------------------------------------------------------
/// PAUSE/RESUME MODEL — the key de-risk finding
/// ---------------------------------------------------------------------------
/// `record`'s [AudioRecorder.pause] suspends capture while keeping the SAME
/// underlying output file open; [AudioRecorder.resume] continues appending to
/// that same file. This mirrors expo-audio's native AudioRecorder exactly, so
/// the mobile app's single-file model ports 1:1 — Finish ([stop]) returns one
/// file containing every pause/resume span. No segment-merge / native muxing is
/// needed for an in-app session.
///
/// The only multi-segment case is a cross-restart recovered draft (the live
/// recorder is gone, so a resumed span is a genuinely separate file). That edge
/// keeps the mobile app's documented behaviour: [mergeSegments] returns the last
/// span as the playable audio (independent containers can't be byte-concatenated
/// without a native muxer — out of scope), while every span path is preserved so
/// a transcription layer could cover them all.
///
/// ---------------------------------------------------------------------------
/// PER-PLATFORM MIC SUPPORT
/// ---------------------------------------------------------------------------
///   * Android / iOS — fully supported (MediaRecorder / AVAudioRecorder), true
///     single-file pause/resume.
///   * Web — supported via MediaRecorder over a secure origin (https/localhost);
///     pause/resume map to MediaRecorder.pause()/resume() on one Blob.
///   * Linux desktop — `record_linux` shells out to the external `fmedia`
///     binary. If `fmedia` is not installed, capture is unavailable; the service
///     degrades gracefully ([isCaptureSupported] returns false; [start] throws a
///     clear [AudioCaptureUnsupportedError]) and never fakes audio.
class AudioRecordingService {
  AudioRecordingService({
    required RecordingDraftsDao draftsDao,
    RecorderBackend? recorder,
    Future<Directory> Function()? documentsDirProvider,
    Future<int?> Function(String path)? durationProbe,
    Future<bool> Function()? captureSupportedProbe,
    this.segmentExtension = 'm4a',
  }) : _recorder = recorder ?? RecordRecorderBackend(),
       _documentsDirProvider = documentsDirProvider ?? matomeStorageDir,
       _durationProbe = durationProbe ?? _probeDurationMs,
       // ignore: prefer_initializing_formals
       _captureSupportedProbe = captureSupportedProbe,
       // ignore: prefer_initializing_formals
       _draftsDao = draftsDao;

  final RecordingDraftsDao _draftsDao;
  final RecorderBackend _recorder;
  final Future<Directory> Function() _documentsDirProvider;
  final Future<int?> Function(String path) _durationProbe;
  final Future<bool> Function()? _captureSupportedProbe;

  /// Container extension the active backend writes (no leading dot). The mic
  /// path keeps `m4a`; the meeting (ffmpeg loopback) backend writes `wav`. It
  /// drives both the live filename handed to [RecorderBackend.start] and the
  /// durable segment copies, so the file the F4 pipeline uploads carries the
  /// correct extension for `mediaTypeForPath`.
  final String segmentExtension;

  // --- per-session module state (reset on every startRecording) -------------

  /// Path of the single live session file (owned by the native recorder).
  String? _liveFilePath;

  /// Ordered durable segment snapshots for the current session. The single-file
  /// model keeps this at length 1 (the latest pause snapshot, then the finalized
  /// file). A recovered draft may seed >1 spans.
  List<String> _sessionSegments = const [];

  /// True once this session has been paused at least once → the finalized file
  /// is the COMPLETE continuous audio and supersedes any pause snapshot.
  bool _isContinuousSession = false;

  /// Accumulated duration (ms) from the last amplitude/status poll. Held across
  /// pause so the UI timer doesn't reset.
  int _lastDurationMs = 0;

  Timer? _durationTimer;
  DateTime? _runStartedAt;
  int _runBaseMs = 0;

  // --------------------------------------------------------------------------
  // Capability + permissions
  // --------------------------------------------------------------------------

  /// Whether audio capture is available on this platform/host. Android, iOS and
  /// web are supported; Linux requires the external `fmedia` binary. An injected
  /// [_captureSupportedProbe] overrides the detection (used in tests).
  Future<bool> isCaptureSupported() async {
    final probe = _captureSupportedProbe;
    if (probe != null) return probe();
    try {
      if (Platform.isAndroid || Platform.isIOS) return true;
    } catch (_) {
      // Platform throws on web; fall through — web is supported.
      return true;
    }
    try {
      if (Platform.isLinux) {
        return await _hasFmedia();
      }
    } catch (_) {
      return true;
    }
    // macOS / Windows: record has a native backend.
    return true;
  }

  static Future<bool> _hasFmedia() async {
    try {
      final result = await Process.run('which', ['fmedia']);
      return result.exitCode == 0;
    } catch (e, st) {
      AppLog.error(LogCat.error, '_hasFmedia: which fmedia failed', e, st);
      return false;
    }
  }

  /// Request microphone permission. Mirrors RN `requestPermissions`.
  Future<bool> requestPermissions() async {
    try {
      return await _recorder.hasPermission();
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'requestPermissions: permission check failed',
        e,
        st,
      );
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // Lifecycle: start / pause / resume / stop
  // --------------------------------------------------------------------------

  /// Start a fresh recording session. Resets ALL per-session state up front so a
  /// back-to-back session can never inherit stale segments/flags. Mirrors RN
  /// `startRecording`. Does NOT delete any files — a recovered-draft resume may
  /// re-seed segments via [restoreSegments] right after.
  Future<void> startRecording() async {
    _sessionSegments = const [];
    _liveFilePath = null;
    _isContinuousSession = false;
    _lastDurationMs = 0;
    _runBaseMs = 0;
    _cancelDurationTimer();

    if (!await isCaptureSupported()) {
      throw const AudioCaptureUnsupportedError();
    }
    if (!await requestPermissions()) {
      throw const MicrophonePermissionDeniedError();
    }

    final dir = await _documentsDirProvider();
    final path = '${dir.path}/${_segmentFileName()}';

    await _recorder.start(path);
    _liveFilePath = path;
    _startDurationTimer();
    AppLog.event(LogCat.action, 'startRecording: started session');
  }

  /// Pause the active recording WITHOUT splitting the file. `record`'s native
  /// pause keeps the single underlying file open for [resumeRecording]. A
  /// durable snapshot of the in-progress file is copied to documentDirectory for
  /// crash recovery and persisted as the draft. Mirrors RN `pauseRecording`.
  ///
  /// Returns the snapshot URI (also the value stored in the draft).
  Future<String> pauseRecording() async {
    final live = _liveFilePath;
    if (live == null) {
      throw StateError('No recording in progress');
    }

    await _recorder.pause();
    _isContinuousSession = true;
    _freezeDuration();

    // Durable snapshot for kill-while-paused recovery. Best-effort: pause has
    // already succeeded, so a copy failure still leaves a resumable session.
    String snapshot = live;
    try {
      final dir = await _documentsDirProvider();
      snapshot = '${dir.path}/${_segmentFileName()}';
      await File(live).copy(snapshot);
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'pauseRecording: durable snapshot copy failed',
        e,
        st,
      );
      snapshot = live;
    }

    // Replace (not append): the single live file is the source of truth; keep
    // only the latest snapshot. Delete any prior snapshot from this session.
    final previous = _sessionSegments;
    _sessionSegments = [snapshot];
    await _safeDeleteAll(previous.where((p) => p != snapshot));

    // Autosave draft to Drift on pause (F2). Crash recovery reads this back.
    await _draftsDao.saveDraft(_sessionSegments, _lastDurationMs);
    AppLog.event(LogCat.action, 'pauseRecording: paused + draft saved');

    return snapshot;
  }

  /// Resume a paused recording — continues appending to the SAME file. Mirrors
  /// RN `resumeRecording`.
  Future<void> resumeRecording() async {
    if (_liveFilePath == null) {
      throw StateError('No paused recording to resume');
    }
    await _recorder.resume();
    _startDurationTimer();
    AppLog.event(LogCat.action, 'resumeRecording: resumed session');
  }

  /// Stop the recorder, persist the finalized file as a durable segment, and
  /// return its path. Mirrors RN `stopRecording`.
  ///
  /// If the session was paused/resumed (continuous), the finalized file is the
  /// COMPLETE audio and supersedes any pause snapshot — the session resolves to
  /// exactly one file. Otherwise (recovered-draft straight-through span) the new
  /// span is APPENDED, preserving restored spans.
  Future<String> stopRecording() async {
    if (_liveFilePath == null) {
      throw StateError('No recording in progress');
    }
    _cancelDurationTimer();

    final stoppedPath = await _recorder.stop();
    final live = stoppedPath ?? _liveFilePath!;
    _liveFilePath = null;

    final wasContinuous = _isContinuousSession;
    final superseded = wasContinuous
        ? List<String>.from(_sessionSegments)
        : const <String>[];
    _isContinuousSession = false;

    // Copy to a uniquely named durable segment so it survives restarts and OS
    // cache eviction.
    final dir = await _documentsDirProvider();
    final segmentPath = '${dir.path}/${_segmentFileName()}';
    await File(live).copy(segmentPath);

    if (wasContinuous) {
      _sessionSegments = [segmentPath];
      await _safeDeleteAll(superseded);
    } else {
      _sessionSegments = [..._sessionSegments, segmentPath];
    }
    AppLog.event(
      LogCat.action,
      'stopRecording: finalized (continuous=$wasContinuous, '
      'segments=${_sessionSegments.length})',
    );
    return segmentPath;
  }

  // --------------------------------------------------------------------------
  // Metering / duration
  // --------------------------------------------------------------------------

  /// Amplitude stream (dBFS) for the waveform, polled at [interval] (~80ms to
  /// match the RN metering poll). Maps `record`'s {current, max} to `current`.
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 80),
  }) {
    return _recorder.onAmplitudeChanged(interval);
  }

  /// Recorder state stream (record / pause / stop).
  Stream<RecordState> stateStream() => _recorder.onStateChanged();

  /// Current accumulated duration in seconds (held across pause). Mirrors RN
  /// `getRecordingDuration`.
  double get recordingDurationSeconds => _currentDurationMs() / 1000.0;

  void _startDurationTimer() {
    _runStartedAt = DateTime.now();
    _runBaseMs = _lastDurationMs;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _lastDurationMs = _currentDurationMs(),
    );
  }

  int _currentDurationMs() {
    final started = _runStartedAt;
    if (started == null) return _lastDurationMs;
    return _runBaseMs + DateTime.now().difference(started).inMilliseconds;
  }

  void _freezeDuration() {
    _lastDurationMs = _currentDurationMs();
    _cancelDurationTimer();
  }

  void _cancelDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _runStartedAt = null;
  }

  // --------------------------------------------------------------------------
  // Segments / draft / merge / discard
  // --------------------------------------------------------------------------

  /// All session segment paths (defensive copy). Mirrors RN `getSegments`.
  List<String> getSegments() => List.unmodifiable(_sessionSegments);

  /// Snapshot of EVERY on-disk path this session owns right now: the resolved
  /// segments PLUS any paths the live draft still references (a continuous
  /// session's draft can name a superseded pause snapshot the finalized file
  /// replaced). Taken at finish() time and handed to [discardSegmentPaths] as
  /// the immutable cleanup set, so the deferred confirm hook deletes only this
  /// session's files and recognizes this session's draft for deletion — even
  /// after a back-to-back session has taken over the live state.
  Future<List<String>> snapshotSessionCleanupPaths() async {
    final paths = <String>{..._sessionSegments};
    try {
      final draft = await _draftsDao.loadDraft();
      if (draft != null) paths.addAll(draft.segments);
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'snapshotSessionCleanupPaths: draft load failed',
        e,
        st,
      );
      // best effort — a missing/corrupt draft just means fewer paths to bind.
    }
    return paths.toList(growable: false);
  }

  /// Whether a live recorder currently exists (recording or paused). Lets Finish
  /// decide between finalizing the live recorder vs. a recovered draft.
  bool get isRecorderActive => _liveFilePath != null;

  /// Seed [_sessionSegments] from a recovered draft's persisted span paths.
  /// Idempotent (replaces wholesale). Mirrors RN `restoreSegments`.
  void restoreSegments(List<String> paths) {
    _sessionSegments = List<String>.from(paths);
  }

  /// Detect a recoverable draft at startup. Returns it (or null). Mirrors the RN
  /// NavigationGuard draft-detection: a draft with at least one still-existing
  /// segment file is recoverable; otherwise it's swept (stale) and null returned.
  Future<RecordingDraft?> detectRecoverableDraft() async {
    final draft = await _draftsDao.loadDraft();
    if (draft == null) return null;
    if (draft.segments.isEmpty) {
      await _draftsDao.deleteDraft();
      return null;
    }
    final existing = <String>[];
    for (final seg in draft.segments) {
      if (await File(seg).exists()) existing.add(seg);
    }
    if (existing.isEmpty) {
      // Stale draft — files gone (e.g. OS cleared cache). Discard it.
      await _draftsDao.deleteDraft();
      AppLog.event(
        LogCat.action,
        'detectRecoverableDraft: swept stale draft (no files)',
      );
      return null;
    }
    AppLog.event(
      LogCat.action,
      'detectRecoverableDraft: recoverable (${existing.length} segment(s))',
    );
    return RecordingDraft(segments: existing, durationMs: draft.durationMs);
  }

  /// Resume a recovered draft: seed its spans so Finish can save from segments.
  /// The accumulated duration is restored too. Mirrors the RN resume flow.
  Future<void> resumeFromDraft(RecordingDraft draft) async {
    restoreSegments(draft.segments);
    _lastDurationMs = draft.durationMs;
    _runBaseMs = draft.durationMs;
    AppLog.event(
      LogCat.action,
      'resumeFromDraft: restored ${draft.segments.length} segment(s)',
    );
  }

  /// Resolve the session audio file. Single segment → that file (the complete
  /// continuous audio). 2+ segments (recovered draft) → the LAST span (see
  /// class doc on why containers can't be byte-merged). Mirrors RN
  /// `mergeSegments`.
  Future<String> mergeSegments() async {
    if (_sessionSegments.isEmpty) {
      throw StateError('mergeSegments: no segments to merge');
    }
    return _sessionSegments.last;
  }

  /// Delete all segment files from disk AND the draft (privacy). Safe to call
  /// when nothing exists. Mirrors RN `discardSegments` + draft delete.
  ///
  /// WARNING — this operates on the LIVE `_sessionSegments` / draft. It is the
  /// right call for an interactive discard/cancel (the user is acting on the
  /// CURRENT session), but it must NOT be used as a deferred/post-upload confirm
  /// hook: by the time an async upload confirms, a back-to-back session may have
  /// replaced `_sessionSegments` and the draft, so this would wipe the NEW
  /// recording. Use [discardSegmentPaths] with a snapshot for that.
  Future<void> discardSegments() async {
    final toDelete = List<String>.from(_sessionSegments);
    _sessionSegments = const [];
    _liveFilePath = null;
    AppLog.event(
      LogCat.action,
      'discardSegments: deleting ${toDelete.length} segment(s) + draft',
    );
    await _safeDeleteAll(toDelete);
    await _draftsDao.deleteDraft();
  }

  /// Clear ONLY the crash-recovery draft row for THIS finished session, leaving
  /// every segment file on disk untouched (plan #46 W2 retention).
  ///
  /// This is the split half of [discardSegments]: a confirmed finish has a
  /// durable saved+uploaded recording, so its draft must be cleared (otherwise
  /// [detectRecoverableDraft] would prompt the user to "recover" an
  /// already-saved recording on next launch). But the segment files MUST survive
  /// — with the single-file finish flow the durable `audioFilePath` IS one of
  /// the segments, so deleting them would wipe the local-first copy.
  ///
  /// [sessionPaths] is the snapshot ([snapshotSessionCleanupPaths]) taken at
  /// finish() time. The draft is dropped ONLY if it still describes THIS session
  /// (every draft segment is in the snapshot) — mirroring [discardSegmentPaths]'s
  /// ownership check — so a back-to-back session B that has already saved its own
  /// crash-recovery draft is left untouched. Best-effort: never throws (clearing
  /// the draft must not regress a confirmed finish).
  Future<void> clearDraftForSession(List<String> sessionPaths) async {
    final snapshot = sessionPaths.toSet();
    try {
      final draft = await _draftsDao.loadDraft();
      if (draft == null) return;
      final ownedByThisSession =
          draft.segments.isNotEmpty && draft.segments.every(snapshot.contains);
      if (ownedByThisSession) {
        await _draftsDao.deleteDraft();
      }
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'clearDraftForSession: draft clear failed',
        e,
        st,
      );
      // best effort — never throw on draft clear.
    }
  }

  /// Discard a SPECIFIC, previously-captured set of segment [paths] — the
  /// snapshot taken at finish() time — instead of the live `_sessionSegments`.
  ///
  /// This is the safe form for a deferred post-upload confirm hook: an upload
  /// for session A can confirm WHILE session B is already capturing on the same
  /// singleton recorder. Deleting the live segments then would destroy B's
  /// in-progress audio + B's draft. By binding to the captured snapshot we only
  /// ever delete A's own files.
  ///
  /// The draft is deleted ONLY if it still belongs to this finished session —
  /// i.e. every segment the current draft references is contained in [paths].
  /// If the draft has migrated to a newer session (any segment NOT in [paths]),
  /// it is left untouched so B's crash-recovery draft survives. Best-effort and
  /// never throws (cleanup must not regress a confirmed upload).
  Future<void> discardSegmentPaths(List<String> paths) async {
    final snapshot = paths.toSet();
    await _safeDeleteAll(snapshot);

    // Only drop the draft if it still describes THIS session's snapshot. A
    // newer session's draft (segments outside the snapshot) must survive.
    try {
      final draft = await _draftsDao.loadDraft();
      if (draft == null) return;
      final ownedByThisSession =
          draft.segments.isNotEmpty && draft.segments.every(snapshot.contains);
      if (ownedByThisSession) {
        await _draftsDao.deleteDraft();
      }
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        'discardSegmentPaths: draft clear failed',
        e,
        st,
      );
      // best effort — never throw on cleanup.
    }
  }

  /// Stop any active recorder, discard all segments + draft, reset state.
  /// Mirrors RN `cancelRecording`.
  Future<void> cancelRecording() async {
    _cancelDurationTimer();
    AppLog.event(LogCat.action, 'cancelRecording: cancel + discard');
    if (_liveFilePath != null) {
      try {
        await _recorder.cancel();
      } catch (e, st) {
        AppLog.error(
          LogCat.error,
          'cancelRecording: recorder cancel failed',
          e,
          st,
        );
        // best effort
      }
      _liveFilePath = null;
      _isContinuousSession = false;
      _lastDurationMs = 0;
    }
    await discardSegments();
  }

  /// Release the native recorder + timer WITHOUT touching persisted segments or
  /// the draft (so a paused session survives for recovery). Mirrors RN
  /// `releaseRecorder`. Idempotent.
  Future<void> releaseRecorder() async {
    _cancelDurationTimer();
    if (_liveFilePath != null) {
      try {
        await _recorder.stop();
      } catch (e, st) {
        AppLog.error(
          LogCat.error,
          'releaseRecorder: recorder stop failed',
          e,
          st,
        );
        // best effort
      }
      _liveFilePath = null;
      _isContinuousSession = false;
    }
  }

  /// Free native resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    _cancelDurationTimer();
    await _recorder.dispose();
  }

  // --------------------------------------------------------------------------
  // Helpers (pure / IO)
  // --------------------------------------------------------------------------

  Future<void> _safeDeleteAll(Iterable<String> paths) async {
    await Future.wait(
      paths.map((p) async {
        try {
          final f = File(p);
          if (await f.exists()) await f.delete();
        } catch (e, st) {
          AppLog.error(
            LogCat.error,
            '_safeDeleteAll: failed to delete segment file',
            e,
            st,
          );
          // best effort — never throw on cleanup.
        }
      }),
    );
  }

  /// Read the true (summed) duration off a finalized audio file. Mirrors RN
  /// `getAudioDurationSeconds`. Returns 0 on failure.
  Future<double> getAudioDurationSeconds(String path) async {
    final ms = await _durationProbe(path);
    return (ms ?? 0) / 1000.0;
  }

  /// Default duration probe. Goes through the platform-swappable
  /// [AudioPlayback] abstraction (#870) so it works on Linux/Windows desktop
  /// too — `just_audio` 0.9.x has no desktop backend, so the old direct
  /// `AudioPlayer().setFilePath` silently returned a null duration there.
  static Future<int?> _probeDurationMs(String path) async {
    final player = createAudioPlayback();
    try {
      final dur = await player.setFilePath(path);
      return dur?.inMilliseconds;
    } catch (e, st) {
      AppLog.error(
        LogCat.error,
        '_probeDurationMs: duration probe failed',
        e,
        st,
      );
      return null;
    } finally {
      await player.dispose();
    }
  }

  static final Random _rng = Random();

  static String _randSuffix(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  String _segmentFileName() =>
      'segment_${DateTime.now().millisecondsSinceEpoch}_${_randSuffix(6)}.$segmentExtension';

  /// Format duration in seconds → "2m 14s" / "9s". Mirrors RN `formatDuration`.
  static String formatDuration(double seconds) {
    final total = seconds.floor();
    final mins = total ~/ 60;
    final secs = total % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }

  /// Unique recording id. Mirrors RN `generateRecordingId`.
  static String generateRecordingId() =>
      'rec_${DateTime.now().millisecondsSinceEpoch}_${_randSuffix(9)}';

  /// Title from transcript or default. Mirrors RN `generateTitle`.
  static String generateTitle(String? transcript) {
    String defaultTitle() {
      final now = DateTime.now();
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      return 'New Recording $m/$d/${now.year}';
    }

    if (transcript == null || transcript.isEmpty) return defaultTitle();
    final firstLine = transcript.split('\n').first.trim();
    if (firstLine.isEmpty) return defaultTitle();
    if (firstLine.length > 50) return '${firstLine.substring(0, 47)}...';
    return firstLine;
  }

  /// Format a timestamp as "10:42 AM". Mirrors RN `formatTimestamp`.
  static String formatTimestamp(DateTime date) {
    final hour24 = date.hour;
    final period = hour24 < 12 ? 'AM' : 'PM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}

/// Thrown by [AudioRecordingService.startRecording] when the host has no mic
/// capture backend (e.g. Linux without `fmedia`).
class AudioCaptureUnsupportedError implements Exception {
  const AudioCaptureUnsupportedError();
  @override
  String toString() =>
      'AudioCaptureUnsupportedError: microphone capture is not available on '
      'this platform/host (Linux requires the external `fmedia` binary).';
}

/// Thrown when the microphone permission was denied.
class MicrophonePermissionDeniedError implements Exception {
  const MicrophonePermissionDeniedError();
  @override
  String toString() =>
      'MicrophonePermissionDeniedError: microphone permission not granted.';
}
