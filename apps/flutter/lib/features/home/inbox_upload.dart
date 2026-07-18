import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_playback.dart';
import '../../core/crypto/key_material.dart' show Dek;
import '../../core/crypto/media_cipher.dart'
    show encodeNoncePrefix, encryptFileToFile, kMediaEncryptionEnabled;
import '../../core/db/db_encryption.dart'
    show FlutterSecureKeyStore, NativeDekProvisioner;
import '../../core/observability/app_log.dart';
import '../../core/providers.dart';
import '../../core/storage/app_storage.dart';
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
    required this.file,
    required this.title,
    required this.mediaType,
    this.filename,
    this.mimeType,
    this.byteSize,
    this.wrappedFekBase64,
    this.fileNoncePrefixBase64,
  });

  final File file;
  final String title;
  final String? filename;
  final String? mimeType;
  final int? byteSize;

  /// `audio` / `image` / `document`, derived from the picked file extension.
  final String mediaType;

  /// Per-file media encryption metadata (task #1855, plan #131 W4) — set only
  /// when [file] was written by [encryptedDurableImportCopy] (i.e.
  /// [kMediaEncryptionEnabled] was on at import time). NULL means [file] is a
  /// plaintext file, which is every import today (the flag is dark). Mirrors
  /// `recordings.wrapped_fek` / `recordings.file_nonce_prefix` — see
  /// `tables.dart` ([FileBlobs.wrappedFek]) for the exact contract.
  final String? wrappedFekBase64;
  final String? fileNoncePrefixBase64;
}

/// Copies a file-picker-imported [picked] file into durable app storage and
/// returns the durable path. Injectable so the durable-copy step can be unit
/// tested without `path_provider`'s platform channel.
///
/// Plan #45 W1 (unified local-first audio): a file-picker import must enter the
/// SAME pipeline as a captured recording — bytes live in durable app storage
/// FIRST, then the #43 [UploadQueue] syncs local→cloud. Returning the unchanged
/// [picked] (no copy) is the web behaviour (cloud-direct, no durable FS).
typedef DurableImportCopy = Future<PickedUpload> Function(PickedUpload picked);

/// Default [DurableImportCopy]: on NATIVE, copies the picked file's bytes into
/// `getApplicationDocumentsDirectory` (the same area the recorder writes its
/// finalized segment) and returns a [PickedUpload] pointing at that DURABLE
/// copy — so the stored `audioFilePath` survives the user deleting the source
/// and never depends on the source path remaining present.
///
/// On WEB (`kIsWeb`) there is no durable native filesystem, so the import stays
/// cloud-direct: the picked file is returned UNCHANGED (the upload queue streams
/// it straight to Core, as today).
Future<PickedUpload> durableImportCopy(PickedUpload picked) async {
  // WEB: cloud-direct — no durable local FS, return the picked file unchanged.
  if (kIsWeb) return picked;

  // NATIVE: copy bytes into the dedicated Matome folder and point at the copy.
  try {
    final dir = await matomeStorageDir();
    // Derive the extension from the BASENAME only: splitting the FULL path on
    // '.' breaks when a PARENT dir has a dot (e.g. `/home/a.b/file` → `b/file`).
    // Take the last path segment first, then its last '.'-suffix.
    final basename = picked.file.path.split('/').last;
    final ext = basename.contains('.') ? basename.split('.').last : 'bin';

    // Media-at-rest encryption (task #1855, plan #131 W4) — DARK by default
    // (see [kMediaEncryptionEnabled] doc for why: Core's upload/transcription
    // pipeline isn't ciphertext-aware yet). When flipped on, the durable copy
    // is written as `<id>.enc` ciphertext instead of a plain byte copy.
    if (kMediaEncryptionEnabled) {
      final durable = await encryptedDurableImportCopy(
        picked,
        dir: dir,
        dekSource: () =>
            NativeDekProvisioner(FlutterSecureKeyStore.deviceKek()).obtainDek(),
      );
      AppLog.event(
        LogCat.upload,
        'durableImportCopy ok (encrypted) -> ${durable.file.path}',
      );
      return durable;
    }

    final destPath =
        '${dir.path}/import_'
        '${DateTime.now().millisecondsSinceEpoch}_${_randSuffix(6)}.$ext';
    final durable = await picked.file.copy(destPath);
    AppLog.event(LogCat.upload, 'durableImportCopy ok -> $destPath');
    return PickedUpload(
      file: durable,
      title: picked.title,
      mediaType: picked.mediaType,
      filename: picked.filename,
      mimeType: picked.mimeType,
      byteSize: picked.byteSize,
    );
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'durableImportCopy fell back, kept source ${picked.file.path}',
      e,
      st,
    );
    // Best-effort: if the copy fails (e.g. no storage), fall back to the source
    // path so the import is no WORSE than before — the local-first insert still
    // happens and the queue can still try to upload the source while it exists.
    return picked;
  }
}

