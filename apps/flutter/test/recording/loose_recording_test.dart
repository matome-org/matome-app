import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import 'audio_recording_service_test.dart' show FakeRecorderBackend;

/// Local-first-spaces #102 W2 — AUDIO RECORDINGS land LOOSE behind the flag.
///
/// This is the highest-blast-radius capture surface: the recorder FINISH path.
/// It is a DIFFERENT caller than the file/photo import path covered by
/// `test/home/loose_import_test.dart` (#1495) — but BOTH ultimately persist via
/// the SAME gated step, `InboxController.insertLocalUpload`, so this file proves
/// the recorder caller end-to-end (`RecordingFinisher.finish`, the real S3
/// Finish orchestrator) lands loose on ON and mints as today on OFF.
///
/// #43 COUPLING (no id regression): in the local-first-recordings plan (#43 W2)
/// the recorder finish path no longer uses the Core id as the PK. It mints a
/// LOCAL `rec_local_<uuid>` PK up front (see `mintLocalRecordingId` /
/// `InboxUploader.upload`) and reconciles the Core id into the SEPARATE `coreId`
/// column once the upload lands. The loose insert (`insertLooseRecording`) keeps
/// that same `rec_local_<uuid>` PK + NULL coreId and only NULLs `matomeId` /
/// `workspaceId`, so the PK==Core-id concern is moot: there is no Core id at the
/// PK to conflict with, and `coreId` reconciliation is untouched. The ON lane
/// below asserts the PK is a local id and the OFF lane that coreId reconciles to
/// the Core id on the SAME local-PK row — proving no id regression either way.
///
/// `FeatureFlags.localFirstSpaces` is a compile-time `const bool.fromEnvironment`,
/// so this file is run TWICE by the `flutter-design-system-check` gate — once
/// forced OFF and once forced ON via `--dart-define=ff.localFirstSpaces=…`.
/// Each lane group self-skips under the wrong build so each invocation proves
/// exactly its reality.
const _flagOn = bool.fromEnvironment(
  'ff.localFirstSpaces',
  defaultValue: false,
);

