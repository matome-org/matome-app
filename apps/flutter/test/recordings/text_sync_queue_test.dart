import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/work_queue_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_sync.dart';
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'file-backed create, edit, and delete work survives each restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('text_sync_restart_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/items.sqlite');
      final repo = _TextRepository();

      var db = AppDatabase.forTesting(NativeDatabase(file));
      await _insertPendingText(db, id: 'text-local', body: 'offline body');
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      var container = _container(db, repo);
      await container.read(uploadQueueProvider).drain();
      var item = await db.itemsDao.getById('text-local', 'owner-1');
      expect(item?.coreId, 41);
      expect(item?.item.acceptedSourceRevision, 1);
      expect(repo.createdBodies, ['offline body']);
      container.dispose();
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      await db.itemsDao.editTextBody(
        itemId: 'text-local',
        ownerId: 'owner-1',
        body: 'edited offline',
        now: 20,
        configRevision: 0,
      );
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      container = _container(db, repo);
      await container.read(uploadQueueProvider).drain();
      item = await db.itemsDao.getById('text-local', 'owner-1');
      expect(item?.text?.body, 'edited offline');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(repo.updatedBodies, ['edited offline']);
      container.dispose();
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      await db.itemsDao.tombstoneText(
        itemId: 'text-local',
        ownerId: 'owner-1',
        now: 30,
        configRevision: 0,
      );
      expect((await db.itemsDao.listAll('owner-1')), isEmpty);
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      container = _container(db, repo);
      await container.read(uploadQueueProvider).drain();
      expect(await db.itemsDao.getById('text-local', 'owner-1'), isNull);
      expect(repo.deletedRevisions, [2]);
      container.dispose();
      await db.close();
    },
  );

  test('lost create response replays one permanent client identity', () async {
    final dir = await Directory.systemTemp.createTemp('text_lost_response_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/items.sqlite');
    final repo = _TextRepository(loseFirstCreateResponse: true);

    var db = AppDatabase.forTesting(NativeDatabase(file));
    await _insertPendingText(db, id: 'stable-client', body: 'once');
    var container = _container(db, repo);
    await container.read(uploadQueueProvider).drain();
    container.dispose();
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    container = _container(db, repo);
    await container.read(uploadQueueProvider).resumeNow();

    final item = await db.itemsDao.getById('stable-client', 'owner-1');
    expect(item?.coreId, 41);
    expect(item?.item.clientId, 'stable-client');
    expect(repo.createRequests, 2);
    expect(repo.serverCreates, 1);
    container.dispose();
    await db.close();
  });

  test(
    'lost create response plus later edit reconciles conflict then PATCHes snapshot',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'text_lost_response_edit_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/items.sqlite');
      final repo = _TextRepository(
        loseFirstCreateResponse: true,
        conflictOnCreateReplay: true,
      );

      var db = AppDatabase.forTesting(NativeDatabase(file));
      await _insertPendingText(
        db,
        id: 'lost-then-edit',
        body: 'submitted first',
      );
      var container = _container(db, repo);
      await container.read(uploadQueueProvider).drain();
      container.dispose();
      await db.close();

      db = AppDatabase.forTesting(NativeDatabase(file));
      await db.itemsDao.editTextBody(
        itemId: 'lost-then-edit',
        ownerId: 'owner-1',
        body: 'edited after loss',
        now: 2,
        configRevision: 0,
      );
      container = _container(db, repo);
      await container.read(uploadQueueProvider).resumeNow();

      final item = await db.itemsDao.getById('lost-then-edit', 'owner-1');
      expect(repo.createRequests, 2);
      expect(repo.serverCreates, 1);
      expect(repo.createdBodies, ['submitted first']);
      expect(repo.updatedBodies, ['edited after loss']);
      expect(repo.updateExpectedRevisions, [1]);
      expect(item?.text?.body, 'edited after loss');
      expect(item?.text?.acceptedBody, 'edited after loss');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(item?.item.syncState, 'synced');
      container.dispose();
      await db.close();
    },
  );

  test(
    'owner B drain cannot claim or mutate owner A queued text work',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'owner-a-work', body: 'owner A body');
      final repo = _TextRepository();
      final ownerB = _container(db, repo, ownerId: 'owner-2');

      await ownerB.read(uploadQueueProvider).drain();

      var work = await db.workQueueDao.getForItem(
        'owner-a-work',
        kWorkKindTextCreate,
      );
      expect(work?.state, kWorkStateQueued);
      expect(work?.attempt, 0);
      expect(work?.leaseOwner, isNull);
      expect(repo.createRequests, 0);
      ownerB.dispose();

      final ownerA = _container(db, repo);
      addTearDown(ownerA.dispose);
      await ownerA.read(uploadQueueProvider).drain();

      work = await db.workQueueDao.getForItem(
        'owner-a-work',
        kWorkKindTextCreate,
      );
      expect(work?.state, kWorkStateSucceeded);
      expect(repo.createRequests, 1);
      expect(
        (await db.itemsDao.getById('owner-a-work', 'owner-1'))?.item.syncState,
        'synced',
      );
    },
  );

  test(
    'owner B resumeNow leaves owner A delayed work unchanged; owner A makes it due',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'owner-a-delayed', body: 'owner A body');
      await (db.delete(
        db.workQueue,
      )..where((work) => work.itemId.equals('owner-a-delayed'))).go();
      await db.workQueueDao.enqueue(
        ownerId: 'owner-1',
        work: genericWork(
          id: 'owner-a-hold',
          kind: 'hold',
          itemId: 'owner-a-delayed',
          dedupeKey: 'owner-a-hold',
          now: 1,
        ),
      );
      final fileWork = fileUploadWork(
        itemId: 'owner-a-delayed',
        sourceRevision: 1,
        now: 1,
        dependsOn: 'owner-a-hold',
      );
      final textWorkRow = textWork(
        kind: kWorkKindTextUpdate,
        itemId: 'owner-a-delayed',
        submittedSourceRevision: 2,
        expectedSourceRevision: 1,
        operationBody: 'owner A body',
        now: 1,
        configRevision: 0,
        dependsOn: 'owner-a-hold',
      );
      await db.workQueueDao.enqueue(ownerId: 'owner-1', work: fileWork);
      await db.workQueueDao.enqueue(ownerId: 'owner-1', work: textWorkRow);
      await (db.update(
        db.workQueue,
      )..where((work) => work.id.equals(fileWork.id.value))).write(
        const WorkQueueCompanion(
          state: Value(kWorkStateRetry),
          availableAt: Value(9000),
          attempt: Value(2),
        ),
      );
      await (db.update(
        db.workQueue,
      )..where((work) => work.id.equals(textWorkRow.id.value))).write(
        const WorkQueueCompanion(
          state: Value(kWorkStateBlocked),
          availableAt: Value(10000),
          blockedReason: Value(kWorkBlockOffline),
        ),
      );
      final repo = _TextRepository();
      final ownerB = _container(db, repo, ownerId: 'owner-2');

      await ownerB.read(uploadQueueProvider).resumeNow();

      var file = await db.workQueueDao.getById(fileWork.id.value);
      var text = await db.workQueueDao.getById(textWorkRow.id.value);
      expect(file?.state, kWorkStateRetry);
      expect(file?.availableAt, 9000);
      expect(file?.attempt, 2);
      expect(text?.state, kWorkStateBlocked);
      expect(text?.availableAt, 10000);
      expect(text?.blockedReason, kWorkBlockOffline);
      ownerB.dispose();

      final ownerA = _container(db, repo);
      addTearDown(ownerA.dispose);
      final resumedAfter = DateTime.now().millisecondsSinceEpoch;
      await ownerA.read(uploadQueueProvider).resumeNow();

      file = await db.workQueueDao.getById(fileWork.id.value);
      text = await db.workQueueDao.getById(textWorkRow.id.value);
      expect(file?.state, kWorkStateQueued);
      expect(file!.availableAt, greaterThanOrEqualTo(resumedAfter));
      expect(
        file.availableAt,
        lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch),
      );
      expect(
        file.attempt,
        2,
        reason: 'manual resume preserves attempt history',
      );
      expect(text?.state, kWorkStateQueued);
      expect(text!.availableAt, greaterThanOrEqualTo(resumedAfter));
      expect(
        text.availableAt,
        lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch),
      );
      expect(text.blockedReason, kWorkBlockOffline);
      expect(
        repo.createRequests,
        0,
        reason: 'the hold dependency stays pending',
      );
    },
  );

  test(
    'client_id conflict reconciles identity then PATCHes latest body',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'client-conflict', body: 'local body');
      final repo = _TextRepository(clientConflictBody: 'remote body');
      final container = _container(db, repo);
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();

      final item = await db.itemsDao.getById('client-conflict', 'owner-1');
      expect(item?.coreId, 41);
      expect(item?.text?.body, 'local body');
      expect(item?.text?.acceptedBody, 'local body');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(item?.item.syncState, 'synced');
      expect(repo.updatedBodies, ['local body']);
      expect(repo.updateExpectedRevisions, [1]);
    },
  );

  test('unreconciled Matome is created before its text child', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: 'local-matome',
            title: 'Parent',
            happenedAt: 1,
            createdAt: 1,
          ),
        );
    await _insertPendingText(
      db,
      id: 'child',
      body: 'child body',
      matomeId: 'local-matome',
    );
    final calls = <String>[];
    final repo = _TextRepository(calls: calls);
    final parent = _ParentRepository(calls);
    final container = _container(db, repo, matomes: parent);
    addTearDown(container.dispose);

    await container.read(uploadQueueProvider).drain();

    expect(calls.take(2), ['parent', 'child']);
    expect((await db.matomesDao.getById('local-matome'))?.coreId, 7);
  });

  test(
    'lost parent response replays the same permanent Matome client id',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.matomes)
          .insert(
            MatomesCompanion.insert(
              id: 'stable-parent',
              title: 'Parent',
              happenedAt: 1,
              createdAt: 1,
            ),
          );
      await _insertPendingText(
        db,
        id: 'parent-child',
        body: 'child',
        matomeId: 'stable-parent',
      );
      final calls = <String>[];
      final parent = _ParentRepository(calls, loseFirstResponse: true);
      final container = _container(
        db,
        _TextRepository(calls: calls),
        matomes: parent,
      );
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();
      await container.read(uploadQueueProvider).resumeNow();

      expect(parent.clientIds, ['stable-parent', 'stable-parent']);
      expect(parent.serverCreates, 1);
      expect((await db.matomesDao.getById('stable-parent'))?.coreId, 7);
      expect(calls.last, 'child');
    },
  );

  test(
    'create response cannot clear an edit made while request was in flight',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'race', body: 'first body');
      late final _TextRepository repo;
      repo = _TextRepository(
        onCreate: () async {
          await db.itemsDao.editTextBody(
            itemId: 'race',
            ownerId: 'owner-1',
            body: 'newer body',
            now: 2,
            configRevision: 0,
          );
          final work = await db.workQueueDao.listAll();
          expect(work, hasLength(2));
          expect(work[0].state, kWorkStateRunning);
          expect(work[0].operationBody, 'first body');
          expect(work[0].submittedSourceRevision, 1);
          expect(work[1].state, kWorkStateQueued);
          expect(work[1].operationBody, 'newer body');
          expect(work[1].submittedSourceRevision, 2);
          expect(work[1].dependsOn, work[0].id);
        },
      );
      final container = _container(db, repo);
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();

      final item = await db.itemsDao.getById('race', 'owner-1');
      expect(item?.text?.body, 'newer body');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(item?.item.syncState, 'synced');
      expect(repo.createdBodies, ['first body']);
      expect(repo.updatedBodies, ['newer body']);
    },
  );

  test(
    'true update conflict preserves local body and becomes explicit',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'conflict', body: 'accepted');
      await db.itemsDao.updateItem(
        'conflict',
        'owner-1',
        const ItemsCompanion(
          coreId: Value(41),
          sourceRevision: Value(1),
          acceptedSourceRevision: Value(1),
          syncState: Value('synced'),
          isDirty: Value(false),
        ),
      );
      await db.itemsDao.updateText(
        'conflict',
        'owner-1',
        const TextContentsCompanion(isDirty: Value(false)),
      );
      await db.itemsDao.editTextBody(
        itemId: 'conflict',
        ownerId: 'owner-1',
        body: 'my local edit',
        now: 2,
        configRevision: 0,
      );
      final repo = _TextRepository(conflictingBody: 'their remote edit');
      final container = _container(db, repo);
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();

      final item = await db.itemsDao.getById('conflict', 'owner-1');
      expect(item?.text?.body, 'my local edit');
      expect(item?.item.syncState, 'conflict');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(item?.text?.acceptedBody, 'their remote edit');
    },
  );

  test(
    'dirty pull and tombstone reconciliation never resurrect local text',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'pull', body: 'local edit');
      await db.itemsDao.updateItem(
        'pull',
        'owner-1',
        const ItemsCompanion(
          coreId: Value(41),
          acceptedSourceRevision: Value(1),
          sourceRevision: Value(2),
        ),
      );
      final remote = _remote(body: 'remote edit', revision: 2);
      final companions = textToItemCompanions(
        remote,
        existing: await db.itemsDao.getById('pull', 'owner-1'),
      );
      await db.itemsDao.upsertTextItem(
        item: companions.item,
        text: companions.text,
      );
      var item = await db.itemsDao.getById('pull', 'owner-1');
      expect(item?.text?.body, 'local edit');
      expect(item?.item.syncState, 'conflict');

      await db.itemsDao.tombstoneText(
        itemId: 'pull',
        ownerId: 'owner-1',
        now: 3,
        configRevision: 0,
      );
      final repo = _TextRepository(fetchItems: [remote]);
      final container = _container(db, repo);
      addTearDown(container.dispose);
      await container.read(inboxControllerProvider.notifier).refresh();
      item = await db.itemsDao.getById('pull', 'owner-1');
      expect(item?.item.isDeleted, isTrue);
      expect(await db.itemsDao.listAll('owner-1'), isEmpty);
    },
  );

  test(
    'delete conflict restores visibility and explicit retry cleans contacts',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'delete-conflict', body: 'local body');
      final repo = _TextRepository(deleteConflictBody: 'remote newer body');
      final container = _container(db, repo);
      addTearDown(container.dispose);
      await container.read(uploadQueueProvider).drain();
      await db
          .into(db.itemContacts)
          .insert(
            ItemContactsCompanion.insert(
              id: 'edge-1',
              itemId: 'delete-conflict',
              contactId: 'contact-1',
            ),
          );

      await db.itemsDao.tombstoneText(
        itemId: 'delete-conflict',
        ownerId: 'owner-1',
        now: 10,
        configRevision: 0,
      );
      await container.read(uploadQueueProvider).drain();

      var item = await db.itemsDao.getById('delete-conflict', 'owner-1');
      expect(item?.item.isDeleted, isFalse);
      expect(item?.item.syncState, 'conflict');
      expect(item?.item.acceptedSourceRevision, 2);
      expect(item?.text?.acceptedBody, 'remote newer body');
      expect(await db.itemsDao.listAll('owner-1'), hasLength(1));

      await db.itemsDao.tombstoneText(
        itemId: 'delete-conflict',
        ownerId: 'owner-1',
        now: 11,
        configRevision: 0,
      );
      await container.read(uploadQueueProvider).drain();

      item = await db.itemsDao.getById('delete-conflict', 'owner-1');
      expect(item, isNull);
      expect(await db.select(db.itemContacts).get(), isEmpty);
      expect(repo.deletedRevisions, [1, 2]);
    },
  );

  test('complete pull removes only clean Core text absent remotely', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertPendingText(db, id: 'removed-remote', body: 'clean body');
    await db.itemsDao.updateItem(
      'removed-remote',
      'owner-1',
      const ItemsCompanion(
        coreId: Value(41),
        sourceRevision: Value(1),
        acceptedSourceRevision: Value(1),
        isDirty: Value(false),
        syncState: Value('synced'),
      ),
    );
    await db.itemsDao.updateText(
      'removed-remote',
      'owner-1',
      const TextContentsCompanion(
        coreId: Value(41),
        acceptedBody: Value('clean body'),
        isDirty: Value(false),
      ),
    );
    await (db.delete(
      db.workQueue,
    )..where((work) => work.itemId.equals('removed-remote'))).go();
    await _insertPendingText(db, id: 'still-local', body: 'pending body');
    final repo = _TextRepository(fetchItems: const []);
    final container = _container(db, repo);
    addTearDown(container.dispose);

    await container.read(inboxControllerProvider.notifier).refresh();

    expect(await db.itemsDao.getById('removed-remote', 'owner-1'), isNull);
    expect(await db.itemsDao.getById('still-local', 'owner-1'), isNotNull);
  });

  test(
    'permanent text sync failure does not masquerade as processing failure',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'rejected', body: 'local body');
      final repo = _TextRepository(permanentCreateFailure: true);
      final container = _container(db, repo);
      addTearDown(container.dispose);

      await container.read(uploadQueueProvider).drain();

      final item = await db.itemsDao.getById('rejected', 'owner-1');
      expect(item?.item.syncState, 'failed');
      expect(item?.processingState, ProcessingState.notRequested);
      expect(item?.text?.body, 'local body');
    },
  );

  test(
    'older source revision cannot restore invalidated machine output',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'guard', body: 'new body');
      await db.itemsDao.updateItem(
        'guard',
        'owner-1',
        const ItemsCompanion(
          sourceRevision: Value(2),
          processingOutputs: Value('{}'),
        ),
      );
      final current = await db.itemsDao.getById('guard', 'owner-1');
      final patch = itemProcessingUpdate(
        _remote(
          body: 'old body',
          revision: 1,
          processing: ItemProcessing(
            state: ProcessingState.succeeded,
            runId: 'old-run',
            attempt: 9,
            requestedOutputs: const {ProcessingOutputKind.summary},
            outputs: ProcessingOutputs.fromJson(const {
              'summary': {'type': 'summary', 'markdown': 'stale summary'},
            }),
          ),
        ),
        existing: current,
      );
      await db.itemsDao.updateItem('guard', 'owner-1', patch);

      final guarded = await db.itemsDao.getById('guard', 'owner-1');
      expect(guarded?.summary, isNull);
      expect(guarded?.item.processingRunId, isNull);
    },
  );

  test('clean pull ignores an older source revision', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _insertPendingText(db, id: 'clean', body: 'new accepted body');
    await db.itemsDao.updateItem(
      'clean',
      'owner-1',
      const ItemsCompanion(
        coreId: Value(41),
        sourceRevision: Value(3),
        acceptedSourceRevision: Value(3),
        isDirty: Value(false),
        syncState: Value('synced'),
      ),
    );
    await db.itemsDao.updateText(
      'clean',
      'owner-1',
      const TextContentsCompanion(isDirty: Value(false)),
    );
    final companions = textToItemCompanions(
      _remote(body: 'older body', revision: 2),
      existing: await db.itemsDao.getById('clean', 'owner-1'),
    );
    await db.itemsDao.upsertTextItem(
      item: companions.item,
      text: companions.text,
    );

    final item = await db.itemsDao.getById('clean', 'owner-1');
    expect(item?.text?.body, 'new accepted body');
    expect(item?.item.sourceRevision, 3);
    expect(item?.item.acceptedSourceRevision, 3);
  });

  test(
    'equal revision divergent dirty pull never attaches remote processing output',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertPendingText(db, id: 'equal-divergence', body: 'local body');
      await db.itemsDao.updateItem(
        'equal-divergence',
        'owner-1',
        const ItemsCompanion(
          coreId: Value(41),
          sourceRevision: Value(2),
          acceptedSourceRevision: Value(1),
          processingState: Value('not_requested'),
          processingOutputs: Value('{}'),
          isDirty: Value(true),
          syncState: Value('pending_sync'),
        ),
      );
      final existing = await db.itemsDao.getById('equal-divergence', 'owner-1');
      final remote = _remote(
        body: 'remote body',
        revision: 2,
        processing: ItemProcessing(
          state: ProcessingState.succeeded,
          runId: 'remote-run',
          attempt: 2,
          requestedOutputs: const {ProcessingOutputKind.summary},
          outputs: ProcessingOutputs.fromJson(const {
            'summary': {'type': 'summary', 'markdown': 'remote summary'},
          }),
        ),
      );
      final companions = textToItemCompanions(remote, existing: existing);
      await db.itemsDao.upsertTextItem(
        item: companions.item,
        text: companions.text,
      );

      final item = await db.itemsDao.getById('equal-divergence', 'owner-1');
      expect(item?.text?.body, 'local body');
      expect(item?.summary, isNull);
      expect(item?.processingState, ProcessingState.notRequested);
      expect(item?.item.processingRunId, isNull);
      expect(item?.item.syncState, 'conflict');
    },
  );
}

