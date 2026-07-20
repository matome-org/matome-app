import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matome_vault/matome_vault.dart';
import 'package:record/record.dart';

import 'package:matome_flutter/core/db/daos/recording_drafts_dao.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';

import 'support/e2e_database.dart';
import 'support/fake_media_blob_store.dart';
import 'support/fake_parent_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'WEB: record → pause → resume → finish uploads one Vault blob and queues',
    (tester) async {
      final db = await createE2EDatabase();
      addTearDown(db.close);
      final blobs = FakeMediaBlobStore();
      addTearDown(blobs.close);
      final service = _WebAudioRecordingService(
        db.recordingDraftsDao,
        _WebRecordingStore(),
      );
      final repo = _StubUploadRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
        ),
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
      await controller.pause();
      await controller.resume();
      final path = await controller.finish();
      final bytes = service.store.artifacts[path]!;
      final localId = await container
          .read(inboxUploaderProvider)
          .upload(
            PickedUpload(
              input: _BytesMediaInput('recording.webm', bytes),
              title: 'Memo',
              mediaType: 'audio',
              filename: 'recording.webm',
            ),
            durationSeconds: 2,
          );
      await service.discardSegmentPaths([path]);

      expect(localId, startsWith('rec_local_'));
      final row = await db.itemsDao.getById(localId, '1');
      expect(row?.coreId, 555);
      expect(row?.processingState, ProcessingState.queued);
      expect(container.read(inboxControllerProvider).requireValue, isNotEmpty);
      expect(await blobs.readyBlobIds(), hasLength(1));
      expect(service.store.artifacts, isEmpty);
      expect(await db.recordingDraftsDao.loadDraft(), isNull);
    },
  );

  testWidgets('WEB: record → kill → recover restores a paused draft', (
    tester,
  ) async {
    final db = await createE2EDatabase();
    addTearDown(db.close);
    final store = _WebRecordingStore();
    final first = _WebAudioRecordingService(db.recordingDraftsDao, store);
    final firstController = RecordingController(first);
    await firstController.start();
    await firstController.pause();
    await first.releaseRecorder();
    firstController.dispose();

    final second = _WebAudioRecordingService(db.recordingDraftsDao, store);
    final secondController = RecordingController(second);
    final detection = await secondController.detectDraft();
    expect(detection.draft, isNotNull);
    await secondController.resumeFromDraft(detection);
    expect(secondController.state.phase, RecordingPhase.recording);
    await secondController.discard();
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
    secondController.dispose();
  });

  testWidgets('WEB: discard removes the captured artifact and draft', (
    tester,
  ) async {
    final db = await createE2EDatabase();
    addTearDown(db.close);
    final store = _WebRecordingStore();
    final controller = RecordingController(
      _WebAudioRecordingService(db.recordingDraftsDao, store),
    );
    await controller.start();
    await controller.pause();
    expect(store.artifacts, isNotEmpty);
    await controller.discard();
    expect(store.artifacts, isEmpty);
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
    controller.dispose();
  });

  testWidgets('WEB: back-to-back discard starts the next session clean', (
    tester,
  ) async {
    final db = await createE2EDatabase();
    addTearDown(db.close);
    final store = _WebRecordingStore();
    final first = RecordingController(
      _WebAudioRecordingService(db.recordingDraftsDao, store),
    );
    await first.start();
    await first.pause();
    await first.discard();
    first.dispose();

    final second = RecordingController(
      _WebAudioRecordingService(db.recordingDraftsDao, store),
    );
    final detection = await second.detectDraft();
    expect(detection.draft, isNull);
    await second.start();
    expect(second.state.phase, RecordingPhase.recording);
    second.dispose();
  });
}

final class _WebRecordingStore {
  final Map<String, List<int>> artifacts = {};
  int nextId = 0;
}

final class _WebAudioRecordingService extends AudioRecordingService {
  _WebAudioRecordingService(this.drafts, this.store) : super(draftsDao: drafts);

  final RecordingDraftsDao drafts;
  final _WebRecordingStore store;
  final List<String> _segments = [];
  bool _active = false;

  @override
  Future<void> startRecording() async {
    final path = 'memory://recording-${++store.nextId}.webm';
    store.artifacts[path] = List<int>.filled(
      1024,
      store.nextId,
      growable: true,
    );
    _segments
      ..clear()
      ..add(path);
    _active = true;
  }

  @override
  Future<String> pauseRecording() async {
    await drafts.saveDraft([_segments.single], 1000);
    return _segments.single;
  }

  @override
  Future<void> resumeRecording() async {
    store.artifacts[_segments.single]!.addAll(List<int>.filled(1024, 2));
  }

  @override
  Future<String> stopRecording() async {
    _active = false;
    return _segments.single;
  }

  @override
  Stream<Amplitude> amplitudeStream({
    Duration interval = const Duration(milliseconds: 80),
  }) => const Stream.empty();

  @override
  double get recordingDurationSeconds => 2;

  @override
  bool get isRecorderActive => _active;

  @override
  List<String> getSegments() => List.unmodifiable(_segments);

  @override
  Future<RecordingDraft?> detectRecoverableDraft() => drafts.loadDraft();

  @override
  Future<void> resumeFromDraft(RecordingDraft draft) async {
    _segments
      ..clear()
      ..addAll(draft.segmentHandles);
  }

  @override
  Future<String> mergeSegments() async => _segments.last;

  @override
  Future<void> cancelRecording() async {
    for (final path in _segments) {
      store.artifacts.remove(path);
    }
    _segments.clear();
    _active = false;
    await drafts.deleteDraft();
  }

  @override
  Future<void> releaseRecorder() async {
    _active = false;
  }

  @override
  Future<void> discardSegmentPaths(List<String> paths) async {
    for (final path in paths) {
      store.artifacts.remove(path);
    }
    await drafts.deleteDraft();
  }

  @override
  Future<double> getAudioDurationSeconds(String path) async => 2;

  @override
  Future<void> dispose() async {}
}

final class _BytesMediaInput implements MediaInput {
  _BytesMediaInput(this.filename, this.bytes);

  @override
  final String filename;
  final List<int> bytes;

  @override
  String? get contentType => 'audio/webm';

  @override
  int get knownLength => bytes.length;

  @override
  Stream<List<int>> openRead() => Stream.value(bytes);
}

final class _StubUploadRepository extends RecordingsRepository {
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
