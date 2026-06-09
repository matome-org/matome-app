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
import 'package:matome_flutter/features/recordings/recordings_repository.dart';

/// Builds a ProviderContainer wired to an in-memory Drift DB and a mock-adapter
/// dio (no live backend). [recordings] is the JSON list `/api/recordings`
/// returns; pass `null` to make the endpoint fail (offline path).
ProviderContainer _container(
  AppDatabase db, {
  List<Map<String, dynamic>>? recordings,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:4000',
    validateStatus: (s) => s != null && s < 500,
  ));
  final adapter = DioAdapter(dio: dio);
  if (recordings != null) {
    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(200, {'recordings': recordings}),
    );
  } else {
    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(500, {'error': 'offline'}),
    );
  }
  final repo = RecordingsRepository(
    apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
  );

  return ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    recordingsRepositoryProvider.overrideWithValue(repo),
  ]);
}

Map<String, dynamic> _remote({
  required int id,
  String title = 'Remote',
  String status = 'done',
  String? summary,
  int? workspaceId,
  String? insertedAt,
}) {
  return {
    'id': id,
    'owner_id': 1,
    'title': title,
    'status': status,
    'summary': summary,
    'workspace_id': workspaceId,
    'inserted_at': insertedAt ?? '2026-06-08T12:00:00Z',
  };
}

