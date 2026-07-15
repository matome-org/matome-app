import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() => db = _memDb());
  tearDown(() => db.close());

  test('schemaVersion is 21 (bounded processing error state)', () {
    expect(db.schemaVersion, 21);
  });

  test(
    'onCreate builds Core-shaped item payload tables without client FKs',
    () async {
      final names = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((row) => row.read<String>('name'))
          .get();
      expect(names, containsAll(['items', 'file_blobs', 'text_contents']));

      final itemSql = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='items'",
          )
          .map((row) => row.read<String>('sql'))
          .getSingle();
      expect(itemSql, contains('"item_type" TEXT NOT NULL'));
      expect(itemSql, isNot(contains('REFERENCES')));
    },
  );

  test('v18 local cache upgrades to v19 by creating item tables', () async {
    final dir = await Directory.systemTemp.createTemp('matome_m019_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final sdb = raw.sqlite3.open(file.path);
    try {
      // Minimal v18-shaped `recordings` (no rows needed here — this test
      // isolates the m019 item-table creation) so m020's `ALTER TABLE
      // recordings ADD COLUMN wrapped_fek/file_nonce_prefix` (#1855) has a
      // table to alter, same as any real v18 install would.
      sdb.execute('''
        CREATE TABLE recordings (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          duration TEXT NOT NULL,
          badge TEXT NOT NULL DEFAULT 'Inbox',
          isProcessing INTEGER NOT NULL DEFAULT 1,
          audioFilePath TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          mediaType TEXT NOT NULL DEFAULT 'audio',
          processingStatus TEXT NOT NULL DEFAULT 'done'
        );
      ''');
      sdb.execute('PRAGMA user_version = 18;');
    } finally {
      sdb.dispose();
    }

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(upgraded.schemaVersion, 21);
    final names = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(names, containsAll(['items', 'file_blobs', 'text_contents']));
  });

  test(
    'listForMatome resolves the payload arc by item_type with left joins',
    () async {
      await db
          .into(db.fileBlobs)
          .insert(
            FileBlobsCompanion.insert(
              id: const Value(10),
              storageKey: 'owners/1/items/10/media',
              byteSize: 2048,
              mediaType: 'image',
            ),
          );
      await db
          .into(db.textContents)
          .insert(
            TextContentsCompanion.insert(
              id: const Value(20),
              body: 'A typed note',
            ),
          );
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: const Value(100),
              matomeId: 7,
              position: 1,
              itemType: MatomeItemType.file.wireName,
              fileBlobId: const Value(10),
            ),
          );
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: const Value(101),
              matomeId: 7,
              position: 2,
              itemType: MatomeItemType.text.wireName,
              textContentId: const Value(20),
            ),
          );

      final rows = await db.itemsDao.listForMatome(7);

      expect(rows.map((row) => row.item.id), [100, 101]);
      expect(rows[0].type, MatomeItemType.file);
      expect(rows[0].file?.storageKey, 'owners/1/items/10/media');
      expect(rows[0].text, isNull);
      expect(rows[1].type, MatomeItemType.text);
      expect(rows[1].file, isNull);
      expect(rows[1].text?.body, 'A typed note');
    },
  );

  test('matome detail hydration includes persisted text item rows', () async {
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: 'mat_local_1',
            title: 'Kickoff',
            happenedAt: 1,
            createdAt: 1,
            coreId: const Value(7),
          ),
        );
    await db
        .into(db.textContents)
        .insert(
          TextContentsCompanion.insert(
            id: const Value(20),
            body: 'A typed note that should reload',
          ),
        );
    await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            id: const Value(101),
            matomeId: 7,
            position: 1,
            itemType: MatomeItemType.text.wireName,
            textContentId: const Value(20),
          ),
        );

    final matome = await db.matomesDao.getMatomeWithRecordings('mat_local_1');

    expect(matome, isNotNull);
    expect(matome!.recordings, hasLength(1));
    expect(matome.recordings.single.itemType, MatomeItemType.text);
    expect(matome.recordings.single.title, 'A typed note that should reload');
    expect(matome.recordings.single.notes, 'A typed note that should reload');
  });
}
