import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/items_dao.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording.dart';

Future<ItemWithPayload> insertTestFileItem(
  AppDatabase db, {
  required String id,
  String ownerId = '1',
  String title = 'File',
  String? summary,
  String? transcript,
  String? description,
  String? ocrText,
  String? extractedText,
  String? notes,
  String? workspaceId,
  String? matomeId,
  int? position,
  String mediaType = 'audio',
  int durationSeconds = 30,
  String localPath = '/tmp/item.m4a',
  String? filename,
  String? originalExtension,
  String? contentType,
  String openPolicy = 'download_only',
  int byteSize = 0,
  int createdAt = 1000,
  int? coreId,
  String processingStatus = 'done',
  ProcessingState? processingState,
  String? processingRunId,
  int processingAttempt = 0,
  String? processingErrorCode,
  String? wrappedFek,
  String? fileNoncePrefix,
}) async {
  final payloadId = 'file_$id';
  final isQueueState =
      isUploadQueuePendingStatus(processingStatus) ||
      processingStatus.startsWith('blocked_');
  final resolvedProcessingState =
      processingState?.wireName ??
      switch (processingStatus) {
        'processing' => 'processing',
        'failed' => 'failed',
        _ => 'succeeded',
      };
  final outputs = <String, dynamic>{
    if (summary != null)
      'summary': <String, dynamic>{'type': 'summary', 'markdown': summary},
    if (transcript != null)
      'transcript': <String, dynamic>{'type': 'transcript', 'text': transcript},
    if (description != null)
      'description': <String, dynamic>{
        'type': 'description',
        'text': description,
      },
    if (ocrText != null)
      'ocr_text': <String, dynamic>{'type': 'ocr_text', 'text': ocrText},
    if (extractedText != null)
      'extracted_text': <String, dynamic>{
        'type': 'extracted_text',
        'text': extractedText,
      },
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
      processingState: Value(resolvedProcessingState),
      processingRunId: Value(processingRunId),
      processingAttempt: Value(processingAttempt),
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
      originalExtension: Value(
        originalExtension ?? _extensionFromFilename(filename),
      ),
      contentType: Value(contentType),
      byteSize: Value(byteSize),
      mediaType: mediaType,
      duration: Value(durationSeconds),
      uploadState: Value(coreId == null ? 'pending' : 'uploaded'),
      uploadedAt: Value(coreId == null ? null : createdAt),
      openPolicy: Value(openPolicy),
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

String? _extensionFromFilename(String? filename) {
  if (filename == null) return null;
  final dot = filename.lastIndexOf('.');
  if (dot <= 0 || dot == filename.length - 1) return null;
  return filename.substring(dot + 1).toLowerCase();
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
  String? summary,
  ProcessingState processingState = ProcessingState.notRequested,
  String? processingRunId,
  int processingAttempt = 0,
  String? processingErrorCode,
}) async {
  final payloadId = 'text_content_$id';
  final outputs = <String, dynamic>{
    if (summary != null)
      'summary': <String, dynamic>{'type': 'summary', 'markdown': summary},
  };
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
      processingState: Value(processingState.wireName),
      processingRunId: Value(processingRunId),
      processingAttempt: Value(processingAttempt),
      processingOutputs: Value(jsonEncode(outputs)),
      processingErrorCode: Value(processingErrorCode),
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
