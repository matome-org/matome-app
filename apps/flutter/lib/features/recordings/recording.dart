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
/// Hand-written with tolerant parsing: only `id`, `title` and `status` are
/// treated as required; everything else is nullable because the backend may emit
/// nulls before processing completes. `owner_id` is NOT NULL on Core but is
/// parsed defensively as a nullable STRING (#1469): a missing/blank value yields
/// `null` so the sync write path can REJECT it rather than default it to a
/// cross-owner POISON value (`0`/`""`).
class Recording {
  const Recording({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    this.summary,
    this.transcript,
    this.notes,
    this.mediaType,
    this.storageKey,
    this.errorReason,
    this.duration,
    this.byteSize,
    this.badge,
    this.workspaceId,
    this.matomeId,
    this.insertedAt,
    this.updatedAt,
  });

  final int id;

  /// The OWNING USER's Core id, as the TEXT/string id it is on the wire.
  ///
  /// SECURITY (#1469, A01 — Broken Access Control): Core's `items.owner_id`
  /// is NOT NULL and server-enforced (`MatomeApi.Content.list_recordings` filters
  /// `owner_id == ^owner_id`), and the Drift mirror column is TEXT (tables.dart).
  /// It is parsed as a STRING — NEVER coerced through `asInt` (which would turn an
  /// absent value into `0`, a POISON value that collides across owners). A
  /// missing/blank `owner_id` parses to `null` here so the write path can REJECT
  /// it (leave the column untouched) rather than default it — the owner-scoped
  /// Files query treats a NULL owner as "not the current owner" (excluded).
  final String? ownerId;
  final String title;
  final RecordingStatus status;
  final String? summary;

  /// Machine-produced transcript text (Core-owned). A pull populates/updates it.
  final String? transcript;

  /// User-produced notes (user-owned, task #1434). Parsed independently of
  /// [transcript] so the Inbox sync write-path can route Core `notes` → Drift
  /// `notes` without aliasing the transcript over it. A Core pull must NEVER
  /// clobber a locally-edited note (the save-path / task #1435 owns writes here).
  final String? notes;

  final String? mediaType;
  final String? storageKey;
  final String? errorReason;
  final int? duration;

  /// The uploaded media's size in BYTES (#1471), from Core's nullable
  /// `recordings.byte_size`. Null when the row carries no declared size (legacy
  /// rows); the Files view renders a dash in that case.
  final int? byteSize;

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
      // #1469: parse owner_id as the TEXT id it is. `asStringOrNull` yields null
      // for an absent value; we ALSO collapse a blank string to null so the write
      // path can reject it (never default a missing owner to "0"/"").
      ownerId: _ownerIdOrNull(json['owner_id']),
      title: asString(json['title']),
      status: RecordingStatus.fromName(asStringOrNull(json['status'])),
      summary: asStringOrNull(json['summary']),
      transcript: asStringOrNull(json['transcript']),
      notes: asStringOrNull(json['notes']),
      mediaType: asStringOrNull(json['media_type']),
      storageKey: asStringOrNull(json['storage_key']),
      errorReason: asStringOrNull(json['error_reason']),
      duration: asIntOrNull(json['duration']),
      byteSize: asIntOrNull(json['byte_size']),
      badge: asStringOrNull(json['badge']),
      workspaceId: asIntOrNull(json['workspace_id']),
      matomeId: asIntOrNull(json['matome_id']),
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  factory Recording.fromItemJson(Map<String, dynamic> json) {
    final file = json['file'] is Map<String, dynamic>
        ? json['file'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final transcript = asStringOrNull(file['transcript']);
    final summary = asStringOrNull(file['summary']);
    return Recording(
      id: asInt(json['id']),
      ownerId: _ownerIdOrNull(json['owner_id']),
      title: asString(metadata['title'], fallback: 'Untitled'),
      status: RecordingStatus.fromName(
        asStringOrNull(metadata['status']) ??
            (summary != null || transcript != null ? 'done' : 'pending'),
      ),
      summary: summary,
      transcript: transcript,
      notes: asStringOrNull(metadata['notes']),
      mediaType: asStringOrNull(file['media_type']),
      storageKey: asStringOrNull(file['storage_key']),
      duration: asIntOrNull(file['duration']),
      byteSize: asIntOrNull(file['byte_size']),
      badge: asStringOrNull(metadata['badge']),
      workspaceId: asIntOrNull(metadata['workspace_id']),
      matomeId: asIntOrNull(json['matome_id']),
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  /// Parses a wire `owner_id` into a non-empty TEXT id, or null.
  ///
  /// Returns null for an absent value AND for a blank/whitespace string, so a
  /// missing owner is never mistaken for a real one. NEVER coerces through
  /// `asInt` (which would default a missing value to `0` — the #1469 poison).
  static String? _ownerIdOrNull(Object? value) {
    final id = asStringOrNull(value);
    if (id == null) return null;
    final trimmed = id.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  static List<Recording> listFromItemsEnvelope(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((item) => item['item_type'] == 'file')
        .map(Recording.fromItemJson)
        .toList(growable: false);
  }
}
