import 'package:crypto/crypto.dart';
import 'package:matome_vault/matome_vault.dart';

import '../db/app_database.dart';
import '../db/connection_web.dart';
import '../db/web_opfs_blob_store.dart';
import 'vault_boot_coordinator.dart';
import 'web_media_blob_store.dart';

Future<VaultOpenedStores> openAccountStores(VaultKeyMaterial material) async {
  final accountId = material.accountId;
  final namespace = sha256.convert(accountId.value.codeUnits).toString();
  await OpfsBlobStore(fileName: 'matome_db_v1_$namespace.enc').delete();
  final executor = await openEncryptedWebConnectionWithKeyMaterial(
    keyMaterial: material,
    blobStore: OpfsBlobStore(fileName: 'matome_db_v2_$namespace.enc'),
  );
  final database = AppDatabase.opened(executor);
  try {
    await database.validateReady();
    final blobs = await openWebMediaBlobStore(
      accountId: accountId,
      keyMaterial: material,
    );
    return VaultOpenedStores(
      database: database,
      blobs: blobs,
      checkpoint: executor.checkpoint,
    );
  } catch (_) {
    await database.close();
    rethrow;
  }
}
