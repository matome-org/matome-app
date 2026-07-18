import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/home/inbox_upload.dart'
    show mediaTypeForPath;
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import '../support/item_fixtures.dart';
import '../support/verified_upload_repository_fake.dart';

/// CHARACTERIZATION TEST (task #1451).
///
/// Proves an end-to-end claim that was previously UNPROVEN: that the #43
/// [UploadQueue] can actually drain a NON-AUDIO `mediaType = 'document'` row
/// from `pending_upload` through Core processing acceptance,
/// preserving the document bytes through the presigned PUT, for the
/// representative imported types txt / md / pdf / docx (#1449, schema v12).
///
/// The test exercises the REAL queue drain (not a stub of the queue) and the
/// REAL [RecordingsRepository.uploadFile] / `_uploadStream` against a REAL
/// loopback HTTP server standing in for the presigned-PUT target — so the
/// captured PUT bytes + content-type are exactly what the production code
/// streams to storage. Only Core's own API calls (create / enqueue / fetch)
/// are faked, because those are not what is under test here.
void main() {
  /// A real loopback server that ACCEPTS one presigned PUT and CAPTURES the
  /// streamed body bytes + the `content-type` header the queue sent. This is
  /// the storage stand-in; it lets the REAL repo `_uploadStream` run unchanged.
  late HttpServer putServer;
  late List<int> capturedBody;
  String? capturedContentType;
  String? capturedMethod;
  late Completer<void> putReceived;

  setUp(() async {
    capturedBody = <int>[];
    capturedContentType = null;
    capturedMethod = null;
    putReceived = Completer<void>();
    putServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    putServer.listen((HttpRequest req) async {
      capturedMethod = req.method;
      capturedContentType = req.headers.value('content-type');
      capturedBody = await req.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      req.response.statusCode = 200;
      await req.response.close();
      if (!putReceived.isCompleted) putReceived.complete();
    });
  });
  tearDown(() async {
    await putServer.close(force: true);
  });

  String presignUrl() =>
      'http://${putServer.address.host}:${putServer.port}/upload';

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('upload_queue_doc_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  ProviderContainer containerFor(AppDatabase db, RecordingsRepository repo) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        recordingsRepositoryProvider.overrideWithValue(repo),
        uploadQueueProvider.overrideWith(UploadQueue.new),
      ],
    );
  }

  /// Seeds a `pending_upload` DOCUMENT row exactly as the #1449 import
  /// (`MatomeDetailController.addFile`) writes one: a durable file on disk
  /// (path stored in the reused `audioFilePath` column), `mediaType = 'document'`
  /// and the original extension PERSISTED in `originalExtension`. The bytes are
  /// a recognizable per-type payload so the PUT capture can be byte-asserted.
  Future<(String, File, List<int>)> seedPendingDocumentRow(
    AppDatabase db,
    Directory tmp, {
    required String extension,
    required String contentType,
  }) async {
    final localId = mintLocalRecordingId();
    // A document is imported from within a matome (MatomeDetailController.addFile),
    // so the pending_upload row is already parented to a matome that has a Core id.
    // The queue's create leg (createItemRecording) needs that reconciled matome —
    // POST /api/matomes/{coreMatomeId}/items — so seed one here.
    final matomeId = 'mat_local_$localId';
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: matomeId,
            title: 'Docs',
            happenedAt: DateTime.now().millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            coreId: const Value(42),
          ),
        );
    // Durable copy uses an opaque `import_*.<ext>` name (see durableImportCopy);
    // reproduce that — the extension survives the rename via originalExtension.
    final durable = File('${tmp.path}/import_${localId}_doc.$extension');
    final bytes = utf8.encode('DOC[$extension] body for $localId');
    await durable.writeAsBytes(bytes);
    final now = DateTime.now();
    await insertTestFileItem(
      db,
      id: localId,
      matomeId: matomeId,
      title: 'Quarterly report',
      localPath: durable.path,
      filename: 'Report.$extension',
      createdAt: now.millisecondsSinceEpoch,
      mediaType: 'document',
      contentType: contentType,
      processingStatus: kProcessingStatusPendingUpload,
    );
    return (localId, durable, bytes);
  }

  // ── Sanity: the import classifier buckets all four as 'document' ──────────
  test('mediaTypeForPath buckets txt/md/pdf/docx as document', () {
    for (final ext in ['txt', 'md', 'pdf', 'docx']) {
      expect(
        mediaTypeForPath('/x/file.$ext'),
        'document',
        reason: '$ext must classify as document (not audio/image)',
      );
    }
  });

  test('mediaTypeForPath buckets common video extensions as video', () {
    for (final ext in ['mp4', 'mov', 'mkv', 'avi']) {
      expect(
        mediaTypeForPath('/x/clip.$ext'),
        'video',
        reason: '$ext must classify as video (not document/audio/image)',
      );
    }
  });

  // ── Sanity: the detail-host router routes a document row to the DOC host ──
  test(
    'mediaKindForType("document") resolves to the DOCUMENT host, NOT audio',
    () {
      expect(
        mediaKindForType('document'),
        FileMediaKind.doc,
        reason:
            'a document row must route to the doc file-detail host '
            '(FileDetailScreen.documentById), never the audio host '
            '(FileDetailScreen.byId / FileMediaKind.audio)',
      );
      // Guard the negative explicitly — the bug this whole task de-risks is a
      // document silently falling through to the audio host.
      expect(mediaKindForType('document'), isNot(FileMediaKind.audio));
      // And audio still routes to audio (no accidental cross-wiring).
      expect(mediaKindForType('audio'), FileMediaKind.audio);
    },
  );

  test('mediaKindForType("video") resolves to the VIDEO file host', () {
    expect(mediaKindForType('video'), FileMediaKind.video);
    expect(mediaKindForType('video/mp4'), FileMediaKind.video);
    expect(mediaKindForType('video'), isNot(FileMediaKind.audio));
  });

  // ── The core characterization: drain a document row end-to-end ────────────
  for (final entry in const {
    'txt': 'text/plain',
    'md': 'text/markdown',
    'pdf': 'application/pdf',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  }.entries) {
    final ext = entry.key;
    final contentType = entry.value;
    test('document[$ext] drains through Core processing acceptance '
        '(create → reconcile coreId → uploadFile → enqueue); '
        'PUT preserves the document bytes; row resolves to the DOC host', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repo = _DocCapturingRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
        ),
        presignUrl: presignUrl(),
      );
      final container = containerFor(db, repo);
      addTearDown(container.dispose);

      final (localId, file, bytes) = await seedPendingDocumentRow(
        db,
        tmp,
        extension: ext,
        contentType: contentType,
      );

      // Drive the REAL queue drain.
      await container.read(uploadQueueProvider).drain();
      // The real _uploadStream PUT landed on the loopback server.
      await putReceived.future.timeout(const Duration(seconds: 5));

      // 1. Pipeline ran in order, end-to-end.
      expect(
        repo.createCalls,
        1,
        reason: 'create happened for the $ext document',
      );
      expect(
        repo.createdMediaType,
        'document',
        reason:
            'createRecording carried mediaType=document (row.mediaType '
            'flows straight through — the queue never forces audio)',
      );
      // #1471: the queue computed the on-disk size and declared it as
      // content_length so Core can persist byte_size (the send leg of the
      // size round-trip).
      expect(
        repo.createdContentLength,
        bytes.length,
        reason: 'createRecording declared the real document byte size',
      );
      expect(
        repo.createdFilename,
        'Report.$ext',
        reason:
            'Core receives the preserved source filename, not the display title',
      );
      expect(
        repo.createdContentType,
        contentType,
        reason: 'Core receives the persisted document MIME on creation',
      );
      expect(
        repo.enqueueCalls,
        greaterThanOrEqualTo(1),
        reason: 'processing was enqueued after upload',
      );

      // 2. The presigned PUT carried the DOCUMENT bytes (extension preserved
      //    THROUGH the upload — the queue uploaded File(row.audioFilePath),
      //    which for a document is the .$ext file, byte-for-byte).
      expect(capturedMethod, 'PUT', reason: 'presigned PUT method');
      expect(
        capturedBody,
        bytes,
        reason: 'the exact $ext document bytes were streamed to storage',
      );
      // INTEL: production hardcodes application/octet-stream for the PUT and
      // does NOT encode the extension in the content-type. Extension fidelity
      // rides on the persisted originalExtension column + storageKey, NOT this
      // header. Captured + asserted so any future change is caught.
      expect(
        capturedContentType,
        'application/octet-stream',
        reason:
            'queue streams a generic binary content-type; the original '
            'extension is carried by originalExtension, not this header',
      );

      // 3. Device-terminal state: Core owns processing from acceptance onward.
      final row = await db.itemsDao.getById(localId, '1');
      expect(
        row!.processingStatus,
        'queued',
        reason: 'document row stopped after Core accepted processing',
      );
      expect(row.isProcessing, isTrue);
      expect(row.coreId, repo.coreIdMinted, reason: 'coreId reconciled');
      expect(
        row.mediaType,
        'document',
        reason: 'stored media_type stays document through the drain',
      );
      expect(
        row.originalExtension,
        ext,
        reason: 'original extension preserved on the row',
      );
      expect(
        await file.exists(),
        isTrue,
        reason: 'local file retained after the Core handoff',
      );

      // 4. After draining, the row still resolves to the DOCUMENT host.
      expect(
        mediaKindForType(row.mediaType),
        FileMediaKind.doc,
        reason:
            'a drained document routes to the doc host, not the audio '
            'host (FileDetailScreen.byId)',
      );
    });
  }
}

