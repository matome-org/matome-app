import 'package:matome_vault/matome_vault.dart';

typedef MediaIngestCommit = Future<void> Function(VaultBlobStat stat);

/// The sole app-to-Vault publication boundary for newly captured or imported
/// media. Drift references are committed only after encrypted bytes are ready.
final class MediaIngestService {
  const MediaIngestService(this._store);

  final MediaBlobStore _store;

  Future<VaultBlobStat> ingestAndCommit(
    MediaInput input, {
    required MediaIngestCommit commit,
  }) async {
    final stat = await _store.ingest(input);
    try {
      if (stat.state != VaultBlobState.ready) {
        throw const VaultFailure(
          VaultFailureCode.blobNotReady,
          'Vault ingest did not publish a ready blob.',
        );
      }
      await commit(stat);
      return stat;
    } catch (_) {
      try {
        await _store.delete(stat.id);
      } finally {
        await _store.reconcile();
      }
      rethrow;
    }
  }
}
