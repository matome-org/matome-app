import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/home/inbox_sync.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

Recording _recording({
  required int id,
  Object? ownerId = '1',
  String? storageKey,
}) => Recording.fromJson({
  'id': id,
  'owner_id': ?ownerId,
  'title': 'File',
  'status': 'done',
  'media_type': 'audio',
  'byte_size': 4096,
  'storage_key': ?storageKey,
  'inserted_at': '2026-06-08T12:00:00Z',
  'updated_at': '2026-06-08T12:05:00Z',
});

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('Core recording maps to canonical Item and FileBlob owner fields', () {
    final companions = recordingToItemCompanions(
      _recording(id: 7, ownerId: '9'),
    );
    expect(companions.item.ownerId.value, '9');
    expect(companions.item.coreId.value, 7);
    expect(companions.item.fileBlobId.value, 'file_7');
    expect(companions.file.byteSize.value, 4096);
  });

  test('missing owner is rejected instead of creating an unscoped row', () {
    expect(
      () => recordingToItemCompanions(_recording(id: 7, ownerId: null)),
      throwsFormatException,
    );
  });

  test('uploaded Core file maps coherent FileBlob upload facts', () {
    final companions = recordingToItemCompanions(
      _recording(id: 7, storageKey: 'owners/1/item-7.m4a'),
    );

    expect(companions.file.uploadState.value, 'uploaded');
    expect(companions.file.uploadedAt.value, isNotNull);
    expect(companions.file.isDirty.value, isFalse);
  });

  test('reconciled Items remain invisible to another owner', () async {
    for (final owner in ['1', '2']) {
      final companions = recordingToItemCompanions(
        _recording(id: int.parse(owner), ownerId: owner),
      );
      await db.itemsDao.upsertFileItem(
        item: companions.item,
        file: companions.file,
      );
    }

    expect((await db.itemsDao.filesForOwner('1')).map((file) => file.id), [
      '1',
    ]);
    expect((await db.itemsDao.filesForOwner('2')).map((file) => file.id), [
      '2',
    ]);
    expect(await db.itemsDao.getById('2', '1'), isNull);
  });
}
