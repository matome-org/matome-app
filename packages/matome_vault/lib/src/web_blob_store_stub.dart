import 'contracts.dart';
import 'web_blob_store_api.dart';

export 'web_blob_store_api.dart';

Future<WebVaultCapabilityReport> probeWebMediaBlobStore() async =>
    const WebVaultCapabilityReport(
      WebVaultCapability.opfsUnavailable,
      reason: 'OPFS is unavailable on this platform.',
    );

final class WebMediaBlobStore implements MediaBlobStore {
  WebMediaBlobStore._(this.accountId);

  static Future<WebMediaBlobStore> open({
    required VaultAccountId accountId,
    required VaultKeyMaterial keyMaterial,
    WebVaultFaultInjector faults = const NoWebVaultFaults(),
  }) => Future.error(
    const VaultFailure(
      VaultFailureCode.backendUnavailable,
      'OPFS is unavailable on this platform.',
    ),
  );

  @override
  final VaultAccountId accountId;

  Never _unsupported() => throw const VaultFailure(
    VaultFailureCode.backendUnavailable,
    'OPFS is unavailable on this platform.',
  );

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
