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
import 'package:matome_flutter/features/items/matome_item_type.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

void main() {
  group('work queue persistence', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('file Item and initial deduped work commit atomically', () async {
      const now = 1000;
      await _insertMatome(db, id: 'matome', coreId: 41);

      await db.itemsDao.createFileItem(
        item: _item('item-a', 'file-a', 'matome', now),
        file: _file('file-a', '/tmp/a.wav', now),
        initialWork: fileUploadWork(
          itemId: 'item-a',
          sourceRevision: 1,
          now: now,
          configRevision: 7,
        ),
      );

      final work = await db.workQueueDao.getForItem(
        'item-a',
        kWorkKindFileUpload,
      );
      expect(work, isNotNull);
      expect(work!.dedupeKey, 'item-a:$kWorkKindFileUpload:1');
      expect(work.state, kWorkStateQueued);
      expect(work.stage, kWorkStageReconcileParent);
      expect(work.attempt, 0);
      expect(work.availableAt, now);
      expect(work.configRevision, 7);

      await expectLater(
        db.itemsDao.createFileItem(
          item: _item('item-b', 'file-b', 'matome', now),
          file: _file('file-b', '/tmp/b.wav', now),
          initialWork: fileUploadWork(
            itemId: 'item-b',
            sourceRevision: 1,
            now: now,
            dedupeKey: work.dedupeKey,
          ),
        ),
        throwsA(anything),
      );
      expect(await db.itemsDao.getById('item-b', 'owner-1'), isNull);
      expect(
        await (db.select(
          db.fileBlobs,
        )..where((row) => row.id.equals('file-b'))).getSingleOrNull(),
        isNull,
      );
    });

    test('a dependency and an unexpired lease prevent a claim', () async {
      await db.workQueueDao.enqueue(
        genericWork(
          id: 'parent',
          kind: 'parent_sync',
          itemId: 'parent-item',
          dedupeKey: 'parent',
          now: 1000,
        ),
      );
      await db.workQueueDao.enqueue(
        genericWork(
          id: 'child',
          kind: kWorkKindFileUpload,
          itemId: 'child-item',
          dedupeKey: 'child',
          dependsOn: 'parent',
          now: 1000,
        ),
      );

      final parent = await db.workQueueDao.claimNext(
        leaseOwner: 'worker-a',
        now: 1000,
        leaseDuration: const Duration(seconds: 10),
      );
      expect(parent?.id, 'parent');
      expect(
        await db.workQueueDao.claimNext(
          leaseOwner: 'worker-b',
          now: 9999,
          leaseDuration: const Duration(seconds: 10),
        ),
        isNull,
      );

      final recovered = await db.workQueueDao.claimNext(
        leaseOwner: 'worker-b',
        now: 11000,
        leaseDuration: const Duration(seconds: 10),
      );
      expect(recovered?.id, 'parent', reason: 'expired work is reclaimable');
      expect(
        await db.workQueueDao.complete(
          'parent',
          leaseOwner: 'worker-b',
          now: 11001,
        ),
        isTrue,
      );

      final child = await db.workQueueDao.claimNext(
        leaseOwner: 'worker-b',
        now: 11002,
        leaseDuration: const Duration(seconds: 10),
      );
      expect(child?.id, 'child');
    });
  });

  group('durable upload executor', () {
    late AppDatabase db;
    late Directory tmp;
    late _Clock clock;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('work_queue_test_');
      clock = _Clock(DateTime.fromMillisecondsSinceEpoch(1000));
    });

    tearDown(() async {
      await db.close();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    ProviderContainer containerFor(
      _WorkRepository repo, {
      int configRevision = 1,
      int maxAttempts = 5,
    }) {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentOwnerIdProvider.overrideWithValue('owner-1'),
          recordingsRepositoryProvider.overrideWithValue(repo),
          uploadQueueProvider.overrideWith(
            (ref) => UploadQueue(
              ref,
              clock: clock.call,
              jitter: () => 0.5,
              configRevision: () => configRevision,
              baseRetryDelay: const Duration(seconds: 1),
              maxRetryDelay: const Duration(seconds: 4),
              maxAttempts: maxAttempts,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    for (final stage in <String>[
      kWorkStageReconcileParent,
      kWorkStageCreateRemote,
      kWorkStageUpload,
      kWorkStageEnqueueProcessing,
    ]) {
      test('restart at $stage resumes and stops at Core acceptance', () async {
        final repo = _WorkRepository();
        final itemId = await _seedUpload(
          db,
          tmp,
          stage: stage,
          now: clock.now.millisecondsSinceEpoch,
        );
        final container = containerFor(repo);

        await container.read(uploadQueueProvider).drain();

        final work = await db.workQueueDao.getForItem(
          itemId,
          kWorkKindFileUpload,
        );
        final item = await db.itemsDao.getById(itemId, 'owner-1');
        expect(work?.state, kWorkStateSucceeded);
        expect(work?.stage, kWorkStageProcessingAccepted);
        expect(work?.progress, 1);
        expect(item?.processingStatus, 'processing');
        expect(item?.file?.uploadState, 'uploaded');
        expect(repo.fetchCalls, 0, reason: 'device work never polls AI');
        expect(repo.enqueueEffects, 1);
        expect(repo.uploadCalls, stage == kWorkStageEnqueueProcessing ? 0 : 1);
      });
    }

    test('restart after processing acceptance is a durable no-op', () async {
      final repo = _WorkRepository();
      final itemId = await _seedUpload(
        db,
        tmp,
        stage: kWorkStageProcessingAccepted,
        now: clock.now.millisecondsSinceEpoch,
      );
      await (db.update(
        db.workQueue,
      )..where((work) => work.itemId.equals(itemId))).write(
        const WorkQueueCompanion(
          state: Value(kWorkStateSucceeded),
          progress: Value(1),
        ),
      );
      final container = containerFor(repo);

      await container.read(uploadQueueProvider).drain();

      expect(repo.createCalls, 0);
      expect(repo.uploadCalls, 0);
      expect(repo.enqueueCalls, 0);
    });

    test(
      'duplicate triggers produce one Core create/upload/process effect',
      () async {
        final repo = _WorkRepository(delay: const Duration(milliseconds: 20));
        final itemId = await _seedUpload(
          db,
          tmp,
          now: clock.now.millisecondsSinceEpoch,
        );
        final first = containerFor(repo);
        final second = containerFor(repo);

        await Future.wait([
          first.read(uploadQueueProvider).drainRow(itemId),
          first.read(uploadQueueProvider).drain(),
          second.read(uploadQueueProvider).drain(),
        ]);

        expect(repo.createEffects, 1);
        expect(repo.uploadEffects, 1);
        expect(repo.enqueueEffects, 1);
        expect(
          (await db.workQueueDao.getForItem(
            itemId,
            kWorkKindFileUpload,
          ))?.state,
          kWorkStateSucceeded,
        );
      },
    );

    test(
      'accepted process replay remains exactly-once after lost response',
      () async {
        final repo = _WorkRepository()..loseFirstProcessResponse = true;
        final itemId = await _seedUpload(
          db,
          tmp,
          stage: kWorkStageEnqueueProcessing,
          now: clock.now.millisecondsSinceEpoch,
        );
        final first = containerFor(repo);

        await first.read(uploadQueueProvider).drain();
        expect(repo.enqueueCalls, 1);
        expect(repo.enqueueEffects, 1);

        clock.advance(const Duration(milliseconds: 500));
        final second = containerFor(repo);
        await second.read(uploadQueueProvider).drain();

        expect(
          repo.enqueueCalls,
          2,
          reason: 'restart safely replays the request',
        );
        expect(
          repo.enqueueEffects,
          1,
          reason: 'Core idempotency owns the effect',
        );
        expect(
          (await db.workQueueDao.getForItem(
            itemId,
            kWorkKindFileUpload,
          ))?.state,
          kWorkStateSucceeded,
        );
      },
    );

    test(
      'bounded exponential full jitter reaches the dead-letter boundary',
      () async {
        final repo = _WorkRepository()..createError = _unavailable;
        final itemId = await _seedUpload(
          db,
          tmp,
          now: clock.now.millisecondsSinceEpoch,
        );
        final container = containerFor(repo, maxAttempts: 3);
        final queue = container.read(uploadQueueProvider);

        await queue.drain();
        var work = await db.workQueueDao.getForItem(
          itemId,
          kWorkKindFileUpload,
        );
        expect(work?.attempt, 1);
        expect(work?.state, kWorkStateRetry);
        expect(work?.availableAt, 1500);

        clock.advance(const Duration(milliseconds: 500));
        await queue.drain();
        work = await db.workQueueDao.getForItem(itemId, kWorkKindFileUpload);
        expect(work?.attempt, 2);
        expect(work?.availableAt, 2500);

        clock.advance(const Duration(seconds: 1));
        await queue.drain();
        work = await db.workQueueDao.getForItem(itemId, kWorkKindFileUpload);
        expect(work?.attempt, 3);
        expect(work?.state, kWorkStateDead);
        expect(work?.errorCode, kWorkErrorServerUnavailable);
        expect(work?.leaseOwner, isNull);
      },
    );

    test(
      'a config revision change releases delayed work immediately',
      () async {
        final repo = _WorkRepository()..createError = _unavailable;
        final itemId = await _seedUpload(
          db,
          tmp,
          now: clock.now.millisecondsSinceEpoch,
          configRevision: 1,
        );
        final oldConfig = containerFor(repo, configRevision: 1);
        await oldConfig.read(uploadQueueProvider).drain();

        repo.createError = null;
        final newConfig = containerFor(repo, configRevision: 2);
        await newConfig.read(uploadQueueProvider).drain();

        final work = await db.workQueueDao.getForItem(
          itemId,
          kWorkKindFileUpload,
        );
        expect(work?.state, kWorkStateSucceeded);
        expect(work?.configRevision, 2);
        expect(work?.attempt, 0);
      },
    );

    test('local-space hold does not stall unrelated cloud work', () async {
      await db
          .into(db.workspaces)
          .insert(
            WorkspacesCompanion.insert(
              id: 'local-space',
              name: 'Local',
              createdAt: 1000,
              isLocal: const Value(1),
            ),
          );
      await db
          .into(db.workspaces)
          .insert(
            WorkspacesCompanion.insert(
              id: 'cloud-space',
              name: 'Cloud',
              createdAt: 1000,
              isLocal: const Value(0),
            ),
          );
      final held = await _seedUpload(
        db,
        tmp,
        itemId: 'a-held',
        matomeId: 'held-matome',
        spaceId: 'local-space',
        now: 1000,
      );
      final allowed = await _seedUpload(
        db,
        tmp,
        itemId: 'b-allowed',
        matomeId: 'allowed-matome',
        spaceId: 'cloud-space',
        now: 1000,
      );
      final repo = _WorkRepository();
      final container = containerFor(repo);

      await container.read(uploadQueueProvider).drain();

      final heldWork = await db.workQueueDao.getForItem(
        held,
        kWorkKindFileUpload,
      );
      final allowedWork = await db.workQueueDao.getForItem(
        allowed,
        kWorkKindFileUpload,
      );
      expect(heldWork?.state, kWorkStateBlocked);
      expect(heldWork?.blockedReason, kWorkBlockLocalSpace);
      expect(allowedWork?.state, kWorkStateSucceeded);
      expect(repo.createdClientIds, isNot(contains(held)));
      expect(repo.createdClientIds, contains(allowed));
    });
  });
}

const _unavailable = ApiException(
  'Core unavailable',
  statusCode: 503,
  code: 'service_unavailable',
);

ItemsCompanion _item(String id, String fileId, String matomeId, int now) {
  return ItemsCompanion.insert(
    id: id,
    ownerId: 'owner-1',
    clientId: id,
    matomeId: Value(matomeId),
    itemType: MatomeItemType.file.wireName,
    fileBlobId: Value(fileId),
    syncState: const Value(kProcessingStatusPendingUpload),
    createdAt: now,
    updatedAt: now,
  );
}

FileBlobsCompanion _file(String id, String path, int now) {
  return FileBlobsCompanion.insert(
    id: id,
    filename: const Value('memo.wav'),
    mediaType: 'audio',
    byteSize: const Value(4),
    localPath: Value(path),
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _insertMatome(
  AppDatabase db, {
  required String id,
  required int coreId,
  String? spaceId,
}) {
  return db
      .into(db.matomes)
      .insert(
        MatomesCompanion.insert(
          id: id,
          coreId: Value(coreId),
          spaceId: Value(spaceId),
          title: 'Memo',
          happenedAt: 1000,
          createdAt: 1000,
        ),
      );
}

Future<String> _seedUpload(
  AppDatabase db,
  Directory tmp, {
  String? itemId,
  String? matomeId,
  String? spaceId,
  String stage = kWorkStageReconcileParent,
  required int now,
  int configRevision = 1,
}) async {
  final id = itemId ?? 'item-$now-$stage';
  final parentId = matomeId ?? 'matome-$id';
  await _insertMatome(db, id: parentId, coreId: 41, spaceId: spaceId);
  final file = File('${tmp.path}/$id.wav');
  await file.writeAsBytes(const [1, 2, 3, 4]);
  final hasCoreItem =
      stage == kWorkStageUpload ||
      stage == kWorkStageEnqueueProcessing ||
      stage == kWorkStageProcessingAccepted;
  final item = _item(
    id,
    'file-$id',
    parentId,
    now,
  ).copyWith(coreId: hasCoreItem ? const Value(900) : const Value.absent());
  final blob = _file('file-$id', file.path, now).copyWith(
    uploadState:
        stage == kWorkStageEnqueueProcessing ||
            stage == kWorkStageProcessingAccepted
        ? const Value('uploaded')
        : const Value.absent(),
    uploadedAt:
        stage == kWorkStageEnqueueProcessing ||
            stage == kWorkStageProcessingAccepted
        ? Value(now)
        : const Value.absent(),
  );
  await db.itemsDao.createFileItem(
    item: item,
    file: blob,
    initialWork: fileUploadWork(
      itemId: id,
      sourceRevision: 1,
      now: now,
      configRevision: configRevision,
      stage: stage,
    ),
  );
  return id;
}

class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

class _WorkRepository extends RecordingsRepository {
  _WorkRepository({this.delay = Duration.zero})
    : super(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
        ),
      );

  final Duration delay;
  Object? createError;
  bool loseFirstProcessResponse = false;
  int createCalls = 0;
  int uploadCalls = 0;
  int enqueueCalls = 0;
  int fetchCalls = 0;
  final Set<String> createdClientIds = {};
  final Set<String> uploadedClientIds = {};
  final Set<int> processedIds = {};

  int get createEffects => createdClientIds.length;
  int get uploadEffects => uploadedClientIds.length;
  int get enqueueEffects => processedIds.length;

  Recording _recording(String status) => Recording.fromJson({
    'id': 900,
    'owner_id': 'owner-1',
    'title': 'Memo',
    'status': status,
  });

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
  }) async {
    createCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (createError case final error?) throw error;
    createdClientIds.add(clientId);
    return RecordingCreateResult(
      recording: _recording('pending'),
      upload: const UploadDescriptor(
        method: 'PUT',
        url: 'http://127.0.0.1:9/upload',
        storageKey: 'key',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    uploadCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    uploadedClientIds.add(file.path.split('/').last.replaceFirst('.wav', ''));
  }

  @override
  Future<Recording> enqueueProcessing(int id) async {
    enqueueCalls++;
    processedIds.add(id);
    if (loseFirstProcessResponse && enqueueCalls == 1) throw _unavailable;
    return _recording('processing');
  }

  @override
  Future<Recording?> fetchRecording(int id) async {
    fetchCalls++;
    throw StateError('device executor must not poll server-owned AI');
  }
}
