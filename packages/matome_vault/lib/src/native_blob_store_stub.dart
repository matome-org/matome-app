import 'contracts.dart';
import 'native_blob_store_api.dart';

export 'native_blob_store_api.dart';

/// Web placeholder that keeps the public entrypoint free of `dart:io`.
final class NativeMediaBlobStore implements MediaBlobStore {
  NativeMediaBlobStore._(this.accountId);

  static Future<NativeMediaBlobStore> open({
    required String applicationSupportRoot,
    required VaultAccountId accountId,
    required VaultKeyMaterial keyMaterial,
    NativeVaultFaultInjector faults = const NoNativeVaultFaults(),
  }) => Future.error(
    UnsupportedError('NativeMediaBlobStore is unavailable on this platform'),
  );

  @override
  final VaultAccountId accountId;

  Never _unsupported() =>
      throw UnsupportedError('NativeMediaBlobStore is unavailable on Web');

  @override
  Future<void> delete(VaultBlobId id) async => _unsupported();
  @override
  Future<void> prepareDelete(VaultBlobId id) async => _unsupported();
  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) async =>
      _unsupported();
  @override
  Future<void> close() async => _unsupported();
  @override
  Future<VaultBlobStat> ingest(MediaInput input) async => _unsupported();
  @override
  Future<List<VaultJournalEntry>> journal() async => _unsupported();
  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => _unsupported();
  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  }) async => _unsupported();
  @override
  Future<VaultReconciliationReport> reconcile() async => _unsupported();
  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async => _unsupported();
  @override
  Future<VaultPlaintextLease> createLease(
    VaultBlobId id, {
    required VaultLeasePurpose purpose,
    required Duration ttl,
  }) async => _unsupported();
}
