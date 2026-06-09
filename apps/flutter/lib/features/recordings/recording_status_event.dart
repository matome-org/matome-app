import '../../core/http/json_utils.dart';
import 'recording.dart';

/// Parsed `recording:status` push event from the Phoenix `user:{ownerId}`
/// channel.
///
/// Mirrors the Core broadcast payload (see
/// `MatomeApi.Content.broadcast_recording_status/2`):
///
/// ```elixir
/// %{recording_id, status, summary, transcript, error_reason,
///   duration, badge, updated_at}
/// ```
///
/// Parsing is tolerant: only `recording_id` and `status` carry meaning for the
/// state machine; the rest are nullable because the backend emits nulls before
/// processing completes.
class RecordingStatusEvent {
  const RecordingStatusEvent({
    required this.recordingId,
    required this.status,
    this.summary,
    this.transcript,
    this.errorReason,
    this.duration,
    this.badge,
    this.updatedAt,
  });

  final int recordingId;
  final RecordingStatus status;
  final String? summary;
  final String? transcript;
  final String? errorReason;
  final int? duration;
  final String? badge;
  final DateTime? updatedAt;

  /// Parses a raw Phoenix push payload. Returns `null` when the payload is not
  /// a recording-status map (defensive — the same channel could carry other
  /// events in future).
  static RecordingStatusEvent? tryParse(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.cast<dynamic, dynamic>();
    final rawId = map['recording_id'];
    if (rawId == null) return null;
    return RecordingStatusEvent(
      recordingId: asInt(rawId),
      status: RecordingStatus.fromName(asStringOrNull(map['status'])),
      summary: asStringOrNull(map['summary']),
      transcript: asStringOrNull(map['transcript']),
      errorReason: asStringOrNull(map['error_reason']),
      duration: asIntOrNull(map['duration']),
      badge: asStringOrNull(map['badge']),
      updatedAt: asDateTimeOrNull(map['updated_at']),
    );
  }

  /// Folds this event onto an existing [Recording], preserving fields the
  /// event does not carry (title, mediaType, storageKey, ownerId).
  Recording applyTo(Recording base) {
    return Recording(
      id: base.id,
      ownerId: base.ownerId,
      title: base.title,
      status: status,
      summary: summary ?? base.summary,
      transcript: transcript ?? base.transcript,
      mediaType: base.mediaType,
      storageKey: base.storageKey,
      errorReason: errorReason,
      duration: duration ?? base.duration,
      badge: badge ?? base.badge,
      workspaceId: base.workspaceId,
      insertedAt: base.insertedAt,
      updatedAt: updatedAt ?? base.updatedAt,
    );
  }
}
