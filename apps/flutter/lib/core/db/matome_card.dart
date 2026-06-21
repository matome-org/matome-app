import 'app_database.dart';
import 'recording_card.dart';

/// Sync state of a Matome rolled up from its child Items, so the Matome pill
/// speaks the same Synced / Syncing / On device vocabulary (#1407) as the
/// per-tile badges instead of contradicting them:
///   * [cloud]    — every hydrated child is reconciled to Core → "Synced",
///   * [partial]  — some children are still uploading (mixed) → "Syncing",
///   * [onDevice] — no child has reached Core yet → "On device".
///
/// DECIDED (#1407): only three states. A permanently-failed child stays inside
/// [partial] and is therefore surfaced as "Syncing" — an accepted trade-off to
/// avoid a fourth chip state.
enum MatomeSyncRollup { onDevice, partial, cloud }

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
    this.spaceName,
    this.audioCount = 0,
    this.imageCount = 0,
    this.peopleCount = 0,
    this.archivedAt,
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

  /// Display name of the filed Space (`workspaces.name`), or NULL when the
  /// Matome is in the Inbox (`spaceId == null`). Populated by the list query's
  /// join so the row's place chip shows the folder name without a per-row read.
  final String? spaceName;

  /// Item-mix counts for the list row's dense meta strip (#1412), derived from
  /// the child recordings' `mediaType` by the list query. [audioCount] +
  /// [imageCount] need not sum to [recordingCount] (other media types exist),
  /// so each token is shown independently and only when its count > 0.
  final int audioCount;
  final int imageCount;

  /// Number of Contacts tagged on this Matome (`matome_contacts` edges),
  /// populated by the list query for the people token. 0 when none / not loaded.
  final int peopleCount;

  /// Epoch ms the Matome was archived (soft-deleted), or NULL when active.
  /// List queries exclude archived rows, but the detail hub stays openable via
  /// `/matome/:id`, so the header surfaces an archived banner when this is set
  /// (#1431/I-1).
  final int? archivedAt;

  /// Derived untriaged state — `spaceId == null` (glossary: Inbox).
  bool get isInbox => spaceId == null;

  /// Whether this Matome is archived (soft-deleted) — `archivedAt != null`.
  bool get isArchived => archivedAt != null;

  /// Local-only / not-yet-synced — no reconciled Core id yet (ADR-0004).
  bool get isLocalOnly => coreId == null;

  /// Sync state rolled up from the hydrated child Items, using the same
  /// [RecordingItem.isOnCloud] rule the per-tile badges use. Falls back to the
  /// Matome's own [coreId] when no children are loaded (count-only / empty), so
  /// the pill stays meaningful even without hydrated rows.
  MatomeSyncRollup get syncRollup {
    if (recordings.isEmpty) {
      return coreId != null ? MatomeSyncRollup.cloud : MatomeSyncRollup.onDevice;
    }
    final synced = recordings.where((r) => r.isOnCloud).length;
    if (synced == 0) return MatomeSyncRollup.onDevice;
    if (synced == recordings.length) return MatomeSyncRollup.cloud;
    return MatomeSyncRollup.partial;
  }

  /// Maps a persisted [MatomeRow] (+ optional hydrated children) to the UI card.
  factory MatomeItem.fromRow(
    MatomeRow row, {
    List<RecordingItem> recordings = const [],
    int? recordingCount,
    String? spaceName,
    int audioCount = 0,
    int imageCount = 0,
    int peopleCount = 0,
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
      spaceName: spaceName,
      audioCount: audioCount,
      imageCount: imageCount,
      peopleCount: peopleCount,
      archivedAt: row.archivedAt,
    );
  }
}
