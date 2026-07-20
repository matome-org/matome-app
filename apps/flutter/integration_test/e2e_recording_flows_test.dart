import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';

import '../test/recording/audio_recording_service_test.dart'
    show FakeRecorderBackend;
import '../test/support/fake_media_blob_store.dart';
import '../test/support/fake_parent_sync.dart';

// ---------------------------------------------------------------------------
// E2E recording flows — HEADLESS counterpart to integration_test/
// audio_recording_live_test.dart (which needs a real mic). These drive the
// production providers (RecordingController + RecordingFinisher + the F4 inbox
// upload pipeline) wired to the injectable FakeRecorderBackend + an in-memory
// Drift DB + a stubbed presigned PUT, so they run under
// `flutter test integration_test/` on web / linux / android with no device.
//
// Mirrors the maestro flows:
//   * record-pause-resume-finish.yaml — full finish pipeline → Inbox row done
//   * record-kill-recover.yaml        — paused draft survives a service restart
//   * discard-cleanup.yaml            — discard deletes the file + the draft
//   * back-to-back-discard.yaml       — a discarded session leaves no draft, a
//                                       fresh session starts clean
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('e2e_rec_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  AudioRecordingService svc(AppDatabase db, FakeRecorderBackend backend) {
    return AudioRecordingService(
      draftsDao: db.recordingDraftsDao,
      recorder: backend,
      documentsDirProvider: () async => tmp,
      durationProbe: (p) async => File(p).lengthSync(),
      captureSupportedProbe: () async => true,
    );
  }

  Dio stubbedDio() {
    return Dio(
      BaseOptions(
        baseUrl: 'http://localhost:7001',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  testWidgets('record → pause → resume → finish: single Vault blob uploads and '
      'the Inbox row reconciles to queued', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final backend = FakeRecorderBackend();
    final service = svc(db, backend);
    final blobs = FakeMediaBlobStore();
    addTearDown(blobs.close);
    final repo = _StubUploadRepository(
      apiClient: ApiClient(tokenStore: InMemoryTokenStore(), dio: stubbedDio()),
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaBlobStoreProvider.overrideWithValue(blobs),
        currentOwnerIdProvider.overrideWithValue('1'),
        testParentSyncOverride(),
        audioRecordingServiceProvider.overrideWithValue(service),
        recordingsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(recordingControllerProvider.notifier);

    await controller.start();
    expect(controller.state.phase, RecordingPhase.recording);

    await controller.pause();
    expect(controller.state.phase, RecordingPhase.paused);
    // Pause autosaved a crash-recovery draft.
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);

    await controller.resume();
    expect(controller.state.phase, RecordingPhase.recording);

    final localId = await container
        .read(recordingFinisherProvider)
        .finish(title: 'Memo');
    // #43 local-first: finish() returns the stable LOCAL id (`rec_local_<uuid>`);
    // the Core id is reconciled into the `coreId` column on upload — the PK is
    // NOT remapped to the Core id.
    expect(localId, startsWith('rec_local_'));

    // Single continuous file (pause/resume collapsed to one segment), reconciled
    // to the stubbed Core id 555 with a terminal `done` status.
    final row = await db.itemsDao.getById(localId, '1');
    expect(row, isNotNull);
    expect(row!.coreId, 555);
    expect(row.processingState, ProcessingState.queued);
    expect(row.isProcessing, isTrue);
    expect(row.summary, isNull);

    // Appears in the Inbox under its local id.
    final items = container.read(inboxControllerProvider).requireValue;
    expect(items.any((i) => i.id == localId), isTrue);

    // Privacy cleanup after finish: draft gone.
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
  });

  testWidgets('record → kill → recover: a paused draft survives a service '
      'restart and resumes', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Session 1: record, pause (autosaves draft), then "kill" by releasing the
    // recorder without discarding.
    final s1 = svc(db, FakeRecorderBackend());
    final c1 = RecordingController(s1);
    await c1.start();
    await c1.pause();
    expect(await db.recordingDraftsDao.loadDraft(), isNotNull);
    await s1.releaseRecorder(); // kill: draft persists, files untouched
    c1.dispose();

    // Session 2 (next app start) on the SAME persisted DB detects + recovers.
    final s2 = svc(db, FakeRecorderBackend());
    final c2 = RecordingController(s2);
    final detection = await c2.detectDraft();
    expect(c2.state.hasRecoverableDraft, isTrue);
    expect(detection.draft, isNotNull);

    await c2.resumeFromDraft(detection);
    expect(c2.state.phase, RecordingPhase.recording);
    expect(c2.state.hasRecoverableDraft, isFalse);

    // Finishing the recovered session would discard the draft; here we just
    // discard to prove cleanup.
    await c2.discard();
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
    c2.dispose();
  });

  testWidgets('discard-cleanup: discard deletes the on-disk file + the draft', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final backend = FakeRecorderBackend();
    final service = svc(db, backend);
    final controller = RecordingController(service);
    addTearDown(controller.dispose);

    await controller.start();
    await controller.pause();

    final draft = await db.recordingDraftsDao.loadDraft();
    expect(draft, isNotNull);
    // The recorder wrote a real file under the temp documents dir.
    final filePath = backend.path!;
    expect(await File(filePath).exists(), isTrue);

    await controller.discard();

    expect(controller.state.phase, RecordingPhase.idle);
    expect(await File(filePath).exists(), isFalse); // file cleaned
    expect(await db.recordingDraftsDao.loadDraft(), isNull); // draft cleared
  });

  testWidgets('back-to-back-discard: a discarded session leaves no draft so a '
      'fresh session starts clean', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // First session: record → discard.
    final c1 = RecordingController(svc(db, FakeRecorderBackend()));
    await c1.start();
    await c1.pause();
    await c1.discard();
    c1.dispose();
    expect(await db.recordingDraftsDao.loadDraft(), isNull);

    // Immediately start a second session — no stale draft should be detected.
    final c2 = RecordingController(svc(db, FakeRecorderBackend()));
    final detection = await c2.detectDraft();
    expect(c2.state.hasRecoverableDraft, isFalse);
    expect(detection.draft, isNull);

    await c2.start();
    expect(c2.state.phase, RecordingPhase.recording);
    c2.dispose();
  });
}

