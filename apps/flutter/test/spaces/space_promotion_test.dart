// W4 #1499 — local→cloud PROMOTION invariants (plan #102, spec §3). This is the
// DATA-EGRESS path: promoting a local space is the moment its items LEAVE THE
// DEVICE, so idempotency + partial-failure correctness ARE the deliverable.
//
// These tests pin, against COUNTING SINKS (not log scraping):
//   * EXACTLY-ONCE        — N items ⇒ each created on Core exactly once.
//   * RETRY/CRASH IDEMPOTENCY — interrupt mid-batch, re-run ⇒ no duplicate;
//                           resumes from where it stopped (coreId-keyed).
//   * PARTIAL-FAILURE     — some items fail ⇒ space lands `failed`/resumable
//                           (NOT cloud); succeeded items NOT re-sent on resume.
//   * OWNER-SCOPE AUTHZ   — a non-owner caller cannot promote/assign (Core write
//                           never attempted).
//   * CONSENT counts      — itemized count via the resolver (matome WINS).
//   * FLAG-OFF            — promotion is behind `localFirstSpaces`.
//
// The "Core create sink" is the fake repositories' `createCalls` — an item that
// reached createRecording / createMatome has egressed. Idempotency means a
// resume does NOT increment it for an already-pushed item.
//
// In the dual-flag LFS lane (mise `flutter-design-system-check`): runs under
// BOTH ff.localFirstSpaces=false and =true; flag-state groups self-skip the
// wrong build so each invocation proves exactly its reality.

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
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matome_ids.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/features/spaces/space_promotion.dart';
import 'package:matome_flutter/features/spaces/spaces_repository.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('promotion_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

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
      pollInterval: const Duration(milliseconds: 5),
    );
    final result = await waiter.wait();
    await events.close();
    return result;
  }

  ApiClient apiClient() => ApiClient(
    tokenStore: InMemoryTokenStore(),
    dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
  );

  ProviderContainer containerFor(
    AppDatabase db, {
    required RecordingsRepository recordings,
    required MatomesRepository matomes,
    required SpacesRepository spaces,
    String? ownerId = 'owner-1',
  }) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        recordingsRepositoryProvider.overrideWithValue(recordings),
        matomesRepositoryProvider.overrideWithValue(matomes),
        spacesRepositoryProvider.overrideWithValue(spaces),
        currentOwnerIdProvider.overrideWithValue(ownerId),
        uploadQueueProvider.overrideWith(
          (ref) => UploadQueue(ref, awaitResult: pollAwaiter),
        ),
      ],
    );
  }

  /// Insert a LOCAL space (`ws_<...>` id, is_local = 1). Returns its id.
  Future<String> seedLocalSpace(AppDatabase db, {String? ownerId}) async {
    final id =
        'ws_${DateTime.now().microsecondsSinceEpoch}_'
        '${db.hashCode ^ DateTime.now().microsecond}';
    await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            id: id,
            name: 'Local Space $id',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            isLocal: const Value(1),
            ownerId: Value(ownerId),
          ),
        );
    return id;
  }

  /// Insert a `pending_upload` recording filed directly into [workspaceId]
  /// (no matome) or wrapped in [matomeId]. Returns its local id.
  Future<String> seedRecording(
    AppDatabase db,
    Directory tmp, {
    String? workspaceId,
    String? matomeId,
    int? coreId,
  }) async {
    final localId = mintLocalRecordingId();
    final audio = File('${tmp.path}/$localId.m4a');
    await audio.writeAsBytes(List<int>.filled(16, 0));
    await db.recordingsDao.upsertRecording(
      RecordingsCompanion(
        id: Value(localId),
        coreId: Value(coreId),
        title: const Value('Memo'),
        timestamp: const Value('1:00 PM'),
        duration: const Value('34s'),
        isProcessing: const Value(1),
        audioFilePath: Value(audio.path),
        workspaceId: Value(workspaceId),
        matomeId: Value(matomeId),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        mediaType: const Value('audio'),
        processingStatus: const Value(kProcessingStatusPendingUpload),
      ),
    );
    return localId;
  }

  /// Insert a matome filed into [spaceId]. Returns its id.
  Future<String> seedMatome(AppDatabase db, {required String spaceId}) async {
    final id = mintLocalMatomeId();
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: id,
            title: 'M',
            happenedAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            spaceId: Value(spaceId),
          ),
        );
    return id;
  }

  // ===================================================================== //
  // FLAG ON — promotion behaviour (future-wave reality).                   //
  // ===================================================================== //
  group('flag ON — local→cloud promotion', () {
    test('W2 boundary: promotion reconciles Matome parents but reports loose '
        'items without parents as resumably failed', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final recordings = _CountingRecordingsRepo(apiClient: apiClient());
      final matomesRepo = _CountingMatomesRepo(apiClient: apiClient());
      final spacesRepo = _CountingSpacesRepo(apiClient: apiClient());
      final container = containerFor(
        db,
        recordings: recordings,
        matomes: matomesRepo,
        spaces: spacesRepo,
      );
      addTearDown(container.dispose);

      final space = await seedLocalSpace(db, ownerId: null);
      // 3 directly-filed recordings + 2 matomes filed into the space.
      await seedRecording(db, tmp, workspaceId: space);
      await seedRecording(db, tmp, workspaceId: space);
      await seedRecording(db, tmp, workspaceId: space);
      await seedMatome(db, spaceId: space);
      await seedMatome(db, spaceId: space);

      final svc = container.read(spacePromotionServiceProvider);
      final state = await svc.promote(space);

      expect(state, isA<PromotionFailed>());
      expect((state as PromotionFailed).remaining, 3);
      // W1 does not synthesize parents for loose items; W2 owns that schema and
      // work_queue cutover. The two real Matome parents still reconcile once.
      expect(recordings.createCalls, 0);
      expect(matomesRepo.createCalls, 2, reason: '2 matomes create once each');
      expect(spacesRepo.createCalls, 1, reason: 'ONE Core space created');

      // The space is now CLOUD: re-keyed to the numeric Core id, is_local = 0.
      final old = await db.workspacesDao.getWorkspaceById(space);
      expect(old, isNull, reason: 'the ws_<...> local row was re-keyed away');
      final cloud = await db.workspacesDao.getWorkspaceById(
        spacesRepo.lastId.toString(),
      );
      expect(cloud, isNotNull);
      expect(cloud!.isLocal, 0, reason: 'promoted space is cloud');
    });

    test('EXACTLY-ONCE (matome + child): a matome with a pending child '
        'recording promotes — matome creates once, child uploads once, lands '
        '`cloud`', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final recordings = _CountingRecordingsRepo(apiClient: apiClient());
      final matomesRepo = _CountingMatomesRepo(apiClient: apiClient());
      final spacesRepo = _CountingSpacesRepo(apiClient: apiClient());
      final container = containerFor(
        db,
        recordings: recordings,
        matomes: matomesRepo,
        spaces: spacesRepo,
      );
      addTearDown(container.dispose);

      final space = await seedLocalSpace(db);
      final matome = await seedMatome(db, spaceId: space);
      // A pending-upload child of the matome (no coreId yet): it egresses via
      // the upload queue once the space is cloud (matome WINS resolves it to the
      // now-cloud space).
      final child = await seedRecording(
        db,
        tmp,
        matomeId: matome,
        workspaceId: space,
      );

      final svc = container.read(spacePromotionServiceProvider);
      final state = await svc.promote(space);

      expect(state, isA<PromotionCloud>());
      expect(matomesRepo.createCalls, 1, reason: 'matome created exactly once');
      expect(recordings.createCalls, 1, reason: 'child uploaded exactly once');
      expect(spacesRepo.createCalls, 1);
      final childRow = await db.recordingsDao.getRecordingById(child);
      expect(childRow!.coreId, isNotNull, reason: 'child acked a Core id');
    });

    test('RETRY/CRASH IDEMPOTENCY: re-running promotion after a clean success '
        'creates NOTHING new (coreId-keyed no-op)', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final recordings = _CountingRecordingsRepo(apiClient: apiClient());
      final matomesRepo = _CountingMatomesRepo(apiClient: apiClient());
      final spacesRepo = _CountingSpacesRepo(apiClient: apiClient());
      final container = containerFor(
        db,
        recordings: recordings,
        matomes: matomesRepo,
        spaces: spacesRepo,
      );
      addTearDown(container.dispose);

      final space = await seedLocalSpace(db);
      final matome = await seedMatome(db, spaceId: space);
      await seedRecording(db, tmp, matomeId: matome, workspaceId: space);

      final svc = container.read(spacePromotionServiceProvider);
      final first = await svc.promote(space);
      expect(first, isA<PromotionCloud>());
      expect(recordings.createCalls, 1);
      expect(matomesRepo.createCalls, 1);
      expect(spacesRepo.createCalls, 1);

      // Resume by id (the space is now cloud; its local id is the numeric Core
      // id). A double-tap / crash-retry MUST NOT duplicate anything.
      final cloudId = spacesRepo.lastId.toString();
      final second = await svc.promote(cloudId);
      expect(second, isA<PromotionCloud>());
      expect(recordings.createCalls, 1, reason: 'no recording re-created');
      expect(matomesRepo.createCalls, 1, reason: 'no matome re-created');
      expect(
        spacesRepo.createCalls,
        1,
        reason: 'no SECOND Core space (re-key made create idempotent)',
      );
    });

    test('PARTIAL-FAILURE: one item fails ⇒ space lands `failed`/resumable '
        '(NOT cloud); resume completes the remainder without re-sending the '
        'succeeded items', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      // The recordings repo fails the FIRST upload attempt for one storage key,
      // then succeeds on resume — simulating a transient mid-batch failure.
      final recordings = _FlakyRecordingsRepo(apiClient: apiClient());
      final matomesRepo = _CountingMatomesRepo(apiClient: apiClient());
      final spacesRepo = _CountingSpacesRepo(apiClient: apiClient());
      final container = containerFor(
        db,
        recordings: recordings,
        matomes: matomesRepo,
        spaces: spacesRepo,
      );
      addTearDown(container.dispose);

      final space = await seedLocalSpace(db);
      final goodMatome = await seedMatome(db, spaceId: space);
      final flakyMatome = await seedMatome(db, spaceId: space);
      final good = await seedRecording(
        db,
        tmp,
        matomeId: goodMatome,
        workspaceId: space,
      );
      final flaky = await seedRecording(
        db,
        tmp,
        matomeId: flakyMatome,
        workspaceId: space,
      );
      recordings.failCreateForTitleOnce = true; // first create throws once.

      final svc = container.read(spacePromotionServiceProvider);
      final state = await svc.promote(space);

      // One item failed to reach Core ⇒ NOT cloud, resumable.
      expect(
        state,
        isA<PromotionFailed>(),
        reason: 'a half-cloud space MUST NOT look done',
      );
      expect((state as PromotionFailed).remaining, 1);

      // The space WAS re-keyed (its succeeded item kept its Core row — no
      // rollback, spec R3.5) but is reported failed, not cloud.
      final cloudId = spacesRepo.lastId.toString();
      final goodRow = await db.recordingsDao.getRecordingById(good);
      final flakyRow = await db.recordingsDao.getRecordingById(flaky);
      final acked = [goodRow, flakyRow].where((r) => r!.coreId != null).length;
      expect(acked, 1, reason: 'exactly one item acked before the failure');
      final createsAfterFirstPass = recordings.createCalls;

      // RESUME: re-run. The succeeded item is a coreId-keyed no-op; only the
      // remainder completes. No duplicate create for the already-acked item.
      recordings.failCreateForTitleOnce = false;
      final resumed = await svc.promote(cloudId);
      expect(
        resumed,
        isA<PromotionCloud>(),
        reason: 'resume finishes the rest',
      );
      expect(
        recordings.createCalls,
        createsAfterFirstPass + 1,
        reason:
            'resume creates ONLY the previously-failed item (no re-send '
            'of the succeeded one)',
      );
    });

    test(
      'OWNER-SCOPE AUTHZ: a non-owner caller cannot promote — Core create is '
      'never attempted (spec R3.6)',
      () async {
        if (!FeatureFlags.localFirstSpaces) return;
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final recordings = _CountingRecordingsRepo(apiClient: apiClient());
        final matomesRepo = _CountingMatomesRepo(apiClient: apiClient());
        final spacesRepo = _CountingSpacesRepo(apiClient: apiClient());
        // Space is OWNED by 'owner-1' but the acting caller is 'intruder'.
        final container = containerFor(
          db,
          recordings: recordings,
          matomes: matomesRepo,
          spaces: spacesRepo,
          ownerId: 'intruder',
        );
        addTearDown(container.dispose);

        final space = await seedLocalSpace(db, ownerId: 'owner-1');
        await seedRecording(db, tmp, workspaceId: space);

        final svc = container.read(spacePromotionServiceProvider);
        await expectLater(
          svc.promote(space),
          throwsA(isA<PromotionNotAuthorized>()),
        );

        // No Core write of any kind — the gate refused before egress.
        expect(spacesRepo.createCalls, 0, reason: 'no Core space create');
        expect(recordings.createCalls, 0, reason: 'no item egress');
        // The space stays LOCAL (no state change on denial).
        final row = await db.workspacesDao.getWorkspaceById(space);
        expect(row!.isLocal, 1, reason: 'denied promotion leaves space local');
      },
    );

    test('CONSENT counts (matome WINS): itemized count is the items whose '
        'effective space is this space with no Core row — children counted '
        'under their matome, not double-counted', () async {
      if (!FeatureFlags.localFirstSpaces) return;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = containerFor(
        db,
        recordings: _CountingRecordingsRepo(apiClient: apiClient()),
        matomes: _CountingMatomesRepo(apiClient: apiClient()),
        spaces: _CountingSpacesRepo(apiClient: apiClient()),
      );
      addTearDown(container.dispose);

      final space = await seedLocalSpace(db);
      final matome = await seedMatome(db, spaceId: space);
      // 2 children of the matome (counted under the matome's recordingCount).
      await seedRecording(db, tmp, matomeId: matome, workspaceId: space);
      await seedRecording(db, tmp, matomeId: matome);
      // 1 loose recording filed DIRECTLY into the space (no matome).
      await seedRecording(db, tmp, workspaceId: space);
      // 1 already-synced recording (has coreId) — NOT counted (already on Core).
      await seedRecording(db, tmp, workspaceId: space, coreId: 5050);

      final svc = container.read(spacePromotionServiceProvider);
      final consent = await svc.consentFor(space);

      expect(consent.matomeCount, 1, reason: 'one un-synced matome');
      expect(
        consent.recordingCount,
        3,
        reason:
            '2 matome children + 1 loose; the already-synced one excluded; '
            'the matome child filed into the space is NOT double-counted',
      );
      expect(consent.totalCount, 4);
    });
  });

  // ===================================================================== //
  // FLAG OFF — promotion gated by the flag (shipped reality).              //
  // ===================================================================== //
  group('flag OFF — promotion behind the flag', () {
    test('the localFirstSpaces flag is OFF in this build', () async {
      if (FeatureFlags.localFirstSpaces) return; // self-skip under ON build.
      expect(
        FeatureFlags.localFirstSpaces,
        isFalse,
        reason: 'promotion (data-egress) ships dark behind the single flag',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Counting fakes — the egress sinks.
// ---------------------------------------------------------------------------

/// Counts `POST /api/spaces` creates; returns sequential numeric Core ids.
class _CountingSpacesRepo extends SpacesRepository {
  _CountingSpacesRepo({required super.apiClient});

  int createCalls = 0;
  int lastId = 0;

  @override
  Future<CoreSpace> createSpace({
    required String name,
    String? description,
  }) async {
    createCalls++;
    lastId = 7000 + createCalls;
    return CoreSpace(id: lastId, name: name, ownerId: 'owner-1');
  }
}

/// Counts `POST /api/matomes` creates; returns sequential numeric ids. Other
/// surfaces (contacts/children/patch) are no-ops so the matome push completes.
class _CountingMatomesRepo extends MatomesRepository {
  _CountingMatomesRepo({required super.apiClient});

  int createCalls = 0;
  int _next = 8000;

  Matome _matome(int id, {required String title, int? workspaceId}) => Matome(
    id: id,
    ownerId: 'owner-1',
    title: title,
    workspaceId: workspaceId,
  );

  @override
  Future<Matome> createMatome({
    required String title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    createCalls++;
    return _matome(_next++, title: title, workspaceId: workspaceId);
  }

  @override
  Future<Matome> updateMatome(
    int id, {
    String? title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async => _matome(id, title: title ?? 'M');

  @override
  Future<Matome> archiveMatome(int id) async => _matome(id, title: 'M');

  @override
  Future<void> attachContact({
    required int matomeId,
    required int contactId,
    String role = 'attendee',
  }) async {}
}

/// Counts idempotent item creates and PUT uploads; resolves `done`.
class _CountingRecordingsRepo extends RecordingsRepository {
  _CountingRecordingsRepo({required super.apiClient});

  int createCalls = 0;
  int _nextCoreId = 9000;
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
  }) async => _recording(id, status: 'done');
}

/// Like [_CountingRecordingsRepo] but throws on the FIRST create while
/// [failCreateForTitleOnce] is set — simulating a transient mid-batch failure.
/// Once cleared (resume), creates succeed normally. The ALREADY-acked item is
/// never re-created (the queue is coreId-keyed), so resume only creates the
/// previously-failed one.
class _FlakyRecordingsRepo extends _CountingRecordingsRepo {
  _FlakyRecordingsRepo({required super.apiClient});

  bool failCreateForTitleOnce = false;
  bool _failedOnce = false;

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
    if (failCreateForTitleOnce && !_failedOnce) {
      _failedOnce = true;
      throw const ApiException(
        'transient',
        statusCode: 503,
        code: 'upload_failed',
      );
    }
    return super.createItemRecording(
      title: title,
      matomeId: matomeId,
      clientId: clientId,
      durationSeconds: durationSeconds,
      badge: badge,
      mediaType: mediaType,
      workspaceId: workspaceId,
      contentLength: contentLength,
    );
  }
}