Future<void> _insertPendingText(
  AppDatabase db, {
  required String id,
  required String body,
  String? matomeId,
}) {
  return db.itemsDao.createTextItem(
    item: ItemsCompanion.insert(
      id: id,
      ownerId: 'owner-1',
      clientId: id,
      matomeId: Value(matomeId),
      itemType: MatomeItemType.text.wireName,
      title: Value(body),
      textContentId: Value('payload-$id'),
      syncState: const Value('local_saved'),
      createdAt: 1,
      updatedAt: 1,
    ),
    text: TextContentsCompanion.insert(
      id: 'payload-$id',
      body: body,
      createdAt: 1,
      updatedAt: 1,
    ),
    initialWork: textWork(
      kind: kWorkKindTextCreate,
      itemId: id,
      submittedSourceRevision: 1,
      expectedSourceRevision: 0,
      operationBody: body,
      now: 1,
      configRevision: 0,
    ),
  );
}

ProviderContainer _container(
  AppDatabase db,
  RecordingsRepository repo, {
  MatomesRepository? matomes,
  String ownerId = 'owner-1',
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentOwnerIdProvider.overrideWithValue(ownerId),
      recordingsRepositoryProvider.overrideWithValue(repo),
      if (matomes != null) matomesRepositoryProvider.overrideWithValue(matomes),
      uploadQueueProvider.overrideWith(
        (ref) => UploadQueue(
          ref,
          configRevision: () => 0,
          baseRetryDelay: Duration.zero,
          maxRetryDelay: Duration.zero,
        ),
      ),
    ],
  );
}

