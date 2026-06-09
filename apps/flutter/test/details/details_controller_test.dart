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
    expect(row.notes, 'fresh transcript'); // transcript -> notes
    expect(row.processingStatus, 'done');
  });
}
