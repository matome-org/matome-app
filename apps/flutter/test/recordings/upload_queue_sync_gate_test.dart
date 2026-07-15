// W4 #1498 — the sync data-egress GATE invariants (plan #102, spec R2.1).
//
// These invariants ARE the deliverable: the upload queue drains ONLY items
// whose EFFECTIVE space is a CLOUD space, routed through the ONE operation-keyed
// decision point `SyncPolicy.can(caller, Operation.spaceSync, space)`.
//
// The "upload sink" is COUNTED via the fake repository's `createCalls` /
// `uploadedIds` (NOT log scraping): a row that reaches `createRecording` /
// `uploadFile` has been egressed to Core. Held items never touch the sink.
//
// This file is in the dual-flag LFS lane (mise `flutter-design-system-check`),
// so it runs under BOTH `ff.localFirstSpaces=false` (gate compiled out → drain
// on pending_upload, the shipped reality) and `=true` (gate ON). It self-skips
// the wrong-flag groups so each invocation proves exactly its reality.

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/matome/matome_ids.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import '../support/fake_parent_sync.dart';
import '../support/item_fixtures.dart';

void main() {
  Future<RecordingResult> pollAwaiter({
    required Recording recording,
    required Future<Recording?> Function() poll,
    required Ref ref,
  }) async {
    final events = StreamController<RecordingStatusEvent>();
    final waiter = RecordingResultWaiter(
      recordingId: recording.id,
      statusEvents: events.stream,
      poll: poll,
      pollInterval: const Duration(milliseconds: 10),
    );
    final result = await waiter.wait();
    await events.close();
    return result;
  }

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('upload_gate_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  ProviderContainer containerFor(AppDatabase db, RecordingsRepository repo) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        testParentSyncOverride(),
        recordingsRepositoryProvider.overrideWithValue(repo),
        // The gate's [Caller] reads this; override it so the test never builds the
        // real auth chain (secure-storage platform channels). The id is the
        // future-PDP input — today's `spaceSync` decision gates only on the space
        // being cloud, so this value does not change any assertion here.
        currentOwnerIdProvider.overrideWithValue('owner-1'),
        uploadQueueProvider.overrideWith(
          (ref) => UploadQueue(ref, awaitResult: pollAwaiter),
        ),
      ],
    );
  }

  /// Insert a `pending_upload` row optionally filed directly into [workspaceId]
  /// or wrapped in matome [matomeId]. Returns the local id.
  Future<String> seedRow(
    AppDatabase db,
    Directory tmp, {
    String? workspaceId,
    String? matomeId,
    int? coreId,
  }) async {
    final localId = mintLocalRecordingId();
    final audio = File('${tmp.path}/$localId.m4a');
    await audio.writeAsBytes(List<int>.filled(16, 0));
    await insertTestFileItem(
      db,
      id: localId,
      ownerId: 'owner-1',
      coreId: coreId,
      title: 'Memo',
      durationSeconds: 34,
      localPath: audio.path,
      workspaceId: workspaceId,
      matomeId: matomeId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      mediaType: 'audio',
      processingStatus: kProcessingStatusPendingUpload,
    );
    return localId;
  }

  /// Insert a `workspaces` row with an explicit `is_local` bit.
  Future<String> seedSpace(
    AppDatabase db, {
    required bool isLocal,
    String? id,
  }) async {
    final spaceId = id ?? 'ws_${DateTime.now().microsecondsSinceEpoch}';
    await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            id: spaceId,
            name: 'space-$spaceId',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            isLocal: Value(isLocal ? 1 : 0),
          ),
        );
    return spaceId;
  }

  /// Insert a matome filed into [spaceId] (or draft when null). A [coreId] marks
  /// the matome as reconciled to Core — required for a child row to actually
  /// drain, since the two-phase create leg POSTs to /api/matomes/{coreId}/items.
  /// Returns its id.
  Future<String> seedMatome(
    AppDatabase db, {
    String? spaceId,
    int? coreId,
  }) async {
    final matomeId = mintLocalMatomeId();
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: matomeId,
            title: 'M',
            happenedAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            spaceId: Value(spaceId),
            coreId: Value(coreId),
          ),
        );
    return matomeId;
  }

  RecordingsRepository repo() => _CountingRepository(
    apiClient: ApiClient(
      tokenStore: InMemoryTokenStore(),
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
    ),
  );

  /// The DRAINED set, read from the counting sink's effect on the DB: a row
  /// that egressed reconciled a coreId (and flipped off pending_upload). A held
  /// row stays pending_upload with a null coreId. This is the counting sink —
  /// `createCalls` corroborates it (no log scraping).
  Future<Set<String>> drainedIds(AppDatabase db, Iterable<String> all) async {
    final out = <String>{};
    for (final id in all) {
      final row = await db.itemsDao.getById(id, 'owner-1');
      if (row != null && row.coreId != null) out.add(id);
    }
    return out;
  }

  // ===================================================================== //
  // FLAG ON — the gate is active (future-wave reality).                    //
  // ===================================================================== //
  group('flag ON — data-egress gate active', () {
    setUp(() {
      if (!FeatureFlags.localFirstSpaces) {
        // self-skip under the OFF build; the OFF group proves that reality.
        return;
      }
    });

    test(
      'W0 parent rule: an Inbox Matome drains; missing-parent and LOCAL-space '
      'items stay explicitly blocked',
      () async {
        if (!FeatureFlags.localFirstSpaces) return;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final r = repo() as _CountingRepository;
        final container = containerFor(db, r);
        addTearDown(container.dispose);

        final localSpace = await seedSpace(db, isLocal: true);
        final localMatome = await seedMatome(db, spaceId: localSpace);
        final draftMatome = await seedMatome(db, spaceId: null);

        // (a) loose item: no matome, no space → effective space NULL (Inbox).
        await seedRow(db, tmp);
        // (b) draft matome: matome with NULL space → effective space NULL.
        final draftChild = await seedRow(db, tmp, matomeId: draftMatome);
        // (c) filed directly into a LOCAL space → effective space local.
        await seedRow(db, tmp, workspaceId: localSpace);
        // (d) in a matome filed into a LOCAL space → effective space local.
        await seedRow(db, tmp, matomeId: localMatome);

        await container.read(uploadQueueProvider).drain();

        expect(
          r.createCalls,
          1,
          reason:
              'the Inbox Matome parent and its child reconcile in one drain',
        );
        expect(r.uploadedIds, hasLength(1));
        expect(
          (await db.itemsDao.getById(draftChild, 'owner-1'))!.processingStatus,
          'done',
        );
        // Missing-parent and LOCAL-space rows remain durably blocked.
        final pending = await db.itemsDao.listPendingUploads('owner-1');
        expect(pending.length, 3);
        for (final row in pending) {
          expect(row.coreId, isNull, reason: 'held rows never create on Core');
        }
      },
    );

    test(
      'drainable set is cloud-space plus Inbox-parent work, never LOCAL-space',
      () async {
        if (!FeatureFlags.localFirstSpaces) return;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final r = repo() as _CountingRepository;
        final container = containerFor(db, r);
        addTearDown(container.dispose);

        final cloudSpace = await seedSpace(db, isLocal: false);
        final localSpace = await seedSpace(db, isLocal: true);
        // Every drainable row rides a matome that has reconciled a coreId (the
        // two-phase create leg POSTs under the matome). The EFFECTIVE space — and
        // thus the gate decision — is the matome's space (matome wins).
        final cloudMatome = await seedMatome(
          db,
          spaceId: cloudSpace,
          coreId: 61,
        );
        final draftMatome = await seedMatome(db, spaceId: null, coreId: 62);
        final localMatome = await seedMatome(
          db,
          spaceId: localSpace,
          coreId: 63,
        );

        // CLOUD set (MUST all drain): both ride a cloud-space matome.
        final cloudFiled = await seedRow(db, tmp, matomeId: cloudMatome);
        final cloudViaMatome = await seedRow(db, tmp, matomeId: cloudMatome);
        final cloudIds = {cloudFiled, cloudViaMatome};

        // W0 also drains an Inbox parent (NULL space). LOCAL space stays held.
        final inboxParent = await seedRow(db, tmp, matomeId: draftMatome);
        final localFiled = await seedRow(db, tmp, matomeId: localMatome);
        final drainableIds = {...cloudIds, inboxParent};

        await container.read(uploadQueueProvider).drain();

        final drained = await drainedIds(db, {...drainableIds, localFiled});

        expect(r.createCalls, 3);

        for (final id in drainableIds) {
          expect(
            drained.contains(id),
            isTrue,
            reason: 'W0-drainable item $id MUST drain',
          );
        }
        expect(drained.contains(localFiled), isFalse);
        expect(
          drained,
          equals(drainableIds),
          reason: 'the drained set is exactly W0-drainable work',
        );
      },
    );

    test(
      'matome WINS: a row filed into a CLOUD space but wrapped in a matome '
      'in a LOCAL space is HELD (shadowed workspaceId never egresses)',
      () async {
        if (!FeatureFlags.localFirstSpaces) return;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final r = repo() as _CountingRepository;
        final container = containerFor(db, r);
        addTearDown(container.dispose);

        final cloudSpace = await seedSpace(db, isLocal: false);
        final localSpace = await seedSpace(db, isLocal: true);
        final localMatome = await seedMatome(db, spaceId: localSpace);

        // workspaceId = cloud, but matome's space = local → matome WINS → HELD.
        await seedRow(db, tmp, workspaceId: cloudSpace, matomeId: localMatome);

        await container.read(uploadQueueProvider).drain();

        expect(
          r.createCalls,
          0,
          reason: 'matome (local) WINS over the shadowed cloud workspaceId',
        );
      },
    );

    test('leak-close #74712: moveToSpace into a LOCAL space files locally but '
        'does NOT egress (no Core PATCH); into a CLOUD space it DOES', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final r = repo() as _CountingRepository;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          recordingsRepositoryProvider.overrideWithValue(r),
          currentOwnerIdProvider.overrideWithValue('owner-1'),
        ],
      );
      addTearDown(container.dispose);

      // Numeric ids so the LEGACY `int.tryParse(workspaceId)` gate would pass
      // for BOTH — proving the egress decision is the NEW resolver gate
      // (`is_local`), not the old numeric-id heuristic (the #74712 leak).
      final localSpace = await seedSpace(db, isLocal: true, id: '11');
      final cloudSpace = await seedSpace(db, isLocal: false, id: '22');

      // A reconciled row (coreId set) so the legacy numeric-id gate would PATCH.
      Future<String> seedReconciled() async {
        final id = mintLocalRecordingId();
        await insertTestFileItem(
          db,
          id: id,
          ownerId: 'owner-1',
          coreId: 900,
          title: 't',
          localPath: '/tmp/a',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        return id;
      }

      final inbox = container.read(inboxControllerProvider.notifier);

      // Filing into a LOCAL space: the local move holds, but NO Core PATCH.
      final toLocal = await seedReconciled();
      await inbox.moveToSpace(toLocal, localSpace);
      expect(
        r.updateCalls,
        0,
        reason: 'filing into a LOCAL space must NOT egress (#74712)',
      );
      final localRow = await db.itemsDao.getById(toLocal, 'owner-1');
      expect(
        localRow!.workspaceId,
        localSpace,
        reason: 'the local file-move still holds (filing ≠ sync)',
      );

      // Filing into a CLOUD space: the Core PATCH (egress) fires.
      final toCloud = await seedReconciled();
      await inbox.moveToSpace(toCloud, cloudSpace);
      expect(
        r.updateCalls,
        1,
        reason: 'filing into a CLOUD space DOES egress (synced path intact)',
      );
    });

    test('duplicate-coreId regression (d8cc85d): a duplicate coreId does not '
        'double-drain or crash', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final r = repo() as _CountingRepository;
      final container = containerFor(db, r);
      addTearDown(container.dispose);

      final cloudSpace = await seedSpace(db, isLocal: false);

      // Two rows in the SAME cloud space that share a coreId (the legacy
      // corruption d8cc85d pinned). Both are pending_upload + already carry a
      // coreId, so the queue resumes (never re-creates) — and must not crash on
      // the duplicate while resolving the gate.
      final a = await seedRow(db, tmp, workspaceId: cloudSpace, coreId: 7777);
      final b = await seedRow(db, tmp, workspaceId: cloudSpace, coreId: 7777);

      await container.read(uploadQueueProvider).drain();

      // Never re-created on Core (both already have a coreId → idempotent).
      expect(
        r.createCalls,
        0,
        reason: 'a row with a coreId is never recreated',
      );
      // Both rows resolved without throwing; the gate tolerated the duplicate.
      final rowA = await db.itemsDao.getById(a, 'owner-1');
      final rowB = await db.itemsDao.getById(b, 'owner-1');
      expect(rowA, isNotNull);
      expect(rowB, isNotNull);
    });
  });

  // ===================================================================== //
  // FLAG OFF — gate compiled out; drain-on-pending_upload (shipped).       //
  // ===================================================================== //
  group('flag OFF — W0 parent/local-space contract', () {
    test(
      'an Inbox parent drains but an explicit LOCAL-space parent stays blocked',
      () async {
        if (FeatureFlags.localFirstSpaces) return; // self-skip under ON build.
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final r = repo() as _CountingRepository;
        final container = containerFor(db, r);
        addTearDown(container.dispose);

        final localSpace = await seedSpace(db, isLocal: true);
        // Both rows ride a reconciled matome. W0 permits a parent with no space,
        // while an explicitly LOCAL space must remain on-device under every flag.
        final draftMatome = await seedMatome(db, spaceId: null, coreId: 55);
        final localMatome = await seedMatome(
          db,
          spaceId: localSpace,
          coreId: 56,
        );

        // An Inbox-parented row drains; a local-space row records why it cannot.
        final loose = await seedRow(db, tmp, matomeId: draftMatome);
        final localFiled = await seedRow(db, tmp, matomeId: localMatome);

        await container.read(uploadQueueProvider).drain();

        final drained = await drainedIds(db, {loose, localFiled});
        expect(drained, equals({loose}));
        expect(
          r.createCalls,
          1,
          reason: 'only the Inbox-parented item creates',
        );
        expect(
          (await db.itemsDao.getById(localFiled, 'owner-1'))!.processingStatus,
          kProcessingStatusBlockedLocalSpace,
        );
      },
    );
  });
}

