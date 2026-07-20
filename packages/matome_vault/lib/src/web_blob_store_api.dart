import 'contracts.dart';

enum WebVaultCapability { available, opfsUnavailable }

final class WebVaultCapabilityReport {
  const WebVaultCapabilityReport(this.capability, {this.reason});

  final WebVaultCapability capability;
  final String? reason;

  bool get isAvailable => capability == WebVaultCapability.available;
}

enum WebVaultIoOperation {
  manifestWrite,
  manifestCommitted,
  stagingWrite,
  stagingCommitted,
  verification,
  verified,
  objectWrite,
  objectCommitted,
  tombstone,
  tombstoned,
  remove,
  removed,
}

abstract interface class WebVaultFaultInjector {
  void before(WebVaultIoOperation operation, VaultBlobId? blobId);
}

final class NoWebVaultFaults implements WebVaultFaultInjector {
  const NoWebVaultFaults();

  @override
  void before(WebVaultIoOperation operation, VaultBlobId? blobId) {}
}

/// Abrupt page termination used only by browser recovery tests.
final class WebVaultCrash implements Exception {
  const WebVaultCrash([this.message = 'simulated Web vault crash']);

  final String message;

  @override
  String toString() => 'WebVaultCrash: $message';
}
