@Tags(['native_spike'])
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/connection_native.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

// ---------------------------------------------------------------------------
// Task #1853 (plan #131 Wave 3) — the LIVE native SQLCipher open path.
//
// Unlike sqlcipher_native_spike_test.dart (task #1847's go/no-go PoC, which
// hand-rolls its own key/open calls to prove the MECHANISM), this file
// exercises the actual production entry point —
// `openEncryptedNativeConnection` in connection_native.dart — end to end
// through a real `AppDatabase`. Same opt-in gating as the spike (needs a
// built libsqlcipher; no production per-platform library is packaged yet,
// see connection_native.dart's kSqlCipherEnabled doc / DECISION.md gap #1),
// so this is skipped by default and does not affect ordinary CI.
//
// Run with:
//   MATOME_SQLCIPHER_POC_LIB=<built .so> flutter test --tags native_spike \
//     --run-skipped test/db/sqlcipher_encrypted_open_test.dart
// (build the lib with tool/spike_815_sqlcipher/build_libsqlcipher.sh)
// ---------------------------------------------------------------------------

class _FakeSecureStore implements SecureKeyStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  final libPath = Platform.environment['MATOME_SQLCIPHER_POC_LIB'];
  final libReady =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();

  setUpAll(() {
    if (!libReady) return;
    sqlite3_open.open.overrideFor(
      sqlite3_open.OperatingSystem.linux,
      () => DynamicLibrary.open(libPath),
    );
  });

  void skipIfLibMissing() {
    if (!libReady) {
      markTestSkipped(
        'MATOME_SQLCIPHER_POC_LIB not set / library not built — see '
        'tool/spike_815_sqlcipher/build_libsqlcipher.sh',
      );
    }
  }

  group('openEncryptedNativeConnection — plaintext-scan (#1853 AC)', () {
    test(
      'on-disk file contains ZERO plaintext markers for a known written row',
      () async {
        if (!libReady) {
          skipIfLibMissing();
          return;
        }

        final dir =
            Directory.systemTemp.createTempSync('matome_1853_plaintext_scan');
        addTearDown(() => dir.deleteSync(recursive: true));

        const marker = 'PLAINTEXT-MARKER-1853-do-not-leak-xyz789';

        final executor = await openEncryptedNativeConnection(
          keyStore: _FakeSecureStore(),
          databaseDirectory: () async => dir.path,
        );
        final db = AppDatabase.forTesting(executor);
        await db.workspacesDao.createWorkspace(marker);
        await db.close();

        final file = File('${dir.path}/matome.sqlite');
        expect(file.existsSync(), isTrue);
        final bytes = await file.readAsBytes();

        // Hex/entropy scan: the known row string must not appear anywhere in
        // the raw file bytes as plaintext ASCII.
        final asLatin1 = String.fromCharCodes(bytes);
        expect(
          asLatin1.contains(marker),
          isFalse,
          reason: 'known plaintext row content must not appear unencrypted '
              'on disk — SQLCipher must be actually engaged, not a no-op',
        );
        // Also scan for the default "Pessoal" seeded workspace name and the
        // literal table name — both are always present in the schema/rows,
        // and both must be unreadable ciphertext, not just the marker.
        expect(asLatin1.contains('Pessoal'), isFalse);
        expect(asLatin1.contains('workspaces'), isFalse);

        // SQLCipher replaces the first 16 bytes (the standard SQLite header
        // salt region) with random salt instead of the "SQLite format 3\0"
        // magic string — a second, independent signal that this is not a
        // plain SQLite file.
        final header = bytes.sublist(0, 16);
        expect(
          latin1.decode(header).contains('SQLite format'),
          isFalse,
          reason: 'an encrypted file must not carry the plaintext SQLite '
              'header magic',
        );
      },
    );
  });

  group('openEncryptedNativeConnection — wrong-key fails-closed (#1853 AC)',
      () {
    test(
      'reopening an existing keyed file through a DIFFERENT (unrelated) '
      'enrollment throws and never returns a usable connection',
      () async {
        if (!libReady) {
          skipIfLibMissing();
          return;
        }

        final dir =
            Directory.systemTemp.createTempSync('matome_1853_wrong_key');
        addTearDown(() => dir.deleteSync(recursive: true));

        // Enrollment A: bootstrap + write + close.
        final storeA = _FakeSecureStore();
        final executorA = await openEncryptedNativeConnection(
          keyStore: storeA,
          databaseDirectory: () async => dir.path,
        );
        final dbA = AppDatabase.forTesting(executorA);
        await dbA.workspacesDao.createWorkspace('should-not-be-readable');
        await dbA.close();

        // Enrollment B: a FRESH secure store (simulating, e.g., a restored
        // app on a different device, or a wiped/corrupted keystore) pointed
        // at the SAME on-disk file. It bootstraps its own independent DEK —
        // which is, by construction, the wrong key for the existing file.
        final storeB = _FakeSecureStore();
        await expectLater(
          openEncryptedNativeConnection(
            keyStore: storeB,
            databaseDirectory: () async => dir.path,
          ),
          throwsA(isA<SqliteException>()),
          reason: 'a wrong DEK must fail the real decrypt probe — never '
              'silently open (or worse, overwrite/recreate) the existing '
              'encrypted file',
        );

        // The file on disk must be untouched by the failed attempt: it must
        // still only open correctly under the ORIGINAL enrollment.
        final executorAAgain = await openEncryptedNativeConnection(
          keyStore: storeA,
          databaseDirectory: () async => dir.path,
        );
        final dbAAgain = AppDatabase.forTesting(executorAAgain);
        final names = (await dbAAgain.workspacesDao.getWorkspaces())
            .map((w) => w.name)
            .toList();
        await dbAAgain.close();
        expect(names, contains('should-not-be-readable'));
      },
    );
  });

  group('offline cold-start (#1853 AC)', () {
    test(
      'DB still opens with the network hard-blocked (airplane mode + '
      '/keybundle unreachable) — the device-keystore DEK path never calls '
      'out',
      () async {
        if (!libReady) {
          skipIfLibMissing();
          return;
        }

        final dir =
            Directory.systemTemp.createTempSync('matome_1853_offline_cold');
        addTearDown(() => dir.deleteSync(recursive: true));

        // Persisted store standing in for "app process dead, relaunched" —
        // its data outlives the object, exactly like the OS keystore does
        // across process restarts. First open = the prior (online) session
        // that enrolled the device; second open = the cold start under
        // test, using a FRESH provisioner/connection instance against the
        // same persisted data (no in-memory state carried over).
        final persistedStore = _FakeSecureStore();
        final warmExecutor = await openEncryptedNativeConnection(
          keyStore: persistedStore,
          databaseDirectory: () async => dir.path,
        );
        final warmDb = AppDatabase.forTesting(warmExecutor);
        await warmDb.workspacesDao.createWorkspace('offline-cold-start-row');
        await warmDb.close();

        // Cold start: block ALL network access for the duration of the
        // open — any attempt to reach `/keybundle` or anything else would
        // throw from createHttpClient, failing the test.
        await HttpOverrides.runZoned(
          () async {
            final coldExecutor = await openEncryptedNativeConnection(
              keyStore: persistedStore,
              databaseDirectory: () async => dir.path,
            );
            final coldDb = AppDatabase.forTesting(coldExecutor);
            final names = (await coldDb.workspacesDao.getWorkspaces())
                .map((w) => w.name)
                .toList();
            await coldDb.close();
            expect(names, contains('offline-cold-start-row'));
          },
          createHttpClient: (context) => throw StateError(
            'network access attempted during a simulated offline '
            'cold-start (airplane mode) — the device-keystore DEK path '
            'must never need the network',
          ),
        );
      },
    );
  });
}