/// Repo whose presigned-PUT upload is a no-op (the stub host is unreachable),
/// so the test exercises the create/process/poll flow without a real S3.
class _StubUploadRepository extends RecordingsRepository {
  _StubUploadRepository({required super.apiClient});

  int _byteSize = 0;

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
    String? checksumSha256,
    String? filename,
    String? contentType,
  }) async => RecordingCreateResult(
    recording: Recording(
      id: 555,
      ownerId: '1',
      title: title,
      clientId: clientId,
      mediaType: mediaType,
      matomeId: matomeId,
    ),
    upload: const UploadDescriptor(
      method: 'PUT',
      url: 'https://storage.invalid/initial',
      storageKey: 'unused',
      uploadId: 'upload-555',
    ),
  );

  @override
  Future<UploadDescriptor> requestUpload(
    int itemId, {
    required int inputRevision,
    required int byteSize,
    required String checksumSha256,
    String? contentType,
  }) async {
    _byteSize = byteSize;
    return const UploadDescriptor(
      method: 'PUT',
      url: 'https://storage.invalid/upload',
      storageKey: 'item-555',
      uploadId: 'upload-555',
    );
  }

  @override
  Future<String> uploadStreamRange(
    UploadRequest request,
    Stream<List<int>> stream,
    int length,
  ) async {
    await stream.drain<void>();
    return 'etag-test';
  }

  @override
  Future<UploadDescriptor> completeUpload(
    String uploadId, {
    required int uploadGeneration,
    required String checksumSha256,
    String? etag,
    List<UploadPart> parts = const [],
  }) async => UploadDescriptor(
    method: 'PUT',
    url: '',
    storageKey: 'item-555',
    uploadId: uploadId,
    uploadGeneration: uploadGeneration,
    state: UploadState.uploaded,
    verifiedByteSize: _byteSize,
    verifiedChecksumSha256: checksumSha256,
  );

  @override
  Future<Recording> enqueueProcessing(int id) async => Recording(
    id: id,
    ownerId: '1',
    title: 'Memo',
    processing: const ItemProcessing(
      state: ProcessingState.queued,
      runId: 'run-555',
      attempt: 1,
      requestedOutputs: {ProcessingOutputKind.transcript},
      outputs: ProcessingOutputs.empty(),
    ),
  );
}
