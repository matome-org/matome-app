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
import 'package:matome_flutter/features/matome/matome.dart';
import 'package:matome_flutter/features/matome/matomes_repository.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';

import '../support/item_fixtures.dart';
import '../support/verified_upload_repository_fake.dart';

void main() {
  test('drain reconciles an unreconciled parent before its child', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final temp = await Directory.systemTemp.createTemp('parent_reconcile_');
    addTearDown(() => temp.delete(recursive: true));

    await db
        .into(db.workspaces)
        .insert(
          WorkspacesCompanion.insert(
            id: '42',
            name: 'Cloud',
            createdAt: 1,
            isLocal: const Value(0),
          ),
        );
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: 'mat_local_parent',
            title: 'Parent',
            happenedAt: 1,
            createdAt: 1,
            spaceId: const Value('42'),
          ),
        );
    final media = File('${temp.path}/child.m4a');
    await media.writeAsBytes(const [1, 2, 3]);
    await insertTestFileItem(
      db,
      id: 'rec_local_child',
      ownerId: 'owner-1',
      title: 'Child',
      durationSeconds: 1,
      localPath: media.path,
      createdAt: 1,
      matomeId: 'mat_local_parent',
      processingStatus: 'pending_upload',
    );

    final calls = <String>[];
    final tokenStore = InMemoryTokenStore();
    await tokenStore.saveTokens(accessToken: 'test-token');
    final client = ApiClient(
      tokenStore: tokenStore,
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
    );
    final matomes = _ParentRepository(apiClient: client, calls: calls);
    final recordings = _ChildRepository(apiClient: client, calls: calls);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokenStore),
        currentOwnerIdProvider.overrideWithValue('owner-1'),
        matomesRepositoryProvider.overrideWithValue(matomes),
        recordingsRepositoryProvider.overrideWithValue(recordings),
        uploadQueueProvider.overrideWith(UploadQueue.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(uploadQueueProvider).drain();

    expect(calls, ['parent', 'child', 'upload', 'enqueue']);
    expect(
      (await db.matomesDao.getById('mat_local_parent'))!.coreId,
      matomes.coreId,
    );
    final child = await db.itemsDao.getById('rec_local_child', 'owner-1');
    expect(child!.coreId, recordings.coreId);
    expect(child.processingStatus, 'queued');
  });
}

class _ParentRepository extends MatomesRepository {
  _ParentRepository({required super.apiClient, required this.calls});

  final List<String> calls;
  final int coreId = 101;

  @override
  Future<Matome> createMatome({
    required String title,
    int? workspaceId,
    DateTime? happenedAt,
    String? description,
    String? aggregatedSummary,
  }) async {
    calls.add('parent');
    return Matome(
      id: coreId,
      ownerId: 'owner-1',
      title: title,
      workspaceId: workspaceId,
      happenedAt: happenedAt,
    );
  }
}

class _ChildRepository extends RecordingsRepository
    with VerifiedSingleUploadRepositoryFake {
  _ChildRepository({required super.apiClient, required this.calls});

  final List<String> calls;
  final int coreId = 202;

  Recording _recording(ProcessingState state) => Recording(
    id: coreId,
    ownerId: 'owner-1',
    title: 'Child',
    processing: ItemProcessing(
      state: state,
      runId: state == ProcessingState.notRequested ? null : 'run-$coreId',
      attempt: state == ProcessingState.notRequested ? 0 : 1,
      requestedOutputs: const {ProcessingOutputKind.transcript},
      outputs: const ProcessingOutputs.empty(),
    ),
  );

  @override
  Future<List<Recording>> fetchRecordings() async => const [];

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
  }) async {
    calls.add('child');
    expect(matomeId, 101);
    expect(clientId, 'rec_local_child');
    return RecordingCreateResult(
      recording: _recording(ProcessingState.notRequested),
      upload: const UploadDescriptor(
        method: 'PUT',
        url: 'http://127.0.0.1:9/upload',
        storageKey: 'child',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> uploadFile(UploadDescriptor upload, File file) async {
    calls.add('upload');
  }

  @override
  Future<Recording> enqueueProcessing(int id) async {
    calls.add('enqueue');
    return _recording(ProcessingState.queued);
  }
}
