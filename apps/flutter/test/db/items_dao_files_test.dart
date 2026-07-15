import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/file_row.dart';

import '../support/item_fixtures.dart';

const _ownerA = '1';
const _ownerB = '2';

MatomesCompanion _matome(String id, String title) => MatomesCompanion.insert(
  id: id,
  title: title,
  happenedAt: 1000,
  createdAt: 1000,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'Files aggregation is owner-scoped for loose and Matome Items',
    () async {
      await db.matomesDao.create(_matome('mat-a', 'A'));
      await db.matomesDao.create(_matome('mat-b', 'B'));
      await insertTestFileItem(
        db,
        id: 'file-a',
        ownerId: _ownerA,
        matomeId: 'mat-a',
      );
      await insertTestFileItem(
        db,
        id: 'loose-a',
        ownerId: _ownerA,
        createdAt: 2000,
      );
      await insertTestFileItem(
        db,
        id: 'file-b',
        ownerId: _ownerB,
        matomeId: 'mat-b',
      );

      final files = await db.itemsDao.filesForOwner(_ownerA);
      expect(files.map((file) => file.id), ['loose-a', 'file-a']);
      expect(files.singleWhere((file) => file.id == 'file-a').matome, 'A');
      expect(files.singleWhere((file) => file.id == 'loose-a').unfiled, isTrue);
      expect(files.any((file) => file.id == 'file-b'), isFalse);
    },
  );

  test('Files maps canonical file payload facts', () async {
    await insertTestFileItem(
      db,
      id: 'document',
      filename: 'budget.xlsx',
      mediaType: 'document',
      byteSize: 2_516_582,
      coreId: 9,
    );

    final file = (await db.itemsDao.filesForOwner(_ownerA)).single;
    expect(file.kind, FileKind.document);
    expect(file.ext, 'xlsx');
    expect(file.sizeLabel, '2.4 MB');
    expect(file.rollup.name, 'cloud');
  });

  test('move and undo are owner-scoped', () async {
    await db.matomesDao.create(_matome('source', 'Source'));
    await db.matomesDao.create(_matome('destination', 'Destination'));
    await insertTestFileItem(
      db,
      id: 'owned',
      ownerId: _ownerA,
      matomeId: 'source',
    );
    await insertTestFileItem(
      db,
      id: 'foreign',
      ownerId: _ownerB,
      matomeId: 'source',
    );

    final prior = await db.itemsDao.matomeIdsForOwnedItems({
      'owned',
      'foreign',
    }, _ownerA);
    expect(prior, {'owned': 'source'});
    expect(
      await db.itemsDao.moveItemsToMatome(
        {'owned', 'foreign'},
        'destination',
        _ownerA,
      ),
      1,
    );
    expect((await db.itemsDao.getById('foreign', _ownerB))?.matomeId, 'source');

    await db.itemsDao.restoreItemMatomes(prior, _ownerA);
    expect((await db.itemsDao.getById('owned', _ownerA))?.matomeId, 'source');
  });
}
