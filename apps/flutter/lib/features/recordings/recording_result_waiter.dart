// Private fields are paired with public named constructor parameters.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../core/observability/app_log.dart';
import 'recording.dart';

const Duration kProcessingObservationTimeout = Duration(seconds: 30);
const Duration kInitialPollInterval = Duration(seconds: 1);
const Duration kMaxPollInterval = Duration(seconds: 8);

enum RecordingWaitOutcome { terminal, observationTimedOut }

class RecordingResult {
  const RecordingResult.terminal(this.recording)
    : outcome = RecordingWaitOutcome.terminal,
      _standaloneErrorCode = null;
  const RecordingResult.observationTimedOut()
    : outcome = RecordingWaitOutcome.observationTimedOut,
      recording = null,
      _standaloneErrorCode = null;

  /// Compatibility constructors for injected test awaiters.
  const RecordingResult.done(this.recording)
    : outcome = RecordingWaitOutcome.terminal,
      _standaloneErrorCode = null;
  const RecordingResult.failed(String? errorCode)
    : outcome = RecordingWaitOutcome.terminal,
      recording = null,
      _standaloneErrorCode = errorCode;

  final RecordingWaitOutcome outcome;
  final Recording? recording;
  final String? _standaloneErrorCode;

  bool get failed =>
      recording?.processing.state == ProcessingState.failed ||
      _standaloneErrorCode != null;
  String? get errorCode =>
      recording?.processing.error?.code ?? _standaloneErrorCode;
  String? get errorReason => errorCode;
}

/// Polls one explicit Core processing run with one request in flight at a time.
///
/// The timeout bounds only this client observation. Core's watchdog remains the
/// authority for changing an active run to failed.
class RecordingResultWaiter {
  RecordingResultWaiter({
    required int recordingId,
    required String runId,
    required Future<Recording?> Function() poll,
    Duration initialPollInterval = kInitialPollInterval,
    Duration maxPollInterval = kMaxPollInterval,
    Duration observationTimeout = kProcessingObservationTimeout,
  }) : _recordingId = recordingId,
       _runId = runId,
       _poll = poll,
       _initialPollInterval = initialPollInterval,
       _maxPollInterval = maxPollInterval,
       _observationTimeout = observationTimeout,
       _nextInterval = initialPollInterval;

  final int _recordingId;
  final String _runId;
  final Future<Recording?> Function() _poll;
  final Duration _initialPollInterval;
  final Duration _maxPollInterval;
  final Duration _observationTimeout;

  final _completer = Completer<RecordingResult>();
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  late Duration _nextInterval;
  bool _polling = false;
  bool _settled = false;
  bool _started = false;

  Future<RecordingResult> wait() {
    if (_started) return _completer.future;
    _started = true;
    AppLog.event(
      LogCat.upload,
      'wait: observing item=$_recordingId run=$_runId',
    );
    _timeoutTimer = Timer(
      _observationTimeout,
      () => _settle(const RecordingResult.observationTimedOut()),
    );
    unawaited(_pollOnce());
    return _completer.future;
  }

  Future<void> _pollOnce() async {
    if (_settled || _polling) return;
    _polling = true;
    try {
      final latest = await _poll();
      if (_settled) return;
      if (latest != null &&
          latest.id == _recordingId &&
          latest.processing.runId == _runId &&
          latest.processing.state.isTerminal) {
        _settle(RecordingResult.terminal(latest));
        return;
      }
    } catch (error, stack) {
      AppLog.error(
        LogCat.upload,
        '_pollOnce: transient poll failure item=$_recordingId run=$_runId',
        error,
        stack,
      );
    } finally {
      _polling = false;
    }
    if (_settled) return;
    final delay = _nextInterval;
    final doubled = delay.inMicroseconds * 2;
    _nextInterval = Duration(
      microseconds: doubled.clamp(
        _initialPollInterval.inMicroseconds,
        _maxPollInterval.inMicroseconds,
      ),
    );
    _pollTimer = Timer(delay, () => unawaited(_pollOnce()));
  }

  void _settle(RecordingResult result) {
    if (_settled) return;
    _settled = true;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    if (!_completer.isCompleted) _completer.complete(result);
  }

  void cancel() {
    _settled = true;
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
  }
}
