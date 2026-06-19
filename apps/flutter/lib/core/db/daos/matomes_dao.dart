import 'package:drift/drift.dart';

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
@DriftAccessor(tables: [Matomes, Recordings])
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

  // ---------------------------------------------------------------------------
  // Reads — listing
  // ---------------------------------------------------------------------------

  /// All Matomes, newest happening first.
  Future<List<MatomeRow>> listMatomes() {
    return (select(matomes)
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Inbox Matomes — `space_id IS NULL` (untriaged/local-only), newest first.
  Future<List<MatomeRow>> listInboxMatomes() {
    return (select(matomes)
          ..where((m) => m.spaceId.isNull())
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Matomes filed into a given Space, newest first.
  Future<List<MatomeRow>> listMatomesInSpace(String spaceId) {
    return (select(matomes)
          ..where((m) => m.spaceId.equals(spaceId))
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
  }

  /// Matomes ordered by `happened_at` descending — explicit by-date variant
  /// (same ordering as [listMatomes], named for intent at call sites).
  Future<List<MatomeRow>> listMatomesByDate() {
    return (select(matomes)
          ..orderBy([(m) => OrderingTerm.desc(m.happenedAt)]))
        .get();
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
  Future<int> moveRecordingToMatome(String recordingId, String matomeId) {
    return (update(recordings)..where((r) => r.id.equals(recordingId)))
        .write(RecordingsCompanion(matomeId: Value(matomeId)));
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
}