/// A repository that COUNTS egress (createRecording / uploadFile) and records
/// which LOCAL ids reached the sink, so the gate invariants assert against a
/// real counting sink rather than logs. Always "Core up"; resolves `done`.
class _CountingRepository extends RecordingsRepository {
  _CountingRepository({required super.apiClient});

  int createCalls = 0;
  int _nextCoreId = 1000;

  /// PATCH /api/recordings/:id egress calls (the moveToSpace sync sink).
  int updateCalls = 0;

  /// Core ids that were PUT-uploaded (the egress sink).
  final Set<int> uploadedIds = <int>{};

  Recording _recording(int id, {required String status, String? summary}) {
    return Recording.fromJson(<String, dynamic>{
      'id': id,
      'owner_id': 1,
      'title': 'Memo',
      'status': status,
      'summary': ?summary,
    });
  }

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
    final id = _nextCoreId++;
    return RecordingCreateResult(
      recording: _recording(id, status: 'pending'),
      upload: UploadDescriptor(
        method: 'PUT',
        url: 'http://127.0.0.1:9/upload',
        storageKey: 'k$id',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    uploadedIds.add(int.parse(upload.storageKey.substring(1)));
  }

  @override
  Future<Recording> enqueueProcessing(int id) async =>
      _recording(id, status: 'processing');

  @override
  Future<Recording?> fetchRecording(int id) async =>
      _recording(id, status: 'done', summary: 'ok');

  @override
  Future<Recording> updateRecording(
    int id, {
    String? transcript,
    String? notes,
    String? summary,
    String? title,
    String? badge,
    int? workspaceId,
    int? matomeId,
    bool clearWorkspace = false,
  }) async {
    updateCalls++;
    return _recording(id, status: 'done');
  }
}
