import 'dart:async';

import 'package:crypto/crypto.dart';
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
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_descriptor.dart';
import 'package:matome_flutter/features/recordings/upload_queue.dart';
import 'package:matome_vault/matome_vault.dart';

import '../support/fake_media_blob_store.dart';
import '../support/item_fixtures.dart';

void main() {
  test(
    'single PUT streams exact logical plaintext while delete is leased',
    () async {
      final fixture = List<int>.generate(
        mec1ChunkPlaintextSize * 3 + 117,
        (index) => (index * 31) & 0xff,
      );
      final harness = await _Harness.create(fixture, mode: UploadMode.single);
      addTearDown(harness.dispose);

      await harness.queue.drainRow(harness.itemId);

      expect(harness.repository.uploaded, fixture);
      expect(
        harness.repository.completedChecksum,
        sha256.convert(fixture).toString(),
      );
      expect(harness.repository.deleteFailure, isA<VaultFailure>());
      expect(harness.store.openedRanges, [
        PlaintextRange(start: 0, endExclusive: fixture.length),
      ]);
      expect(harness.store.activeLeaseCount, 0);
      final item = await harness.db.itemsDao.getById(harness.itemId, '1');
      expect(item!.file!.uploadState, 'uploaded');
      final work = await harness.db.workQueueDao.getForItem(
        harness.itemId,
        'file_upload',
      );
      expect(work!.blobId, harness.blobId.value);
      expect(work.blobRevision, 1);
      expect(work.state, 'succeeded');
    },
  );

  test('multipart restart reopens only missing plaintext ranges', () async {
    final fixture = List<int>.generate(
      mec1ChunkPlaintextSize * 4 + 913,
      (index) => (index * 17 + 9) & 0xff,
    );
    final harness = await _Harness.create(
      fixture,
      mode: UploadMode.multipart,
      partSize: mec1ChunkPlaintextSize + 733,
    );
    addTearDown(harness.dispose);
    harness.repository.failPartOnce = 2;

    await harness.queue.drainRow(harness.itemId);
    expect(harness.store.activeLeaseCount, 0);
    expect(harness.repository.successfulParts.keys, [1]);

    harness.restartQueue();
    await harness.queue.resumeNow();

    expect(harness.repository.uploaded, fixture);
    expect(harness.store.activeLeaseCount, 0);
    final partSize = harness.repository.partSize;
    final part1 = PlaintextRange(start: 0, endExclusive: partSize);
    final part2 = PlaintextRange(start: partSize, endExclusive: partSize * 2);
    expect(
      harness.store.openedRanges.where((range) => range == part1).length,
      2,
      reason: 'checksum and PUT open the first range once each',
    );
    expect(
      harness.store.openedRanges.where((range) => range == part2).length,
      4,
      reason: 'retry reopens only part 2 for a fresh checksum and PUT',
    );
    expect(
      harness.store.openedRanges.where((range) => range!.start == 0).length,
      2,
      reason: 'accepted part 1 is not reopened after process restart',
    );
  });

  test('tamper fails closed, sends no body, and releases the lease', () async {
    final fixture = List<int>.generate(
      mec1ChunkPlaintextSize * 2 + 3,
      (index) => index & 0xff,
    );
    final harness = await _Harness.create(fixture, mode: UploadMode.single);
    addTearDown(harness.dispose);
    harness.store.readFailure = const VaultFailure(
      VaultFailureCode.corruptCiphertext,
      'authenticated chunk failed',
    );

    await harness.queue.drainRow(harness.itemId);

    expect(harness.repository.uploaded, isEmpty);
    expect(harness.repository.completedChecksum, isNull);
    expect(harness.store.activeLeaseCount, 0);
    final work = await harness.db.workQueueDao.getForItem(
      harness.itemId,
      'file_upload',
    );
    expect(work!.state, 'dead');
    expect(work.errorCode, 'invalid_local_data');
  });

  test('missing blob is dead without opening an upload stream', () async {
    final fixture = List<int>.generate(100000, (index) => index & 0xff);
    final harness = await _Harness.create(fixture, mode: UploadMode.single);
    addTearDown(harness.dispose);
    await harness.store.delete(harness.blobId);

    await harness.queue.drainRow(harness.itemId);

    expect(harness.repository.uploaded, isEmpty);
    expect(harness.store.openedRanges, isEmpty);
    final work = await harness.db.workQueueDao.getForItem(
      harness.itemId,
      'file_upload',
    );
    expect(work!.state, 'dead');
  });

  test('account lock blocks old work before plaintext egress', () async {
    final fixture = List<int>.generate(100000, (index) => index & 0xff);
    final harness = await _Harness.create(fixture, mode: UploadMode.single);
    addTearDown(harness.dispose);
    await harness.store.close();

    await harness.queue.drainRow(harness.itemId);

    expect(harness.repository.uploaded, isEmpty);
    expect(harness.store.openedRanges, isEmpty);
    final work = await harness.db.workQueueDao.getForItem(
      harness.itemId,
      'file_upload',
    );
    expect(work!.state, 'blocked');
    expect(work.blockedReason, 'signed_out');
  });

  test('shared delete converges Core, ciphertext and metadata', () async {
    final harness = await _Harness.create([1, 2, 3], mode: UploadMode.single);
    addTearDown(harness.dispose);

    await harness.container
        .read(itemDeletionServiceProvider)
        .delete(harness.itemId, '1');

    expect(harness.repository.deletedCoreIds, [42]);
    expect(harness.store.deleted, contains(harness.blobId));
    expect(await harness.db.itemsDao.getById(harness.itemId, '1'), isNull);
    expect(await harness.db.workQueueDao.listAll(), isEmpty);
  });

  test('delete waits durably for an active Vault lease', () async {
    final harness = await _Harness.create([1, 2, 3], mode: UploadMode.single);
    addTearDown(harness.dispose);
    final lease = await harness.store.acquireReadLease(harness.blobId);

    await harness.container
        .read(itemDeletionServiceProvider)
        .delete(harness.itemId, '1');

    var work = await harness.db.workQueueDao.getForItem(
      harness.itemId,
      'file_delete',
    );
    expect(work?.state, 'retry');
    expect(work?.stage, 'prepare_delete');
    expect(harness.repository.deletedCoreIds, isEmpty);
    expect(harness.store.deleted, isNot(contains(harness.blobId)));

    await lease.dispose();
    await harness.queue.resumeNow();
    expect(harness.store.deleted, contains(harness.blobId));
    expect(await harness.db.itemsDao.getById(harness.itemId, '1'), isNull);
  });

  test(
    'Core delete failure remains durable and retries before local GC',
    () async {
      final harness = await _Harness.create([1, 2, 3], mode: UploadMode.single);
      addTearDown(harness.dispose);
      harness.repository.failDeleteOnce = true;

      await harness.container
          .read(itemDeletionServiceProvider)
          .delete(harness.itemId, '1');

      expect(harness.store.deleted, isNot(contains(harness.blobId)));
      expect(
        (await harness.db.workQueueDao.getForItem(
          harness.itemId,
          'file_delete',
        ))?.state,
        'retry',
      );

      await harness.queue.resumeNow();
      expect(harness.repository.deletedCoreIds, [42]);
      expect(harness.store.deleted, contains(harness.blobId));
    },
  );
}

