import 'package:drift/drift.dart';

import '../../../features/matome/matome_summary.dart';
import '../app_database.dart';
import '../matome_card.dart';
import '../recording_card.dart';
import '../tables.dart';

part 'matomes_dao.g.dart';

@DriftAccessor(tables: [Matomes, Items, FileBlobs, MatomeContacts, Workspaces])
class MatomesDao extends DatabaseAccessor<AppDatabase> with _$MatomesDaoMixin {
  MatomesDao(super.db);

  Future<void> create(MatomesCompanion entry) => into(matomes).insert(entry);

  Future<void> upsert(MatomesCompanion entry) =>
      into(matomes).insertOnConflictUpdate(entry);

  Future<MatomeRow?> getById(String id) => (select(
    matomes,
  )..where((matome) => matome.id.equals(id))).getSingleOrNull();

  Future<MatomeRow?> matomeByCoreId(int coreId) => (select(
    matomes,
  )..where((matome) => matome.coreId.equals(coreId))).getSingleOrNull();

  Future<int> updateMatome(String id, MatomesCompanion patch) =>
      (update(matomes)..where((matome) => matome.id.equals(id))).write(patch);

  Future<int> deleteMatome(String id) {
    return transaction(() async {
      await attachedDatabase.contactsDao.deleteMatomeEdges(id);
      return (delete(matomes)..where((matome) => matome.id.equals(id))).go();
    });
  }

