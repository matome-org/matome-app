import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:matome_vault/matome_vault.dart';

Future<bool> exportVaultBlob(
  MediaBlobStore blobs,
  VaultBlobId id,
  String suggestedFilename,
) async {
  final destination = await FilePicker.platform.saveFile(
    dialogTitle: 'Export from Matome',
    fileName: suggestedFilename,
  );
  if (destination == null) return false;
  final lease = await blobs.acquireReadLease(id);
  final file = File(destination);
  final output = file.openWrite();
  try {
    final read = await lease.openAuthenticatedRead();
    await output.addStream(read.bytes);
    await output.flush();
    await output.close();
    return true;
  } catch (_) {
    await output.close();
    try {
      await file.delete();
    } catch (_) {}
    rethrow;
  } finally {
    await lease.dispose();
  }
}
