import 'recording.dart';

/// Phase of a recording in the upload -> process -> result pipeline (F4).
///
/// This is the client-side progress projection the UI binds to; it is broader
/// than the server [RecordingStatus] because it also covers the local upload
/// phase before the server has any status to report.
enum RecordingPhase {
  /// No work started.
  idle,

  /// Creating the recording + streaming the file to the presigned URL.
  uploading,

  /// File uploaded; `/process` enqueued; awaiting `recording:status` / poll.
  processing,

  /// Server reported `done`.
  done,

  /// Server reported `failed`, the upload failed, or processing timed out.
  failed,
}

/// Immutable per-recording progress snapshot exposed to the UI via riverpod.
class RecordingProgress {
  const RecordingProgress({
    required this.phase,
    this.recordingId,
    this.recording,
    this.errorReason,
  });

  final RecordingPhase phase;
  final int? recordingId;

  /// The latest known recording (populated once created / on a done result).
  final Recording? recording;

  /// Failure detail (`error_reason`, upload error, or `timeout`).
  final String? errorReason;

  static const idle = RecordingProgress(phase: RecordingPhase.idle);

  bool get isTerminal =>
      phase == RecordingPhase.done || phase == RecordingPhase.failed;

  RecordingProgress copyWith({
    RecordingPhase? phase,
    int? recordingId,
    Recording? recording,
    String? errorReason,
  }) {
    return RecordingProgress(
      phase: phase ?? this.phase,
      recordingId: recordingId ?? this.recordingId,
      recording: recording ?? this.recording,
      errorReason: errorReason ?? this.errorReason,
    );
  }

  @override
  String toString() =>
      'RecordingProgress(phase: $phase, id: $recordingId, error: $errorReason)';
}

/// Maps a server [RecordingStatus] onto the next [RecordingProgress] for a
/// recording already in the [RecordingPhase.processing]/uploading phase.
///
/// Pure function — the unit-testable core of the state machine. Returns `null`
/// when the status is non-terminal and non-actionable (e.g. `pending` /
/// `processing`), meaning "stay in the current phase".
RecordingProgress? advanceOnStatus({
  required RecordingProgress current,
  required RecordingStatus status,
  Recording? recording,
  String? errorReason,
}) {
  switch (status) {
    case RecordingStatus.done:
      return current.copyWith(phase: RecordingPhase.done, recording: recording);
    case RecordingStatus.failed:
      return RecordingProgress(
        phase: RecordingPhase.failed,
        recordingId: current.recordingId,
        recording: recording ?? current.recording,
        errorReason: errorReason ?? 'recording_processing_failed',
      );
    case RecordingStatus.processing:
      // Move idle/uploading -> processing; otherwise stay put.
      if (current.phase == RecordingPhase.processing) return null;
      return current.copyWith(phase: RecordingPhase.processing);
    case RecordingStatus.pending:
    case RecordingStatus.unknown:
      return null;
  }
}
