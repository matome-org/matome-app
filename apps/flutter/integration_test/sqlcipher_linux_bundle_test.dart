import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/connection_native.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
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
    expect(Platform.isLinux, isTrue);
    expect(kSqlCipherEnabled, isTrue);

    final executable = File(Platform.resolvedExecutable);
    final library = File(
      '${executable.parent.path}/lib/libmatome_sqlcipher.so',
    );
    expect(library.existsSync(), isTrue);

    loadBundledLinuxSqlCipher();
    final maps = File('/proc/self/maps').readAsStringSync();
    expect(maps, contains(library.resolveSymbolicLinksSync()));

    final elf = Process.runSync('readelf', ['-d', library.path]);
    expect(elf.exitCode, 0, reason: elf.stderr.toString());
    expect(
      elf.stdout.toString(),
      contains('(SYMBOLIC)'),
      reason: 'The SQLCipher DSO must bind its own symbols locally.',
    );
  });

  testWidgets('Vault-ready keys isolate physical account namespaces', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('matome_accounts_2147');
    addTearDown(() => root.deleteSync(recursive: true));
    final firstDir = Directory('${root.path}/opaque-a');
    final secondDir = Directory('${root.path}/opaque-b');
    final firstKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final secondKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

    final first = AppDatabase.forTesting(
      await openEncryptedNativeConnectionWithKey(
        databaseKey: firstKey,
        databaseDirectory: () async => firstDir.path,
      ),
    );
    await first.workspacesDao.createWorkspace('account-a-only');
    await first.close();

    final second = AppDatabase.forTesting(
      await openEncryptedNativeConnectionWithKey(
        databaseKey: secondKey,
        databaseDirectory: () async => secondDir.path,
      ),
    );
    await second.workspacesDao.createWorkspace('account-b-only');
    await second.close();

    final reopened = AppDatabase.forTesting(
      await openEncryptedNativeConnectionWithKey(
        databaseKey: firstKey,
        databaseDirectory: () async => firstDir.path,
      ),
    );
    final names = (await reopened.workspacesDao.getWorkspaces())
        .map((row) => row.name)
        .toList();
    expect(names, contains('account-a-only'));
    expect(names, isNot(contains('account-b-only')));
    await reopened.close();

    await expectLater(
      openEncryptedNativeConnectionWithKey(
        databaseKey: secondKey,
        databaseDirectory: () async => firstDir.path,
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  testWidgets(
    'real app process reports SQLCipher and round-trips encrypted Drift data',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync(
        'matome_sqlcipher_bundle',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = _FakeSecureStore();
      const sentinel = 'MATOME-SQLCIPHER-SENTINEL-2152';

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
      final names = (await reopened.workspacesDao.getWorkspaces()).map(
        (workspace) => workspace.name,
      );
      expect(names, contains(sentinel));
      await reopened.close();

      final versionDb = sqlite3.openInMemory();
      final versionRows = versionDb.select('PRAGMA cipher_version;');
      versionDb.dispose();
      expect(versionRows, isNotEmpty);
      expect(versionRows.single.values.single.toString(), isNotEmpty);

      final bytes = await File('${dir.path}/matome.sqlite').readAsBytes();
      final scan = latin1.decode(bytes, allowInvalid: true);
      expect(scan, isNot(contains('SQLite format 3')));
      expect(scan, isNot(contains(sentinel)));
    },
  );

  testWidgets('wrong key fails closed and leaves the original data intact', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('matome_sqlcipher_wrong');
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
    final dir = Directory.systemTemp.createTempSync('matome_sqlcipher_tamper');
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
