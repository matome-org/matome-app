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
      'm007 matomeId merge-guard: a sparse Core refresh must NOT null-clobber '
      'a local recording.matomeId', () async {
    // A local-first recording reconciled to coreId 5, already an Item of a
    // Matome (matome_id set) — mirrors the post-upload steady state.
    await db.recordingsDao.upsertRecordingWithMatome(
      RecordingsCompanion.insert(
        id: '5',
        title: 'Has a Matome',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        coreId: const Value(5),
      ),
    );
    final before = await db.recordingsDao.getRecordingById('5');
    expect(before!.matomeId, isNotNull); // guaranteed by the insert path
    final matomeId = before.matomeId;

    // Core list reports id 5 with NO matome information at all (the Core
    // payload doesn't carry one). A naive full-companion upsert would NULL the
    // column on the conflict-update, orphaning the recording from its Matome.
    final container = _container(db, recordings: [
      _remote(id: 5, title: 'Has a Matome'),
    ]);
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    await _awaitItems(container);

    final after = await db.recordingsDao.getRecordingById('5');
    expect(after!.matomeId, matomeId); // local matome_id preserved across sync
    // And no duplicate/extra Matome was minted by the refresh upsert.
    final matCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM matomes')
        .map((r) => r.read<int>('c'))
        .getSingle();
    expect(matCount, 1);
  });

  test(
      'B2/W3: moveToSpace persists to Core via PATCH using the reconciled '
      'coreId column (not the stringified PK)', () async {
    // A reconciled local row: UUID PK, coreId column = 5 (Core-backed). W3 keys
    // the PATCH on the coreId column, so the move reaches Core /api/recordings/5
    // even though the local PK is a `rec_local_<uuid>` string.
    const localId = 'rec_local_move-me';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        coreId: const Value(5),
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
        .moveToSpace(localId, '42');

    expect(patched, isTrue); // PATCH /api/recordings/5 was issued (via coreId)
    final row = await db.recordingsDao.getRecordingById(localId);
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
      'W3: sync keeps the locally-probed import duration when Core reports none',
      () async {
    // An imported row whose duration was probed on-device (plan #46 W3). A Core
    // list-row that has no duration yet must NOT blank it back out.
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: '11',
        title: 'Imported',
        timestamp: '9:00 AM',
        duration: '3m 25s', // probed on import
        audioFilePath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    final container = _container(db, recordings: [
      _remote(id: 11, title: 'Imported'), // _remote carries NO duration
    ]);
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    final row = await db.recordingsDao.getRecordingById('11');
    expect(row!.duration, '3m 25s'); // not wiped by the duration-less Core row
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

  test(
      'W3 reconcile: a local row whose coreId is filled later, then a Core '
      'terminal result for that coreId, lands on the SAME local row — no '
      'duplicate, no wrong-row write', () async {
    // 1. A local-first row: rec_local_<uuid> PK, coreId NULL (pending_upload).
    const localId = 'rec_local_w3-reconcile';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        title: 'Captured offline',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/cap.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: const Value('pending_upload'),
      ),
    );

    // The Core list later returns the same recording under Core int id 321 —
    // i.e. the row has reconciled to coreId 321 and Core now reports it `done`
    // with a transcript. This is the socket/poll terminal landing via sync.
    final container = _container(db, recordings: [
      _remote(id: 321, title: 'Captured offline', status: 'done',
          summary: 'the summary'),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);

    // 2. Core-create succeeds → reconcile fills coreId on the EXISTING row.
    await controller.reconcileCoreId(localId, 321);
    final reconciled = await db.recordingsDao.getRecordingById(localId);
    expect(reconciled!.coreId, 321); // coreId filled on the existing PK
    expect(reconciled.processingStatus, 'processing'); // pending_upload flipped

    // 3. A refresh pulls the Core terminal for id 321. It MUST land on the
    //    existing rec_local_ row (matched by coreId), NOT create a second row
    //    under the stringified-id PK '321'.
    await controller.refresh();
    await _awaitItems(container);

    final allRows = await db.recordingsDao.getAllRecordings();
    expect(allRows.length, 1); // no duplicate row
    final landed = allRows.single;
    expect(landed.id, localId); // same local PK — the right row
    expect(landed.coreId, 321);
    expect(landed.summary, 'the summary'); // terminal result applied here
    expect(await db.recordingsDao.getRecordingById('321'), isNull); // no PK '321'
  });

  test(
      'BLOCKER: refresh after coreId reconcile keeps the durable LOCAL '
      'audioFilePath when Core storage_key is null/empty (no wipe to "")',
      () async {
    // A local-first import: rec_local_<uuid> PK, coreId NULL, with a durable
    // on-device audio path persisted (#45 W1 / #46 W2).
    const localId = 'rec_local_import-keep-audio';
    const localPath = '/data/user/0/app/files/import_x.mp3';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        title: 'Imported clip',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: localPath,
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: const Value('pending_upload'),
      ),
    );

    // Core list returns the same recording under Core int id 555 with NO
    // storage_key (fresh recording — null/empty). Pre-fix the first refresh
    // upsert WIPED audioFilePath to '' (the headline "audio disappeared" bug).
    final container = _container(db, recordings: [
      _remote(id: 555, title: 'Imported clip', status: 'done'),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);

    // Reconcile coreId onto the existing local row, then run the sync/refresh.
    await controller.reconcileCoreId(localId, 555);
    await controller.refresh();
    await _awaitItems(container);

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.coreId, 555);
    expect(row.audioFilePath, localPath); // STILL the local path — NOT wiped
  });

  test(
      'W3: moveToSpace on a local-only row (coreId null) does NOT call Core; '
      'the move holds locally', () async {
    const localId = 'rec_local_not-uploaded';
    await db.recordingsDao.insertRecording(
      RecordingsCompanion.insert(
        id: localId,
        title: 'Local only',
        timestamp: '9:00 AM',
        duration: '0:30',
        audioFilePath: '/tmp/x.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: const Value('pending_upload'),
      ),
    );

    // Pre-condition: the seeded row is genuinely local-only (coreId NULL).
    final seeded = await db.recordingsDao.getRecordingById(localId);
    expect(seeded!.coreId, isNull);

    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);

    await container
        .read(inboxControllerProvider.notifier)
        .moveToSpace(localId, '9');

    // coreId NULL ⇒ moveToSpace must NOT reach Core. The only mocked endpoint is
    // GET /api/recordings (the refresh); there is NO PATCH mock, so if the guard
    // were wrong the PATCH would throw an unmocked-route error and fail the test.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.workspaceId, '9'); // the local move still holds (durable)
    expect(row.coreId, isNull); // still local-only — nothing round-tripped
  });
}
