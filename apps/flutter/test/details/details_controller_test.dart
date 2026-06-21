import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/details/details_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

/// An injected [RecordingResultAwaiter] that resolves immediately with a fixed
/// terminal [result], standing in for the socket-vs-poll race outcome.
RecordingResultAwaiter _awaiterReturning(RecordingResult result) {
  return ({required recording, required poll, required ref}) async => result;
}

/// A test provider yielding a [DetailsController] for id '5' with an injected
/// [awaiter] (so the socket-vs-poll race is deterministic).
Provider<DetailsController> _controllerProvider(RecordingResultAwaiter awaiter) {
  return Provider<DetailsController>(
    (ref) => DetailsController(ref, '5', awaitResult: awaiter),
  );
}

/// Wires an in-memory Drift DB + a mock-adapter dio (no live backend). The
/// `POST /api/recordings/5/process` endpoint returns 202 so
/// [DetailsController.retry] can run; `GET /api/recordings/5` 404s (the poll
/// fallback never wins — the injected awaiter resolves the race instead).
ProviderContainer _container(AppDatabase db) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:4000',
    validateStatus: (s) => s != null && s < 500,
  ));
  final adapter = DioAdapter(dio: dio);
  adapter
    ..onPost(
      '/api/recordings/5/process',
      (s) => s.reply(202, {
        'recording': {
          'id': 5,
          'owner_id': 1,
          'title': 'Rec',
          'status': 'processing',
        },
        'processing': {'queued': true},
      }),
    )
    ..onGet(
      '/api/recordings/5',
      (s) => s.reply(404, {'error': 'not found'}),
    );
  final repo = RecordingsRepository(
    apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
  );
  return ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    recordingsRepositoryProvider.overrideWithValue(repo),
  ]);
}

