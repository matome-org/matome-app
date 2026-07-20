import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/connection_native.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException, sqlite3;

class _FakeSecureStore implements SecureKeyStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    expect(Platform.isAndroid, isTrue);
    expect(kSqlCipherEnabled, isTrue);
    loadBundledAndroidSqlCipher();

    final versionDb = sqlite3.openInMemory();
    final versionRows = versionDb.select('PRAGMA cipher_version;');
    versionDb.dispose();
    expect(versionRows, isNotEmpty);
    expect(versionRows.single.values.single.toString(), isNotEmpty);
  });

  testWidgets(
    'packaged SQLCipher round-trips Drift data without plaintext leakage',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/sqlcipher_android_acceptance');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final store = _FakeSecureStore();
      const sentinel = 'MATOME-SQLCIPHER-SENTINEL-2153';

      final first = AppDatabase.forTesting(
        await openEncryptedNativeConnection(
          keyStore: store,
          databaseDirectory: () async => dir.path,
        ),
      );
      await first.workspacesDao.createWorkspace(sentinel);
      await first.close();

      final reopened = AppDatabase.forTesting(
        await openEncryptedNativeConnection(
          keyStore: store,
          databaseDirectory: () async => dir.path,
        ),
      );
      expect(
        (await reopened.workspacesDao.getWorkspaces()).map((row) => row.name),
        contains(sentinel),
      );
      await reopened.close();

      final file = File('${dir.path}/matome.sqlite');
      final scan = latin1.decode(await file.readAsBytes(), allowInvalid: true);
      expect(scan, isNot(contains('SQLite format 3')));
      expect(scan, isNot(contains(sentinel)));
    },
  );

  testWidgets('wrong key fails closed and preserves the encrypted database', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp(
      'matome_sqlcipher_android_wrong',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final originalStore = _FakeSecureStore();
    final original = AppDatabase.forTesting(
      await openEncryptedNativeConnection(
        keyStore: originalStore,
        databaseDirectory: () async => dir.path,
      ),
    );
    await original.workspacesDao.createWorkspace('wrong-key-control');
    await original.close();

    await expectLater(
      openEncryptedNativeConnection(
        keyStore: _FakeSecureStore(),
        databaseDirectory: () async => dir.path,
      ),
      throwsA(isA<SqliteException>()),
    );

    final check = AppDatabase.forTesting(
      await openEncryptedNativeConnection(
        keyStore: originalStore,
        databaseDirectory: () async => dir.path,
      ),
    );
    expect(
      (await check.workspacesDao.getWorkspaces()).map((row) => row.name),
      contains('wrong-key-control'),
    );
    await check.close();
  });

  testWidgets('tampering fails closed before Drift receives a connection', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp(
      'matome_sqlcipher_android_tamper',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = _FakeSecureStore();
    final db = AppDatabase.forTesting(
      await openEncryptedNativeConnection(
        keyStore: store,
        databaseDirectory: () async => dir.path,
      ),
    );
    await db.workspacesDao.createWorkspace('tamper-control');
    await db.close();

    final file = File('${dir.path}/matome.sqlite');
    final bytes = await file.readAsBytes();
    bytes[100] ^= 0xff;
    await file.writeAsBytes(bytes, flush: true);

    await expectLater(
      openEncryptedNativeConnection(
        keyStore: store,
        databaseDirectory: () async => dir.path,
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
