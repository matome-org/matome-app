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
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/processing_error.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import '../support/item_fixtures.dart';
import '../support/verified_upload_repository_fake.dart';

void main() {
  /// Inserts a `pending_upload` local row (the W2 local-first shape) with a
  /// real on-disk audio file the queue must keep until upload is confirmed.
  Future<(String, File)> seedPendingRow(
    AppDatabase db,
    Directory tmp, {
    int? coreId,
    String? notes,
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
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: matomeId,
            title: 'Memo',
            happenedAt: now.millisecondsSinceEpoch,
            createdAt: now.millisecondsSinceEpoch,
            coreId: const Value(42),
          ),
        );
    await insertTestFileItem(
      db,
      id: localId,
      coreId: coreId,
      matomeId: matomeId,
      title: 'Memo',
      durationSeconds: 34,
      localPath: audio.path,
      createdAt: now.millisecondsSinceEpoch,
      mediaType: 'audio',
      processingStatus: kProcessingStatusPendingUpload,
      notes: notes,
    );
    return (localId, audio);
  }

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('upload_queue_test_');
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

  test(
    'Core-down holds work; Core-up uploads and stops after process acceptance',
    () async {
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

      const userNotes = '  Offline-safe note.\nSecond line.  ';
      final (localId, audio) = await seedPendingRow(db, tmp, notes: userNotes);
      final queue = container.read(uploadQueueProvider);

      // CORE DOWN: drain persists an explicit durable block, coreId null, audio kept.
      repo.coreUp = false;
      await queue.drain();

      var row = await db.itemsDao.getById(localId, '1');
      expect(
        row!.processingStatus,
        kProcessingStatusBlockedOffline,
        reason: 'Core-down keeps the row retriable with an explicit reason',
      );
      expect(row.coreId, isNull, reason: 'no Core id minted while down');
      expect(
        row.notes,
        userNotes,
        reason: 'blocked upload preserves user notes',
      );
      expect(await audio.exists(), isTrue, reason: 'audio kept while down');
      expect(repo.createCalls, 0, reason: 'create never succeeded while down');

      // CORE UP: drain reconciles coreId and hands processing to Core.
      repo.coreUp = true;
      await queue.drain();

      row = await db.itemsDao.getById(localId, '1');
      expect(
        row!.coreId,
        repo.coreIdMinted,
        reason: 'coreId reconciled on drain',
      );
      expect(row.processingStatus, 'queued');
      expect(row.isProcessing, isTrue);
      expect(row.summary, isNull);
      expect(row.file?.uploadState, 'uploaded');
      expect(row.file?.uploadedAt, isNotNull);
      expect(row.file?.isDirty, isFalse);
      expect(
        row.notes,
        userNotes,
        reason: 'eventual success preserves exact user-note bytes',
      );
      expect(
        repo.lastClientId,
        localId,
        reason: 'local row id is the Core client_id',
      );
      // W2 / #871 RETENTION (reverses #43 W4): reaching `done` must NOT delete the
      // local audio. `done` proves Core accepted the upload, not that the user can
      // play a cloud copy, so the local-first file is the source of truth and
      // persists until the user explicitly deletes the recording.
      expect(
        await audio.exists(),
        isTrue,
        reason:
            'audio RETAINED after confirmed done (local-first; user-only delete)',
      );
    },
  );

  test('device work does not wait for a terminal AI failure', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo =
        _ToggleRepository(
            apiClient: ApiClient(
              tokenStore: InMemoryTokenStore(),
              dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
            ),
          )
          ..coreUp = true
          ..failProcessing = true; // GET returns status `failed`.

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    const userNotes = '  My upload note.\nSecond line.  ';
    final (localId, audio) = await seedPendingRow(db, tmp, notes: userNotes);
    await container.read(uploadQueueProvider).drain();

    final row = await db.itemsDao.getById(localId, '1');
    expect(row!.processingStatus, 'queued');
    expect(row.coreId, repo.coreIdMinted, reason: 'create did happen');
    expect(row.file?.uploadState, 'uploaded');
    expect(row.file?.uploadedAt, isNotNull);
    expect(row.processingErrorCode, isNull);
    expect(
      row.notes,
      userNotes,
      reason: 'terminal processing failure must not mutate user notes',
    );
    expect(
      await audio.exists(),
      isTrue,
      reason: 'audio KEPT on failure for inspection / retry',
    );
  });

  test('transport failure mid-process stays durably blocked without leaking '
      'the ApiException message into notes', () async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo =
        _ToggleRepository(
            apiClient: ApiClient(
              tokenStore: InMemoryTokenStore(),
              dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
            ),
          )
          ..coreUp = true
          // No `code` ⇒ NOT whitelisted ⇒ must collapse to the generic string.
          ..throwOnEnqueue = const ApiException(
            'transcription backend exploded',
          );

    final container = containerFor(db, repo);
    addTearDown(container.dispose);

    const userNotes = '  Offline-safe note.\nSecond line.  ';
    final (localId, audio) = await seedPendingRow(db, tmp, notes: userNotes);
    await container.read(uploadQueueProvider).drain();

    final row = await db.itemsDao.getById(localId, '1');
    expect(row!.processingStatus, kProcessingStatusBlockedOffline);
    expect(
      row.notes,
      userNotes,
      reason: 'a retryable transport block must preserve user notes',
    );
    expect(
      row.notes,
      isNot(contains('transcription backend exploded')),
      reason: 'raw transport message must never reach the Core-synced notes',
    );
    expect(await audio.exists(), isTrue, reason: 'audio kept on failure');
  });

  test(
    'server/upload failure remains durably blocked for a fresh-presign retry',
    () async {
      LocaleSettings.setLocaleSync(AppLocale.en);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repo =
          _ToggleRepository(
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

      const userNotes = '  Private note\nwith exact bytes.  ';
      final (localId, _) = await seedPendingRow(db, tmp, notes: userNotes);
      await container.read(uploadQueueProvider).drain();

      final row = await db.itemsDao.getById(localId, '1');
      expect(row!.processingStatus, kProcessingStatusBlockedCore);
      expect(
        row.notes,
        userNotes,
        reason: 'retry orchestration never overwrites user-authored notes',
      );
    },
  );

  test(
    'failure path: a non-ApiException is sanitized (never toString)',
    () async {
      LocaleSettings.setLocaleSync(AppLocale.en);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repo =
          _ToggleRepository(
              apiClient: ApiClient(
                tokenStore: InMemoryTokenStore(),
                dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
              ),
            )
            ..coreUp = true
            // A raw StateError carries a sensitive .toString() that must NOT leak.
            ..throwRawOnEnqueue = StateError(
              'secret host 10.0.0.5:7001 '
              'https://s3.invalid/object?X-Amz-Credential=secret',
            );

      final container = containerFor(db, repo);
      addTearDown(container.dispose);

      const userNotes = '  Private note\nwith exact bytes.  ';
      final (localId, _) = await seedPendingRow(db, tmp, notes: userNotes);
      await container.read(uploadQueueProvider).drain();

      final row = await db.itemsDao.getById(localId, '1');
      expect(row!.processingStatus, kProcessingStatusBlockedCore);
      expect(
        row.notes,
        userNotes,
        reason: 'queue exceptions must not overwrite user notes',
      );
      expect(
        row.notes,
        isNot(contains('10.0.0.5')),
        reason: 'raw toString() detail must never reach notes',
      );
      final persisted = '${row.item.toJson()} ${row.file?.toJson()}';
      expect(persisted, isNot(contains('10.0.0.5')));
      expect(persisted, isNot(contains('X-Amz-Credential')));
    },
  );

  test('restart after verified upload resumes at process acceptance', () async {
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
    final (localId, _) = await seedPendingRow(
      db,
      tmp,
      coreId: repo.coreIdMinted,
      notes: '  Restart note.\nExact bytes.  ',
    );
    await container.read(uploadQueueProvider).drainRow(localId);

    expect(repo.createCalls, 0, reason: 'verified upload is not repeated');
    final row = await db.itemsDao.getById(localId, '1');
    expect(row!.coreId, repo.coreIdMinted, reason: 'keeps the existing coreId');
    expect(row.processingStatus, 'queued');
  });

  test(
    'single-flight: concurrent drains of the same row create only once',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final repo =
          _ToggleRepository(
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
    },
  );

  test(
    'signed-out work persists an explicit block and resumes after auth',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _ToggleRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
        ),
      )..unauthorized = true;
      final container = containerFor(db, repo);
      addTearDown(container.dispose);
      final (localId, audio) = await seedPendingRow(db, tmp);

      await container.read(uploadQueueProvider).drain();

      var row = await db.itemsDao.getById(localId, '1');
      expect(row!.processingStatus, kProcessingStatusBlockedSignedOut);
      expect(row.coreId, isNull);
      expect(await audio.exists(), isTrue);

      repo.unauthorized = false;
      await container.read(uploadQueueProvider).drain();

      row = await db.itemsDao.getById(localId, '1');
      expect(row!.processingStatus, 'queued');
      expect(row.coreId, repo.coreIdMinted);
    },
  );

  test(
    'app restart resumes a local processing row from idempotent create',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _ToggleRepository(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
        ),
      );
      final (localId, _) = await seedPendingRow(
        db,
        tmp,
        coreId: repo.coreIdMinted,
        notes: '  Restart note.\nExact bytes.  ',
      );
      await db.itemsDao.updateItem(
        localId,
        '1',
        const ItemsCompanion(
          processingState: Value('processing'),
          syncState: Value('processing'),
          processingErrorCode: Value(kProcessingErrorUploadFailed),
        ),
      );

      // A fresh container models a process restart after Core id reconciliation.
      final container = containerFor(db, repo);
      addTearDown(container.dispose);
      await container.read(uploadQueueProvider).drain();

      final row = await db.itemsDao.getById(localId, '1');
      expect(repo.createCalls, 0);
      expect(row!.coreId, repo.coreIdMinted);
      expect(row.processingStatus, 'queued');
      expect(row.processingErrorCode, isNull);
      expect(row.notes, '  Restart note.\nExact bytes.  ');
    },
  );
}

