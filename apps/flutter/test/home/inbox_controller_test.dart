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

import '../support/item_fixtures.dart';

/// Builds a ProviderContainer wired to an in-memory Drift DB and a mock-adapter
/// dio (no live backend). [recordings] is the JSON list `/api/recordings`
/// returns; pass `null` to make the endpoint fail (offline path).
ProviderContainer _container(
  AppDatabase db, {
  List<Map<String, dynamic>>? recordings,
  // #1469: the authenticated owner the sync backfill stamps onto NULL-owner
  // local rows. Overridden directly so the test never builds the real
  // authController chain (which would hit flutter_secure_storage / the platform
  // binding). Defaults to '1' to match the `_remote` owner_id.
  String? ownerId = '1',
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:7001',
      validateStatus: (s) => s != null && s < 500,
    ),
  );
  final adapter = DioAdapter(dio: dio);
  if (recordings != null) {
    adapter.onGet(
      '/api/items',
      (server) => server.reply(200, {'items': recordings}),
    );
  } else {
    adapter.onGet(
      '/api/items',
      (server) => server.reply(500, {'error': 'offline'}),
    );
  }
  final repo = RecordingsRepository(
    apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
  );

  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      currentOwnerIdProvider.overrideWithValue(ownerId),
    ],
  );
}