Future<void> _seedDone(AppDatabase db) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion.insert(
      id: '5',
      title: 'Rec',
      timestamp: '9:00 AM',
      duration: '0:30',
      audioFilePath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      summary: const Value('good summary'),
      notes: const Value('good notes'),
      processingStatus: const Value('failed'),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
      'B3 regression: retry won by a sparse socket `done` (null summary/notes) '
      'does NOT wipe previously-good values', () async {
    await _seedDone(db);
    final container = _container(db);
    addTearDown(container.dispose);

    // Sparse terminal: a `done` recording carrying null summary/transcript —
    // exactly what a partial socket broadcast (or a race loser) yields.
    const sparse = Recording(
      id: 5,
      ownerId: 1,
      title: '',
      status: RecordingStatus.done,
    );
    final controller = container.read(
      _controllerProvider(_awaiterReturning(const RecordingResult.done(sparse))),
    );

    await controller.retry();

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.summary, 'good summary'); // preserved, not null-wiped
    expect(row.notes, 'good notes'); // preserved, not null-wiped
    expect(row.processingStatus, 'done');
    expect(row.isProcessing, 0);
  });

  test('B3: a real non-null terminal DOES apply (overwrites old values)',
      () async {
    await _seedDone(db);
    final container = _container(db);
    addTearDown(container.dispose);

    const full = Recording(
      id: 5,
      ownerId: 1,
      title: 'Rec',
      status: RecordingStatus.done,
      summary: 'fresh summary',
      transcript: 'fresh transcript',
    );
    final controller = container.read(
      _controllerProvider(_awaiterReturning(const RecordingResult.done(full))),
    );

    await controller.retry();

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.summary, 'fresh summary'); // real update applied
    // 1435 write-authority: the machine transcript lands in the `transcript`
    // column, NOT the user `notes` column. The seeded user note survives.
    expect(row.transcript, 'fresh transcript');
    expect(row.notes, 'good notes'); // user note untouched by the terminal apply
    expect(row.processingStatus, 'done');
  });

  test(
      '1435: save(text) writes the buffer to Drift `notes`, leaves Drift '
      '`transcript` UNCHANGED, and the Core PATCH carries `notes` but NOT '
      '`transcript`', () async {
    // Seed a row carrying BOTH a user note and a machine transcript so we can
    // prove the write path touches notes only.
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '5',
        title: 'Rec',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        summary: const Value('good summary'),
        notes: const Value('old note'),
        transcript: const Value('machine transcript'),
      ),
    );

    // Capture the outgoing PATCH body via an interceptor (the mock-adapter
    // handler callback does not expose the request body directly).
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    Map<String, dynamic>? patchBody;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'PATCH' && options.path == '/api/recordings/5') {
          patchBody = options.data as Map<String, dynamic>;
        }
        handler.next(options);
      },
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onPatch(
      '/api/recordings/5',
      (s) => s.reply(200, {
        'recording': {
          'id': 5,
          'owner_id': 1,
          'title': 'Rec',
          'status': 'done',
        },
      }),
      data: Matchers.any,
    );
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(
      _controllerProvider(_awaiterReturning(const RecordingResult.done(null))),
    );
    for (var i = 0; i < 20 && controller.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    await controller.save('new note');

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.notes, 'new note'); // buffer written to notes
    expect(row.transcript, 'machine transcript'); // transcript UNCHANGED

    // The Core PATCH carries the note under `notes` and NEVER `transcript`.
    expect(patchBody, isNotNull, reason: 'a Core PATCH was issued');
    expect(patchBody!['notes'], 'new note');
    expect(patchBody!.containsKey('transcript'), isFalse,
        reason: 'save() must not PATCH Core transcript (data-loss path)');
  });

  test(
      'W3: a local-only row (rec_local_, coreId null) reads coreId from the '
      'column and degrades cleanly — save persists locally, retry is a no-op, '
      'no Core call is attempted', () async {
    // A captured-but-not-yet-uploaded row: UUID PK, coreId NULL.
    const localId = 'rec_local_details-degrade';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        title: 'Local capture',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/local.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: const Value('pending_upload'),
      ),
    );

    // No /api/recordings/* endpoints are mocked: any Core call would throw an
    // unmocked-route error and fail the test. The awaiter must NOT be reached.
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    DioAdapter(dio: dio);
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    var awaiterCalled = false;
    final controllerProvider = Provider<DetailsController>(
      (ref) => DetailsController(
        ref,
        localId,
        awaitResult: ({required recording, required poll, required ref}) async {
          awaiterCalled = true;
          return const RecordingResult.done(null);
        },
      ),
    );
    final controller = container.read(controllerProvider);
    // Let load() settle.
    for (var i = 0; i < 20 && controller.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(controller.state.coreId, isNull); // derived from the column, not parse

    // save() writes notes to Drift even with no Core counterpart.
    await controller.save('offline edit');
    expect((await db.recordingsDao.getRecordingById(localId))!.notes,
        'offline edit');

    // retry() is a clean no-op for a row Core has never seen.
    await controller.retry();
    expect(awaiterCalled, isFalse); // never raced the socket/poll
    final after = await db.recordingsDao.getRecordingById(localId);
    expect(after!.processingStatus, 'pending_upload'); // unchanged, not 'failed'
  });

  test(
      'W2 #871: explicit user delete removes BOTH the on-disk local audio file '
      'AND the Drift row (free disk on user-initiated deletion)', () async {
    // Seed a local-only row pointing at a REAL on-disk temp file.
    final tmp = await Directory.systemTemp.createTemp('details_delete_test_');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });
    final audio = File('${tmp.path}/local.m4a');
    await audio.writeAsBytes(List<int>.filled(8, 0));
    expect(await audio.exists(), isTrue);

    const localId = 'rec_local_details-delete';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        title: 'Local capture',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: audio.path,
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: const Value('done'),
      ),
    );

    // No Core endpoints mocked: a local-only row (coreId null) makes no Core
    // call on delete, so an unmocked route would fail the test if it did.
    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    DioAdapter(dio: dio);
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final controllerProvider = Provider<DetailsController>(
      (ref) => DetailsController(
        ref,
        localId,
        awaitResult: ({required recording, required poll, required ref}) async =>
            const RecordingResult.done(null),
      ),
    );
    final controller = container.read(controllerProvider);
    for (var i = 0; i < 20 && controller.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    await controller.delete();

    // The on-disk audio is freed AND the row is gone.
    expect(await audio.exists(), isFalse,
        reason: 'user-delete frees the local audio file (W2 #871)');
    expect(await db.recordingsDao.getRecordingById(localId), isNull,
        reason: 'user-delete removes the Drift row');
  });
}
