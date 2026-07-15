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

String statusToProcessingState(RecordingStatus status) => switch (status) {
  RecordingStatus.pending => 'queued',
  RecordingStatus.processing => 'processing',
  RecordingStatus.failed => 'failed',
  RecordingStatus.done || RecordingStatus.unknown => 'succeeded',
};

/// Canonical Item + FileBlob companions for one legacy W0 wire recording.
/// The HTTP model remains until its endpoint cutover, but no local persistence
/// path writes or reads a recording-shaped table.
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
  final outputs = _mergeOutputs(
    existing?.item.processingOutputs,
    summary: recording.summary,
    transcript: recording.transcript,
  );

  final storageKey = recording.storageKey;
  final uploaded = storageKey != null && storageKey.isNotEmpty;
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
      processingState: Value(statusToProcessingState(recording.status)),
      processingRunId: Value(existing?.item.processingRunId),
      sourceRevision: Value(existing?.item.sourceRevision ?? 1),
      processingConfigRevision: Value(existing?.item.processingConfigRevision),
      processingOutputs: Value(outputs),
      processingError: Value(existing?.item.processingError),
      processingErrorCode: Value(existing?.item.processingErrorCode),
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
      uploadState: Value(
        uploaded ? 'uploaded' : existing?.file?.uploadState ?? 'pending',
      ),
      uploadGeneration: Value(existing?.file?.uploadGeneration ?? 1),
      uploadedAt: Value(
        uploaded
            ? existing?.file?.uploadedAt ??
                  (recording.updatedAt ?? recording.insertedAt)
                      ?.millisecondsSinceEpoch ??
                  now
            : null,
      ),
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
  if (summary != null && summary.isNotEmpty) outputs['summary'] = summary;
  if (transcript != null && transcript.isNotEmpty) {
    outputs['transcript'] = transcript;
  }
  return jsonEncode(outputs);
}

String mergeProcessingOutputs(
  String existing, {
  String? summary,
  String? transcript,
}) => _mergeOutputs(existing, summary: summary, transcript: transcript);
