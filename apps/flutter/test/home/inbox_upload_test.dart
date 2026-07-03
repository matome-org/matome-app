import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

void main() {
  test('mediaTypeForPath buckets audio / image / document', () {
    expect(mediaTypeForPath('/a/b.m4a'), 'audio');
    expect(mediaTypeForPath('/a/b.PNG'), 'image');
    expect(mediaTypeForPath('/a/b.pdf'), 'document');
  });

  test('upload creates a Core recording, inserts a local row, then resolves done',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A small temp file to upload.
    final tmp = File('${Directory.systemTemp.path}/inbox_upload_test.m4a');
    await tmp.writeAsBytes(List<int>.filled(16, 0));
    addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);

    // 1. create item under the reconciled matome (coreId 42) -> item id 321 +
    //    presign to a stub URL.
    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'Voice memo', 'status': 'pending'},
          'file': {'media_type': 'audio'},
        },
        'presign': {
          'method': 'PUT',
          'url': 'http://127.0.0.1:9/upload',
          'storage_key': 'k',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
    );
    // 3. enqueue process -> 202.
    adapter.onPost(
      '/api/items/321/process',
      (server) => server.reply(202, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'Voice memo', 'status': 'processing'},
        },
        'processing': {'queued': true},
      }),
    );
    // 4. poll -> done.
    adapter.onGet(
      '/api/items/321',
      (server) => server.reply(200, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'Voice memo', 'status': 'done'},
          'file': {'summary': 'A short memo', 'transcript': 'hello world'},
        },
      }),
    );

    // The presigned PUT goes through a *separate* bare Dio in the repo. Point a
    // top-level handler at the stub host so the stream-upload "succeeds".
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );

    // Socket absent → poll fallback resolves (GET → done). Drives the real
    // RecordingResultWaiter race without a live Phoenix socket.
    Future<RecordingResult> pollFallbackAwaiter({
      required Recording recording,
      required Future<Recording?> Function() poll,
      required Ref ref,
    }) async {
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: recording.id,
        statusEvents: events.stream,
        poll: poll,
        pollInterval: const Duration(milliseconds: 20),
      );
      final result = await waiter.wait();
      await events.close();
      return result;
    }

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      // W4: the terminal-result awaiter moved from InboxUploader onto the queue.
      // No-op cleanup so the stub temp file isn't deleted out from under the
      // test's own teardown.
      uploadQueueProvider.overrideWith(
        (ref) => UploadQueue(
          ref,
          awaitResult: pollFallbackAwaiter,
          cleanupAudio: (_) async {},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final uploader = container.read(inboxUploaderProvider);

    final localId = await uploader.upload(PickedUpload(
      file: tmp,
      title: 'Voice memo',
      mediaType: 'audio',
    ));

    // W2: local-first id (rec_local_<uuid>), NOT the Core id.
    expect(isLocalRecordingId(localId), isTrue);

    // The import minted a LOCAL matome with no Core id yet, so the inline drain
    // HOLDS the row (an item can only be created under a reconciled matome —
    // POST /api/matomes/{coreMatomeId}/items). Simulate the matome→Core sync
    // (matome_sync) reconciling that matome's Core id, then re-drain: this is the
    // two-phase contract after the recordings→items migration.
    final held = await db.recordingsDao.getRecordingById(localId);
    await db.matomesDao.updateMatome(
      held!.matomeId!,
      const MatomesCompanion(coreId: Value(42)),
    );
    await container.read(uploadQueueProvider).drainRow(localId);

    // Pipeline drove (local row) -> create -> reconcile coreId -> upload ->
    // process -> done. The row keeps its local PK; coreId is reconciled to 321.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.coreId, 321);
    expect(row.processingStatus, 'done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'A short memo');

    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.single.id, localId);
    expect(items.single.card.isProcessing, isFalse);
  });

  test('upload is local-first: a createRecording failure still persists a '
      'visible local row + on-disk audio (reproduces the #828 orphan-WAV bug)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A real on-disk audio file — it must SURVIVE the Core failure.
    final tmp = File('${Directory.systemTemp.path}/inbox_upload_coredown.m4a');
    await tmp.writeAsBytes(List<int>.filled(16, 0));
    addTearDown(() => tmp.exists().then((e) => e ? tmp.delete() : null));

    // Repo whose createRecording THROWS — Core is unreachable.
    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final uploader = container.read(inboxUploaderProvider);

    // upload() must NOT throw even though Core create throws.
    final localId = await uploader.upload(PickedUpload(
      file: tmp,
      title: 'Voice memo',
      mediaType: 'audio',
    ));

    expect(isLocalRecordingId(localId), isTrue);

    // The local row survives, pending_upload, coreId NULL.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.coreId, isNull);
    expect(row.processingStatus, 'pending_upload');
    expect(row.isProcessing, 1);
    expect(row.audioFilePath, tmp.path);

    // The card is visible in the Inbox.
    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.single.id, localId);

    // The on-disk audio still exists (NOT orphaned/deleted).
    expect(await tmp.exists(), isTrue);
  });

  // ─── Plan #45 W1 — unified local-first audio (import durable-copy) ─────────

  test(
      'NATIVE import copies the picked file into durable storage and stores the '
      'DURABLE path (not the source); the source can be deleted and a playable '
      'local file survives', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // The user's SOURCE file (e.g. ~/Videos/…mp3) — it will be DELETED after
    // import to prove the durable copy is independent of it (the row 9 bug).
    final source = File('${Directory.systemTemp.path}/import_source_test.mp3');
    await source.writeAsBytes(List<int>.filled(32, 7));
    addTearDown(() => source.exists().then((e) => e ? source.delete() : null));

    // A durable destination dir, standing in for getApplicationDocumentsDirectory
    // (whose path_provider platform channel isn't available in unit tests).
    final durableDir = await Directory.systemTemp.createTemp('docs_');
    addTearDown(() => durableDir.delete(recursive: true));

    // Injected durable-copy mirroring the production native branch: copy bytes
    // into durable storage, return a PickedUpload pointing at the COPY.
    Future<PickedUpload> nativeDurableCopy(PickedUpload picked) async {
      final dest = '${durableDir.path}/import_copy.mp3';
      final durable = await picked.file.copy(dest);
      return PickedUpload(
        file: durable,
        title: picked.title,
        mediaType: picked.mediaType,
      );
    }

    // Core unreachable so the row stays pending_upload + the audio stays on disk.
    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      inboxUploaderProvider.overrideWith((ref) => InboxUploader(
            ref,
            durableCopy: nativeDurableCopy,
            // This test exercises the durable COPY, not the W3 duration probe;
            // inject a no-op so it never spins up a real audio engine on the
            // stub bytes (which has no Linux/VM backend → would hang).
            durationProbe: (_) async => 0,
          )),
    ]);
    addTearDown(container.dispose);

    final uploader = container.read(inboxUploaderProvider);

    final localId = await uploader.upload(
      PickedUpload(
        file: source,
        title: 'Imported memo',
        mediaType: 'audio',
      ),
      importFromExternalSource: true,
    );

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    // Stored path is the DURABLE copy, NOT the picker source.
    expect(row!.audioFilePath, isNot(source.path));
    expect(row.audioFilePath.startsWith(durableDir.path), isTrue);
    expect(File(row.audioFilePath).existsSync(), isTrue);

    // Delete the SOURCE — the durable copy must still be a playable local file.
    await source.delete();
    expect(await source.exists(), isFalse);
    expect(File(row.audioFilePath).existsSync(), isTrue);
    expect(await File(row.audioFilePath).length(), 32);
  });

  test(
      'WEB import is cloud-direct: durableImportCopy returns the picked file '
      'UNCHANGED (no durable copy made)', () async {
    // durableImportCopy on web (kIsWeb) is a no-op. We can\'t toggle kIsWeb in a
    // VM test, but the web CONTRACT is "return the picked file unchanged, no FS
    // copy". A no-op copy modelling the web branch must leave the source path as
    // the stored audioFilePath — exactly the recorder/no-import path below.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final source = File('${Directory.systemTemp.path}/import_web_test.mp3');
    await source.writeAsBytes(List<int>.filled(8, 1));
    addTearDown(() => source.exists().then((e) => e ? source.delete() : null));

    // Web branch = cloud-direct = no copy: return picked unchanged.
    Future<PickedUpload> webNoCopy(PickedUpload picked) async => picked;

    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      inboxUploaderProvider.overrideWith((ref) => InboxUploader(
            ref,
            durableCopy: webNoCopy,
            // Cloud-direct path: no on-device probe (Core backfills duration).
            durationProbe: (_) async => 0,
          )),
    ]);
    addTearDown(container.dispose);

    final localId = await container.read(inboxUploaderProvider).upload(
          PickedUpload(file: source, title: 'Web memo', mediaType: 'audio'),
          importFromExternalSource: true,
        );

    final row = await db.recordingsDao.getRecordingById(localId);
    // No durable copy: the stored path is the picked file itself (cloud-direct).
    expect(row!.audioFilePath, source.path);
  });

  test(
      'recorder finish path (importFromExternalSource = false) does NOT copy — '
      'its already-durable segment path is stored unchanged (#43 W2 intact)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // A finalized recorder segment (already durable per #43 W2).
    final segment = File('${Directory.systemTemp.path}/segment_durable.m4a');
    await segment.writeAsBytes(List<int>.filled(16, 0));
    addTearDown(() => segment.exists().then((e) => e ? segment.delete() : null));

    // If this copy ran it would prove a regression (recorder double-copy).
    var copyCalled = false;
    Future<PickedUpload> failIfCopied(PickedUpload picked) async {
      copyCalled = true;
      return picked;
    }

    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      inboxUploaderProvider
          .overrideWith((ref) => InboxUploader(ref, durableCopy: failIfCopied)),
    ]);
    addTearDown(container.dispose);

    final localId = await container.read(inboxUploaderProvider).upload(
          PickedUpload(file: segment, title: 'Recording', mediaType: 'audio'),
          durationSeconds: 5,
          // importFromExternalSource omitted → defaults false (recorder path).
        );

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.audioFilePath, segment.path);
    expect(copyCalled, isFalse, reason: 'recorder path must not durable-copy');
  });

  // ─── Plan #46 W3 — import duration probe (store + display) ─────────────────

  test(
      'NATIVE import of an audio of KNOWN length probes the durable file and '
      'stores a non-zero duration the card renders (was blank before W3)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final source = File('${Directory.systemTemp.path}/import_dur_test.mp3');
    await source.writeAsBytes(List<int>.filled(32, 7));
    addTearDown(() => source.exists().then((e) => e ? source.delete() : null));

    final durableDir = await Directory.systemTemp.createTemp('docs_dur_');
    addTearDown(() => durableDir.delete(recursive: true));

    // Durable-copy into a known dir (path_provider unavailable in unit tests).
    Future<PickedUpload> nativeDurableCopy(PickedUpload picked) async {
      final dest = '${durableDir.path}/import_copy.mp3';
      final durable = await picked.file.copy(dest);
      return PickedUpload(
        file: durable,
        title: picked.title,
        mediaType: picked.mediaType,
      );
    }

    // Fake probe (mirrors the recorder's injectable durationProbe seam): the
    // imported clip is 3m25s = 205s. It must be called with the DURABLE path,
    // not the picker source.
    String? probedPath;
    Future<int> fakeProbe(String path) async {
      probedPath = path;
      return 205;
    }

    // Core unreachable → row stays pending_upload, so the assertion sees the
    // locally-probed duration (not a Core-backfilled one).
    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      inboxUploaderProvider.overrideWith((ref) => InboxUploader(
            ref,
            durableCopy: nativeDurableCopy,
            durationProbe: fakeProbe,
          )),
    ]);
    addTearDown(container.dispose);

    final localId = await container.read(inboxUploaderProvider).upload(
          PickedUpload(
            file: source,
            title: 'Imported memo',
            mediaType: 'audio',
          ),
          importFromExternalSource: true,
        );

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    // Stored duration is the probed length, formatted as the card renders it.
    expect(row!.duration, '3m 25s');
    // The probe read the DURABLE copy, not the (deletable) picker source.
    expect(probedPath, isNot(source.path));
    expect(probedPath, row.audioFilePath);

    // The Inbox card surfaces the same (non-empty) duration string → renders it.
    final item = container.read(inboxControllerProvider).requireValue.single;
    expect(item.card.duration, '3m 25s');
  });

  test(
      'a caller-supplied durationSeconds (recorder path) is NOT re-probed on '
      'import', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final source = File('${Directory.systemTemp.path}/import_noprobe.mp3');
    await source.writeAsBytes(List<int>.filled(16, 0));
    addTearDown(() => source.exists().then((e) => e ? source.delete() : null));

    var probeCalled = false;
    Future<int> failIfProbed(String path) async {
      probeCalled = true;
      return 999;
    }

    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      inboxUploaderProvider.overrideWith((ref) => InboxUploader(
            ref,
            durableCopy: (p) async => p,
            durationProbe: failIfProbed,
          )),
    ]);
    addTearDown(container.dispose);

    final localId = await container.read(inboxUploaderProvider).upload(
          PickedUpload(file: source, title: 'Recording', mediaType: 'audio'),
          durationSeconds: 12,
          importFromExternalSource: true,
        );

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.duration, '12s');
    expect(probeCalled, isFalse,
        reason: 'a known duration must not trigger a redundant probe');
  });
}

/// Repo whose Core create throws — simulates Core being unreachable so the
/// local-first persistence path can be proven independent of Core.
class _CoreDownRepository extends RecordingsRepository {
  _CoreDownRepository({required super.apiClient});

  @override
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) async {
    throw const ApiException('Core unreachable');
  }
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll flow without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}
