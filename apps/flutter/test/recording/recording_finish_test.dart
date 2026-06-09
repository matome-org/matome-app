import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';

import 'audio_recording_service_test.dart' show FakeRecorderBackend;

// ---------------------------------------------------------------------------
// Mirrors apps/mobile RecordingScreen.handleFinish: F3 finalizes the session
// file → S1/F4 InboxUploader creates the Core recording + a local Drift row
// (processing) + uploads + enqueues + awaits done → F3 discardSegments cleans
// up. No live mic (FakeRecorderBackend); upload PUT is stubbed.
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

  Dio stubbedDio() {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/recordings',
      (server) => server.reply(201, {
        'recording': {
          'id': 777,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'pending',
        },
        'upload': {
          'method': 'PUT',
          'url': 'http://127.0.0.1:9/upload',
          'storage_key': 'k',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
    );
    adapter.onPost(
      '/api/recordings/777/process',
      (server) => server.reply(202, {
        'recording': {
          'id': 777,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'processing',
        },
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/recordings/777',
      (server) => server.reply(200, {
        'recording': {
          'id': 777,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'done',
          'summary': 'A memo',
          'transcript': 'hello',
        },
      }),
    );
    return dio;
  }

  // GET /api/recordings/777 that never reports terminal — so ONLY the injected
  // socket awaiter can flip processing→done (proves the realtime path is wired).
  Dio stubbedDioProcessing() {
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPost(
      '/api/recordings',
      (server) => server.reply(201, {
        'recording': {
          'id': 777,
          'owner_id': 1,
          'title': 'New Recording',
          'status': 'pending',
        },
        'upload': {
          'method': 'PUT',
          'url': 'http://127.0.0.1:9/upload',
          'storage_key': 'k',
          'expires_in': 900,
        },
      }),
      data: Matchers.any,
    );
    adapter.onPost(
      '/api/recordings/777/process',
      (server) => server.reply(202, {
        'recording': {'id': 777, 'owner_id': 1, 'status': 'processing'},
        'processing': {'queued': true},
      }),
    );
    adapter.onGet(
      '/api/recordings/777',
      (server) => server.reply(200, {
        'recording': {'id': 777, 'owner_id': 1, 'status': 'processing'},
      }),
    );
    return dio;
  }

  /// Builds an [InboxUploader] with an injected [RecordingResultAwaiter], so the
  /// finish flow can be driven by a fake socket-vs-poll race in tests.
  InboxUploader uploaderWith(Ref ref, RecordingResultAwaiter awaiter) =>
      InboxUploader(ref, awaitResult: awaiter);

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
      inboxUploaderProvider
          .overrideWith((ref) => uploaderWith(ref, pollFallbackAwaiter)),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId = await container.read(recordingFinisherProvider).finish(
          title: 'Standup notes',
        );

    expect(localId, '777'); // Core int 777 -> local TEXT '777'

    // Inbox row reconciled to done.
    final row = await db.recordingsDao.getRecordingById('777');
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'A memo');

    // It appears in the Inbox list (workspaceId IS NULL).
    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.any((i) => i.id == '777'), isTrue);

    // Privacy cleanup: segments + draft gone.
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
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
      inboxUploaderProvider
          .overrideWith((ref) => uploaderWith(ref, fakeSocketAwaiter)),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();

    final localId =
        await container.read(recordingFinisherProvider).finish(title: 'Live');

    expect(awaiterCalled, isTrue, reason: 'finish must use the realtime waiter');
    expect(localId, '777');

    final row = await db.recordingsDao.getRecordingById('777');
    expect(row, isNotNull);
    expect(row!.processingStatus, 'done',
        reason: 'socket event must drive processing→done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'From socket');
    expect(row.notes, 'realtime');
  });
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll flow without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}
