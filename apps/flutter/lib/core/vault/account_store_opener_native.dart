import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:matome_vault/matome_vault.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/connection_native.dart';
import 'native_media_blob_store.dart';
import 'vault_boot_coordinator.dart';

Future<VaultOpenedStores> openAccountStores(VaultKeyMaterial material) async {
  final accountId = material.accountId;
  final databaseKey = await material.use(
    (dek) => Uint8List.fromList(
      sha256.convert([...utf8.encode('matome-db-key-v1'), ...dek]).bytes,
    ),
  );
  try {
    final support = await getApplicationSupportDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final namespace = sha256.convert(utf8.encode(accountId.value)).toString();
    await resetLegacyNativeStorage(
      applicationSupportRoot: support,
      applicationDocumentsRoot: documents,
      accountNamespace: namespace,
    );
    final directory = '${support.path}/matome_db/v2/$namespace';
    final executor = await openEncryptedNativeConnectionWithKey(
      databaseKey: databaseKey,
      databaseDirectory: () async => directory,
    );
    final database = AppDatabase.opened(executor);
    try {
      await database.validateReady();
      final blobs = await openNativeMediaBlobStore(
        accountId: accountId,
        keyMaterial: material,
      );
      return VaultOpenedStores(database: database, blobs: blobs);
    } catch (_) {
      await database.close();
      rethrow;
    }
  } finally {
    databaseKey.fillRange(0, databaseKey.length, 0);
  }
}

Future<void> resetLegacyNativeStorage({
  required Directory applicationSupportRoot,
  required Directory applicationDocumentsRoot,
  required String accountNamespace,
}) async {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(accountNamespace)) {
    throw ArgumentError.value(accountNamespace, 'accountNamespace');
  }
  for (final directory in <Directory>[
    Directory('${applicationSupportRoot.path}/matome_db/v1/$accountNamespace'),
    Directory(
      '${applicationSupportRoot.path}/matome_vault/v1/$accountNamespace',
    ),
    Directory('${applicationDocumentsRoot.path}/Matome'),
  ]) {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