  Future<int> archive(String id) =>
      (update(matomes)..where((matome) => matome.id.equals(id))).write(
        MatomesCompanion(
          archivedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> restore(String id) =>
      (update(matomes)..where((matome) => matome.id.equals(id))).write(
        const MatomesCompanion(archivedAt: Value(null)),
      );

  Future<List<MatomeRow>> listMatomes() =>
      (select(matomes)
            ..where((matome) => matome.archivedAt.isNull())
            ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
          .get();

  Future<List<MatomeRow>> listInboxMatomes() =>
      (select(matomes)
            ..where(
              (matome) => matome.spaceId.isNull() & matome.archivedAt.isNull(),
            )
            ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
          .get();

  Future<List<MatomeRow>> listFiledMatomes() =>
      (select(matomes)
            ..where(
              (matome) =>
                  matome.spaceId.isNotNull() & matome.archivedAt.isNull(),
            )
            ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
          .get();

  Future<List<MatomeRow>> listArchivedReconciledMatomes() =>
      (select(matomes)..where(
            (matome) =>
                matome.archivedAt.isNotNull() & matome.coreId.isNotNull(),
          ))
          .get();

  Future<List<MatomeRow>> listMatomesInSpace(String spaceId) =>
      (select(matomes)
            ..where(
              (matome) =>
                  matome.spaceId.equals(spaceId) & matome.archivedAt.isNull(),
            )
            ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
          .get();

  Future<List<MatomeRow>> listMatomesByDate() => listMatomes();

  Future<List<MatomeRow>> matomesByDateRange(int startEpoch, int endEpoch) =>
      (select(matomes)
            ..where(
              (matome) =>
                  matome.happenedAt.isBetweenValues(startEpoch, endEpoch) &
                  matome.archivedAt.isNull(),
            )
            ..orderBy([(matome) => OrderingTerm.desc(matome.happenedAt)]))
          .get();

  Future<List<MatomeItem>> _hydrateCounts(
    List<MatomeRow> rows,
    String ownerId,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row.id).toSet();
    final itemRows = await attachedDatabase.itemsDao.listAll(ownerId);
    final byMatome = <String, List<RecordingItem>>{};
    for (final item in itemRows) {
      final matomeId = item.matomeId;
      if (matomeId == null || !ids.contains(matomeId)) continue;
      (byMatome[matomeId] ??= []).add(RecordingItem.fromItem(item));
    }

    final peopleExpr = matomeContacts.id.count();
    final peopleQuery = selectOnly(matomeContacts)
      ..addColumns([matomeContacts.matomeId, peopleExpr])
      ..where(matomeContacts.matomeId.isIn(ids))
      ..groupBy([matomeContacts.matomeId]);
    final people = <String, int>{};
    for (final row in await peopleQuery.get()) {
      people[row.read(matomeContacts.matomeId)!] = row.read(peopleExpr) ?? 0;
    }

    final spaceIds = rows.map((row) => row.spaceId).whereType<String>().toSet();
    final spaceNames = <String, String>{};
    if (spaceIds.isNotEmpty) {
      final query = selectOnly(workspaces)
        ..addColumns([workspaces.id, workspaces.name])
        ..where(workspaces.id.isIn(spaceIds));
      for (final row in await query.get()) {
        spaceNames[row.read(workspaces.id)!] = row.read(workspaces.name)!;
      }
    }

    return rows
        .map((row) {
          final children = byMatome[row.id] ?? const <RecordingItem>[];
          return MatomeItem.fromRow(
            row,
            recordingCount: children.length,
            audioCount: children
                .where((item) => item.mediaType == 'audio')
                .length,
            imageCount: children
                .where((item) => item.mediaType == 'image')
                .length,
            documentCount: children
                .where((item) => item.mediaType == 'document')
                .length,
            peopleCount: people[row.id] ?? 0,
            spaceName: row.spaceId == null ? null : spaceNames[row.spaceId],
          );
        })
        .toList(growable: false);
  }

  Future<List<MatomeItem>> listInboxMatomeItems(String ownerId) async =>
      _hydrateCounts(await listInboxMatomes(), ownerId);

  Future<List<MatomeItem>> listMatomeItemsInSpace(
    String spaceId,
    String ownerId,
  ) async => _hydrateCounts(await listMatomesInSpace(spaceId), ownerId);

  Future<List<MatomeItem>> matomeItemsByDateRange(
    int startEpoch,
    int endEpoch,
    String ownerId,
  ) async =>
      _hydrateCounts(await matomesByDateRange(startEpoch, endEpoch), ownerId);

  Future<String?> matomeIdForItem(String itemId, String ownerId) async =>
      (await attachedDatabase.itemsDao.getById(itemId, ownerId))?.matomeId;

  Future<MatomeItem?> getMatomeWithItems(String id, String ownerId) async {
    final row = await getById(id);
    if (row == null) return null;
    final children = await attachedDatabase.itemsDao.listForMatome(id, ownerId);
    return MatomeItem.fromRow(
      row,
      recordings: children.map(RecordingItem.fromItem).toList(growable: false),
    );
  }

  Future<int> fileIntoSpace(String matomeId, String spaceId) =>
      (update(matomes)..where((matome) => matome.id.equals(matomeId))).write(
        MatomesCompanion(spaceId: Value(spaceId)),
      );

  Future<int> moveMatomeToSpace(String matomeId, String spaceId) =>
      fileIntoSpace(matomeId, spaceId);

  Future<int> moveItemToMatome(
    String itemId,
    String matomeId,
    String ownerId,
  ) => attachedDatabase.itemsDao.moveItemsToMatome({itemId}, matomeId, ownerId);

  Future<int> setAggregatedSummary(String matomeId, String text) =>
      (update(matomes)..where((matome) => matome.id.equals(matomeId))).write(
        MatomesCompanion(
          aggregatedSummary: Value(text),
          summaryStale: const Value(false),
        ),
      );

  Future<int> markSummaryStale(String matomeId, bool stale) =>
      (update(matomes)..where((matome) => matome.id.equals(matomeId))).write(
        MatomesCompanion(summaryStale: Value(stale)),
      );

  Future<String?> regenerateSummary(String matomeId, String ownerId) async {
    final item = await getMatomeWithItems(matomeId, ownerId);
    if (item == null) return null;
    final composed = composeAggregatedSummary(item.recordings);
    if (composed == null) {
      await (update(
        matomes,
      )..where((matome) => matome.id.equals(matomeId))).write(
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