Recording _remote({
  String body = 'body',
  int revision = 1,
  ItemProcessing processing = const ItemProcessing.notRequested(),
}) {
  return Recording(
    id: 41,
    ownerId: 'owner-1',
    clientId: 'pull',
    itemType: 'text',
    sourceRevision: revision,
    textBody: body,
    title: body,
    processing: processing,
  );
}

class _TextRepository extends RecordingsRepository {
  _TextRepository({
    this.loseFirstCreateResponse = false,
    this.conflictingBody,
    this.fetchItems = const [],
    this.onCreate,
    this.calls,
    this.permanentCreateFailure = false,
    this.clientConflictBody,
    this.deleteConflictBody,
    this.conflictOnCreateReplay = false,
  }) : super(
         apiClient: ApiClient(
           tokenStore: InMemoryTokenStore(),
           dio: Dio(BaseOptions(baseUrl: 'http://localhost')),
         ),
       );

  final bool loseFirstCreateResponse;
  final String? conflictingBody;
  final List<Recording> fetchItems;
  final Future<void> Function()? onCreate;
  final List<String>? calls;
  final bool permanentCreateFailure;
  final String? clientConflictBody;
  final String? deleteConflictBody;
  final bool conflictOnCreateReplay;
  final List<String> createdBodies = [];
  final List<String> updatedBodies = [];
  final List<int> deletedRevisions = [];
  final List<int> updateExpectedRevisions = [];
  bool deleteConflictReturned = false;
  int createRequests = 0;
  int serverCreates = 0;
  int revision = 1;

