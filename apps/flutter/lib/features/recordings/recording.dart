import '../../core/http/json_utils.dart';

/// Processing status of a recording, mirroring the backend enum.
enum RecordingStatus {
  pending,
  processing,
  done,
  failed,
  unknown;

  static RecordingStatus fromName(String? value) {
    switch (value) {
      case 'pending':
        return RecordingStatus.pending;
      case 'processing':
        return RecordingStatus.processing;
      case 'done':
        return RecordingStatus.done;
      case 'failed':
        return RecordingStatus.failed;
      default:
        return RecordingStatus.unknown;
    }
  }
}

/// A user's recording, per the `/api/recordings` contract.
///
/// Hand-written with tolerant parsing: only `id`, `owner_id`, `title` and
/// `status` are treated as required; everything else is nullable because the
/// backend may emit nulls before processing completes.
class Recording {
  const Recording({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.summary,
    this.transcript,
    this.mediaType,
    this.storageKey,
    this.errorReason,
    this.duration,
    this.badge,
    this.workspaceId,
    this.matomeId,
    this.insertedAt,
    this.updatedAt,
  });

  final int id;
  final int ownerId;
  final String title;
  final RecordingStatus status;
  final String? summary;
  final String? transcript;
  final String? mediaType;
  final String? storageKey;
  final String? errorReason;
  final int? duration;
  final String? badge;
  final int? workspaceId;

  /// REMOTE (Core) Matome id this recording belongs to (task #1377). Carried so
  /// the child-before-parent sync can map it back to a local Matome by `core_id`.
  final int? matomeId;

  final DateTime? insertedAt;
  final DateTime? updatedAt;

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: asInt(json['id']),
      ownerId: asInt(json['owner_id']),
      title: asString(json['title']),
      status: RecordingStatus.fromName(asStringOrNull(json['status'])),
      summary: asStringOrNull(json['summary']),
      transcript: asStringOrNull(json['transcript']),
      mediaType: asStringOrNull(json['media_type']),
      storageKey: asStringOrNull(json['storage_key']),
      errorReason: asStringOrNull(json['error_reason']),
      duration: asIntOrNull(json['duration']),
      badge: asStringOrNull(json['badge']),
      workspaceId: asIntOrNull(json['workspace_id']),
      matomeId: asIntOrNull(json['matome_id']),
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  /// Parses the `{ "recordings": [...] }` envelope into a typed list.
  static List<Recording> listFromEnvelope(Map<String, dynamic> json) {
    final raw = json['recordings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Recording.fromJson)
        .toList(growable: false);
  }
}