/// A repository whose Core reachability + processing outcome are toggleable, so
/// the queue's drain/retry/failure/idempotency paths can be driven without a
/// live Core. Counts createRecording calls to assert single-create semantics.
class _ToggleRepository extends RecordingsRepository
    with VerifiedSingleUploadRepositoryFake {
  _ToggleRepository({required super.apiClient});

  bool coreUp = true;
  bool unauthorized = false;
  bool failProcessing = false;
  ApiException? throwOnEnqueue;
  Object? throwRawOnEnqueue;
  Duration createDelay = Duration.zero;

  int createCalls = 0;
  String? lastClientId;
  final int coreIdMinted = 999;

  Recording _recording({
    required ProcessingState state,
    String? summary,
    String? tx,
  }) {
    return Recording.fromItemJson(<String, dynamic>{
      'id': coreIdMinted,
      'owner_id': 1,
      'item_type': 'file',
      'title': 'Memo',
      'processing_state': state.wireName,
      'processing_run_id': state == ProcessingState.notRequested
          ? null
          : '00000000-0000-4000-8000-000000000999',
      'processing_attempt': state == ProcessingState.notRequested ? 0 : 1,
      'processing_requested_outputs': const ['transcript', 'summary'],
      'processing_outputs': <String, dynamic>{
        if (summary != null)
          'summary': {'type': 'summary', 'markdown': summary},
        if (tx != null) 'transcript': {'type': 'transcript', 'text': tx},
      },
      'processing_error': state == ProcessingState.failed
          ? const {'code': 'processor_unavailable', 'retryable': true}
          : null,
      'file': const <String, dynamic>{'media_type': 'audio'},
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
    if (createDelay > Duration.zero) await Future<void>.delayed(createDelay);
    if (unauthorized) {
      throw const ApiException(
        'Session expired.',
        statusCode: 401,
        code: 'unauthorized',
      );
    }
    if (!coreUp) throw const ApiException('Core unreachable');
    createCalls++;
    lastClientId = clientId;
    return RecordingCreateResult(
      recording: _recording(state: ProcessingState.notRequested),
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
    return _recording(state: ProcessingState.queued);
  }

  @override
  Future<Recording?> fetchRecording(int id) async {
    if (!coreUp) throw const ApiException('Core unreachable');
    if (failProcessing) return _recording(state: ProcessingState.failed);
    return _recording(
      state: ProcessingState.succeeded,
      summary: 'A memo',
      tx: 'hello world',
    );
  }
}