/// Encrypts [picked]'s bytes into a fresh `<id>.enc` file under [dir] (task
/// #1855, plan #131 W4) — the real "write NEW media as ciphertext" path,
/// streamed via `media_cipher.dart`'s [encryptFileToFile] so the source is
/// never fully buffered in memory. [dekSource] is injectable so this is
/// directly unit-testable without touching `flutter_secure_storage`;
/// [durableImportCopy] wires it to [NativeDekProvisioner] for real use.
///
/// Returns a [PickedUpload] pointing at the ciphertext file, carrying the
/// wrapped FEK + nonce prefix the caller must persist onto the media's DB row
/// (`recordings.wrapped_fek` / `recordings.file_nonce_prefix` —
/// [InboxUploader._pendingCompanion] does this).
@visibleForTesting
Future<PickedUpload> encryptedDurableImportCopy(
  PickedUpload picked, {
  required Directory dir,
  required Future<Dek> Function() dekSource,
}) async {
  final destPath =
      '${dir.path}/import_'
      '${DateTime.now().millisecondsSinceEpoch}_${_randSuffix(6)}.enc';
  final destination = File(destPath);
  final dek = await dekSource();
  final String wrappedFekBase64;
  final String fileNoncePrefixBase64;
  try {
    final raw = await encryptFileToFile(
      source: picked.file,
      destination: destination,
      dek: dek,
    );
    wrappedFekBase64 = raw.wrappedFek.toBase64();
    fileNoncePrefixBase64 = encodeNoncePrefix(raw.noncePrefix);
  } finally {
    dek.wipe();
  }
  return PickedUpload(
    file: destination,
    title: picked.title,
    mediaType: picked.mediaType,
    filename: picked.filename,
    mimeType: picked.mimeType,
    byteSize: picked.byteSize,
    wrappedFekBase64: wrappedFekBase64,
    fileNoncePrefixBase64: fileNoncePrefixBase64,
  );
}

/// Probes the real duration (whole seconds) of a durable audio file. Returns 0
/// when the duration can't be determined (probe failed / web blob / non-audio).
/// Injectable so the import flow can be unit-tested without a real audio engine
/// — mirrors `AudioRecordingService`'s injectable `durationProbe` seam.
typedef ImportDurationProbe = Future<int> Function(String path);

/// Default [ImportDurationProbe] (plan #46 W3): reads the true clip length off a
/// durable local audio file through the platform-swappable [AudioPlayback]
/// abstraction (#870 W1) — the SAME `createAudioPlayback().setFilePath(...)`
/// probe the recorder uses, so it now works on Linux/Windows desktop too
/// (`just_audio` 0.9.x has no desktop backend → the old probe returned null).
///
/// On WEB there is no durable native file to probe here (the import is
/// cloud-direct, see [durableImportCopy]), so callers leave the duration 0 and
/// it is backfilled by Core once the pipeline resolves.
Future<int> probeImportDurationSeconds(String path) async {
  final player = createAudioPlayback();
  try {
    final dur = await player.setFilePath(path);
    final ms = dur?.inMilliseconds ?? 0;
    return ms > 0 ? (ms / 1000).round() : 0;
  } catch (e, st) {
    AppLog.error(
      LogCat.upload,
      'probeImportDurationSeconds: probe failed for $path (duration 0)',
      e,
      st,
    );
    return 0;
  } finally {
    await player.dispose();
  }
}

final _rng = Random();

