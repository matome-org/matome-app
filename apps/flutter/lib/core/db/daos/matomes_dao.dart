import 'package:drift/drift.dart';

import '../../../features/matome/matome_summary.dart';
import '../app_database.dart';
import '../matome_card.dart';
import '../recording_card.dart';
import '../tables.dart';

part 'matomes_dao.g.dart';

/// CRUD + query DAO for the **Matome** — the central entity of the
/// matome-centric pivot (ADR-0003). A Matome aggregates Items (recordings);
/// every recording is an Item of exactly one Matome (`recordings.matome_id` FK).
///
/// Pure-Dart surface: no HTTP. The sync layer decides when to pull from Core
/// and writes through these methods. `spaceId == null` ⟺ Inbox ⟺
/// local-only/untriaged (ADR-0004).
@DriftAccessor(tables: [Matomes, Recordings, MatomeContacts, Workspaces])
class MatomesDao extends DatabaseAccessor<AppDatabase> with _$MatomesDaoMixin {
  MatomesDao(super.db);

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Insert a new Matome.
  Future<void> create(MatomesCompanion entry) {
    return into(matomes).insert(entry);
  }

  /// Insert-or-replace (upsert) by primary key — used by the Core reconcile
  /// path (mirrors recordings' `upsertRecording`).
  Future<void> upsert(MatomesCompanion entry) {
    return into(matomes).insertOnConflictUpdate(entry);
  }

