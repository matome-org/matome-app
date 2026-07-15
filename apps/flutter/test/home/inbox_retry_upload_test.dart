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
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/recording_result_waiter.dart';
import 'package:matome_flutter/features/recordings/recording_status_event.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

/// W5 (plan #43): the manual retry affordance must RE-ENQUEUE through the same
/// auto-retry upload queue (drainRow), not a parallel pipeline. A `failed` row
/// has already left `pending_upload`, so the queue would otherwise no-op on it;
/// [InboxController.retryUpload] flips it back to `pending_upload`, clears the
/// failure reason in `notes`, then drains.
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
    tmp = await Directory.systemTemp.createTemp('inbox_retry_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Seeds a FAILED row (coreId set — upload reconciled but transcription failed)
  /// with its audio still on disk, the shape the queue's failure policy leaves.
  Future<(String, File)> seedFailedRow(
    AppDatabase db, {
    int? coreId,
    String? notes,
    String? matomeId,
  }) async {
    final localId = mintLocalRecordingId();
    final audio = File('${tmp.path}/$localId.m4a');
    await audio.writeAsBytes(List<int>.filled(16, 0));
    await db.recordingsDao.upsertRecording(RecordingsCompanion(
      id: Value(localId),
      coreId: Value(coreId),
      // A coreId-less retry re-runs the CREATE leg, which now targets the
      // recording's parent matome (POST /api/matomes/{coreMatomeId}/items), so
      // the row must be parented to a Core-reconciled matome to egress.
      matomeId: Value(matomeId),
      title: const Value('Memo'),
      timestamp: const Value('1:00 PM'),
      duration: const Value('34s'),
      badge: const Value('Inbox'),
      isProcessing: const Value(0),
      audioFilePath: Value(audio.path),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      mediaType: const Value('audio'),
      processingStatus: const Value('failed'),
      notes: Value(notes),
    ));
    return (localId, audio);
  }

  /// Seeds a Core-reconciled local matome (coreId set) the retry can create an
  /// item under, returning its local id.
  Future<String> seedReconciledMatome(AppDatabase db, {required int coreId}) async {
    final matomeId = 'mat_local_$coreId';
    await db.into(db.matomes).insert(MatomesCompanion.insert(
          id: matomeId,
          title: 'M',
          happenedAt: DateTime.now().millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          coreId: Value(coreId),
        ));
    return matomeId;
  }

  ProviderContainer containerFor(AppDatabase db, RecordingsRepository repo) {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      recordingsRepositoryProvider.overrideWithValue(repo),
      uploadQueueProvider.overrideWith(
        (ref) => UploadQueue(ref, awaitResult: pollAwaiter),
      ),
    ]);
  }

  test('manual retry of a failed row re-enqueues via the queue → done', () async {
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

    // A failed row that already reconciled a coreId (transcription failed).
    final (localId, audio) =
        await seedFailedRow(db, coreId: 999, notes: 'backend exploded');

    await container
        .read(inboxControllerProvider.notifier)
        .retryUpload(localId);

    final row = await db.recordingsDao.getRecordingById(localId);
    // Re-enqueued through the queue and resolved to done (NOT a new pipeline).
    expect(row!.processingStatus, 'done', reason: 'retry drove it to done');
    expect(row.notes, isNot('backend exploded'),
        reason: 'the persisted failure reason was cleared on retry');
    expect(row.coreId, 999, reason: 'no double-create — kept the coreId');
    expect(repo.createCalls, 0, reason: 'reused the existing Core recording');
    // W2 / #871 RETENTION (reverses #43 W4): a retry that reaches `done` must
    // NOT delete the local audio — `done` proves Core accepted the upload, not
    // that the user can play a cloud copy. The local-first file persists until
    // the user explicitly deletes the recording.
    expect(await audio.exists(), isTrue,
        reason: 'audio RETAINED after confirmed done (local-first; user-only delete)');
  });

  test('manual retry of a coreId-less failure re-creates then reconciles',
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

    // A failure with NO coreId (the create/upload itself failed), parented to a
    // Core-reconciled matome so the retry's create leg can egress.
    final matomeId = await seedReconciledMatome(db, coreId: 42);
    final (localId, _) = await seedFailedRow(db, matomeId: matomeId);

    await container
        .read(inboxControllerProvider.notifier)
        .retryUpload(localId);

    final row = await db.recordingsDao.getRecordingById(localId);
    expect(row!.coreId, repo.coreIdMinted, reason: 'create happened on retry');
    expect(row.processingStatus, 'done');
    expect(repo.createCalls, 1, reason: 'one create for the never-uploaded row');
  });
}

class _ToggleRepository extends RecordingsRepository {
  _ToggleRepository({required super.apiClient});

  bool coreUp = true;
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
    required String clientId,
    int? durationSeconds,
    String? badge,
    String mediaType = 'audio',
    int? workspaceId,
    int? contentLength,
  }) async {
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
  Future<Recording> enqueueProcessing(int id) async =>
      _recording(status: 'processing');

  @override
  Future<Recording?> fetchRecording(int id) async {
    if (!coreUp) throw const ApiException('Core unreachable');
    return _recording(status: 'done', summary: 'A memo', tx: 'hello world');
  }
}