String _randSuffix(int len) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
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
  InboxUploader(
    this._ref, {
    DurableImportCopy? durableCopy,
    ImportDurationProbe? durationProbe,
  }) : _durableCopy = durableCopy ?? durableImportCopy,
       _durationProbe = durationProbe ?? probeImportDurationSeconds;

  final Ref _ref;

  /// Copies a file-picker import into durable app storage before the local-first
  /// insert (plan #45 W1). Injectable for tests; defaults to [durableImportCopy]
  /// (native = copy, web = cloud-direct no-copy).
  final DurableImportCopy _durableCopy;

  /// Probes a durable imported audio file's real duration (plan #46 W3).
  /// Injectable for tests; defaults to [probeImportDurationSeconds] (the #870
  /// platform-swappable audio probe — works on Linux desktop too).
  final ImportDurationProbe _durationProbe;

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
  }) async {
    AppLog.event(
      LogCat.upload,
      'upload: ${picked.mediaType} import=$importFromExternalSource',
    );
    final pathSegments = picked.file.uri.pathSegments;
    final rawSourceFilename =
        picked.filename ??
        (pathSegments.isEmpty ? picked.title : pathSegments.last);
    final probeBytes = picked.mediaType == 'document' && !kIsWeb
        ? await _readDocumentPrefix(picked.file)
        : const <int>[];
    final fileMetadata = DocumentMetadata.fromImport(
      filename: rawSourceFilename,
      mimeType: picked.mimeType ?? contentTypeForPath(rawSourceFilename),
      probeBytes: probeBytes,
    );
    final sourceFilename = fileMetadata.filename;
    final contentType = fileMetadata.mimeType;
    // 0. DURABLE-COPY (plan #45 W1): a file-picker import names the user's SOURCE
    //    file (e.g. ~/Videos/…mp3) which can vanish, leaving playback dead. The
    //    import must enter the SAME pipeline as a captured recording — copy the
    //    bytes into durable app storage FIRST and store THAT path, so the audio
    //    no longer depends on the source surviving. The recorder finish path
    //    already hands a durable segment (#43 W2), so it skips this step to avoid
    //    a redundant copy that would also slip the #43 cleanup. On WEB the copy
    //    is a no-op (cloud-direct), see [durableImportCopy].
    final stored = importFromExternalSource
        ? await _durableCopy(picked)
        : picked;

    // 0b. DURATION PROBE (plan #46 W3): an imported audio file arrives with NO
    //     known length, so the card + Details showed a BLANK duration. Probe the
    //     real length off the now-DURABLE local file (so we read a stable path,
    //     after the #45 copy) via the #870 platform-swappable probe — the SAME
    //     probe the recorder uses — and store it on FIRST insert so the card and
    //     Details render the duration immediately (no row-update round-trip).
    //
    //     Probe BEFORE insert because: the upload itself is already fire-and-
    //     forget (the home-screen FAB does `unawaited(upload(...))`), so this
    //     short file read never blocks the UI; and storing the real value up
    //     front means the duration is correct on the card's first render with
    //     ZERO extra pipeline plumbing (an after-insert update would re-render
    //     and risk racing the Core-side backfill).
    //
    //     Only the IMPORT path needs this: the recorder already passes its known
    //     `durationSeconds`. Skip when a caller already supplied one, on WEB (no
    //     durable file to probe; cloud-direct — Core backfills it), and for
    //     non-audio media.
    var resolvedDuration = durationSeconds;
    if (resolvedDuration <= 0 &&
        importFromExternalSource &&
        !kIsWeb &&
        stored.mediaType == 'audio') {
      try {
        resolvedDuration = await _durationProbe(stored.file.path);
      } catch (e, st) {
        AppLog.error(
          LogCat.upload,
          'upload: duration probe failed (duration unknown)',
          e,
          st,
        );
        // Best-effort: a probe failure just leaves the duration unknown (0) —
        // no worse than before; Core may still backfill it.
        resolvedDuration = 0;
      }
    }

    // 1. LOCAL-FIRST: persist the row before touching Core so the capture can
    //    never be orphaned (the #828 root cause). The card appears immediately.
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
        if (existing.localPath != stored.file.path) {
          throw StateError('Stable local Item id belongs to another file');
        }
        return localId;
      }
    }
    if (!kIsWeb &&
        expectedByteSize != null &&
        stored.file.lengthSync() != expectedByteSize) {
      throw StateError('Local artifact changed before persistence');
    }
    final pending = _pendingCompanions(
      resolvedLocalId,
      stored,
      resolvedDuration,
      contentType,
      sourceFilename,
      fileMetadata,
    );
    await _inbox.insertLocalUpload(
      item: pending.item,
      file: pending.file,
      initialWork: pending.work,
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
        byteSize: Value(
          kIsWeb
              ? (picked.byteSize != null && picked.byteSize! > 0
                    ? picked.byteSize!
                    : 0)
              : picked.file.lengthSync(),
        ),
        mediaType: picked.mediaType,
        duration: Value(durationSeconds > 0 ? durationSeconds : null),
        openPolicy: Value(
          picked.mediaType == 'document'
              ? fileMetadata.openPolicy.wireName
              : 'download_only',
        ),
        localPath: Value(picked.file.path),
        wrappedFek: Value(picked.wrappedFekBase64),
        fileNoncePrefix: Value(picked.fileNoncePrefixBase64),
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      work: fileUploadWork(
        itemId: localId,
        sourceRevision: 1,
        now: timestamp,
        configRevision: _ref.read(systemPolicyProvider).revision,
      ),
    );
  }
}

Future<List<int>> _readDocumentPrefix(File file) async {
  try {
    final handle = await file.open();
    try {
      return handle.read(documentContentProbeLimit);
    } finally {
      await handle.close();
    }
  } catch (_) {
    return const [];
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
