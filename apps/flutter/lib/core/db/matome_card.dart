import 'app_database.dart';
import 'recording_card.dart';

/// UI-facing **Matome** item — the display-ready view of a [MatomeRow] plus its
/// child Items (recordings) and aggregated state. Mirrors [RecordingItem]: the
/// DB row keeps the raw SQLite columns, this card exposes the typed view the
/// Matome detail/list screens consume.
///
/// A Matome (ADR-0003) aggregates Items (audio|image recordings), with a stored
/// [aggregatedSummary] regenerated when the item set changes. [isInbox] is the
/// derived untriaged state (`spaceId == null`); [isLocalOnly] is true while the
/// Matome has not been reconciled to a Core id (Inbox / not yet synced).
class MatomeItem {
  const MatomeItem({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.happenedAt,
    required this.createdAt,
    required this.summaryStale,
    required this.recordingCount,
    required this.recordings,
    this.description,
    this.aggregatedSummary,
    this.coreId,
  });

  final String id;

  /// FK → the Space (`workspaces.id`). NULL ⟺ Inbox ⟺ local-only/untriaged.
  final String? spaceId;

  final String title;

  /// Epoch ms of the happening this Matome gathers.
  final int happenedAt;

  final int createdAt;

  final String? description;

  /// Stored, Matome-level summary across the items (ADR-0003). NULL until first
  /// regeneration.
  final String? aggregatedSummary;

  /// Whether [aggregatedSummary] is pending regeneration (the item set changed).
  final bool summaryStale;

  /// Reconciled Core numeric id, NULL until the Matome is triaged into a Space
  /// and the first sync succeeds (mirrors recordings.coreId / m005).
  final int? coreId;

  /// Number of child Items (recordings) — equals `recordings.length` when the
  /// children were hydrated, but is carried explicitly so a count-only query
  /// (no child rows loaded) can still populate it.
  final int recordingCount;

  /// The child Items (recordings) of this Matome, as UI cards. Empty when the
  /// Matome was loaded count-only.
  final List<RecordingItem> recordings;

  /// Derived untriaged state — `spaceId == null` (glossary: Inbox).
  bool get isInbox => spaceId == null;

  /// Local-only / not-yet-synced — no reconciled Core id yet (ADR-0004).
  bool get isLocalOnly => coreId == null;

  /// Maps a persisted [MatomeRow] (+ optional hydrated children) to the UI card.
  factory MatomeItem.fromRow(
    MatomeRow row, {
    List<RecordingItem> recordings = const [],
    int? recordingCount,
  }) {
    return MatomeItem(
      id: row.id,
      spaceId: row.spaceId,
      title: row.title,
      happenedAt: row.happenedAt,
      createdAt: row.createdAt,
      description: row.description,
      aggregatedSummary: row.aggregatedSummary,
      summaryStale: row.summaryStale,
      coreId: row.coreId,
      recordingCount: recordingCount ?? recordings.length,
      recordings: recordings,
    );
  }
}
