import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../items/matome_item_type.dart';
import '../documents/document_open_policy.dart';
import '../recordings/recording.dart';

String coreIdToLocalId(int coreId) => coreId.toString();

Value<String?> mergeText(String? incoming) {
  if (incoming == null || incoming.isEmpty) return const Value.absent();
  return Value(incoming);
}

String? coreWorkspaceIdToLocal(int? workspaceId) => workspaceId?.toString();

String formatDurationText(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  return mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
}

String formatClock(DateTime when) {
  final local = when.toLocal();
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} $period';
}

/// Canonical Item + FileBlob companions for one Core Item response.
({ItemsCompanion item, FileBlobsCompanion file}) recordingToItemCompanions(
  Recording recording, {
  ItemWithPayload? existing,
}) {
  final ownerId = recording.ownerId?.trim();
  if (ownerId == null || ownerId.isEmpty) {
    throw const FormatException('Item owner_id is required');
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  final createdAt =
      (recording.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;
  final localId = existing?.id ?? coreIdToLocalId(recording.id);
  final fileId = existing?.file?.id ?? 'file_$localId';
  final coreWorkspaceId = coreWorkspaceIdToLocal(recording.workspaceId);
  final workspaceId = coreWorkspaceId ?? existing?.workspaceId;
  final processing = itemProcessingUpdate(recording, existing: existing);

  final storageKey = recording.storageKey;
  final existingUploadState = existing?.file?.uploadState;
  final uploadState = recording.uploadState ?? existingUploadState ?? 'pending';
  final uploadedAt = uploadState == 'uploaded'
      ? recording.uploadedAt?.millisecondsSinceEpoch ??
            (existingUploadState == 'uploaded'
                ? existing?.file?.uploadedAt
                : null)
      : null;
  final existingLocalPath = existing?.localPath;
  final localPath =
      existingLocalPath != null &&
          (existingLocalPath.startsWith('/') ||
              existingLocalPath.startsWith('file:'))
      ? existingLocalPath
      : null;
  final incomingFilename = recording.filename == null
      ? null
      : sanitizeDocumentFilename(recording.filename!);
  final incomingExtension = incomingFilename != null
      ? documentExtension(incomingFilename)
      : documentExtension('file.${recording.originalExtension ?? ''}');
  final incomingContentType = recording.contentType == null
      ? null
      : normalizeDocumentMime(recording.contentType);
  final incomingOpenPolicy = recording.openPolicy == null
      ? null
      : DocumentOpenPolicy.fromWire(recording.openPolicy).wireName;
  final incomingByteSize = recording.byteSize == null
      ? null
      : (recording.byteSize! < 0 ? 0 : recording.byteSize!);

  return (
    item: ItemsCompanion.insert(
      id: localId,
      coreId: Value(recording.id),
      ownerId: ownerId,
      clientId: existing?.item.clientId ?? localId,
      workspaceId: Value(workspaceId),
      matomeId: Value(existing?.matomeId),
      position: Value(existing?.item.position),
      itemType: MatomeItemType.file.wireName,
      title: Value(recording.title),
      notes: Value(existing?.notes ?? recording.notes),
      metadata: Value(existing?.item.metadata ?? '{}'),
      processingState: processing.processingState,
      processingRunId: processing.processingRunId,
      processingAttempt: processing.processingAttempt,
      sourceRevision: Value(existing?.item.sourceRevision ?? 1),
      processingConfigRevision: Value(existing?.item.processingConfigRevision),
      processingOutputs: processing.processingOutputs,
      processingRequestedOutputs: processing.processingRequestedOutputs,
      processingError: processing.processingError,
      processingErrorCode: processing.processingErrorCode,
      fileBlobId: Value(fileId),
      isDirty: const Value(false),
      syncState: const Value('synced'),
      createdAt: existing?.createdAt ?? createdAt,
      updatedAt: now,
    ),
    file: FileBlobsCompanion.insert(
      id: fileId,
      coreId: Value(existing?.file?.coreId),
      storageKey: Value(storageKey ?? existing?.file?.storageKey),
      filename: Value(incomingFilename ?? existing?.file?.filename),
      originalExtension: Value(
        incomingExtension ?? existing?.file?.originalExtension,
      ),
      contentType: Value(incomingContentType ?? existing?.file?.contentType),
      byteSize: Value(incomingByteSize ?? existing?.byteSize ?? 0),
      checksumSha256: Value(
        recording.checksumSha256 ?? existing?.file?.checksumSha256,
      ),
      mediaType: recording.mediaType ?? existing?.mediaType ?? 'audio',
      duration: Value(recording.duration ?? existing?.durationSeconds),
      uploadState: Value(uploadState),
      uploadGeneration: Value(existing?.file?.uploadGeneration ?? 1),
      uploadedAt: Value(uploadedAt),
      multipartContext: Value(existing?.file?.multipartContext),
      openPolicy: Value(
        incomingOpenPolicy ?? existing?.file?.openPolicy ?? 'download_only',
      ),
      localPath: Value(localPath),
      wrappedFek: Value(existing?.wrappedFek),
      fileNoncePrefix: Value(existing?.fileNoncePrefix),
      isDirty: const Value(false),
      createdAt: existing?.file?.createdAt ?? createdAt,
      updatedAt: now,
    ),
  );
}

/// Builds a current-run guarded processing-only patch for file or text Items.
/// Older attempts and same-attempt/different-run responses are ignored.
ItemsCompanion itemProcessingUpdate(
  Recording recording, {
  required ItemWithPayload? existing,
}) {
  final incoming = recording.processing;
  final existingAttempt = existing?.item.processingAttempt ?? -1;
  final existingRunId = existing?.item.processingRunId;
  final sourceIsCurrent =
      existing == null ||
      recording.sourceRevision >= existing.item.sourceRevision;
  final applies =
      sourceIsCurrent &&
      (existing == null ||
          incoming.attempt > existingAttempt ||
          (incoming.attempt == existingAttempt &&
              incoming.runId == existingRunId));
  final state = applies
      ? incoming.state.wireName
      : existing.item.processingState;
  final runId = applies ? incoming.runId : existing.item.processingRunId;
  final attempt = applies ? incoming.attempt : existing.item.processingAttempt;
  final requestedOutputs = applies
      ? jsonEncode(
          incoming.requestedOutputs
              .map((kind) => kind.wireName)
              .toList(growable: false),
        )
      : existing.item.processingRequestedOutputs;
  final outputs = switch ((applies, existing, incoming.state)) {
    (false, final current?, _) => current.item.processingOutputs,
    (_, null, _) => jsonEncode(incoming.outputs.toJson()),
    (true, _, ProcessingState.succeeded) => jsonEncode(
      incoming.outputs.toJson(),
    ),
    (true, final current?, ProcessingState.partial) => _mergeTypedOutputs(
      current.item.processingOutputs,
      incoming.outputs,
    ),
    (_, final current?, _) => current.item.processingOutputs,
  };
  final incomingError = incoming.error;
  final error = applies
      ? (incomingError == null ? null : jsonEncode(incomingError.toJson()))
      : existing.item.processingError;
  final errorCode = applies
      ? incomingError?.code
      : existing.item.processingErrorCode;
  return ItemsCompanion(
    processingState: Value(state),
    processingRunId: Value(runId),
    processingAttempt: Value(attempt),
    processingOutputs: Value(outputs),
    processingRequestedOutputs: Value(requestedOutputs),
    processingError: Value(error),
    processingErrorCode: Value(errorCode),
  );
}

({ItemsCompanion item, TextContentsCompanion text}) textToItemCompanions(
  Recording remote, {
  ItemWithPayload? existing,
}) {
  final ownerId = remote.ownerId?.trim();
  final clientId = remote.clientId?.trim();
  if (ownerId == null ||
      ownerId.isEmpty ||
      clientId == null ||
      clientId.isEmpty) {
    throw const FormatException(
      'Text item owner_id and client_id are required',
    );
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final createdAt =
      (remote.insertedAt ?? DateTime.now()).millisecondsSinceEpoch;
  final localId = existing?.id ?? clientId;
  final textId = existing?.text?.id ?? 'text_content_$localId';
  final incomingBody = remote.textBody ?? '';
  final dirty =
      existing?.text?.isDirty == true || existing?.item.isDirty == true;
  final sameBody = existing?.text?.body == incomingBody;
  final acceptedRevision = existing?.item.acceptedSourceRevision ?? 0;
  final incomingIsCurrent = remote.sourceRevision >= acceptedRevision;
  final acceptsRemote =
      existing == null || sameBody || (!dirty && incomingIsCurrent);
  final diverged =
      existing != null &&
      dirty &&
      !sameBody &&
      (remote.sourceRevision >= existing.item.sourceRevision ||
          remote.sourceRevision > existing.item.acceptedSourceRevision);
  final processing = existing != null && dirty && !sameBody
      ? ItemsCompanion(
          processingState: Value(existing.item.processingState),
          processingRunId: Value(existing.item.processingRunId),
          processingAttempt: Value(existing.item.processingAttempt),
          processingOutputs: Value(existing.item.processingOutputs),
          processingRequestedOutputs: Value(
            existing.item.processingRequestedOutputs,
          ),
          processingError: Value(existing.item.processingError),
          processingErrorCode: Value(existing.item.processingErrorCode),
        )
      : itemProcessingUpdate(remote, existing: existing);

  return (
    item: ItemsCompanion.insert(
      id: localId,
      coreId: Value(remote.id),
      ownerId: ownerId,
      clientId: clientId,
      workspaceId: Value(
        coreWorkspaceIdToLocal(remote.workspaceId) ?? existing?.workspaceId,
      ),
      matomeId: Value(existing?.matomeId),
      position: Value(existing?.item.position),
      itemType: MatomeItemType.text.wireName,
      title: Value(remote.title),
      notes: Value(existing?.notes),
      metadata: Value(existing?.item.metadata ?? '{}'),
      processingState: processing.processingState,
      processingRunId: processing.processingRunId,
      processingAttempt: processing.processingAttempt,
      sourceRevision: Value(
        acceptsRemote && incomingIsCurrent
            ? remote.sourceRevision
            : existing?.item.sourceRevision ?? remote.sourceRevision,
      ),
      acceptedSourceRevision: Value(
        remote.sourceRevision > acceptedRevision
            ? remote.sourceRevision
            : acceptedRevision,
      ),
      processingConfigRevision: Value(existing?.item.processingConfigRevision),
      processingOutputs: processing.processingOutputs,
      processingRequestedOutputs: processing.processingRequestedOutputs,
      processingError: processing.processingError,
      processingErrorCode: processing.processingErrorCode,
      textContentId: Value(textId),
      isDirty: Value(!acceptsRemote),
      syncState: Value(
        diverged ? 'conflict' : (acceptsRemote ? 'synced' : 'pending_sync'),
      ),
      isDeleted: Value(existing?.item.isDeleted ?? false),
      createdAt: existing?.createdAt ?? createdAt,
      updatedAt: now,
    ),
    text: TextContentsCompanion.insert(
      id: textId,
      coreId: Value(remote.id),
      body: acceptsRemote ? incomingBody : existing.text!.body,
      acceptedBody: Value(incomingBody),
      isDirty: Value(!acceptsRemote),
      createdAt: existing?.text?.createdAt ?? createdAt,
      updatedAt: now,
    ),
  );
}

String _mergeTypedOutputs(String existing, ProcessingOutputs incoming) {
  final outputs = <String, dynamic>{};
  try {
    final decoded = jsonDecode(existing);
    if (decoded is Map<String, dynamic>) outputs.addAll(decoded);
  } on FormatException {
    // Invalid cached machine output is replaced by valid typed output.
  }
  outputs.addAll(incoming.toJson());
  return jsonEncode(outputs);
}

String _mergeOutputs(String? existing, {String? summary, String? transcript}) {
  final outputs = <String, dynamic>{};
  if (existing != null) {
    try {
      final decoded = jsonDecode(existing);
      if (decoded is Map<String, dynamic>) outputs.addAll(decoded);
    } on FormatException {
      // Invalid cached machine output is replaced by the valid incoming fields.
    }
  }
  if (summary != null && summary.isNotEmpty) {
    outputs['summary'] = <String, dynamic>{
      'type': 'summary',
      'markdown': summary,
    };
  }
  if (transcript != null && transcript.isNotEmpty) {
    outputs['transcript'] = <String, dynamic>{
      'type': 'transcript',
      'text': transcript,
    };
  }
  return jsonEncode(outputs);
}

String mergeProcessingOutputs(
  String existing, {
  String? summary,
  String? transcript,
}) => _mergeOutputs(existing, summary: summary, transcript: transcript);
