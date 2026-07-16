import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import 'audio_recording_service_test.dart' show FakeRecorderBackend;
import '../support/fake_parent_sync.dart';
import '../support/verified_upload_repository_fake.dart';

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
  // /api/matomes/{coreMatomeId}/items and returns an ITEM + W0 upload; processing
  // is POST /api/items/{id}/process; the current-run poll source is GET
  // /api/items/{id}. The minted-matome coreId is 42; the created item id is 321.
  Dio stubbedDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'title': 'New Recording',
          'processing_state': 'not_requested',
          'processing_run_id': null,
          'processing_attempt': 0,
          'processing_requested_outputs': const <String>[],
          'processing_outputs': const <String, dynamic>{},
          'file': {'media_type': 'audio', 'upload_state': 'pending'},
        },
        'upload': {
          'request': {
            'method': 'PUT',
            'url': 'http://127.0.0.1:9/upload',
            'headers': <String, String>{},
          },
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
          'title': 'New Recording',
          'processing_state': 'queued',
          'processing_run_id': 'run-321',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
          'file': {'media_type': 'audio', 'upload_state': 'uploaded'},
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
          'title': 'New Recording',
          'processing_state': 'succeeded',
          'processing_run_id': 'run-321',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': {
            'summary': {'type': 'summary', 'markdown': 'A memo'},
            'transcript': {'type': 'transcript', 'text': 'hello'},
          },
          'file': {'media_type': 'audio', 'upload_state': 'uploaded'},
        },
      }),
    );
    return dio;
  }

  // GET /api/items/321 that never reports terminal.
  Dio stubbedDioProcessing() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/matomes/42/items',
      (server) => server.reply(201, {
        'item': {
          'id': 321,
          'owner_id': 1,
          'matome_id': 42,
          'item_type': 'file',
          'title': 'New Recording',
          'processing_state': 'not_requested',
          'processing_run_id': null,
          'processing_attempt': 0,
          'processing_requested_outputs': const <String>[],
          'processing_outputs': const <String, dynamic>{},
          'file': {'media_type': 'audio', 'upload_state': 'pending'},
        },
        'upload': {
          'request': {
            'method': 'PUT',
            'url': 'http://127.0.0.1:9/upload',
            'headers': <String, String>{},
          },
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
          'title': 'New Recording',
          'processing_state': 'queued',
          'processing_run_id': 'run-321',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
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
          'title': 'New Recording',
          'processing_state': 'processing',
          'processing_run_id': 'run-321',
          'processing_attempt': 1,
          'processing_requested_outputs': ['transcript', 'summary'],
          'processing_outputs': const <String, dynamic>{},
        },
      }),
    );
    return dio;
  }

  Override queueOverride() => uploadQueueProvider.overrideWith(UploadQueue.new);

  test(
    'finish persists locally and stops after Core accepts processing',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final service = svc(db);
      final repo = _StubUploadRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: stubbedDio(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
          testParentSyncOverride(),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
          queueOverride(),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(recordingControllerProvider.notifier);
      await controller.start();
      await controller.pause();
      await controller.resume();

      final localId = await container
          .read(recordingFinisherProvider)
          .finish(title: 'Standup notes');

      // W2: local-first id (rec_local_<uuid>), NOT the Core id.
      expect(isLocalRecordingId(localId), isTrue);

      // Inbox row keeps its local PK; Core owns processing after acceptance.
      final row = await db.itemsDao.getById(localId, '1');
      expect(row, isNotNull);
      expect(row!.coreId, 321);
      expect(row.processingStatus, 'queued');
      expect(row.isProcessing, isTrue);
      expect(row.summary, isNull);

      // It appears in the Inbox list (workspaceId IS NULL).
      final items = container.read(inboxControllerProvider).requireValue;
      expect(items.any((i) => i.id == localId), isTrue);
    },
  );

  test(
    'W2 #871 RETENTION: Core handoff RETAINS the durable local '
    'audio file (reverses #43 W4; uses the REAL deleteAudioFile cleanup)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final service = svc(db);
      final repo = _StubUploadRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: stubbedDio(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
          testParentSyncOverride(),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
          queueOverride(),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(recordingControllerProvider.notifier);
      await controller.start();
      await controller.pause();
      await controller.resume();

      final localId = await container
          .read(recordingFinisherProvider)
          .finish(title: 'Retained memo');

      final row = await db.itemsDao.getById(localId, '1');
      expect(row, isNotNull);
      expect(
        row!.processingStatus,
        'queued',
        reason: 'device work stopped after Core accepted processing',
      );

      // The local-first source of truth must survive a confirmed done.
      expect(row.localPath, isNotEmpty);
      expect(
        await File(row.localPath!).exists(),
        isTrue,
        reason: 'done must NOT auto-delete the durable local audio (W2 #871)',
      );
    },
  );

  test(
    'stale-draft fix: finish clears the crash-recovery draft row but '
    'KEEPS the durable segment file (no "recover already-saved" prompt)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final service = svc(db);
      final repo = _StubUploadRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: stubbedDio(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
          testParentSyncOverride(),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
          queueOverride(),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(recordingControllerProvider.notifier);
      await controller.start();
      // A pause persists a crash-recovery DRAFT row (autosave on pause).
      await controller.pause();
      await controller.resume();
      expect(
        await db.recordingDraftsDao.loadDraft(),
        isNotNull,
        reason: 'pause autosaves a draft',
      );

      final localId = await container
          .read(recordingFinisherProvider)
          .finish(title: 'Saved memo');

      // The recording is saved, uploaded, and handed to Core processing.
      final row = await db.itemsDao.getById(localId, '1');
      expect(row, isNotNull);
      expect(row!.processingStatus, 'queued');

      // FIX: the draft row is cleared on a confirmed finish — so a next launch
      // does NOT prompt to "recover" this already-saved recording.
      expect(
        await db.recordingDraftsDao.loadDraft(),
        isNull,
        reason: 'finish must clear the draft row',
      );
      expect(
        await service.detectRecoverableDraft(),
        isNull,
        reason: 'no recoverable draft remains to prompt on',
      );

      // RETENTION (W2): the durable segment file STAYS on disk (draft-clear is
      // split from file-delete) — the audio remains playable.
      expect(row.localPath, isNotEmpty);
      expect(
        await File(row.localPath!).exists(),
        isTrue,
        reason: 'clearing the draft must NOT delete the durable audio (W2)',
      );
    },
  );

  test(
    'finish is local-first: a Core-down repo (createRecording throws) still '
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

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('1'),
          testParentSyncOverride(),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(recordingControllerProvider.notifier);
      await controller.start();
      await controller.pause();
      await controller.resume();

      // finish() must NOT throw even though Core is down.
      final localId = await container
          .read(recordingFinisherProvider)
          .finish(title: 'Memo');

      expect(isLocalRecordingId(localId), isTrue);

      // The local row survives with a durable retryable Core block, coreId NULL.
      final row = await db.itemsDao.getById(localId, '1');
      expect(row, isNotNull);
      expect(row!.coreId, isNull);
      expect(row.processingStatus, kProcessingStatusBlockedOffline);
      expect(row.isProcessing, isFalse);

      // The captured audio is on disk and NOT orphaned (the #828 symptom).
      expect(row.localPath, isNotEmpty);
      expect(await File(row.localPath!).exists(), isTrue);

      // The card is visible in the Inbox.
      final items = container.read(inboxControllerProvider).requireValue;
      expect(items.any((i) => i.id == localId), isTrue);
    },
  );

  test('finish does not poll for a terminal result after acceptance', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final service = svc(db);
    // Poll endpoint never reports terminal; device work still releases at Core
    // acceptance.
    final repo = _StubUploadRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: stubbedDioProcessing(),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(),
        audioRecordingServiceProvider.overrideWithValue(service),
        recordingsRepositoryProvider.overrideWithValue(repo),
        queueOverride(),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId = await container
        .read(recordingFinisherProvider)
        .finish(title: 'Live');

    expect(isLocalRecordingId(localId), isTrue);

    final row = await db.itemsDao.getById(localId, '1');
    expect(row, isNotNull);
    expect(row!.coreId, 321);
    expect(
      row.processingStatus,
      'queued',
      reason: 'Core owns the processing lifecycle after acceptance',
    );
    expect(row.isProcessing, isTrue);
    expect(row.summary, isNull);
    expect(row.transcript, isNull);
    expect(row.notes, isNull);
  });
}

/// Repo whose Core create throws — simulates Core being unreachable so the
/// local-first finish path can be proven independent of Core.
class _CoreDownRepository extends RecordingsRepository {
  _CoreDownRepository({required super.apiClient});

  @override
  Future<RecordingCreateResult> createItemRecording({
    required String title,
    required int matomeId,
    required String clientId,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
    String? checksumSha256,
  }) async {
    throw const ApiException('Core unreachable');
  }
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll flow without a real S3.
class _StubUploadRepository extends RecordingsRepository
    with VerifiedSingleUploadRepositoryFake {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}
