import 'package:matome_vault/matome_vault.dart' as vault;

/// Capability seam consumed by locked boot before admitting a Web vault.
Future<vault.WebVaultCapabilityReport> probeWebMediaBlobStoreCapability() =>
    vault.probeWebMediaBlobStore();

/// Opens only the encrypted OPFS media store; no memory/plaintext fallback.
Future<vault.MediaBlobStore> openWebMediaBlobStore({
  required vault.VaultAccountId accountId,
  required vault.VaultKeyMaterial keyMaterial,
}) => vault.WebMediaBlobStore.open(
  accountId: accountId,
  keyMaterial: keyMaterial,
);