  Recording item(String clientId, String body, {ItemProcessing? processing}) {
    return Recording(
      id: 41,
      ownerId: 'owner-1',
      clientId: clientId,
      itemType: 'text',
      sourceRevision: revision,
      textBody: body,
      title: body,
      processing: processing ?? const ItemProcessing.notRequested(),
    );
  }

  @override
  Future<List<Recording>> fetchRecordings() async => fetchItems;

  @override
  Future<Recording> createTextItem({
    required String clientId,
    required String body,
    int? matomeId,
    int? workspaceId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    calls?.add('child');
    if (permanentCreateFailure) {
      throw const ApiException(
        'rejected',
        statusCode: 422,
        code: 'invalid_body',
      );
    }
    if (clientConflictBody case final conflict?) {
      throw TextClientIdConflict(item(clientId, conflict));
    }
    createRequests++;
    if (serverCreates == 0) {
      serverCreates++;
      createdBodies.add(body);
    }
    await onCreate?.call();
    if (loseFirstCreateResponse && createRequests == 1) {
      throw const ApiException('lost response', statusCode: 503);
    }
    if (conflictOnCreateReplay && createRequests > 1) {
      throw TextClientIdConflict(item(clientId, createdBodies.single));
    }
    return item(clientId, body);
  }

  @override
  Future<Recording> updateTextItem(
    int id, {
    required String body,
    required int expectedSourceRevision,
  }) async {
    if (conflictingBody case final conflict?) {
      revision = expectedSourceRevision + 1;
      throw TextVersionConflict(item('conflict', conflict));
    }
    updateExpectedRevisions.add(expectedSourceRevision);
    expect(expectedSourceRevision, revision);
    revision++;
    updatedBodies.add(body);
    return item('text-local', body);
  }

  @override
  Future<void> deleteTextItem(
    int id, {
    required int expectedSourceRevision,
  }) async {
    deletedRevisions.add(expectedSourceRevision);
    final conflict = deleteConflictBody;
    if (!deleteConflictReturned && conflict != null) {
      deleteConflictReturned = true;
      revision = expectedSourceRevision + 1;
      throw TextVersionConflict(item('text-local', conflict));
    }
  }

  @override
  Future<Recording> enqueueProcessing(int id) async {
    return item(
      'text-local',
      updatedBodies.isEmpty ? createdBodies.last : updatedBodies.last,
      processing: ItemProcessing(
        state: ProcessingState.queued,
        runId: 'run-$revision',
        attempt: revision,
        requestedOutputs: const {ProcessingOutputKind.summary},
        outputs: const ProcessingOutputs.empty(),
      ),
    );
  }
}

class _ParentRepository extends MatomesRepository {
  _ParentRepository(this.calls, {this.loseFirstResponse = false})
    : super(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost')),
        ),
      );

  final List<String> calls;
  final bool loseFirstResponse;
  final List<String> clientIds = [];
  int requests = 0;
  int serverCreates = 0;

  @override
  Future<Matome> createMatome({
    required String clientId,
    required String title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    calls.add('parent');
    clientIds.add(clientId);
    requests++;
    if (serverCreates == 0) serverCreates++;
    if (loseFirstResponse && requests == 1) {
      throw const ApiException('lost parent response', statusCode: 503);
    }
    return Matome(
      id: 7,
      ownerId: 'owner-1',
      title: title,
      happenedAt: happenedAt,
    );
  }
}
