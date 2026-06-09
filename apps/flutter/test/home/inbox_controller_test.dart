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
}
