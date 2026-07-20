import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_vault/matome_vault.dart';

import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/work_queue_dao.dart';
import '../items/matome_item_type.dart';
import '../documents/document_open_policy.dart';
import '../recordings/recording.dart';
import '../recordings/recording_ids.dart';
import '../recordings/recording_result_waiter.dart';
import '../recordings/upload_queue.dart';
import 'inbox_controller.dart';

/// Observes one explicit Core processing run until it reaches a terminal state.
/// Injectable so retry behavior can be tested without a live backend.
typedef RecordingResultAwaiter =
    Future<RecordingResult> Function({
      required Recording recording,
      required Future<Recording?> Function() poll,
      required Ref ref,
    });

/// Picked file ready to upload through the Inbox upload flow.
class PickedUpload {
  const PickedUpload({
    required this.input,
    required this.title,
    required this.mediaType,
    this.filename,
    this.mimeType,
    this.byteSize,
  });

  final MediaInput input;
  final String title;
  final String? filename;
  final String? mimeType;
  final int? byteSize;

  /// `audio` / `image` / `document`, derived from the picked file extension.
  final String mediaType;
}

/// Resolves a coarse media type from a file path extension, mirroring the
/// audio/image/video/doc buckets apps/mobile uploadRecordingService uses.
String mediaTypeForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  const audio = {'m4a', 'mp3', 'wav', 'aac', 'ogg', 'flac', 'caf', 'webm'};
  const image = {'png', 'jpg', 'jpeg', 'gif', 'heic', 'webp'};
  const video = {'mp4', 'mov', 'mkv', 'avi', 'webm'};
  if (audio.contains(ext)) return 'audio';
  if (image.contains(ext)) return 'image';
  if (video.contains(ext)) return 'video';
  return 'document';
}

/// MIME types currently advertised by the deterministic processing service.
/// Unsupported extensions stay generic so Core truthfully records
/// `not_available` instead of claiming a processor can decode them.
String contentTypeForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'pdf' => 'application/pdf',
    'txt' || 'text' || 'log' => 'text/plain',
    'html' || 'htm' => 'text/html',
    'svg' => 'image/svg+xml',
    'xml' => 'application/xml',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'rtf' => 'application/rtf',
    'odt' => 'application/vnd.oasis.opendocument.text',
    'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
    'odp' => 'application/vnd.oasis.opendocument.presentation',
    _ => 'application/octet-stream',
  };
}

/// Orchestrates an Inbox file upload (S1, #780), local-first (plan #43, W2).
///
/// The order is **inverted** from the original mobile port: the local Drift row
/// is written BEFORE any Core call, so a Core-create failure can never leave the
/// captured audio orphaned with no row (the #828 root cause). The flow is:
///
///  1. Atomically insert the Item, file payload, and initial durable work row.
///  2. Hand the persisted work to [UploadQueue], which reconciles the parent and
///     Item, uploads, and ends once Core accepts server-owned processing. Local
///     media remains durable through blocks, retries, and Core processing.
class InboxUploader {
  InboxUploader(this._ref);

  final Ref _ref;

  InboxController get _inbox => _ref.read(inboxControllerProvider.notifier);
  UploadQueue get _queue => _ref.read(uploadQueueProvider);

  /// Persists [picked] locally FIRST, then best-effort uploads to Core.
  ///
  /// 1. Atomically insert a local Item, file payload, and deduped work row.
  /// 2. Hand off to [UploadQueue] for the restart-safe Core handoff. The device
  ///    never waits for AI completion and never deletes the local source file.
  ///
  /// [durationSeconds] is the known audio length (seconds) for a captured
  /// recording; the Inbox file-picker path leaves it 0 (unknown).
  ///
  /// Returns the **local** Drift id (`rec_local_<uuid>`). NOTE (W3): callers
  /// must not assume this equals the Core id — it no longer does. The Core id,
  /// once known, lives in the row's `coreId` column. Today's only callers (the
  /// recording modal `_finish`, the Inbox file-picker) discard the return value,
  /// so this is safe.
  Future<String> upload(
    PickedUpload picked, {
    int durationSeconds = 0,
    bool importFromExternalSource = false,
  }) async {
    final localId = await persist(
      picked,
      durationSeconds: durationSeconds,
      importFromExternalSource: importFromExternalSource,
    );
    await drainPersisted(localId);
    return localId;
  }