final class _Harness {
  _Harness._(this.db, this.store, this.repository, this.itemId, this.blobId);

  final AppDatabase db;
  final FakeMediaBlobStore store;
  final _UploadRepository repository;
  final String itemId;
  final VaultBlobId blobId;
  ProviderContainer? _container;

  UploadQueue get queue => _container!.read(uploadQueueProvider);
  ProviderContainer get container => _container!;

  static Future<_Harness> create(
    List<int> fixture, {
    required UploadMode mode,
    int partSize = 0,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final store = FakeMediaBlobStore();
    final stat = await store.ingest(_Input(fixture));
    const itemId = 'vault-upload-item';
    const matomeId = 'vault-upload-matome';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.matomes)
        .insert(
          MatomesCompanion.insert(
            id: matomeId,
            coreId: const Value(7),
            title: 'Upload fixture',
            happenedAt: now,
            createdAt: now,
          ),
        );
    await insertTestFileItem(
      db,
      id: itemId,
      coreId: 42,
      matomeId: matomeId,
      blobId: stat.id.value,
      byteSize: fixture.length,
      processingStatus: 'pending_upload',
      createdAt: now,
    );
    await db.itemsDao.updateFile(
      itemId,
      '1',
      FileBlobsCompanion(
        checksumSha256: Value(stat.plaintextSha256),
        uploadState: const Value('pending'),
        uploadedAt: const Value(null),
      ),
    );
    final repository = _UploadRepository(
      mode: mode,
      expected: fixture,
      store: store,
      blobId: stat.id,
      partSize: partSize == 0 ? fixture.length : partSize,
    );
    final harness = _Harness._(db, store, repository, itemId, stat.id);
    harness.restartQueue();
    return harness;
  }

  void restartQueue() {
    _container?.dispose();
    _container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
        mediaBlobStoreProvider.overrideWithValue(store),
        recordingsRepositoryProvider.overrideWithValue(repository),
        uploadQueueProvider.overrideWith(
          (ref) => UploadQueue(
            ref,
            configRevision: () => 1,
            jitter: () => 0,
            baseRetryDelay: Duration.zero,
            maxRetryDelay: Duration.zero,
            shouldProcess: (_) => false,
          ),
        ),
      ],
    );
  }

  Future<void> dispose() async {
    _container?.dispose();
    await db.close();
  }
}

final class _Input implements MediaInput {
  const _Input(this.bytes);
  final List<int> bytes;

