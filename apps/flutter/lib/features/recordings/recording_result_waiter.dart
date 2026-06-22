// Private fields are paired with public named constructor params, so the
// `prefer_initializing_formals` suggestion does not apply here.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../core/observability/app_log.dart';
import 'recording.dart';
import 'recording_status_event.dart';

/// Default timings, mirroring apps/mobile `waitForCoreRecordingResult`.
const Duration kProcessingTimeout = Duration(minutes: 10);
const Duration kPollInterval = Duration(seconds: 2);

/// Result of awaiting a recording's processing.
class RecordingResult {
  const RecordingResult.done(this.recording)
      : failed = false,
        errorReason = null;
  const RecordingResult.failed(this.errorReason)
      : failed = true,
        recording = null;

  final bool failed;
  final Recording? recording;
  final String? errorReason;
}

/// Races the realtime channel against a periodic poll until the recording is
/// `done` / `failed`, or the [timeout] elapses.
///
/// Both inputs are injected so this is unit-testable with no live backend:
///  * [statusEvents] — the `recording:status` stream (the primary path).
///  * [poll] — `GET /api/recordings/{id}` callback (the fallback path), which
///    keeps the pipeline correct even when the socket is down or never emits.
///
/// First terminal signal from *either* source wins; the loser is ignored.
class RecordingResultWaiter {
  RecordingResultWaiter({
    required int recordingId,
    required Stream<RecordingStatusEvent> statusEvents,
    required Future<Recording?> Function() poll,
    Duration timeout = kProcessingTimeout,
    Duration pollInterval = kPollInterval,
  })  : _recordingId = recordingId,
        _statusEvents = statusEvents,
        _poll = poll,
        _timeout = timeout,
        _pollInterval = pollInterval;

  final int _recordingId;
  final Stream<RecordingStatusEvent> _statusEvents;
  final Future<Recording?> Function() _poll;
  final Duration _timeout;
  final Duration _pollInterval;

  final _completer = Completer<RecordingResult>();
  StreamSubscription<RecordingStatusEvent>? _eventSub;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  bool _settled = false;

  /// Begins waiting. Resolves on the first terminal status from the socket or
  /// the poll loop, or rejects-as-failed (`errorReason: 'timeout'`) at
  /// [timeout].
  Future<RecordingResult> wait() {
    AppLog.event(LogCat.upload, 'wait: awaiting terminal for $_recordingId');
    _eventSub = _statusEvents.listen(_onEvent, onError: (_) {/* poll covers */});

    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());

    _timeoutTimer = Timer(_timeout, () {
      _settle(const RecordingResult.failed('timeout'));
    });

    return _completer.future;
  }

  void _onEvent(RecordingStatusEvent event) {
    if (event.recordingId != _recordingId) return;
    if (event.status == RecordingStatus.done) {
      _settle(RecordingResult.done(_recordingFromEvent(event)));
    } else if (event.status == RecordingStatus.failed) {
      _settle(RecordingResult.failed(
        event.errorReason ?? 'recording_processing_failed',
      ));
    }
  }

  Future<void> _pollOnce() async {
    if (_settled) return;
    try {
      final latest = await _poll();
      if (latest == null) return;
      if (latest.status == RecordingStatus.done) {
        _settle(RecordingResult.done(latest));
      } else if (latest.status == RecordingStatus.failed) {
        _settle(RecordingResult.failed(
          latest.errorReason ?? 'recording_processing_failed',
        ));
      }
    } catch (e, st) {
      AppLog.error(
        LogCat.upload,
        '_pollOnce: poll failed for $_recordingId (channel still primary)',
        e,
        st,
      );
      // The channel remains the primary path; ignore transient poll errors.
    }
  }

  Recording _recordingFromEvent(RecordingStatusEvent event) {
    return Recording(
      id: event.recordingId,
      // A status event carries no owner; this synthetic Recording is only used
      // to fold terminal status onto the real row, never persisted, so owner is
      // left null (#1469 — never default to a poison "0").
      ownerId: null,
      title: '',
      status: event.status,
      summary: event.summary,
      transcript: event.transcript,
      errorReason: event.errorReason,
      duration: event.duration,
      badge: event.badge,
      updatedAt: event.updatedAt,
    );
  }

  void _settle(RecordingResult result) {
    if (_settled) return;
    _settled = true;
    _eventSub?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    if (!_completer.isCompleted) _completer.complete(result);
  }

  /// Aborts the wait without resolving the caller's future (used on dispose).
  void cancel() {
    _settled = true;
    _eventSub?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
  }
}
