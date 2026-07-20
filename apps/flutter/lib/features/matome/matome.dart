import '../../core/http/json_utils.dart';

/// A contact edge as Core carries it inside a Matome payload — the remote
/// `contact_id` plus its `role` on this Matome (`matome_contacts`). Both are the
/// REMOTE ids; the sync layer maps `contactId` back to a local Contact row by
/// its reconciled `core_id`.
class MatomeContactEdge {
  const MatomeContactEdge({required this.contactId, required this.role});

  final int contactId;
  final String role;

  factory MatomeContactEdge.fromJson(Map<String, dynamic> json) {
    return MatomeContactEdge(
      contactId: asInt(json['contact_id']),
      role: asString(json['role'], fallback: 'attendee'),
    );
  }
}

/// A user's Matome, per the `/api/matomes` contract (.docs/internal/architecture.md §11 (D3) / .docs/internal/architecture.md §11 (D4), task #1377).
///
/// Hand-written, tolerant parsing: only `id`, `owner_id` and `title` are
/// required. `workspace_id` is optional: ordinary list sync is filed-space
/// scoped, while W0 parent reconciliation may create an Inbox Matome without a
/// workspace so queued child work can progress. `contacts` is the edge set.
class Matome {
  const Matome({
    required this.id,
    required this.ownerId,
    required this.title,
    this.workspaceId,
    this.happenedAt,
    this.description,
    this.aggregatedSummary,
    this.archivedAt,
    this.contacts = const [],
    this.insertedAt,
    this.updatedAt,
  });

  /// Remote (Core) numeric id — reconciled into `matomes.core_id`.
  final int id;
  final String ownerId;
  final String title;

  /// FK → the Space (`workspaces`), or null for a reconciled Inbox parent.
  final int? workspaceId;
  final DateTime? happenedAt;
  final String? description;
  final String? aggregatedSummary;

  /// Soft-delete (archive) marker (#1409). Non-null ⟺ archived; an archived
  /// Matome is hidden from the default Core lists and every local list/watch.
  final DateTime? archivedAt;

  /// The role-bearing `matome_contacts` edge set Core returned (remote ids).
  final List<MatomeContactEdge> contacts;

  final DateTime? insertedAt;
  final DateTime? updatedAt;

  factory Matome.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'];
    final contacts = rawContacts is List
        ? rawContacts
              .whereType<Map<String, dynamic>>()
              .map(MatomeContactEdge.fromJson)
              .toList(growable: false)
        : const <MatomeContactEdge>[];
    return Matome(
      id: asInt(json['id']),
      ownerId: asString(json['owner_id']),
      title: asString(json['title']),
      workspaceId: asIntOrNull(json['workspace_id']),
      happenedAt: asDateTimeOrNull(json['happened_at']),
      description: asStringOrNull(json['description']),
      aggregatedSummary: asStringOrNull(json['aggregated_summary']),
      archivedAt: asDateTimeOrNull(json['archived_at']),
      contacts: contacts,
      insertedAt: asDateTimeOrNull(json['inserted_at']),
      updatedAt: asDateTimeOrNull(json['updated_at']),
    );
  }

  /// Parses the `{ "matomes": [...] }` envelope into a typed list.
  static List<Matome> listFromEnvelope(Map<String, dynamic> json) {
    final raw = json['matomes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Matome.fromJson)
        .toList(growable: false);
  }
}
