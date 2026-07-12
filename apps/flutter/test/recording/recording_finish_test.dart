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
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import 'audio_recording_service_test.dart' show FakeRecorderBackend;

// ---------------------------------------------------------------------------
// Mirrors apps/mobile RecordingScreen.handleFinish: F3 finalizes the session
// file → S1/F4 InboxUploader creates the Core recording + a local Drift row
// (processing) + uploads + enqueues + awaits done. W2 (#871): reaching `done`
// RETAINS the durable local audio (no auto-cleanup) — deletion is user-only.
// No live mic (FakeRecorderBackend); upload PUT is stubbed.
// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rec_finish_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService svc(AppDatabase db) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: FakeRecorderBackend(),
      documentsDirProvider: () async => tmp,
      durationProbe: (p) async => File(p).lengthSync(),
      captureSupportedProbe: () async => true,
    );
  }

  // Modern items contract (recordings→items migration): the create leg POSTs to
  // /api/matomes/{coreMatomeId}/items and returns an ITEM (+presign); processing
  // is POST /api/items/{id}/process; the poll-fallback source is GET
  // /api/items/{id}. The minted-matome coreId is 42; the created item id is 321.
  Dio stubbedDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:7001',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'New Recording', 'status': 'pending'},
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
    adapter.onPost(
      '/api/items/321/process',
      (server) => server.reply(202, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'New Recording', 'status': 'processing'},
        },
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/items/321',
      (server) => server.reply(200, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'New Recording', 'status': 'done'},
          'file': {'summary': 'A memo', 'transcript': 'hello'},
        },
      }),
    );
    return dio;
  }

  // GET /api/items/321 that never reports terminal — so ONLY the injected socket
  // awaiter can flip processing→done (proves the realtime path is wired).
  Dio stubbedDioProcessing() {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:7001',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'metadata': {'title': 'New Recording', 'status': 'pending'},
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
    adapter.onPost(
      '/api/items/321/process',
      (server) => server.reply(202, {
        'item': {'id': 321, 'owner_id': 1, 'metadata': {'status': 'processing'}},
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/items/321',
      (server) => server.reply(200, {
        'item': {'id': 321, 'owner_id': 1, 'metadata': {'status': 'processing'}},
      }),
    );
    return dio;
  }

  /// Simulate the matome→Core sync (matome_sync) reconciling the just-minted
  /// LOCAL matome's Core id, then re-drain the row. The finish flow (flag OFF)
  /// mints a coreId-less local matome, so the inline drain HOLDS the row (an item
  /// can only be created under a reconciled matome — POST
  /// /api/matomes/{coreMatomeId}/items). This is the two-phase contract after the
  /// recordings→items migration; matome sync supplies the coreId out-of-band.
  Future<void> reconcileMatomeAndRedrain(
    ProviderContainer container,
    AppDatabase db,
    String localId,
  ) async {
    final held = await db.recordingsDao.getRecordingById(localId);
    await db.matomesDao.updateMatome(
      held!.matomeId!,
      const MatomesCompanion(coreId: Value(42)),
    );
    await container.read(uploadQueueProvider).drainRow(localId);
  }

  /// Overrides [uploadQueueProvider] with a queue carrying an injected
  /// [RecordingResultAwaiter] (and a no-op audio cleanup so tests don't touch
  /// the real filesystem unless they assert on it), so the finish→queue flow
  /// can be driven by a fake socket-vs-poll race. W4 moved the awaiter from the
  /// uploader onto the queue.
  Override queueWith(
    RecordingResultAwaiter awaiter, {
    AudioCleanup cleanupAudio = _noopCleanup,
  }) =>
      uploadQueueProvider.overrideWith(
        (ref) => UploadQueue(ref, awaitResult: awaiter, cleanupAudio: cleanupAudio),
      );

  test('finish: F3 file → Core create → Drift processing row → done → cleanup '
      '(poll fallback resolves when socket is absent)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: stubbedDio()),
    );

    // Socket "absent": an empty event stream that never emits, so ONLY the poll
    // fallback (GET → done) can resolve — exercising the fallback branch of the
    // realtime waiter without a live Phoenix socket.
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
      audioRecordingServiceProvider.overrideWithValue(service),
      recordingsRepositoryProvider.overrideWithValue(repo),
      queueWith(pollFallbackAwaiter),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId = await container.read(recordingFinisherProvider).finish(
          title: 'Standup notes',
        );

    // W2: local-first id (rec_local_<uuid>), NOT the Core id.
    expect(isLocalRecordingId(localId), isTrue);

    // Two-phase: reconcile the minted matome's coreId, then re-drain to done.
    await reconcileMatomeAndRedrain(container, db, localId);

    // Inbox row keeps its local PK; coreId reconciled to the item id 321, done.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.coreId, 321);
    expect(row.processingStatus, 'done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'A memo');

    // It appears in the Inbox list (workspaceId IS NULL).
    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.any((i) => i.id == localId), isTrue);
  });

  test('W2 #871 RETENTION: finish → confirmed done RETAINS the durable local '
      'audio file (reverses #43 W4; uses the REAL deleteAudioFile cleanup)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: stubbedDio()),
    );

    // Same poll-fallback awaiter (GET → done) used by the first test.
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
      audioRecordingServiceProvider.overrideWithValue(service),
      recordingsRepositoryProvider.overrideWithValue(repo),
      // Wire the PRODUCTION cleanup deliberately: the queue must STILL not delete
      // the local file on done. (Before W2 this would have deleted it.)
      queueWith(pollFallbackAwaiter, cleanupAudio: deleteAudioFile),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId = await container
        .read(recordingFinisherProvider)
        .finish(title: 'Retained memo');

    // Two-phase: reconcile the minted matome's coreId, then re-drain to done.
    await reconcileMatomeAndRedrain(container, db, localId);

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done',
        reason: 'upload reconciled to done');

    // The local-first source of truth must survive a confirmed done.
    expect(row.audioFilePath, isNotEmpty);
    expect(await File(row.audioFilePath).exists(), isTrue,
        reason: 'done must NOT auto-delete the durable local audio (W2 #871)');
  });

  test('stale-draft fix: finish → done CLEARS the crash-recovery draft row but '
      'KEEPS the durable segment file (no "recover already-saved" prompt)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: stubbedDio()),
    );

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
      audioRecordingServiceProvider.overrideWithValue(service),
      recordingsRepositoryProvider.overrideWithValue(repo),
      queueWith(pollFallbackAwaiter),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    // A pause persists a crash-recovery DRAFT row (autosave on pause).
    await controller.pause();
    await controller.resume();
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull,
        reason: 'pause autosaves a draft');

    final localId = await container
        .read(recordingFinisherProvider)
        .finish(title: 'Saved memo');

    // Two-phase: reconcile the minted matome's coreId, then re-drain to done.
    await reconcileMatomeAndRedrain(container, db, localId);

    // The recording is saved + uploaded done.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done');

    // FIX: the draft row is cleared on a confirmed finish — so a next launch
    // does NOT prompt to "recover" this already-saved recording.
    expect(await db.recordingDraftsDao.loadDraft(), isNull,
        reason: 'finish must clear the draft row');
    expect(await service.detectRecoverableDraft(), isNull,
        reason: 'no recoverable draft remains to prompt on');

    // RETENTION (W2): the durable segment file STAYS on disk (draft-clear is
    // split from file-delete) — the audio remains playable.
    expect(row.audioFilePath, isNotEmpty);
    expect(await File(row.audioFilePath).exists(), isTrue,
        reason: 'clearing the draft must NOT delete the durable audio (W2)');
  });

  test('finish is local-first: a Core-down repo (createRecording throws) still '
      'yields a visible local Drift row + on-disk audio (reproduces #828)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    // Core unreachable — createRecording throws.
    final repo = _CoreDownRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider.overrideWithValue(service),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    // finish() must NOT throw even though Core is down.
    final localId =
        await container.read(recordingFinisherProvider).finish(title: 'Memo');

    expect(isLocalRecordingId(localId), isTrue);

    // The local row survives, pending_upload, coreId NULL.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.coreId, isNull);
    expect(row.processingStatus, 'pending_upload');
    expect(row.isProcessing, 1);

    // The captured audio is on disk and NOT orphaned (the #828 symptom).
    expect(row.audioFilePath, isNotEmpty);
    expect(await File(row.audioFilePath).exists(), isTrue);

    // The card is visible in the Inbox.
    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.any((i) => i.id == localId), isTrue);
  });

  test('finish: realtime socket event drives processing→done (poll stays '
      'processing — proves the F4 realtime waiter is wired into finish)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    // Poll endpoint NEVER reports done — only the socket event can resolve it.
    final repo = _StubUploadRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: stubbedDioProcessing(),
      ),
    );

    var awaiterCalled = false;
    // Fake awaiter: a socket event stream that emits `done`, raced against the
    // (never-terminal) poll — exactly the production RecordingResultWaiter race.
    Future<RecordingResult> fakeSocketAwaiter({
      required Recording recording,
      required Future<Recording?> Function() poll,
      required Ref ref,
    }) async {
      awaiterCalled = true;
      final events = StreamController<RecordingStatusEvent>();
      final waiter = RecordingResultWaiter(
        recordingId: recording.id,
        statusEvents: events.stream,
        poll: poll,
        pollInterval: const Duration(milliseconds: 50),
      );
      final future = waiter.wait();
      // Socket delivers the terminal status first.
      events.add(RecordingStatusEvent(
        recordingId: recording.id,
        status: RecordingStatus.done,
        summary: 'From socket',
        transcript: 'realtime',
      ));
      final result = await future;
      await events.close();
      return result;
    }

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      audioRecordingServiceProvider.overrideWithValue(service),
      recordingsRepositoryProvider.overrideWithValue(repo),
      queueWith(fakeSocketAwaiter),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId =
        await container.read(recordingFinisherProvider).finish(title: 'Live');

    expect(isLocalRecordingId(localId), isTrue);

    // Two-phase: reconcile the minted matome's coreId, then re-drain — this is
    // the drain that actually creates the item and runs the realtime waiter.
    await reconcileMatomeAndRedrain(container, db, localId);

    expect(awaiterCalled, isTrue, reason: 'finish must use the realtime waiter');

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row, isNotNull);
    expect(row!.coreId, 321);
    expect(row.processingStatus, 'done',
        reason: 'socket event must drive processing→done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'From socket');
    // WRITE-AUTHORITY (#1435): the machine transcript from the socket `done`
    // lands in the `transcript` column, not the user-owned `notes` column.
    expect(row.transcript, 'realtime');
    expect(row.notes, isNull);
  });
}

/// No-op audio cleanup for queue tests that don't assert on file deletion.
Future<void> _noopCleanup(String path) async {}

/// Repo whose Core create throws — simulates Core being unreachable so the
/// local-first finish path can be proven independent of Core.
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
