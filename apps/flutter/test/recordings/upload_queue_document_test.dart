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
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

/// CHARACTERIZATION TEST (task #1451).
///
/// Proves an end-to-end claim that was previously UNPROVEN: that the #43
/// [UploadQueue] — which is named and documented around audio
/// (`audioFilePath` / `AudioCleanup`) — can actually drain a NON-AUDIO
/// `mediaType = 'document'` row from `pending_upload` → terminal `done`,
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
  // A poll-driven awaiter that resolves from GET (no live socket). The fake
  // repo's fetchRecording supplies the terminal `done` result. Mirrors the
  // audio upload_queue_test.dart awaiter so we drive the SAME real drain.
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
        recordingsRepositoryProvider.overrideWithValue(repo),
        uploadQueueProvider.overrideWith(
          (ref) => UploadQueue(ref, awaitResult: pollAwaiter),
        ),
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
  }) async {
    final localId = mintLocalRecordingId();
    // A document is imported from within a matome (MatomeDetailController.addFile),
    // so the pending_upload row is already parented to a matome that has a Core id.
    // The queue's create leg (createItemRecording) needs that reconciled matome —
    // POST /api/matomes/{coreMatomeId}/items — so seed one here.
    final matomeId = 'mat_local_$localId';
    await db.into(db.matomes).insert(
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
    await db.recordingsDao.upsertRecording(
      RecordingsCompanion(
        id: Value(localId),
        coreId: const Value(null),
        matomeId: Value(matomeId),
        title: Value('Report.$extension'),
        timestamp: const Value('1:00 PM'),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: Value(durable.path),
        createdAt: Value(now.millisecondsSinceEpoch),
        mediaType: const Value('document'),
        originalExtension: Value(extension),
        processingStatus: const Value(kProcessingStatusPendingUpload),
      ),
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
  for (final ext in const ['txt', 'md', 'pdf', 'docx']) {
    test(
      'document[$ext] drains pending_upload → done end-to-end '
      '(create → reconcile coreId → uploadFile → enqueue → done); '
      'PUT preserves the document bytes; row resolves to the DOC host',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = _DocCapturingRepository(
          apiClient: ApiClient(
            tokenStore: InMemoryTokenStore(),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
          ),
          presignUrl: presignUrl(),
        );
        final container = containerFor(db, repo);
        addTearDown(container.dispose);

        final (localId, file, bytes) = await seedPendingDocumentRow(
          db,
          tmp,
          extension: ext,
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

        // 3. Terminal state: reconciled coreId + done; media_type still document;
        //    original extension preserved on the row.
        final row = await db.recordingsDao.getRecordingById(localId);
        expect(
          row!.processingStatus,
          'done',
          reason: 'document row reached terminal done',
        );
        expect(row.isProcessing, 0);
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
          reason: 'local file retained after done (W2 #871 retention)',
        );

        // 4. After draining, the row still resolves to the DOCUMENT host.
        expect(
          mediaKindForType(row.mediaType),
          FileMediaKind.doc,
          reason:
              'a drained document routes to the doc host, not the audio '
              'host (FileDetailScreen.byId)',
        );
      },
    );
  }
}

/// A repository whose Core API legs (create / enqueue / fetch) are faked, but
/// whose `uploadFile` runs the REAL [RecordingsRepository.uploadFile] (via
/// `super`) so the genuine `_uploadStream` PUTs to the loopback [presignUrl].
/// This keeps the queue + the real upload transport under test while not
/// requiring a live Core.
class _DocCapturingRepository extends RecordingsRepository {
  _DocCapturingRepository({required super.apiClient, required this.presignUrl});

  final String presignUrl;

  int createCalls = 0;
  int enqueueCalls = 0;
  String? createdMediaType;
  int? createdContentLength;
  final int coreIdMinted = 7777;

  Recording _recording({required String status, String? summary}) {
    return Recording.fromJson(<String, dynamic>{
      'id': coreIdMinted,
      'owner_id': 1,
      'title': 'Report',
      'status': status,
      'summary': ?summary,
    });
  }

  @override
  Future<RecordingCreateResult> createItemRecording({
    required String title,
    required int matomeId,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) async {
    createCalls++;
    createdMediaType = mediaType;
    createdContentLength = contentLength;
    return RecordingCreateResult(
      recording: _recording(status: 'pending'),
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
    return _recording(status: 'processing');
  }

  @override
  Future<Recording?> fetchRecording(int id) async =>
      _recording(status: 'done', summary: 'A document');
}
