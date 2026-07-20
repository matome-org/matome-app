import 'contracts.dart';

/// Native filesystem boundaries exposed for deterministic fault injection.
enum NativeVaultIoOperation {
  createDirectory,
  journalWrite,
  journalFlush,
  journalCommit,
  journalCommitted,
  journalCleanup,
  stagingWrite,
  stagingFlush,
  stagingDurable,
  verification,
  verified,
  objectCommit,
  objectCommitted,
  tombstone,
  tombstoned,
  unlink,
  unlinked,
}

/// Test seam invoked immediately before a native filesystem boundary.
abstract interface class NativeVaultFaultInjector {
  void before(NativeVaultIoOperation operation, VaultBlobId? blobId);
}

/// Simulates abrupt process death. Recovery tests use this to retain artifacts.
final class NativeVaultCrash implements Exception {
  const NativeVaultCrash([this.message = 'simulated native vault crash']);

  final String message;

  @override
  String toString() => 'NativeVaultCrash: $message';
}

final class NoNativeVaultFaults implements NativeVaultFaultInjector {
  const NoNativeVaultFaults();

  @override
  void before(NativeVaultIoOperation operation, VaultBlobId? blobId) {}
}