/// A repository whose Core API legs (create / enqueue / fetch) are faked, but
/// whose `uploadFile` runs the REAL [RecordingsRepository.uploadFile] (via
/// `super`) so the genuine `_uploadStream` PUTs to the loopback [presignUrl].
/// This keeps the queue + the real upload transport under test while not
/// requiring a live Core.
class _DocCapturingRepository extends RecordingsRepository
    with VerifiedSingleUploadRepositoryFake {
  _DocCapturingRepository({required super.apiClient, required this.presignUrl});

  final String presignUrl;

  int createCalls = 0;
  int enqueueCalls = 0;
  String? createdMediaType;
  String? createdFilename;
  String? createdContentType;
  int? createdContentLength;
  final int coreIdMinted = 7777;

  @override
  UploadDescriptor descriptorForVerifiedUpload(int itemId) => UploadDescriptor(
    method: 'PUT',
    url: presignUrl,
    storageKey: 'owners/1/recordings/$itemId/media',
    uploadId: 'item-$itemId-upload-1',
    uploadGeneration: 1,
    mode: UploadMode.single,
    state: UploadState.uploading,
  );

  Recording _recording({required ProcessingState state, String? summary}) {
    return Recording.fromItemJson(<String, dynamic>{
      'id': coreIdMinted,
      'owner_id': 1,
      'item_type': 'file',
      'title': 'Report',
      'processing_state': state.wireName,
      'processing_run_id': state == ProcessingState.notRequested
          ? null
          : '00000000-0000-4000-8000-000000000998',
      'processing_attempt': state == ProcessingState.notRequested ? 0 : 1,
      'processing_requested_outputs': const ['extracted_text', 'summary'],
      'processing_outputs': <String, dynamic>{
        if (summary != null)
          'summary': {'type': 'summary', 'markdown': summary},
      },
      'processing_error': null,
      'file': const <String, dynamic>{'media_type': 'document'},
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
    String? checksumSha256,
    String? filename,
    String? contentType,
  }) async {
    createCalls++;
    createdMediaType = mediaType;
    createdFilename = filename;
    createdContentType = contentType;
    createdContentLength = contentLength;
    return RecordingCreateResult(
      recording: _recording(state: ProcessingState.notRequested),
      // Presign points at the real loopback server so super.uploadFile streams
      // the document bytes through the genuine transport.
      upload: UploadDescriptor(
        method: 'PUT',
        url: presignUrl,
        storageKey: 'owners/1/recordings/$coreIdMinted/media',
        expiresIn: 900,
      ),
    );
  }

  // uploadFile is intentionally NOT overridden — the REAL implementation runs.

  @override
  Future<Recording> enqueueProcessing(int id) async {
    enqueueCalls++;
    return _recording(state: ProcessingState.queued);
  }

  @override
  Future<Recording?> fetchRecording(int id) async =>
      _recording(state: ProcessingState.succeeded, summary: 'A document');
}