/// Builds the explicit Core Item processing projection returned by `/api/items`.
Map<String, dynamic> _remote({
  required int id,
  String title = 'Remote',
  String status = 'done',
  String? summary,
  int? workspaceId,
  String? insertedAt,
  String? transcript,
  String? notes,
}) {
  final processingState = switch (status) {
    'pending' => 'queued',
    'done' => 'succeeded',
    _ => status,
  };
  return {
    'id': id,
    'owner_id': 1,
    'item_type': 'file',
    'title': title,
    'notes': notes,
    'workspace_id': workspaceId,
    'processing_state': processingState,
    'processing_run_id': 'run-$id',
    'processing_attempt': 1,
    'processing_requested_outputs': const ['summary', 'transcript'],
    'processing_outputs': {
      if (summary != null) 'summary': {'type': 'summary', 'markdown': summary},
      if (transcript != null)
        'transcript': {'type': 'transcript', 'text': transcript},
    },
    'file': {'media_type': 'audio', 'upload_state': 'uploaded'},
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

  test(
    'refresh syncs Core recordings into Drift and renders from Drift',
    () async {
      final container = _container(
        db,
        recordings: [
          _remote(id: 7, title: 'Synced one', summary: 'hello'),
          _remote(id: 9, title: 'Synced two'),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(inboxControllerProvider.notifier);
      await controller.refresh();

      final items = await _awaitItems(container);
      expect(items.map((i) => i.id), containsAll(<String>['7', '9']));

      // Reconciliation: Core int id 7 -> Drift TEXT id '7'.
      final row = await db.itemsDao.getById('7', '1');
      expect(row, isNotNull);
      expect(row!.title, 'Synced one');
      expect(row.summary, 'hello');
    },
  );

  test(
    'recordings assigned to a workspace are excluded from the Inbox',
    () async {
      final container = _container(
        db,
        recordings: [
          _remote(id: 1, title: 'Inbox one'),
          _remote(id: 2, title: 'In a space', workspaceId: 42),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(inboxControllerProvider.notifier);
      await controller.refresh();
      final items = await _awaitItems(container);

      expect(items.map((i) => i.id), ['1']); // workspace_id 42 row excluded
    },
  );

  test('offline (failed fetch) still renders cached Drift rows', () async {
    // Seed a cached row directly, then refresh with a failing endpoint.
    await insertTestFileItem(
      db,
      id: '100',
      title: 'Cached',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    );
    final container = _container(db, recordings: null); // endpoint 500s
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.refresh();
    final items = await _awaitItems(container);

    expect(items.single.id, '100'); // cache survived the network error
  });

  test(
    'moveToSpace assigns workspaceId and removes the row from the Inbox',
    () async {
      final ws = await db.workspacesDao.createWorkspace('Work');
      await insertTestFileItem(
        db,
        id: '5',
        title: 'Move me',
        durationSeconds: 30,
        localPath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      );
      final container = _container(db, recordings: const []);
      addTearDown(container.dispose);

      final controller = container.read(inboxControllerProvider.notifier);
      await controller.reloadFromLocal();
      expect((await _awaitItems(container)).map((i) => i.id), ['5']);

      await controller.moveToSpace('5', ws.id);
      final after = await _awaitItems(container);
      expect(after, isEmpty); // no longer in the Inbox

      final row = await db.itemsDao.getById('5', '1');
      expect(row!.workspaceId, ws.id);
    },
  );

  test('B2 regression: moveToSpace survives a refresh whose Core list still '
      'reports the recording in the Inbox (no clobber back to Inbox)', () async {
    // A locally-created space ('ws_...' id — no Core counterpart), so the
    // move is durable purely via the merge-upsert safety net.
    final ws = await db.workspacesDao.createWorkspace('Work');
    await insertTestFileItem(
      db,
      id: '5',
      title: 'Move me',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    );

    // Core list keeps reporting id 5 with workspace_id: null (stale: the move
    // hasn't round-tripped). Pre-fix this snapped the row back to the Inbox.
    final container = _container(
      db,
      recordings: [_remote(id: 5, title: 'Move me')],
    );
    addTearDown(container.dispose);

    final controller = container.read(inboxControllerProvider.notifier);
    await controller.moveToSpace('5', ws.id);
    expect((await _awaitItems(container)), isEmpty); // left the Inbox

    // A refresh pulls the stale Core row — the merge-upsert must NOT overwrite
    // the local workspaceId with the stale null.
    await controller.refresh();
    expect((await _awaitItems(container)), isEmpty); // still NOT in the Inbox

    final row = await db.itemsDao.getById('5', '1');
    expect(row!.workspaceId, ws.id); // local move preserved across sync
  });

  test('m007 matomeId merge-guard: a sparse Core refresh must NOT null-clobber '
      'a local recording.matomeId', () async {
    // A local-first recording reconciled to coreId 5, already an Item of a
    // Matome (matome_id set) — mirrors the post-upload steady state.
    await db.matomesDao.create(
      MatomesCompanion.insert(
        id: 'mat_local_5',
        title: 'Has a Matome',
        happenedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );
    await insertTestFileItem(
      db,
      id: '5',
      title: 'Has a Matome',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      coreId: 5,
      matomeId: 'mat_local_5',
    );
    final before = await db.itemsDao.getById('5', '1');
    expect(before!.matomeId, isNotNull); // guaranteed by the insert path
    final matomeId = before.matomeId;

    // Core list reports id 5 with NO matome information at all (the Core
    // payload doesn't carry one). A naive full-companion upsert would NULL the
    // column on the conflict-update, orphaning the recording from its Matome.
    final container = _container(
      db,
      recordings: [_remote(id: 5, title: 'Has a Matome')],
    );
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    await _awaitItems(container);

    final after = await db.itemsDao.getById('5', '1');
    expect(after!.matomeId, matomeId); // local matome_id preserved across sync
    // And no duplicate/extra Matome was minted by the refresh upsert.
    final matCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM matomes')
        .map((r) => r.read<int>('c'))
        .getSingle();
    expect(matCount, 1);
  });

  test('B2/W3: moveToSpace persists to Core via PATCH using the reconciled '
      'coreId column (not the stringified PK)', () async {
    // A reconciled local row: UUID PK, coreId column = 5 (Core-backed). W3 keys
    // the PATCH on the coreId column, so the move reaches Core /api/recordings/5
    // even though the local PK is a `rec_local_<uuid>` string.
    const localId = 'rec_local_move-me';
    await insertTestFileItem(
      db,
      id: localId,
      coreId: 5,
      title: 'Move me',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final adapter = DioAdapter(dio: dio);
    var patched = false;
    adapter
      ..onGet('/api/items', (s) => s.reply(200, {'items': []}))
      ..onPatch('/api/items/5', (s) {
        patched = true;
        return s.reply(200, {
          'item': _remote(id: 5, title: 'Move me', workspaceId: 42),
        });
      }, data: Matchers.any);
    final repo = RecordingsRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: dio),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        recordingsRepositoryProvider.overrideWithValue(repo),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
    );
    addTearDown(container.dispose);

    // Core workspace id 42 -> local TEXT '42' (numeric ⇒ Core-backed).
    await container
        .read(inboxControllerProvider.notifier)
        .moveToSpace(localId, '42');

    expect(patched, isTrue); // PATCH /api/recordings/5 was issued (via coreId)
    final row = await db.itemsDao.getById(localId, '1');
    expect(row!.workspaceId, '42');
  });

  test('B2: sync keeps local notes when Core has no transcript yet', () async {
    await insertTestFileItem(
      db,
      id: '8',
      title: 'Has notes',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      notes: 'local notes',
    );
    final container = _container(
      db,
      recordings: [
        _remote(id: 8, title: 'Has notes'), // no transcript in the Core payload
      ],
    );
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    final row = await db.itemsDao.getById('8', '1');
    expect(row!.notes, 'local notes'); // not wiped by the stale Core row
  });

  test(
    'W3: sync keeps the locally-probed import duration when Core reports none',
    () async {
      // An imported row whose duration was probed on-device (plan #46 W3). A Core
      // list-row that has no duration yet must NOT blank it back out.
      await insertTestFileItem(
        db,
        id: '11',
        title: 'Imported',
        durationSeconds: 205,
        localPath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      );
      final container = _container(
        db,
        recordings: [
          _remote(id: 11, title: 'Imported'), // _remote carries NO duration
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxControllerProvider.notifier).refresh();
      final row = await db.itemsDao.getById('11', '1');
      expect(
        row!.durationSeconds,
        205,
      ); // not wiped by the duration-less Core row
    },
  );

  test('B2: a non-offline sync error (401) is distinguishable from offline — '
      'cache survives but the failure is surfaced as an ApiException', () async {
    // Seed a cached row, then make the list endpoint return 401 (auth error,
    // NOT a transport-level offline). The repo maps it to an ApiException with
    // a statusCode, which the controller treats differently from offline.
    await insertTestFileItem(
      db,
      id: '200',
      title: 'Cached',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/api/items',
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

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        recordingsRepositoryProvider.overrideWithValue(repo),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
    );
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
      item: ItemsCompanion.insert(
        id: '77',
        ownerId: '1',
        clientId: '77',
        itemType: 'file',
        title: const Value('Imported.m4a'),
        fileBlobId: const Value('file_77'),
        processingState: const Value('processing'),
        syncState: const Value('processing'),
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
      file: FileBlobsCompanion.insert(
        id: 'file_77',
        mediaType: 'audio',
        localPath: const Value('/tmp/x.m4a'),
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      ),
    );

    final items = await _awaitItems(container);
    expect(items.single.id, '77');
    expect(items.single.card.isProcessing, isTrue);

    // applyUploadResult flips it to succeeded with a summary.
    await controller.applyUploadResult(
      '77',
      failed: false,
      summary: 'transcribed',
      transcript: 'full text',
    );
    final done = await _awaitItems(container);
    expect(done.single.card.isProcessing, isFalse);
    expect(done.single.card.processingStatus, 'succeeded');
    expect(done.single.card.summary, 'transcribed');
  });

  test('B3 regression: a sparse terminal (null summary/notes) does NOT wipe '
      'previously-good values', () async {
    // A row that already transcribed successfully (has summary + notes).
    await insertTestFileItem(
      db,
      id: '88',
      title: 'Done already',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      summary: 'good summary',
      notes: 'good notes',
    );
    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);
    await controller.reloadFromLocal();

    // A sparse successful result carries no summary/transcript. It must not
    // overwrite previously-good machine output.
    await controller.applyUploadResult('88', failed: false);

    final row = await db.itemsDao.getById('88', '1');
    expect(row!.summary, 'good summary'); // preserved, not wiped to null
    expect(row.notes, 'good notes'); // preserved, not wiped to null
    expect(row.processingStatus, 'succeeded');
    expect(row.isProcessing, isFalse);
  });

  test(
    'B3 / 1435: a real non-null terminal update applies summary + transcript '
    'and NEVER overwrites the user note',
    () async {
      await insertTestFileItem(
        db,
        id: '89',
        title: 'Reprocessing',
        durationSeconds: 30,
        localPath: '/tmp/a.m4a',
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        summary: 'old summary',
        notes: 'user note',
        transcript: 'old transcript',
      );
      final container = _container(db, recordings: const []);
      addTearDown(container.dispose);
      final controller = container.read(inboxControllerProvider.notifier);
      await controller.reloadFromLocal();

      await controller.applyUploadResult(
        '89',
        failed: false,
        summary: 'new summary',
        transcript: 'new transcript',
      );

      final row = await db.itemsDao.getById('89', '1');
      expect(row!.summary, 'new summary'); // real update applied
      // WRITE-AUTHORITY (#1435): machine transcript → transcript column; the
      // user note is left untouched (no more transcript→notes clobber).
      expect(row.transcript, 'new transcript');
      expect(row.notes, 'user note');
    },
  );

  test('W3 reconcile: a local row whose coreId is filled later, then a Core '
      'terminal result for that coreId, lands on the SAME local row — no '
      'duplicate, no wrong-row write', () async {
    // 1. A local-first row: rec_local_<uuid> PK, coreId NULL (pending_upload).
    const localId = 'rec_local_w3-reconcile';
    await insertTestFileItem(
      db,
      id: localId,
      title: 'Captured offline',
      durationSeconds: 30,
      localPath: '/tmp/cap.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      processingStatus: 'pending_upload',
    );

    // The Core list later returns the same recording under Core int id 321 —
    // i.e. the row has reconciled to coreId 321 and Core now reports it `done`
    // with a transcript. This is the terminal response landing via sync.
    final container = _container(
      db,
      recordings: [
        _remote(
          id: 321,
          title: 'Captured offline',
          status: 'done',
          summary: 'the summary',
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);

    // 2. Core-create succeeds → reconcile fills coreId on the EXISTING row.
    await controller.reconcileCoreId(localId, 321);
    final reconciled = await db.itemsDao.getById(localId, '1');
    expect(reconciled!.coreId, 321); // coreId filled on the existing PK
    expect(reconciled.processingStatus, 'processing'); // pending_upload flipped

    // 3. A refresh pulls the Core terminal for id 321. It MUST land on the
    //    existing rec_local_ row (matched by coreId), NOT create a second row
    //    under the stringified-id PK '321'.
    await controller.refresh();
    await _awaitItems(container);

    final allRows = await db.itemsDao.listAll('1');
    expect(allRows.length, 1); // no duplicate row
    final landed = allRows.single;
    expect(landed.id, localId); // same local PK — the right row
    expect(landed.coreId, 321);
    expect(landed.summary, 'the summary'); // terminal result applied here
    expect(await db.itemsDao.getById('321', '1'), isNull); // no PK '321'
  });

  test(
    'BLOCKER: refresh after coreId reconcile keeps the durable LOCAL '
    'audioFilePath when Core storage_key is null/empty (no wipe to "")',
    () async {
      // A local-first import: rec_local_<uuid> PK, coreId NULL, with a durable
      // on-device audio path persisted (#45 W1 / #46 W2).
      const localId = 'rec_local_import-keep-audio';
      const localPath = '/data/user/0/app/files/import_x.mp3';
      await insertTestFileItem(
        db,
        id: localId,
        title: 'Imported clip',
        durationSeconds: 30,
        localPath: localPath,
        createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
        processingStatus: 'pending_upload',
      );

      // Core list returns the same recording under Core int id 555 with NO
      // storage_key (fresh recording — null/empty). Pre-fix the first refresh
      // upsert WIPED audioFilePath to '' (the headline "audio disappeared" bug).
      final container = _container(
        db,
        recordings: [_remote(id: 555, title: 'Imported clip', status: 'done')],
      );
      addTearDown(container.dispose);
      final controller = container.read(inboxControllerProvider.notifier);

      // Reconcile coreId onto the existing local row, then run the sync/refresh.
      await controller.reconcileCoreId(localId, 555);
      await controller.refresh();
      await _awaitItems(container);

      final row = await db.itemsDao.getById(localId, '1');
      expect(row!.coreId, 555);
      expect(row.localPath, localPath); // STILL the local path — NOT wiped
    },
  );

  test('W3: moveToSpace on a local-only row (coreId null) does NOT call Core; '
      'the move holds locally', () async {
    const localId = 'rec_local_not-uploaded';
    await insertTestFileItem(
      db,
      id: localId,
      title: 'Local only',
      durationSeconds: 30,
      localPath: '/tmp/x.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      processingStatus: 'pending_upload',
    );

    // Pre-condition: the seeded row is genuinely local-only (coreId NULL).
    final seeded = await db.itemsDao.getById(localId, '1');
    expect(seeded!.coreId, isNull);

    final container = _container(db, recordings: const []);
    addTearDown(container.dispose);

    await container
        .read(inboxControllerProvider.notifier)
        .moveToSpace(localId, '9');

    // coreId NULL ⇒ moveToSpace must NOT reach Core. The only mocked endpoint is
    // GET /api/recordings (the refresh); there is NO PATCH mock, so if the guard
    // were wrong the PATCH would throw an unmocked-route error and fail the test.
    final row = await db.itemsDao.getById(localId, '1');
    expect(row!.workspaceId, '9'); // the local move still holds (durable)
    expect(row.coreId, isNull); // still local-only — nothing round-tripped
  });

  test('#1434 regression: a Core pull carrying a transcript lands it in the '
      'transcript column and does NOT clobber a locally-edited note', () async {
    // Write-authority contract: `transcript` is Core-produced (a pull
    // populates it); `notes` is user-produced (a pull must NEVER overwrite a
    // local edit). Pre-fix, Core `transcript` was aliased into the `notes`
    // column, so this pull WIPED the user's note with the transcript text.
    await insertTestFileItem(
      db,
      id: '12',
      title: 'User edited',
      durationSeconds: 30,
      localPath: '/tmp/a.m4a',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      notes: 'my hand-written note',
    );

    // Full-state Core pull: transcript present (Core-produced), notes null
    // (Core never owns notes for this row).
    final container = _container(
      db,
      recordings: [
        _remote(
          id: 12,
          title: 'User edited',
          transcript: 'the full transcript',
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();
    final row = await db.itemsDao.getById('12', '1');

    // Transcript landed in its OWN column…
    expect(row!.transcript, 'the full transcript');
    // …and the user's note survived the pull (not clobbered, not aliased).
    expect(row.notes, 'my hand-written note');
  });

  test('#1434 interleaved pull + local edit: a local note written between pulls '
      'survives the next Core pull that carries only a transcript', () async {
    // Steady state: a row already pulled once with a transcript.
    final container = _container(
      db,
      recordings: [
        _remote(id: 13, title: 'Interleaved', transcript: 'transcript v1'),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(inboxControllerProvider.notifier);

    await controller.refresh();
    var row = await db.itemsDao.getById('13', '1');
    expect(row!.transcript, 'transcript v1');
    expect(row.notes, isNull);

    // User edits the note locally (simulating the save-path write to `notes`).
    await db.itemsDao.updateItem(
      '13',
      '1',
      const ItemsCompanion(notes: Value('edited between pulls')),
    );

    // Another Core pull arrives carrying an updated transcript but, as always,
    // no authority over notes. The note must survive.
    final container2 = _container(
      db,
      recordings: [
        _remote(id: 13, title: 'Interleaved', transcript: 'transcript v2'),
      ],
    );
    addTearDown(container2.dispose);
    await container2.read(inboxControllerProvider.notifier).refresh();

    row = await db.itemsDao.getById('13', '1');
    expect(row!.transcript, 'transcript v2'); // Core-owned: pull updates it
    expect(row.notes, 'edited between pulls'); // user-owned: survives the pull
  });

  // #1469 (SECURITY, A01): refresh() must leave every Inbox row owner-scoped so
  // the #1461 Files view is populated for the current owner and never leaks.
  group('#1469 owner-scoping on refresh', () {
    test(
      'a Core-synced row carries Core owner_id and is owner-visible',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final container = _container(
          db,
          recordings: [_remote(id: 21, title: 'Owned')],
          ownerId: '1',
        );
        addTearDown(container.dispose);

        await container.read(inboxControllerProvider.notifier).refresh();
        await _awaitItems(container);

        final row = await db.itemsDao.getById('21', '1');
        expect(row!.ownerId, '1'); // from Core's owner_id, not "0"
        final files = await db.itemsDao.filesForOwner('1');
        expect(files.map((f) => f.id), contains('21'));
        expect(await db.itemsDao.filesForOwner('2'), isEmpty); // no leak
      },
    );

    test(
      'refresh preserves a canonical local-only row for its explicit owner',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await insertTestFileItem(
          db,
          id: 'rec_local_y',
          ownerId: '1',
          title: 'Local memo',
          durationSeconds: 30,
          localPath: '/tmp/y.m4a',
          createdAt: 1000,
        );
        expect(await db.itemsDao.filesForOwner('1'), hasLength(1));

        // Core list is empty, but refresh still runs the owner backfill pass.
        final container = _container(db, recordings: const [], ownerId: '1');
        addTearDown(container.dispose);
        await container.read(inboxControllerProvider.notifier).refresh();
        await _awaitItems(container);

        final row = await db.itemsDao.getById('rec_local_y', '1');
        expect(row!.ownerId, '1');
        expect((await db.itemsDao.filesForOwner('1')).map((f) => f.id), [
          'rec_local_y',
        ]);
      },
    );
  });
}