  /// Commit the Item, file payload, and work row without touching the network.
  /// Capture finishers use this boundary before scheduling a later queue drain.
  Future<String> persist(
    PickedUpload picked, {
    int durationSeconds = 0,
    bool importFromExternalSource = false,
    String? localId,
    int? expectedByteSize,
    String? matomeId,
  }) async {
    AppLog.event(
      LogCat.upload,
      'upload: ${picked.mediaType} import=$importFromExternalSource',
    );
    final rawSourceFilename = picked.filename ?? picked.input.filename;
    final fileMetadata = DocumentMetadata.fromImport(
      filename: rawSourceFilename,
      mimeType: picked.mimeType ?? contentTypeForPath(rawSourceFilename),
      probeBytes: const [],
    );
    final sourceFilename = fileMetadata.filename;
    final contentType = fileMetadata.mimeType;
    final resolvedLocalId = localId ?? mintLocalRecordingId();
    if (localId != null) {
      final ownerId = _ref.read(currentOwnerIdProvider);
      if (ownerId == null) {
        throw StateError(
          'An authenticated owner is required to create an Item',
        );
      }
      final existing = await _ref
          .read(appDatabaseProvider)
          .itemsDao
          .getById(localId, ownerId);
      if (existing != null) {
        return localId;
      }
    }
    if (expectedByteSize != null &&
        picked.input.knownLength != null &&
        picked.input.knownLength != expectedByteSize) {
      throw StateError('Local artifact changed before persistence');
    }
    await _ref
        .read(mediaIngestServiceProvider)
        .ingestAndCommit(
          picked.input,
          commit: (stat) async {
            final pending = _pendingCompanions(
              resolvedLocalId,
              picked,
              durationSeconds,
              contentType,
              sourceFilename,
              fileMetadata,
              stat,
              matomeId,
            );
            await _inbox.insertLocalUpload(
              item: pending.item,
              file: pending.file,
              initialWork: pending.work,
            );
          },
        );

    return resolvedLocalId;
  }

  /// Start the network-capable queue only after local persistence succeeds.
  Future<void> drainPersisted(String localId) => _queue.drainRow(localId);

  ({ItemsCompanion item, FileBlobsCompanion file, WorkQueueCompanion work})
  _pendingCompanions(
    String localId,
    PickedUpload picked,
    int durationSeconds,
    String contentType,
    String filename,
    DocumentMetadata fileMetadata,
    VaultBlobStat stat,
    String? matomeId,
  ) {
    final now = DateTime.now();
    final ownerId = _ref.read(currentOwnerIdProvider);
    if (ownerId == null) {
      throw StateError('An authenticated owner is required to create an Item');
    }
    final timestamp = now.millisecondsSinceEpoch;
    final fileId = 'file_$localId';
    return (
      item: ItemsCompanion.insert(
        id: localId,
        ownerId: ownerId,
        clientId: localId,
        matomeId: Value(matomeId),
        itemType: MatomeItemType.file.wireName,
        title: Value(picked.title),
        fileBlobId: Value(fileId),
        processingState: const Value('not_requested'),
        syncState: const Value(kProcessingStatusPendingUpload),
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      file: FileBlobsCompanion.insert(
        id: fileId,
        filename: Value(filename),
        originalExtension: Value(fileMetadata.extension),
        contentType: Value(contentType),
        byteSize: Value(stat.plaintextLength ?? picked.byteSize ?? 0),
        checksumSha256: Value(stat.plaintextSha256),
        mediaType: picked.mediaType,
        duration: Value(durationSeconds > 0 ? durationSeconds : null),
        openPolicy: Value(
          picked.mediaType == 'document'
              ? fileMetadata.openPolicy.wireName
              : 'download_only',
        ),
        blobId: Value(stat.id.value),
        blobState: Value(stat.state.name),
        cipherFormat: Value(stat.cipherFormat.name),
        cipherVersion: Value(stat.cipherVersion),
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      work: fileUploadWork(
        itemId: localId,
        blobId: stat.id.value,
        blobRevision: 1,
        sourceRevision: 1,
        now: timestamp,
        configRevision: _ref.read(systemPolicyProvider).revision,
      ),
    );
  }
}

/// Bounded, poll-only observation of the current Core run. A client timeout
/// ends observation but never authors a failed Core state.
Future<RecordingResult> liveRecordingResultAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  if (recording.processing.state.isTerminal) {
    return RecordingResult.terminal(recording);
  }
  final runId = recording.processing.runId;
  if (runId == null) return RecordingResult.terminal(recording);
  final waiter = RecordingResultWaiter(
    recordingId: recording.id,
    runId: runId,
    poll: poll,
    initialPollInterval: ref.read(systemPolicyProvider).pollInterval,
  );
  try {
    return await waiter.wait();
  } finally {
    waiter.cancel();
  }
}

final inboxUploaderProvider = Provider<InboxUploader>(
  (ref) => InboxUploader(ref),
);
