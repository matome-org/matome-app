import 'package:drift/drift.dart';
import 'package:matome_vault/matome_vault.dart';

import '../db/app_database.dart';

enum VaultRetentionMode { keepForever, expireAfterUpload }

final class VaultRetentionPolicy {
  const VaultRetentionPolicy({required this.mode, this.expiryDays});

  const VaultRetentionPolicy.keepForever()
    : mode = VaultRetentionMode.keepForever,
      expiryDays = null;

  final VaultRetentionMode mode;
  final int? expiryDays;
}

final class VaultRetentionService {
  VaultRetentionService(
    this._database,
    this._blobs, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final MediaBlobStore _blobs;
  final DateTime Function() _clock;

  Future<VaultRetentionPolicy> readPolicy() async {
    final row = await _database
        .select(_database.vaultRetentionPolicies)
        .getSingle();
    return row.mode == 'expire_after_upload' && row.expiryDays != null
        ? VaultRetentionPolicy(
            mode: VaultRetentionMode.expireAfterUpload,
            expiryDays: row.expiryDays,
          )
        : const VaultRetentionPolicy.keepForever();
  }

  Future<void> setPolicy(VaultRetentionPolicy policy) async {
    final days = policy.expiryDays;
    if (policy.mode == VaultRetentionMode.expireAfterUpload &&
        (days == null || days <= 0)) {
      throw ArgumentError.value(days, 'expiryDays', 'must be positive');
    }
    await _database
        .into(_database.vaultRetentionPolicies)
        .insertOnConflictUpdate(
          VaultRetentionPoliciesCompanion.insert(
            id: const Value(1),
            mode: Value(
              policy.mode == VaultRetentionMode.keepForever
                  ? 'keep_forever'
                  : 'expire_after_upload',
            ),
            expiryDays: Value(days),
            updatedAt: _clock().millisecondsSinceEpoch,
          ),
        );
  }

  /// Reconciles crash artifacts and performs only policy-authorized collection.
  /// Unknown or local-only blobs are preserved rather than guessed disposable.
  Future<VaultReconciliationReport> reconcileAndCollect() async {
    final report = await _blobs.reconcile();
    final now = _clock().millisecondsSinceEpoch;
    final policy = await readPolicy();
    final ready = await _blobs.readyBlobIds();
    final metadataRows = await _database
        .customSelect(
          'SELECT id, blob_id, core_id, upload_state, uploaded_at, byte_size, '
          'checksum_sha256 FROM file_blobs WHERE blob_id IS NOT NULL',
        )
        .get();
    final metadataByBlob = {
      for (final row in metadataRows) row.read<String>('blob_id'): row,
    };
    final itemReferences =
        (await _database
                .customSelect(
                  'SELECT DISTINCT file_blobs.blob_id AS blob_id FROM items '
                  'JOIN file_blobs ON file_blobs.id = items.file_blob_id '
                  'WHERE file_blobs.blob_id IS NOT NULL',
                )
                .get())
            .map((row) => row.read<String>('blob_id'))
            .toSet();
    final activeWork =
        (await _database
                .customSelect(
                  "SELECT DISTINCT blob_id FROM work_queue WHERE blob_id IS NOT NULL "
                  "AND state NOT IN ('succeeded', 'dead')",
                )
                .get())
            .map((row) => row.read<String>('blob_id'))
            .toSet();

    for (final id in ready) {
      final raw = id.value;
      final metadata = metadataByBlob[raw];
      final stat = await _blobs.stat(id);
      var decision = 'preserve';
      var reason = 'keep_forever';
      var collect = false;
      if (metadata == null) {
        reason = 'missing_metadata';
      } else if (itemReferences.contains(raw)) {
        reason = 'referenced';
      } else if (activeWork.contains(raw)) {
        reason = 'active_work';
      } else if (metadata.readNullable<int>('core_id') == null ||
          metadata.read<String>('upload_state') != 'uploaded' ||
          metadata.readNullable<int>('uploaded_at') == null ||
          metadata.read<int>('byte_size') <= 0 ||
          metadata.readNullable<String>('checksum_sha256') == null) {
        reason = 'remote_not_verified';
      } else if (stat.state != VaultBlobState.ready ||
          stat.plaintextLength != metadata.read<int>('byte_size') ||
          stat.plaintextSha256 !=
              metadata.readNullable<String>('checksum_sha256')) {
        reason = 'vault_facts_mismatch';
      } else if (policy.mode == VaultRetentionMode.expireAfterUpload) {
        final expiresAt =
            metadata.read<int>('uploaded_at') +
            policy.expiryDays! * Duration.millisecondsPerDay;
        if (now >= expiresAt) {
          decision = 'collect';
          reason = 'expired_remote_verified';
          collect = true;
        } else {
          reason = 'not_expired';
        }
      }

      await _database
          .into(_database.blobGcDecisions)
          .insertOnConflictUpdate(
            BlobGcDecisionsCompanion.insert(
              blobId: raw,
              decision: decision,
              reason: reason,
              decidedAt: now,
            ),
          );
      if (!collect) continue;
      try {
        await _blobs.delete(id);
      } on VaultFailure catch (error) {
        if (error.code != VaultFailureCode.blobNotReady) rethrow;
        await _database
            .into(_database.blobGcDecisions)
            .insertOnConflictUpdate(
              BlobGcDecisionsCompanion.insert(
                blobId: raw,
                decision: 'preserve',
                reason: 'active_lease',
                decidedAt: now,
              ),
            );
        continue;
      }
      await (_database.update(
        _database.fileBlobs,
      )..where((row) => row.blobId.equals(raw))).write(
        FileBlobsCompanion(
          blobState: const Value('missing'),
          updatedAt: Value(now),
        ),
      );
    }

    for (final row in metadataRows) {
      final raw = row.read<String>('blob_id');
      if (ready.any((id) => id.value == raw)) continue;
      await (_database.update(
        _database.fileBlobs,
      )..where((file) => file.blobId.equals(raw))).write(
        FileBlobsCompanion(
          blobState: const Value('missing'),
          updatedAt: Value(now),
        ),
      );
    }
    return report;
  }
}
