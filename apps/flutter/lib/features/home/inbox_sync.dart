import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/items_dao.dart';
import '../items/matome_item_type.dart';
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
      filename: Value(existing?.file?.filename),
      contentType: Value(existing?.file?.contentType),
      byteSize: Value(recording.byteSize ?? existing?.byteSize ?? 0),
      checksumSha256: Value(existing?.file?.checksumSha256),
      mediaType: recording.mediaType ?? existing?.mediaType ?? 'audio',
      duration: Value(recording.duration ?? existing?.durationSeconds),
      uploadState: Value(uploadState),
      uploadGeneration: Value(existing?.file?.uploadGeneration ?? 1),
      uploadedAt: Value(uploadedAt),
      multipartContext: Value(existing?.file?.multipartContext),
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
  final applies =
      existing == null ||
      incoming.attempt > existingAttempt ||
      (incoming.attempt == existingAttempt && incoming.runId == existingRunId);
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
