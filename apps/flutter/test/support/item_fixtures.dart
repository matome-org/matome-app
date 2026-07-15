import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/items_dao.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';

Future<ItemWithPayload> insertTestFileItem(
  AppDatabase db, {
  required String id,
  String ownerId = '1',
  String title = 'File',
  String? summary,
  String? transcript,
  String? notes,
  String? workspaceId,
  String? matomeId,
  int? position,
  String mediaType = 'audio',
  int durationSeconds = 30,
  String localPath = '/tmp/item.m4a',
  String? filename,
  int byteSize = 0,
  int createdAt = 1000,
  int? coreId,
  String processingStatus = 'done',
  String? processingErrorCode,
  String? wrappedFek,
  String? fileNoncePrefix,
}) async {
  final payloadId = 'file_$id';
  final isQueueState =
      isUploadQueuePendingStatus(processingStatus) ||
      processingStatus.startsWith('blocked_');
  final processingState = switch (processingStatus) {
    'processing' => 'processing',
    'failed' => 'failed',
    _ => 'succeeded',
  };
  final outputs = <String, dynamic>{
    'summary': ?summary,
    'transcript': ?transcript,
  };
  await db.itemsDao.upsertFileItem(
    item: ItemsCompanion.insert(
      id: id,
      coreId: Value(coreId),
      ownerId: ownerId,
      clientId: id,
      workspaceId: Value(workspaceId),
      matomeId: Value(matomeId),
      position: Value(position),
      itemType: MatomeItemType.file.wireName,
      title: Value(title),
      notes: Value(notes),
      processingState: Value(processingState),
      processingOutputs: Value(jsonEncode(outputs)),
      processingErrorCode: Value(processingErrorCode),
      fileBlobId: Value(payloadId),
      isDirty: Value(coreId == null),
      syncState: Value(isQueueState ? processingStatus : 'synced'),
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    file: FileBlobsCompanion.insert(
      id: payloadId,
      filename: Value(filename),
      byteSize: Value(byteSize),
      mediaType: mediaType,
      duration: Value(durationSeconds),
      uploadState: Value(coreId == null ? 'pending' : 'uploaded'),
      uploadedAt: Value(coreId == null ? null : createdAt),
      localPath: Value(localPath),
      wrappedFek: Value(wrappedFek),
      fileNoncePrefix: Value(fileNoncePrefix),
      isDirty: Value(coreId == null),
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  return (await db.itemsDao.getById(id, ownerId))!;
}

Future<ItemWithPayload> insertTestTextItem(
  AppDatabase db, {
  required String id,
  String ownerId = '1',
  required String body,
  String? matomeId,
  String? workspaceId,
  int? position,
  int createdAt = 1000,
  int? coreId,
}) async {
  final payloadId = 'text_content_$id';
  await db.itemsDao.createTextItem(
    item: ItemsCompanion.insert(
      id: id,
      coreId: Value(coreId),
      ownerId: ownerId,
      clientId: id,
      workspaceId: Value(workspaceId),
      matomeId: Value(matomeId),
      position: Value(position),
      itemType: MatomeItemType.text.wireName,
      title: Value(body.trim().split('\n').first),
      textContentId: Value(payloadId),
      isDirty: Value(coreId == null),
      syncState: Value(coreId == null ? 'local_saved' : 'synced'),
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    text: TextContentsCompanion.insert(
      id: payloadId,
      coreId: Value(coreId),
      body: body,
      isDirty: Value(coreId == null),
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  return (await db.itemsDao.getById(id, ownerId))!;
}