Future<List<dynamic>> _awaitItems(ProviderContainer container) async {
  // Drain until a data state is published.
  for (var i = 0; i < 50; i++) {
    final s = container.read(inboxControllerProvider);
    if (s.hasValue) return s.requireValue;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container.read(inboxControllerProvider).requireValue;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('refresh syncs Core recordings into Drift and renders from Drift',
      () async {
    final container = _container(db, recordings: [
      _remote(id: 7, title: 'Synced one', summary: 'hello'),
      _remote(id: 9, title: 'Synced two'),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.refresh();

    final items = await _awaitItems(container);
    expect(items.map((i) => i.id), containsAll(<String>['7', '9']));

    // Reconciliation: Core int id 7 -> Drift TEXT id '7'.
    final row = await db.recordingsDao.getRecordingById('7');
    expect(row, isNotNull);
    expect(row!.title, 'Synced one');
    expect(row.summary, 'hello');
  });

  test('recordings assigned to a workspace are excluded from the Inbox',
      () async {
    final container = _container(db, recordings: [
      _remote(id: 1, title: 'Inbox one'),
      _remote(id: 2, title: 'In a space', workspaceId: 42),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.refresh();
    final items = await _awaitItems(container);

    expect(items.map((i) => i.id), ['1']); // workspace_id 42 row excluded
  });

  test('offline (failed fetch) still renders cached Drift rows', () async {
    // Seed a cached row directly, then refresh with a failing endpoint.
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '100',
        title: 'Cached',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    final container = _container(db, recordings: null); // endpoint 500s
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.refresh();
    final items = await _awaitItems(container);

    expect(items.single.id, '100'); // cache survived the network error
  });

  test('moveToSpace assigns workspaceId and removes the row from the Inbox',
      () async {
    final ws = await db.workspacesDao.createWorkspace('Work');
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '5',
        title: 'Move me',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.reloadFromLocal();
    expect((await _awaitItems(container)).map((i) => i.id), ['5']);

    await controller.moveToSpace('5', ws.id);
    final after = await _awaitItems(container);
    expect(after, isEmpty); // no longer in the Inbox

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.workspaceId, ws.id);
  });

  test(
      'B2 regression: moveToSpace survives a refresh whose Core list still '
      'reports the recording in the Inbox (no clobber back to Inbox)',
      () async {
    // A locally-created space ('ws_...' id — no Core counterpart), so the
    // move is durable purely via the merge-upsert safety net.
    final ws = await db.workspacesDao.createWorkspace('Work');
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '5',
        title: 'Move me',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );

    // Core list keeps reporting id 5 with workspace_id: null (stale: the move
    // hasn't round-tripped). Pre-fix this snapped the row back to the Inbox.
    final container = _container(db, recordings: [
      _remote(id: 5, title: 'Move me'),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.moveToSpace('5', ws.id);
    expect((await _awaitItems(container)), isEmpty); // left the Inbox

    // A refresh pulls the stale Core row — the merge-upsert must NOT overwrite
    // the local workspaceId with the stale null.
    await controller.refresh();
    expect((await _awaitItems(container)), isEmpty); // still NOT in the Inbox

    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.workspaceId, ws.id); // local move preserved across sync
  });

  test(
      'B2: moveToSpace persists to Core via PATCH when both ids are Core-backed '
      '(numeric)', () async {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '5',
        title: 'Move me',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );

    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    var patched = false;
    adapter
      ..onGet('/api/recordings', (s) => s.reply(200, {'recordings': []}))
      ..onPatch(
        '/api/recordings/5',
        (s) {
          patched = true;
          return s.reply(200, {
            'recording': _remote(id: 5, title: 'Move me', workspaceId: 42),
          });
        },
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

    // Core workspace id 42 -> local TEXT '42' (numeric ⇒ Core-backed).
    await container
        .read(inboxControllerProvider.notifier)
        .moveToSpace('5', '42');

    expect(patched, isTrue); // PATCH /api/recordings/5 was issued
    final row = await db.recordingsDao.getRecordingById('5');
    expect(row!.workspaceId, '42');
  });

  test('B2: sync keeps local notes when Core has no transcript yet', () async {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '8',
        title: 'Has notes',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        notes: const Value('local notes'),
      ),
    );
    final container = _container(db, recordings: [
      _remote(id: 8, title: 'Has notes'), // no transcript in the Core payload
    ]);
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    final row = await db.recordingsDao.getRecordingById('8');
    expect(row!.notes, 'local notes'); // not wiped by the stale Core row
  });

  test(
      'B2: a non-offline sync error (401) is distinguishable from offline — '
      'cache survives but the failure is surfaced as an ApiException',
      () async {
    // Seed a cached row, then make the list endpoint return 401 (auth error,
    // NOT a transport-level offline). The repo maps it to an ApiException with
    // a statusCode, which the controller treats differently from offline.
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '200',
        title: 'Cached',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );

    final dio = Dio(BaseOptions(
      baseUrl: 'http://localhost:4000',
      validateStatus: (s) => s != null && s < 500,
    ));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/api/recordings',
      (server) => server.reply(401, {'error': 'unauthorized'}),
    );
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );

    // The repo classifies the 401 as an ApiException carrying a statusCode —
    // the signal the controller uses to NOT treat it as plain offline.
    await expectLater(
      repo.fetchRecordings(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
            .having((e) => e.statusCode, 'statusCode', 401),
      ),
    );

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // refresh() swallows for the offline-first cache, but the row still renders
    // (the controller logged the 401 rather than masking it as connectivity).
    await container.read(inboxControllerProvider.notifier).refresh();
    final items = await _awaitItems(container);
    expect(items.single.id, '200');
  });

  test('insertLocalUpload makes a processing row appear immediately', () async {
    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);

    await controller.insertLocalUpload(
      RecordingsCompanion(
        id: const Value('77'),
        title: const Value('Imported.m4a'),
        timestamp: const Value('9:00 AM'),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(1),
        audioFilePath: const Value('/tmp/x.m4a'),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('audio'),
        processingStatus: const Value('processing'),
      ),
    );

    final items = await _awaitItems(container);
    expect(items.single.id, '77');
    expect(items.single.card.isProcessing, isTrue);

    // applyUploadResult flips it to done with a summary.
    await controller.applyUploadResult('77',
        failed: false, summary: 'transcribed', notes: 'full text');
    final done = await _awaitItems(container);
    expect(done.single.card.isProcessing, isFalse);
    expect(done.single.card.processingStatus, 'done');
    expect(done.single.card.summary, 'transcribed');
  });

  test(
      'B3 regression: a sparse terminal (null summary/notes) does NOT wipe '
      'previously-good values', () async {
    // A row that already transcribed successfully (has summary + notes).
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '88',
        title: 'Done already',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        summary: const Value('good summary'),
        notes: const Value('good notes'),
        processingStatus: const Value('done'),
      ),
    );
    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);
    await controller.reloadFromLocal();

    // The socket-vs-poll race is won by a SPARSE `done` event carrying null
    // summary/transcript — pre-fix this null-overwrote the good data.
    await controller.applyUploadResult('88', failed: false);

    final row = await db.recordingsDao.getRecordingById('88');
    expect(row!.summary, 'good summary'); // preserved, not wiped to null
    expect(row.notes, 'good notes'); // preserved, not wiped to null
    expect(row.processingStatus, 'done');
    expect(row.isProcessing, 0);
  });

  test('B3: a real non-null terminal update DOES apply (overwrites)', () async {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '89',
        title: 'Reprocessing',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        summary: const Value('old summary'),
        notes: const Value('old notes'),
      ),
    );
    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);
    await controller.reloadFromLocal();

    await controller.applyUploadResult('89',
        failed: false, summary: 'new summary', notes: 'new notes');

    final row = await db.recordingsDao.getRecordingById('89');
    expect(row!.summary, 'new summary'); // real update applied
    expect(row.notes, 'new notes');
  });
}
