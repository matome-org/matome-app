import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/api_exception.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

void main() {
  // A poll-driven awaiter that resolves from GET (no live socket). The fake
  // repo's fetchRecording supplies the terminal result.
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

  /// Inserts a `pending_upload` local row (the W2 local-first shape) with a
  /// real on-disk audio file the queue must keep until upload is confirmed.
  Future<(String, File)> seedPendingRow(
    AppDatabase db,
    Directory tmp, {
    int? coreId,
  }) async {
    final localId = mintLocalRecordingId();
    final audio = File('${tmp.path}/$localId.m4a');
    await audio.writeAsBytes(List<int>.filled(16, 0));
    final now = DateTime.now();
    // Two-phase upload contract: the create leg (createItemRecording) POSTs to
    // /api/matomes/{coreMatomeId}/items, so a pending_upload row must be
    // parented to a matome that has already reconciled a Core id. Seed one — the
    // queue holds the row until reconcile, then creates the item under it.
    final matomeId = 'mat_local_$localId';
    await db.into(db.matomes).insert(
      MatomesCompanion.insert(
        id: matomeId,
        title: 'Memo',
        happenedAt: now.millisecondsSinceEpoch,
        createdAt: now.millisecondsSinceEpoch,
        coreId: const Value(42),
      ),
    );
    await db.recordingsDao.upsertRecording(RecordingsCompanion(
      id: Value(localId),
      coreId: Value(coreId),
      matomeId: Value(matomeId),
      title: const Value('Memo'),
      timestamp: const Value('1:00 PM'),
      duration: const Value('34s'),
      badge: const Value('Inbox'),
      isProcessing: const Value(1),
      audioFilePath: Value(audio.path),
      createdAt: Value(now.millisecondsSinceEpoch),
      mediaType: const Value('audio'),
      processingStatus: const Value(kProcessingStatusPendingUpload),
    ));
    return (localId, audio);
  }

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('upload_queue_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  ProviderContainer containerFor(
    AppDatabase db,
    RecordingsRepository repo, {
    AudioCleanup? cleanupAudio,
  }) {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      uploadQueueProvider.overrideWith(
        (ref) => UploadQueue(
          ref,
          awaitResult: pollAwaiter,
          cleanupAudio: cleanupAudio ?? deleteAudioFile,
        ),
      ),
    ]);
  }

  test(
      'Core-down → row stays pending + audio kept → Core-up → drains → '
      'reconciled done → audio RETAINED (W2 #871 retention)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    );
    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, audio) = await seedPendingRow(db, tmp);
    final queue = container.read(uploadQueueProvider);

    // CORE DOWN: drain leaves the row pending_upload, coreId null, audio kept.
    repo.coreUp = false;
    await queue.drain();

    var row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.processingStatus, kProcessingStatusPendingUpload,
        reason: 'Core-down keeps the row retriable');
    expect(row.coreId, isNull, reason: 'no Core id minted while down');
    expect(await audio.exists(), isTrue, reason: 'audio kept while down');
    expect(repo.createCalls, 0, reason: 'create never succeeded while down');

    // CORE UP: drain reconciles coreId, resolves done — but RETAINS the audio.
    repo.coreUp = true;
    await queue.drain();

    row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.coreId, repo.coreIdMinted, reason: 'coreId reconciled on drain');
    expect(row.processingStatus, 'done');
    expect(row.isProcessing, 0);
    expect(row.summary, 'A memo');
    // W2 / #871 RETENTION (reverses #43 W4): reaching `done` must NOT delete the
    // local audio. `done` proves Core accepted the upload, not that the user can
    // play a cloud copy, so the local-first file is the source of truth and
    // persists until the user explicitly deletes the recording.
    expect(await audio.exists(), isTrue,
        reason: 'audio RETAINED after confirmed done (local-first; user-only delete)');
  });

  test('failure path: terminal failure keeps the row + audio + reason',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )
      ..coreUp = true
      ..failProcessing = true; // GET returns status `failed`.

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, audio) = await seedPendingRow(db, tmp);
    await container.read(uploadQueueProvider).drain();

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.processingStatus, 'failed', reason: 'terminal failure persists');
    expect(row.coreId, repo.coreIdMinted, reason: 'create did happen');
    expect(await audio.exists(), isTrue,
        reason: 'audio KEPT on failure for inspection / retry');
  });

  test('failure path (transport throw mid-process): keeps row + audio, notes '
      'SANITIZED to generic (unknown-code ApiException is NOT leaked verbatim)',
      () async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )
      ..coreUp = true
      // No `code` ⇒ NOT whitelisted ⇒ must collapse to the generic string.
      ..throwOnEnqueue = const ApiException('transcription backend exploded');

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, audio) = await seedPendingRow(db, tmp);
    await container.read(uploadQueueProvider).drain();

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.processingStatus, 'failed');
    expect(row.notes, t.cardStatus.failed,
        reason: 'unknown-code error → generic localized reason in notes');
    expect(row.notes, isNot(contains('transcription backend exploded')),
        reason: 'raw transport message must never reach the Core-synced notes');
    expect(await audio.exists(), isTrue, reason: 'audio kept on failure');
  });

  test('failure path: a KNOWN error code is whitelisted through to notes',
      () async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )
      ..coreUp = true
      ..throwOnEnqueue = const ApiException(
        'Failed to enqueue processing.',
        statusCode: 500,
        code: 'upload_failed', // a whitelisted, app-authored code
      );

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, _) = await seedPendingRow(db, tmp);
    await container.read(uploadQueueProvider).drain();

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.processingStatus, 'failed');
    expect(row.notes, 'Failed to enqueue processing.',
        reason: 'curated message for a known code is allowed through');
  });

  test('failure path: a non-ApiException is sanitized (never toString)',
      () async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )
      ..coreUp = true
      // A raw StateError carries a sensitive .toString() that must NOT leak.
      ..throwRawOnEnqueue =
          StateError('secret host 10.0.0.5:7001 internal trace');

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, _) = await seedPendingRow(db, tmp);
    await container.read(uploadQueueProvider).drain();

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.processingStatus, 'failed');
    expect(row.notes, t.cardStatus.failed,
        reason: 'non-ApiException → generic reason, not error.toString()');
    expect(row.notes, isNot(contains('10.0.0.5')),
        reason: 'raw toString() detail must never reach notes');
  });

  test('idempotency: no double-create when the row already has a coreId',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )..coreUp = true;

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    // Row already reconciled a coreId (a prior attempt created on Core but the
    // upload/await didn't finish) — but is STILL pending_upload.
    final (localId, _) = await seedPendingRow(db, tmp, coreId: 4242);
    await container.read(uploadQueueProvider).drainRow(localId);

    expect(repo.createCalls, 0,
        reason: 'a row with a coreId must NEVER be re-created on Core');
    // It resumes by fetching the existing Core recording and resolving it.
    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.coreId, 4242, reason: 'keeps the existing coreId');
  });

  test('single-flight: concurrent drains of the same row create only once',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = _ToggleRepository(
      apiClient: ApiClient(
        tokenStore: InMemoryTokenStore(),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
      ),
    )
      ..coreUp = true
      ..createDelay = const Duration(milliseconds: 30);

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    final (localId, _) = await seedPendingRow(db, tmp);
    final queue = container.read(uploadQueueProvider);

    // Fire two drains for the same row at once — the second must no-op.
    await Future.wait([queue.drainRow(localId), queue.drainRow(localId)]);

    expect(repo.createCalls, 1, reason: 'single-flight guards the same row');
  });
}