/// A no-op terminal-result awaiter that drives the real queue pipeline via the
/// poll fallback (no live Phoenix socket).
Future<RecordingResult> _pollFallbackAwaiter({
  required Recording recording,
  required Future<Recording?> Function() poll,
  required Ref ref,
}) async {
  final events = StreamController<RecordingStatusEvent>();
  final waiter = RecordingResultWaiter(
    recordingId: recording.id,
    statusEvents: events.stream,
    poll: poll,
    pollInterval: const Duration(milliseconds: 20),
  );
  final result = await waiter.wait();
  await events.close();
  return result;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('loose_recording_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService svc(AppDatabase db) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: FakeRecorderBackend(),
      documentsDirProvider: () async => tmp,
      durationProbe: (p) async => File(p).lengthSync(),
      captureSupportedProbe: () async => true,
    );
  }

  /// Drives a real recorder session start→pause→resume→finish so the finish
  /// path under test is the production [RecordingFinisher.finish].
  Future<String> finishASession(ProviderContainer container,
      {String title = 'Memo'}) async {
    final controller = container.read(recordingControllerProvider.notifier);
    await controller.start();
    await controller.pause();
    await controller.resume();
    return container.read(recordingFinisherProvider).finish(title: title);
  }

  group('lane: ff.localFirstSpaces=true (ON / loose recording)', () {
    test(
      'a finished recording lands LOOSE — matome NULL + workspace NULL → in the '
      'Inbox (effective space NULL via the resolver), no Matome minted',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = svc(db);
        // Core unreachable → the row stays pending_upload + loose; the assertion
        // sees the locally-persisted membership (no Core reconcile reshapes it).
        final repo = _CoreDownRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final localId = await finishASession(container, title: 'Standup');

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // LOOSE: no matome, no space. Its effective space is therefore NULL ⇒
        // Inbox (INBOX ⟺ effectiveSpace == NULL, spec R1.3).
        expect(row!.matomeId, isNull,
            reason: 'flag ON: a finished recording must NOT mint a matome');
        expect(row.workspaceId, isNull,
            reason: 'flag ON: a finished recording is loose, no space filed');

        // No Matome row was created at all (the m007 forced-mint is repealed).
        final matomes = await db.matomesDao.listMatomes();
        expect(matomes, isEmpty,
            reason: 'a loose recording mints NO Matome');

        // Surfaces in the Inbox view (workspaceId IS NULL).
        final items = container.read(inboxControllerProvider).requireValue;
        expect(items.single.id, localId);
      },
      skip: _flagOn ? false : 'ON-only lane',
    );

    test(
      'no id regression (#43): the loose recording keeps a rec_local_<uuid> PK '
      '(NOT a Core id) with coreId NULL — Core-first id semantics still hold',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = svc(db);
        final repo = _CoreDownRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final localId = await finishASession(container);

        // The PK is the LOCAL uuid id, never the Core id — so making it loose
        // cannot clash with the #43 PK==Core-id path (there is no Core id at
        // the PK). The Core id, when it arrives, lives in `coreId`.
        expect(isLocalRecordingId(localId), isTrue,
            reason: 'finish returns a local id; PK is never the Core id (#43)');
        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row!.id, localId);
        expect(row.coreId, isNull,
            reason: 'loose insert leaves coreId NULL for the queue to reconcile');

        // A by-coreId lookup must not crash and must find nothing yet (the
        // tolerate-duplicates query, d8cc85d, sees no row for an unminted id).
        expect(await db.recordingsDao.recordingByCoreId(999), isNull);
      },
      skip: _flagOn ? false : 'ON-only lane',
    );

    test(
      'no id regression (#43): a loose recording still reconciles its Core id '
      'into coreId on the SAME local-PK row when Core is reachable (no dup)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = svc(db);
        final repo = _StubUploadRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: _stubbedDio(),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
          uploadQueueProvider.overrideWith(
            (ref) => UploadQueue(
              ref,
              awaitResult: _pollFallbackAwaiter,
              cleanupAudio: (_) async {},
            ),
          ),
        ]);
        addTearDown(container.dispose);

        final localId = await finishASession(container, title: 'Synced');

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // Loose membership SURVIVES the Core reconcile — capture is decoupled
        // from organization; the upload only fills coreId/status.
        expect(row!.matomeId, isNull,
            reason: 'a loose recording stays loose after the Core reconcile');
        expect(row.workspaceId, isNull);
        // The Core id reconciled onto the SAME local-PK row — exactly one row
        // carries coreId 777, so the by-coreId lookup is unambiguous (no dup).
        expect(row.id, localId);
        expect(row.coreId, 777,
            reason: 'loose path still reconciles coreId — no id regression');
        expect(row.processingStatus, 'done');
        final byCore = await db.recordingsDao.recordingByCoreId(777);
        expect(byCore, isNotNull);
        expect(byCore!.id, localId,
            reason: 'no duplicate-coreId: the loose row owns coreId 777');
      },
      skip: _flagOn ? false : 'ON-only lane',
    );
  });

  group('lane: ff.localFirstSpaces=false (OFF / shipped reality)', () {
    test(
      'a finished recording is UNCHANGED — a fresh Matome is minted '
      '(m007/ADR-0003 forced invariant), the recording is an Item of it',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = svc(db);
        final repo = _CoreDownRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
        );

        final container = ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          audioRecordingServiceProvider.overrideWithValue(service),
          recordingsRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final localId = await finishASession(container, title: 'Standup');

        final row = await db.recordingsDao.getRecordingById(localId);
        expect(row, isNotNull);
        // OFF: the forced-mint invariant holds — a Matome was minted and the
        // recording points at it.
        expect(row!.matomeId, isNotNull,
            reason: 'flag OFF: a finished recording still mints a Matome');
        // Inbox capture → Inbox Matome: the minted matome has no space.
        expect(row.workspaceId, isNull);

        final matomes = await db.matomesDao.listMatomes();
        expect(matomes, hasLength(1),
            reason: 'flag OFF mints exactly one Matome per recording');
        expect(matomes.single.id, row.matomeId);

        // No id regression on OFF either: PK is the local id, coreId NULL
        // (Core down) for the queue to reconcile.
        expect(isLocalRecordingId(localId), isTrue);
        expect(row.coreId, isNull);
      },
      skip: _flagOn ? 'OFF-only lane' : false,
    );
  });
}

/// Stubbed Core that drives create → process → done so the queue reconciles a
/// coreId (777) onto the local-PK row.
Dio _stubbedDio() {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:4000',
    validateStatus: (s) => s != null && s < 500,
  ));
  final adapter = DioAdapter(dio: dio);
  adapter.onPost(
    '/api/recordings',
    (server) => server.reply(201, {
      'recording': {
        'id': 777,
        'owner_id': 1,
        'title': 'Synced',
        'status': 'pending',
      },
      'upload': {
        'method': 'PUT',
        'url': 'http://127.0.0.1:9/upload',
        'storage_key': 'k',
        'expires_in': 900,
      },
    }),
    data: Matchers.any,
  );
  adapter.onPost(
    '/api/recordings/777/process',
    (server) => server.reply(202, {
      'recording': {'id': 777, 'owner_id': 1, 'status': 'processing'},
      'processing': {'queued': true},
    }),
  );
  adapter.onGet(
    '/api/recordings/777',
    (server) => server.reply(200, {
      'recording': {
        'id': 777,
        'owner_id': 1,
        'title': 'Synced',
        'status': 'done',
        'summary': 'A memo',
      },
    }),
  );
  return dio;
}

/// Repo whose Core create throws — Core unreachable, so the local-first
/// persistence (membership) can be asserted independent of any Core reconcile.
class _CoreDownRepository extends RecordingsRepository {
  _CoreDownRepository({required super.apiClient});

  @override
  Future<RecordingCreateResult> createRecording({
    required String title,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) async {
    throw const ApiException('Core unreachable (test)');
  }
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll drain without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {}
}
