import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/vault/vault_retention_service.dart';
import 'package:matome_vault/matome_vault.dart';

import '../../support/fake_media_blob_store.dart';

void main() {
  late AppDatabase db;
  late FakeMediaBlobStore blobs;
  late VaultRetentionService service;
  final now = DateTime.utc(2026, 7, 19);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    blobs = FakeMediaBlobStore();
    service = VaultRetentionService(db, blobs, clock: () => now);
    await db.validateReady();
  });

  tearDown(() => db.close());

  Future<VaultBlobId> unreferencedBlob({
    required String uploadState,
    int? coreId,
    int? uploadedAt,
  }) async {
    final stat = await blobs.ingest(
      _BytesInput(List<int>.generate(32, (index) => index)),
    );
    await db
        .into(db.fileBlobs)
        .insert(
          FileBlobsCompanion.insert(
            id: 'file-${stat.id.value}',
            coreId: Value(coreId),
            mediaType: 'document',
            blobId: Value(stat.id.value),
            blobState: const Value('ready'),
            byteSize: Value(stat.plaintextLength!),
            checksumSha256: Value(stat.plaintextSha256),
            uploadState: Value(uploadState),
            uploadedAt: Value(uploadedAt),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    return stat.id;
  }

  test('keep_forever preserves remotely verified unreferenced blobs', () async {
    final id = await unreferencedBlob(
      coreId: 7,
      uploadState: 'uploaded',
      uploadedAt: now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
    );

    await service.reconcileAndCollect();

    expect(blobs.deleted, isNot(contains(id)));
    final decision = await db.select(db.blobGcDecisions).getSingle();
    expect(decision.decision, 'preserve');
    expect(decision.reason, 'keep_forever');
  });

  test('opt-in expiry collects only expired remote-verified blob', () async {
    final id = await unreferencedBlob(
      coreId: 7,
      uploadState: 'uploaded',
      uploadedAt: now.subtract(const Duration(days: 31)).millisecondsSinceEpoch,
    );
    await service.setPolicy(
      const VaultRetentionPolicy(
        mode: VaultRetentionMode.expireAfterUpload,
        expiryDays: 30,
      ),
    );

    await service.reconcileAndCollect();

    expect(blobs.deleted, contains(id));
    final decision = await db.select(db.blobGcDecisions).getSingle();
    expect(decision.decision, 'collect');
    expect(decision.reason, 'expired_remote_verified');
  });

  test('opt-in expiry preserves local-only blobs', () async {
    final id = await unreferencedBlob(uploadState: 'pending');
    await service.setPolicy(
      const VaultRetentionPolicy(
        mode: VaultRetentionMode.expireAfterUpload,
        expiryDays: 1,
      ),
    );

    await service.reconcileAndCollect();

    expect(blobs.deleted, isNot(contains(id)));
    expect(
      (await db.select(db.blobGcDecisions).getSingle()).reason,
      'remote_not_verified',
    );
  });

  test(
    'opt-in expiry preserves a blob whose Vault facts do not match',
    () async {
      final id = await unreferencedBlob(
        coreId: 7,
        uploadState: 'uploaded',
        uploadedAt: now
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
      );
      await (db.update(db.fileBlobs)
            ..where((row) => row.blobId.equals(id.value)))
          .write(FileBlobsCompanion(checksumSha256: Value('f' * 64)));
      await service.setPolicy(
        const VaultRetentionPolicy(
          mode: VaultRetentionMode.expireAfterUpload,
          expiryDays: 1,
        ),
      );

      await service.reconcileAndCollect();

      expect(blobs.deleted, isNot(contains(id)));
      expect(
        (await db.select(db.blobGcDecisions).getSingle()).reason,
        'vault_facts_mismatch',
      );
    },
  );

  test('active work and active leases prevent collection', () async {
    final workId = await unreferencedBlob(
      coreId: 8,
      uploadState: 'uploaded',
      uploadedAt: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    );
    final leasedId = await unreferencedBlob(
      coreId: 9,
      uploadState: 'uploaded',
      uploadedAt: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    );
    await db
        .into(db.workQueue)
        .insert(
          WorkQueueCompanion.insert(
            id: 'work-active',
            kind: 'file_upload',
            itemId: 'missing-item',
            blobId: Value(workId.value),
            dedupeKey: 'work-active',
            state: 'running',
            stage: 'upload',
            availableAt: now.millisecondsSinceEpoch,
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    final lease = await blobs.acquireReadLease(leasedId);
    addTearDown(lease.dispose);
    await service.setPolicy(
      const VaultRetentionPolicy(
        mode: VaultRetentionMode.expireAfterUpload,
        expiryDays: 1,
      ),
    );

    await service.reconcileAndCollect();

    expect(blobs.deleted, isNot(contains(workId)));
    expect(blobs.deleted, isNot(contains(leasedId)));
    final decisions = {
      for (final row in await db.select(db.blobGcDecisions).get())
        row.blobId: row.reason,
    };
    expect(decisions[workId.value], 'active_work');
    expect(decisions[leasedId.value], 'active_lease');
  });
}

final class _BytesInput implements MediaInput {
  const _BytesInput(this.value);

  final List<int> value;
  @override
  String get filename => 'fixture.bin';
  @override
  String? get contentType => 'application/octet-stream';
  @override
  int get knownLength => value.length;
  @override
  Stream<List<int>> openRead() => Stream.value(value);
}