/// A repository whose Core reachability + processing outcome are toggleable, so
/// the queue's drain/retry/failure/idempotency paths can be driven without a
/// live Core. Counts createRecording calls to assert single-create semantics.
class _ToggleRepository extends RecordingsRepository {
  _ToggleRepository({required super.apiClient});

  bool coreUp = true;
  bool failProcessing = false;
  ApiException? throwOnEnqueue;
  Object? throwRawOnEnqueue;
  Duration createDelay = Duration.zero;

  int createCalls = 0;
  final int coreIdMinted = 999;

  Recording _recording({required String status, String? summary, String? tx}) {
    return Recording.fromJson(<String, dynamic>{
      'id': coreIdMinted,
      'owner_id': 1,
      'title': 'Memo',
      'status': status,
      'summary': ?summary,
      'transcript': ?tx,
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
    if (createDelay > Duration.zero) await Future<void>.delayed(createDelay);
    if (!coreUp) throw const ApiException('Core unreachable');
    createCalls++;
    return RecordingCreateResult(
      recording: _recording(status: 'pending'),
      upload: const UploadDescriptor(
        method: 'PUT',
        url: 'http://127.0.0.1:9/upload',
        storageKey: 'k',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    if (!coreUp) throw const ApiException('Core unreachable');
  }

  @override
  Future<Recording> enqueueProcessing(int id) async {
    final raw = throwRawOnEnqueue;
    if (raw != null) throw raw;
    final err = throwOnEnqueue;
    if (err != null) throw err;
    return _recording(status: 'processing');
  }

  @override
  Future<Recording?> fetchRecording(int id) async {
    if (!coreUp) throw const ApiException('Core unreachable');
    if (failProcessing) return _recording(status: 'failed');
    return _recording(status: 'done', summary: 'A memo', tx: 'hello world');
  }
}