  @override
  String get filename => 'fixture.bin';
  @override
  String? get contentType => 'application/octet-stream';
  @override
  int get knownLength => bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.fromIterable([
    for (var start = 0; start < bytes.length; start += 8192)
      bytes.sublist(start, (start + 8192).clamp(0, bytes.length)),
  ]);
}

final class _UploadRepository extends RecordingsRepository {
  _UploadRepository({
    required this.mode,
    required this.expected,
    required this.store,
    required this.blobId,
    required this.partSize,
  }) : super(
         apiClient: ApiClient(
           tokenStore: InMemoryTokenStore(),
           dio: Dio(BaseOptions(baseUrl: 'http://localhost:7001')),
         ),
       );

  final UploadMode mode;
  final List<int> expected;
  final FakeMediaBlobStore store;
  final VaultBlobId blobId;
  final int partSize;
  final Map<int, List<int>> successfulParts = {};
  int? failPartOnce;
  Object? deleteFailure;
  String? completedChecksum;
  List<int> uploaded = const [];
  bool failDeleteOnce = false;
  final List<int> deletedCoreIds = [];

  @override
  Future<void> deleteRecording(int id) async {
    if (failDeleteOnce) {
      failDeleteOnce = false;
      throw const ApiException(
        'simulated Core delete failure',
        statusCode: 503,
        code: 'delete_failed',
      );
    }
    deletedCoreIds.add(id);
  }

  @override
  Future<UploadDescriptor> requestUpload(
    int itemId, {
    required int inputRevision,
    required int byteSize,
    required String checksumSha256,
    String? contentType,
  }) async {
    expect(byteSize, expected.length);
    expect(checksumSha256, sha256.convert(expected).toString());
    final partCount = (expected.length + partSize - 1) ~/ partSize;
    return UploadDescriptor(
      method: 'PUT',
      url: mode == UploadMode.single ? 'https://storage.invalid/single' : '',
      storageKey: 'opaque-key',
      uploadId: 'upload-1',
      uploadGeneration: 1,
      mode: mode,
      state: UploadState.uploading,
      partSize: mode == UploadMode.multipart ? partSize : null,
      acceptedParts: [
        for (final entry in successfulParts.entries)
          UploadPart(
            partNumber: entry.key,
            etag: 'etag-${entry.key}',
            checksumSha256: sha256.convert(entry.value).toString(),
            byteSize: entry.value.length,
          ),
      ],
      missingParts: mode == UploadMode.multipart
          ? [
              for (var part = 1; part <= partCount; part++)
                if (!successfulParts.containsKey(part)) part,
            ]
          : const [],
    );
  }

  @override
  Future<UploadPartDescriptor> presignUploadPart(
    String uploadId, {
    required int partNumber,
    required String checksumSha256,
  }) async {
    final start = (partNumber - 1) * partSize;
    final end = (start + partSize).clamp(0, expected.length);
    expect(
      checksumSha256,
      sha256.convert(expected.sublist(start, end)).toString(),
    );
    return UploadPartDescriptor(
      partNumber: partNumber,
      byteSize: end - start,
      checksumSha256: checksumSha256,
      request: UploadRequest(
        method: 'PUT',
        url: 'https://storage.invalid/part/$partNumber',
      ),
    );
  }

  @override
  Future<String> uploadStreamRange(
    UploadRequest request,
    Stream<List<int>> stream,
    int length,
  ) async {
    try {
      await store.delete(blobId);
    } catch (error) {
      deleteFailure = error;
    }
    final bytes = await stream.expand((chunk) => chunk).toList();
    expect(bytes, hasLength(length));
    if (mode == UploadMode.single) {
      uploaded = bytes;
      return 'etag-single';
    }
    final partNumber = int.parse(request.url.split('/').last);
    if (failPartOnce == partNumber) {
      failPartOnce = null;
      throw const ApiException(
        'simulated provider failure',
        statusCode: 503,
        code: 'upload_failed',
      );
    }
    successfulParts[partNumber] = bytes;
    return 'etag-$partNumber';
  }

  @override
  Future<UploadDescriptor> completeUpload(
    String uploadId, {
    required int uploadGeneration,
    required String checksumSha256,
    String? etag,
    List<UploadPart> parts = const [],
  }) async {
    completedChecksum = checksumSha256;
    if (mode == UploadMode.multipart) {
      uploaded = [
        for (final part in successfulParts.keys.toList()..sort())
          ...successfulParts[part]!,
      ];
    }
    expect(uploaded, expected);
    return UploadDescriptor(
      method: 'PUT',
      url: '',
      storageKey: 'opaque-key',
      uploadId: uploadId,
      uploadGeneration: uploadGeneration,
      mode: mode,
      state: UploadState.uploaded,
      verifiedByteSize: expected.length,
      verifiedChecksumSha256: checksumSha256,
    );
  }
}
