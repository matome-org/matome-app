import 'package:matome_vault/matome_vault.dart';

import 'vault_export_service_io.dart'
    if (dart.library.js_interop) 'vault_export_service_web.dart'
    as platform;

/// Explicit user export. The destination copy is outside Vault lifecycle.
typedef VaultExport =
    Future<bool> Function({
      required String blobId,
      required String suggestedFilename,
    });

final class VaultExportService {
  const VaultExportService(this._blobs, {this.override});

  final MediaBlobStore _blobs;
  final VaultExport? override;

  Future<bool> export({
    required String blobId,
    required String suggestedFilename,
  }) {
    final safeFilename = _safeFilename(suggestedFilename);
    final exportOverride = override;
    if (exportOverride != null) {
      return exportOverride(blobId: blobId, suggestedFilename: safeFilename);
    }
    return platform.exportVaultBlob(_blobs, VaultBlobId(blobId), safeFilename);
  }
}

String _safeFilename(String value) {
  final sanitized = value.replaceAll(RegExp(r'[/\\\u0000-\u001f]'), '_').trim();
  return sanitized.isEmpty ? 'matome-export' : sanitized;
}
