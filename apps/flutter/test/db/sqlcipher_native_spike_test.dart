@Tags(['native_spike'])
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart';

// ---------------------------------------------------------------------------
// Spike #815 / plan p1-unified-login-encryption (task #1847): go/no-go proof
// that a hand-rolled native connection CAN key a real SQLCipher build with a
// raw 32-byte DEK and round-trip data through it, on Linux desktop.
//
// This is deliberately NOT wired through `openPlatformConnection` /
// `kSqlCipherEnabled` (connection_native.dart) — that flag stays `false` until
// the *production* build story (a namespaced sqlcipher_flutter_libs, or a
// hand-rolled CMake/gradle recipe using shared OpenSSL) lands. This test only
// proves the mechanism package:sqlite3 + `open.overrideFor` + a SQLCipher
// shared library + `PRAGMA key = "x'<hex>'"` actually works end-to-end,
// against a *hand-built* libsqlcipher (see tool/spike_815_sqlcipher/), so the
// team can commit to the design in confidence before writing envelope code.
//
// Opt-in only: requires MATOME_SQLCIPHER_POC_LIB pointing at a compiled
// libsqlcipher_poc.so (build it with
// tool/spike_815_sqlcipher/build_libsqlcipher.sh). Skipped by default (not
// buildable in ordinary CI without a C toolchain + the vendored SQLCipher
// amalgamation); run explicitly with:
//   MATOME_SQLCIPHER_POC_LIB=/path/to/libsqlcipher_poc.so \
//     flutter test --tags native_spike --run-skipped \
//       test/db/sqlcipher_native_spike_test.dart
// ---------------------------------------------------------------------------

void main() {
  final libPath = Platform.environment['MATOME_SQLCIPHER_POC_LIB'];

  group('SQLCipher raw-DEK round trip (Linux desktop hand-rolled connection)',
      () {
    test(
      'open -> key(DEK) -> write -> close -> reopen -> read; '
      'cipher_version non-empty; wrong/no key refused',
      () {
        if (libPath == null || libPath.isEmpty || !File(libPath).existsSync()) {
          markTestSkipped(
            'MATOME_SQLCIPHER_POC_LIB not set / library not built — see '
            'tool/spike_815_sqlcipher/build_libsqlcipher.sh',
          );
          return;
        }

        sqlite3_open.open.overrideFor(
          sqlite3_open.OperatingSystem.linux,
          () => DynamicLibrary.open(libPath),
        );

        final dir = Directory.systemTemp.createTempSync('matome_sqlcipher_spike');
        addTearDown(() => dir.deleteSync(recursive: true));
        final path = '${dir.path}/spike.db';

        final dek = _generateHexDek();

        String cipherVersionOf(Database db) {
          final rows = db.select('PRAGMA cipher_version;');
          return rows.isEmpty ? '' : (rows.first.values.first?.toString() ?? '');
        }

        // Open #1: key + assert + write + close.
        var db = sqlite3.open(path);
        db.execute(DbEncryptionKeyManager.pragmaKeyStatement(dek));
        expect(
          cipherVersionOf(db),
          isNotEmpty,
          reason: 'PRAGMA cipher_version must be non-empty once keyed — an '
              'empty result means SQLCipher refused/never engaged and we would '
              'silently be writing plaintext.',
        );
        db.execute('CREATE TABLE spike(id INTEGER PRIMARY KEY, note TEXT);');
        db.execute("INSERT INTO spike(id, note) VALUES (1, 'roundtrip-ok');");
        db.dispose();

        // Open #2 (reopen): key + assert + read back.
        db = sqlite3.open(path);
        db.execute(DbEncryptionKeyManager.pragmaKeyStatement(dek));
        expect(cipherVersionOf(db), isNotEmpty);
        final rows = db.select('SELECT note FROM spike WHERE id = 1;');
        expect(rows, hasLength(1));
        expect(rows.first['note'], 'roundtrip-ok');
        db.dispose();

        // Negative control: reopen WITHOUT the key must not read plaintext.
        db = sqlite3.open(path);
        expect(
          () => db.select('SELECT note FROM spike WHERE id = 1;'),
          throwsA(isA<SqliteException>()),
          reason: 'Without PRAGMA key the file must not be readable as '
              'plaintext SQLite — that would mean the DB is NOT encrypted '
              'at rest.',
        );
        db.dispose();
      },
    );
  });
}

/// A 256-bit hex DEK shaped exactly like [DbEncryptionKeyManager]'s
/// production key (32 raw bytes -> 64 lowercase hex chars), so
/// [DbEncryptionKeyManager.pragmaKeyStatement] is exercised with a realistic
/// input.
String _generateHexDek() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
