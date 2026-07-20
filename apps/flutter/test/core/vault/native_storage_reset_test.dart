import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/vault/account_store_opener_native.dart';

void main() {
  test('reset removes old DB sidecars, Vault and plaintext staging', () async {
    final root = await Directory.systemTemp.createTemp('vault-reset-');
    addTearDown(() => root.delete(recursive: true));
    final support = Directory('${root.path}/support');
    final documents = Directory('${root.path}/documents');
    const namespace =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final db = Directory('${support.path}/matome_db/v1/$namespace')
      ..createSync(recursive: true);
    File('${db.path}/matome.sqlite').writeAsStringSync('old');
    File('${db.path}/matome.sqlite-wal').writeAsStringSync('old-wal');
    File('${db.path}/matome.sqlite-shm').writeAsStringSync('old-shm');
    final vault = Directory('${support.path}/matome_vault/v1/$namespace')
      ..createSync(recursive: true);
    File('${vault.path}/orphan.mec1').writeAsStringSync('old-vault');
    final staging = Directory('${documents.path}/Matome')
      ..createSync(recursive: true);
    File('${staging.path}/sentinel-plaintext').writeAsStringSync('secret');

    await resetLegacyNativeStorage(
      applicationSupportRoot: support,
      applicationDocumentsRoot: documents,
      accountNamespace: namespace,
    );
    await resetLegacyNativeStorage(
      applicationSupportRoot: support,
      applicationDocumentsRoot: documents,
      accountNamespace: namespace,
    );

    expect(db.existsSync(), isFalse);
    expect(vault.existsSync(), isFalse);
    expect(staging.existsSync(), isFalse);
  });
}
