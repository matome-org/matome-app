import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';

import '../support/item_fixtures.dart';

MatomesCompanion _matome({
  required String id,
  required String title,
  String? spaceId,
  int happenedAt = 1000,
}) => MatomesCompanion.insert(
  id: id,
  title: title,
  spaceId: Value(spaceId),
  happenedAt: happenedAt,
  createdAt: happenedAt,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('list hydration counts only the authenticated owner Items', () async {
    await db.matomesDao.create(_matome(id: 'matome', title: 'Meeting'));
    await insertTestFileItem(db, id: 'owned', matomeId: 'matome');
    await insertTestFileItem(
      db,
      id: 'foreign',
      ownerId: '2',
      matomeId: 'matome',
    );

    final item = (await db.matomesDao.listInboxMatomeItems('1')).single;
    expect(item.recordingCount, 1);
    expect(item.recordings, isEmpty);
  });

  test('detail hydrates canonical file and text Items', () async {
    await db.matomesDao.create(_matome(id: 'matome', title: 'Meeting'));
    await insertTestFileItem(db, id: 'file', matomeId: 'matome', position: 0);
    await insertTestTextItem(
      db,
      id: 'text',
      body: 'Decision note',
      matomeId: 'matome',
      position: 1,
    );

    final detail = await db.matomesDao.getMatomeWithItems('matome', '1');
    expect(detail?.recordings.map((item) => item.id), ['file', 'text']);
  });

  test('moving an Item invalidates source and destination summaries', () async {
    await db.matomesDao.create(_matome(id: 'source', title: 'Source'));
    await db.matomesDao.create(
      _matome(id: 'destination', title: 'Destination'),
    );
    await insertTestFileItem(db, id: 'file', matomeId: 'source');

    expect(await db.matomesDao.moveItemToMatome('file', 'destination', '1'), 1);
    expect((await db.matomesDao.getById('source'))?.summaryStale, isTrue);
    expect((await db.matomesDao.getById('destination'))?.summaryStale, isTrue);
  });

  test('summary regeneration composes canonical processing outputs', () async {
    await db.matomesDao.create(_matome(id: 'matome', title: 'Meeting'));
    await insertTestFileItem(
      db,
      id: 'file',
      matomeId: 'matome',
      summary: 'A concise result',
    );

    final summary = await db.matomesDao.regenerateSummary('matome', '1');
    expect(summary, contains('A concise result'));
    final row = await db.matomesDao.getById('matome');
    expect(row?.aggregatedSummary, summary);
    expect(row?.summaryStale, isFalse);
  });

  test('item-to-Matome lookup is owner-scoped', () async {
    await db.matomesDao.create(_matome(id: 'matome', title: 'Meeting'));
    await insertTestFileItem(db, id: 'file', matomeId: 'matome');
    expect(await db.matomesDao.matomeIdForItem('file', '1'), 'matome');
    expect(await db.matomesDao.matomeIdForItem('file', '2'), isNull);
  });
}
