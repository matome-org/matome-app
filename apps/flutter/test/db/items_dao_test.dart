import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/items/item_deletion_service.dart';

const _ownerA = 'owner-a';
const _ownerB = 'owner-b';

ItemsCompanion _item({
  required String id,
  required String ownerId,
  required MatomeItemType type,
  required String payloadId,
  String? matomeId,
  String? workspaceId,
  int? position,
  String title = 'Item',
  int createdAt = 100,
}) {
  return ItemsCompanion.insert(
    id: id,
    ownerId: ownerId,
    clientId: id,
    workspaceId: Value(workspaceId),
    matomeId: Value(matomeId),
    position: Value(position),
    itemType: type.wireName,
    title: Value(title),
    fileBlobId: type == MatomeItemType.file
        ? Value(payloadId)
        : const Value.absent(),
    textContentId: type == MatomeItemType.text
        ? Value(payloadId)
        : const Value.absent(),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

FileBlobsCompanion _file({
  required String id,
  String blobId = 'opaque-item-blob',
  String mediaType = 'audio',
  int createdAt = 100,
}) {
  return FileBlobsCompanion.insert(
    id: id,
    blobId: Value(blobId),
    byteSize: const Value(42),
    mediaType: mediaType,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

TextContentsCompanion _text({
  required String id,
  required String body,
  int createdAt = 100,
}) {
  return TextContentsCompanion.insert(
    id: id,
    body: body,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  test('fresh schema contains only canonical item payload tables', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();

    expect(names, containsAll(['items', 'file_blobs', 'text_contents']));
    expect(names, isNot(contains('recordings')));

    final itemColumns = await db
        .customSelect('PRAGMA table_info(items)')
        .map((row) => row.read<String>('name'))
        .get();
    expect(
      itemColumns,
      containsAll([
        'id',
        'core_id',
        'owner_id',
        'client_id',
        'client_fingerprint',
        'workspace_id',
        'matome_id',
        'position',
        'item_type',
        'title',
        'notes',
        'metadata',
        'processing_state',
        'processing_run_id',
        'source_revision',
        'processing_config_revision',
        'processing_outputs',
        'processing_error',
        'file_blob_id',
        'text_content_id',
        'is_dirty',
        'sync_state',
      ]),
    );

    final fileColumns = await db
        .customSelect('PRAGMA table_info(file_blobs)')
        .map((row) => row.read<String>('name'))
        .get();
    expect(
      fileColumns,
      containsAll([
        'id',
        'core_id',
        'storage_key',
        'filename',
        'content_type',
        'byte_size',
        'checksum_sha256',
        'media_type',
        'duration',
        'upload_state',
        'upload_generation',
        'uploaded_at',
        'multipart_context',
        'blob_id',
        'blob_state',
        'cipher_format',
        'cipher_version',
        'is_dirty',
      ]),
    );
    expect(fileColumns, isNot(contains('local_path')));
    expect(fileColumns, isNot(contains('wrapped_fek')));
    expect(fileColumns, isNot(contains('file_nonce_prefix')));

    final retention = await db.select(db.vaultRetentionPolicies).getSingle();
    expect(retention.mode, 'keep_forever');
    expect(retention.expiryDays, isNull);
  });

  test('file delete tombstones and replaces upload work atomically', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.itemsDao;

    await dao.createFileItem(
      item: _item(
        id: 'delete-me',
        ownerId: _ownerA,
        type: MatomeItemType.file,
        payloadId: 'file-delete-me',
      ),
      file: _file(id: 'file-delete-me', blobId: 'vault-delete-me'),
      initialWork: fileUploadWork(
        itemId: 'delete-me',
        blobId: 'vault-delete-me',
        blobRevision: 1,
        sourceRevision: 1,
        now: 100,
      ),
    );

    expect(
      await dao.tombstoneFileDelete(
        itemId: 'delete-me',
        ownerId: _ownerB,
        now: 200,
      ),
      isFalse,
    );
    expect(
      await dao.tombstoneFileDelete(
        itemId: 'delete-me',
        ownerId: _ownerA,
        now: 200,
      ),
      isTrue,
    );

    expect(await dao.listAll(_ownerA), isEmpty);
    final tombstone = await dao.getByIdIncludingDeleted('delete-me', _ownerA);
    expect(tombstone?.item.isDeleted, isTrue);
    expect(tombstone?.item.syncState, 'pending_delete');
    final work = await db.workQueueDao.listAll();
    expect(work, hasLength(1));
    expect(work.single.kind, kWorkKindFileDelete);
    expect(work.single.blobId, 'vault-delete-me');
    expect(work.single.stage, kWorkStagePrepareDelete);
  });

  test('central deletion removes a local-only text Item', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.itemsDao.createTextItem(
      item: _item(
        id: 'local-text',
        ownerId: _ownerA,
        type: MatomeItemType.text,
        payloadId: 'text-local',
      ),
      text: _text(id: 'text-local', body: 'Local only'),
    );
    var drains = 0;
    final service = ItemDeletionService(db.itemsDao, () async {
      drains++;
    });

    expect(await service.delete('local-text', _ownerA), isTrue);
    expect(await db.itemsDao.getById('local-text', _ownerA), isNull);
    expect(drains, 1);
  });

  test('every item read is owner-scoped across all placement modes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dao = db.itemsDao;

    await db.matomesDao.create(
      MatomesCompanion.insert(
        id: 'mat-a',
        title: 'Owner A',
        happenedAt: 100,
        createdAt: 100,
      ),
    );
    await dao.createFileItem(
      item: _item(
        id: 'loose-a',
        ownerId: _ownerA,
        type: MatomeItemType.file,
        payloadId: 'blob-loose-a',
      ),
      file: _file(id: 'blob-loose-a'),
    );
    await dao.createTextItem(
      item: _item(
        id: 'space-a',
        ownerId: _ownerA,
        type: MatomeItemType.text,
        payloadId: 'text-space-a',
        workspaceId: 'ws_default_personal',
      ),
      text: _text(id: 'text-space-a', body: 'Direct Space'),
    );
    await dao.createTextItem(
      item: _item(
        id: 'matome-a',
        ownerId: _ownerA,
        type: MatomeItemType.text,
        payloadId: 'text-matome-a',
        matomeId: 'mat-a',
        position: 0,
      ),
      text: _text(id: 'text-matome-a', body: 'In Matome'),
    );
    await dao.createFileItem(
      item: _item(
        id: 'loose-b',
        ownerId: _ownerB,
        type: MatomeItemType.file,
        payloadId: 'blob-loose-b',
      ),
      file: _file(id: 'blob-loose-b'),
    );

    expect((await dao.getById('loose-a', _ownerA))?.item.id, 'loose-a');
    expect(await dao.getById('loose-a', _ownerB), isNull);
    expect((await dao.listLoose(_ownerA)).map((row) => row.item.id), [
      'loose-a',
    ]);
    expect(
      (await dao.listForMatome('mat-a', _ownerA)).map((row) => row.item.id),
      ['matome-a'],
    );
    expect(await dao.listForMatome('mat-a', _ownerB), isEmpty);
    expect((await dao.listAll(_ownerA)).map((row) => row.item.id).toSet(), {
      'loose-a',
      'space-a',
      'matome-a',
    });
  });

  test('file and text create edit delete survive database restarts', () async {
    final dir = await Directory.systemTemp.createTemp('matome_items_restart_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/matome.sqlite');

    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.itemsDao.createFileItem(
      item: _item(
        id: 'file-local',
        ownerId: _ownerA,
        type: MatomeItemType.file,
        payloadId: 'blob-local',
        title: 'Original file',
      ),
      file: _file(id: 'blob-local', blobId: 'opaque-capture-blob'),
    );
    await db.itemsDao.createTextItem(
      item: _item(
        id: 'text-local',
        ownerId: _ownerA,
        type: MatomeItemType.text,
        payloadId: 'text-content-local',
        title: 'Original text',
      ),
      text: _text(id: 'text-content-local', body: 'First body'),
    );
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    var fileItem = await db.itemsDao.getById('file-local', _ownerA);
    var textItem = await db.itemsDao.getById('text-local', _ownerA);
    expect(fileItem?.file?.blobId, 'opaque-capture-blob');
    expect(textItem?.text?.body, 'First body');

    await db.itemsDao.updateItem(
      'file-local',
      _ownerA,
      const ItemsCompanion(title: Value('Edited file')),
    );
    await db.itemsDao.editTextBody(
      itemId: 'text-local',
      ownerId: _ownerA,
      body: 'Edited body',
      now: 2000,
      configRevision: 0,
    );
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    fileItem = await db.itemsDao.getById('file-local', _ownerA);
    textItem = await db.itemsDao.getById('text-local', _ownerA);
    expect(fileItem?.item.title, 'Edited file');
    expect(textItem?.text?.body, 'Edited body');

    expect(await db.itemsDao.deleteWithPayload('file-local', _ownerB), 0);
    expect(await db.itemsDao.deleteWithPayload('file-local', _ownerA), 1);
    expect(await db.itemsDao.deleteWithPayload('text-local', _ownerA), 1);
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.itemsDao.getById('file-local', _ownerA), isNull);
    expect(await db.itemsDao.getById('text-local', _ownerA), isNull);
  });
}
