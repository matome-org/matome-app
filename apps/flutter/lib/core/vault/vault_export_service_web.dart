import 'package:matome_vault/matome_vault.dart';
import 'package:web/web.dart' as web;

Future<bool> exportVaultBlob(
  MediaBlobStore blobs,
  VaultBlobId id,
  String suggestedFilename,
) async {
  final lease = await blobs.createLease(
    id,
    purpose: VaultLeasePurpose.explicitExport,
    ttl: const Duration(minutes: 2),
  );
  try {
    final anchor = web.HTMLAnchorElement()
      ..href = lease.location.toString()
      ..download = suggestedFilename;
    anchor.click();
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  } finally {
    await lease.dispose();
  }
}