  Future<MatomeRow?> getById(String id) {
    return (select(matomes)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Local row whose reconciled Core id is [coreId], or null if none has been
  /// reconciled yet (mirrors `recordingByCoreId`).
  Future<MatomeRow?> matomeByCoreId(int coreId) {
    return (select(
      matomes,
    )..where((m) => m.coreId.equals(coreId))).getSingleOrNull();
  }

  /// Partial update — only the provided companion fields are written. Named
  /// `updateMatome` (not `update`) so it does not shadow the inherited
  /// [DatabaseAccessor.update] query builder used throughout this DAO.
  Future<int> updateMatome(String id, MatomesCompanion patch) {
    return (update(matomes)..where((m) => m.id.equals(id))).write(patch);
  }

  /// Delete a Matome by id, EXPLICITLY cascading its contact/share edges
  /// (`matome_contacts` + `matome_shares`) via [ContactsDao.deleteMatomeEdges]
  /// — the Contacts themselves survive (ADR-0004 deletion-cascade). Runs in a
  /// transaction so the Matome and its edges go atomically. Named `deleteMatome`
  /// (not `delete`) so it does not shadow the inherited
  /// [DatabaseAccessor.delete] query builder. Returns `matomes` rows deleted.
  Future<int> deleteMatome(String id) {
    return transaction(() async {
      await attachedDatabase.contactsDao.deleteMatomeEdges(id);
      return (delete(matomes)..where((m) => m.id.equals(id))).go();
    });
  }

  /// Archive (soft-delete) a Matome by id — stamps `archived_at` with now (epoch
  /// ms). The row and its child recordings are RETAINED (recoverable via
  /// [restore]); only the list/watch queries hide it (#1409). Returns rows
  /// updated (0 if [id] does not exist). Idempotent in effect — re-archiving an
  /// already-archived Matome just refreshes the stamp.
  Future<int> archive(String id) {
    return (update(matomes)..where((m) => m.id.equals(id))).write(
      MatomesCompanion(
        archivedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Restore (un-archive) a Matome by id — clears `archived_at`, bringing it
  /// back into every list/watch query (#1409). Returns rows updated.
  Future<int> restore(String id) {
    return (update(matomes)..where((m) => m.id.equals(id))).write(
      const MatomesCompanion(archivedAt: Value(null)),
    );
  }

  // ---------------------------------------------------------------------------
  // Reads — listing
  // ---------------------------------------------------------------------------

  /// All Matomes, newest happening first. Excludes archived (#1409).
  Future<List<MatomeRow>> listMatomes() {
    return (select(matomes)
          ..where((m) => m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Inbox Matomes — `space_id IS NULL` (untriaged/local-only), newest first.
  /// Excludes archived (#1409).
  Future<List<MatomeRow>> listInboxMatomes() {
    return (select(matomes)
          ..where((m) => m.spaceId.isNull() & m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Filed Matomes — `space_id IS NOT NULL` (triaged), newest first. These are
  /// exactly the Matomes eligible for Core push (ADR-0004 space-scoped sync,
  /// task #1377); Inbox Matomes (`space_id IS NULL`) stay local-only. Excludes
  /// archived (#1409) — an archived Matome is not re-pushed.
  Future<List<MatomeRow>> listFiledMatomes() {
    return (select(matomes)
          ..where((m) => m.spaceId.isNotNull() & m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Matomes filed into a given Space, newest first. Excludes archived (#1409).
  Future<List<MatomeRow>> listMatomesInSpace(String spaceId) {
    return (select(matomes)
          ..where((m) => m.spaceId.equals(spaceId) & m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Matomes ordered by `happened_at` descending — explicit by-date variant
  /// (same ordering as [listMatomes], named for intent at call sites). Excludes
  /// archived (#1409).
  Future<List<MatomeRow>> listMatomesByDate() {
    return (select(matomes)
          ..where((m) => m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Matomes whose `happened_at` falls in [startEpoch, endEpoch] inclusive,
  /// newest first — the Calendar's by-day / by-month window (#1378). Groups by
  /// `happened_at` so the day list and month dots are Matome-, not
  /// recording-, scoped. Excludes archived (#1409).
  Future<List<MatomeRow>> matomesByDateRange(int startEpoch, int endEpoch) {
    return (select(matomes)
          ..where((m) =>
              m.happenedAt.isBetweenValues(startEpoch, endEpoch) &
              m.archivedAt.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Reads — hydrated list cards (Matome + its item count)
  // ---------------------------------------------------------------------------

  /// Maps a list of [MatomeRow] to display [MatomeItem]s, populating
  /// `recordingCount` per Matome with a single grouped COUNT over `recordings`
  /// (no child rows loaded — the list cards only need the count). Children are
  /// left empty; the detail hub hydrates them via [getMatomeWithRecordings].
  Future<List<MatomeItem>> _hydrateCounts(List<MatomeRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((r) => r.id).toList(growable: false);

    // (1) Item mix per Matome — grouped COUNT over `recordings`, split by
    // `mediaType` so the list row can show mic vs image tokens (#1412). One
    // grouped scan yields total + audio + image without loading child rows.
    final totalExpr = recordings.id.count();
    final audioExpr = recordings.id.count(
      filter: recordings.mediaType.equals('audio'),
    );
    final imageExpr = recordings.id.count(
      filter: recordings.mediaType.equals('image'),
    );
    final mixQuery = selectOnly(recordings)
      ..addColumns([recordings.matomeId, totalExpr, audioExpr, imageExpr])
      ..where(recordings.matomeId.isIn(ids))
      ..groupBy([recordings.matomeId]);
    final total = <String, int>{};
    final audio = <String, int>{};
    final image = <String, int>{};
    for (final row in await mixQuery.get()) {
      final mid = row.read(recordings.matomeId);
      if (mid == null) continue;
      total[mid] = row.read(totalExpr) ?? 0;
      audio[mid] = row.read(audioExpr) ?? 0;
      image[mid] = row.read(imageExpr) ?? 0;
    }

    // (2) People per Matome — grouped COUNT over `matome_contacts` edges.
    final peopleExpr = matomeContacts.id.count();
    final peopleQuery = selectOnly(matomeContacts)
      ..addColumns([matomeContacts.matomeId, peopleExpr])
      ..where(matomeContacts.matomeId.isIn(ids))
      ..groupBy([matomeContacts.matomeId]);
    final people = <String, int>{};
    for (final row in await peopleQuery.get()) {
      people[row.read(matomeContacts.matomeId)!] = row.read(peopleExpr) ?? 0;
    }

    // (3) Filed Space name per Matome — a single lookup over `workspaces` for
    // the spaceIds present in this page (Inbox rows have a null spaceId and are
    // skipped). Keeps the row's place chip a folder name, not just an id.
    final spaceIds = rows
        .map((r) => r.spaceId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final spaceNames = <String, String>{};
    if (spaceIds.isNotEmpty) {
      final nameQuery = selectOnly(workspaces)
        ..addColumns([workspaces.id, workspaces.name])
        ..where(workspaces.id.isIn(spaceIds));
      for (final row in await nameQuery.get()) {
        spaceNames[row.read(workspaces.id)!] = row.read(workspaces.name)!;
      }
    }

    return rows
        .map(
          (r) => MatomeItem.fromRow(
            r,
            recordingCount: total[r.id] ?? 0,
            audioCount: audio[r.id] ?? 0,
            imageCount: image[r.id] ?? 0,
            peopleCount: people[r.id] ?? 0,
            spaceName: r.spaceId == null ? null : spaceNames[r.spaceId],
          ),
        )
        .toList(growable: false);
  }

  /// Inbox Matomes as display cards (`space_id IS NULL`), each with its item
  /// count, newest first. The Inbox list source (#1378).
  Future<List<MatomeItem>> listInboxMatomeItems() async =>
      _hydrateCounts(await listInboxMatomes());

  /// A Space's Matomes as display cards, each with its item count, newest
  /// first. The Space-detail list source (#1378).
  Future<List<MatomeItem>> listMatomeItemsInSpace(String spaceId) async =>
      _hydrateCounts(await listMatomesInSpace(spaceId));

  /// The Matomes happening in [startEpoch, endEpoch] as display cards, each
  /// with its item count, newest first. The Calendar day-list source (#1378).
  Future<List<MatomeItem>> matomeItemsByDateRange(
    int startEpoch,
    int endEpoch,
  ) async =>
      _hydrateCounts(await matomesByDateRange(startEpoch, endEpoch));

  /// The parent Matome id of a recording, or null when the recording does not
  /// exist (or — pre-backfill — has no Matome). Powers the deep-link redirect
  /// that resolves an OLD recording-centric link to its parent Matome hub
  /// (#1378): `/inbox/:recId` → `/matome/<matomeId>` (1-rec→1-matome invariant).
  Future<String?> matomeIdForRecording(String recordingId) async {
    final row = await (select(recordings)
          ..where((r) => r.id.equals(recordingId)))
        .getSingleOrNull();
    return row?.matomeId;
  }

  // ---------------------------------------------------------------------------
  // Reads — Matome + its Items
  // ---------------------------------------------------------------------------

  /// The Matome plus exactly its child recordings (join on
  /// `recordings.matome_id`), hydrated into a [MatomeItem]. Returns null when no
  /// Matome has [id]. Children are ordered newest-first by `createdAt`.
  Future<MatomeItem?> getMatomeWithRecordings(String id) async {
    final row =
        await (select(matomes)..where((m) => m.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final children = await (select(recordings)
          ..where((r) => r.matomeId.equals(id))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();

    return MatomeItem.fromRow(
      row,
      recordings: children
          .map((r) => RecordingItem.fromRow(r))
          .toList(growable: false),
    );
  }

  // ---------------------------------------------------------------------------
  // Mutations on the Matome <-> Item relationship & summary
  // ---------------------------------------------------------------------------

  /// File this Matome INTO a Space — the core triage action (ADR-0004): sets
  /// `space_id`, moving the Matome out of the Inbox and into the sync domain.
  /// Returns rows updated (0 if [matomeId] does not exist). Alias
  /// [moveMatomeToSpace] re-files an already-filed Matome into a different Space.
  Future<int> fileIntoSpace(String matomeId, String spaceId) {
    return (update(matomes)..where((m) => m.id.equals(matomeId)))
        .write(MatomesCompanion(spaceId: Value(spaceId)));
  }

  /// Re-file a Matome into a different Space (same write as [fileIntoSpace];
  /// named for intent at re-filing call sites). Returns rows updated.
  Future<int> moveMatomeToSpace(String matomeId, String spaceId) =>
      fileIntoSpace(matomeId, spaceId);

  /// Re-assign a recording to a different Matome (move, never copy — a recording
  /// is an Item of exactly ONE Matome; ADR-0003 invariant). Returns the number
  /// of recording rows updated (0 if [recordingId] does not exist).
  ///
  /// The item set of BOTH the source and the destination Matome changed, so
  /// both have their aggregated summary marked stale (ADR-0003 invalidation):
  /// the source lost a contributing Item, the destination gained one. Runs in a
  /// transaction so the move + both stale-marks go atomically.
  Future<int> moveRecordingToMatome(String recordingId, String matomeId) {
    return transaction(() async {
      final current = await (select(recordings)
            ..where((r) => r.id.equals(recordingId)))
          .getSingleOrNull();
      final sourceMatomeId = current?.matomeId;

      final n = await (update(recordings)
            ..where((r) => r.id.equals(recordingId)))
          .write(RecordingsCompanion(matomeId: Value(matomeId)));

      if (n > 0) {
        await markSummaryStale(matomeId, true);
        if (sourceMatomeId != null && sourceMatomeId != matomeId) {
          await markSummaryStale(sourceMatomeId, true);
        }
      }
      return n;
    });
  }

  /// Set the stored aggregated (Matome-level) summary and clear the stale flag —
  /// the summary now reflects the current item set. Returns rows updated.
  Future<int> setAggregatedSummary(String matomeId, String text) {
    return (update(matomes)..where((m) => m.id.equals(matomeId))).write(
      MatomesCompanion(
        aggregatedSummary: Value(text),
        summaryStale: const Value(false),
      ),
    );
  }

  /// Flag/unflag the aggregated summary as pending regeneration (the item set
  /// changed). Returns rows updated.
  Future<int> markSummaryStale(String matomeId, bool stale) {
    return (update(matomes)..where((m) => m.id.equals(matomeId)))
        .write(MatomesCompanion(summaryStale: Value(stale)));
  }

  /// Recompute the aggregated summary from the Matome's CURRENT child Items and
  /// store it, clearing the stale flag (ADR-0003). Deterministic LOCAL
  /// composition via [composeAggregatedSummary] — no AI/backend call (that is
  /// the sync/backend wave's job).
  ///
  /// When the items compose to a non-empty rollup it is stored via
  /// [setAggregatedSummary] (which clears `summaryStale`). When NOTHING composes
  /// (no Item carries a summary), the column is set to NULL and the stale flag
  /// is still cleared — the regeneration ran, the answer is "nothing to roll up
  /// yet", and the hub falls back to its empty state. Returns the regenerated
  /// summary (or null), or null when [matomeId] does not exist.
  Future<String?> regenerateSummary(String matomeId) async {
    final item = await getMatomeWithRecordings(matomeId);
    if (item == null) return null;

    final composed = composeAggregatedSummary(item.recordings);
    if (composed == null) {
      await (update(matomes)..where((m) => m.id.equals(matomeId))).write(
        const MatomesCompanion(
          aggregatedSummary: Value(null),
          summaryStale: Value(false),
        ),
      );
      return null;
    }

    await setAggregatedSummary(matomeId, composed);
    return composed;
  }
}
