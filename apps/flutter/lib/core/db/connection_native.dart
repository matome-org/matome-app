import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../storage/app_storage.dart';
import 'db_encryption.dart';

/// Drift's `databaseDirectory` hook: resolve the dedicated Matome folder and
/// move a legacy `matome.sqlite` (from the old Documents-root location) into it
/// BEFORE the database file is opened, so existing data survives.
Future<String> _matomeDbDirectory() async {
  final dir = await matomeStorageDir();
  await moveLegacyDatabaseInto(dir);
  return dir.path;
}

/// Whether to apply SQLCipher at-rest encryption on native platforms.
///
/// **Currently `false`** (#815). `sqlcipher_flutter_libs` cannot
/// be co-built with `drift_flutter` in the current version set (Android plugin
/// namespace collision; Linux static-OpenSSL requirement), so the lab build
/// relies on OS full-disk encryption (FDE) for at-rest protection. The keying
/// machinery ([DbEncryptionKeyManager]) is shipped and unit-tested so flipping
/// this to `true` (after dropping `drift_flutter` for a hand-rolled native
/// connection, or a sqlcipher build with a distinct namespace) is a localized
/// change — the `setup`/`isolateSetup` recipe is documented below.
///
/// Spike #815 (task #1847, plan #131 Wave 0) proved this exact recipe
/// end-to-end on Linux desktop: `package:sqlite3` + `open.overrideFor` +
/// a SQLCipher build + `PRAGMA key`/`cipher_version` round-trips correctly,
/// and confirmed (not just theorized) that `sqlcipher_flutter_libs`' Linux
/// CMake fails on shared-OpenSSL-only distros. Verdict: GO on the
/// **hand-rolled connection**, not a namespaced fork of the stock plugin —
/// see `tool/spike_815_sqlcipher/DECISION.md` and
/// `test/db/sqlcipher_native_spike_test.dart`. Android round-trip remains
/// unverified (no device/emulator in that spike); this flag stays `false`
/// until the production per-platform library build lands and the connection
/// construction below is swapped for `NativeDatabase.opened(...)` over a
/// hand-rolled `sqlite3.open()` (today's `driftDatabase(..., setup: ...)`
/// path still depends on the very drift_flutter native setup whose co-build
/// was in question).
const bool kSqlCipherEnabled = bool.fromEnvironment(
  'MATOME_SQLCIPHER',
  defaultValue: false,
);

/// Native (Android/iOS/macOS/Linux/Windows) connection.
///
/// When [kSqlCipherEnabled] is `false` (current default), opens a plain
/// `drift_flutter` native connection — at-rest protection comes from OS FDE.
///
/// When enabled, the connection would obtain a 256-bit key from [keyStore]
/// (generated on first boot, stored in `flutter_secure_storage`) and key the
/// SQLCipher-built native library via drift's native `setup`/`isolateSetup`
/// hooks. The exact recipe (override `package:sqlite3` `open` to the SQLCipher
/// build in `isolateSetup`; `PRAGMA key = "x'<hex>'"` + a `cipher_version`
/// assertion in `setup`) is documented in the migration report.
QueryExecutor openPlatformConnection({SecureKeyStore? keyStore}) {
  if (!kSqlCipherEnabled) {
    return driftDatabase(
      name: 'matome',
      native: DriftNativeOptions(databaseDirectory: _matomeDbDirectory),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // Encrypted path — only reachable once a SQLCipher-capable native lib is
  // packaged (see kSqlCipherEnabled doc). Kept as a LazyDatabase so the async
  // key fetch defers to the first open.
  final keyManager = DbEncryptionKeyManager(
    keyStore ?? FlutterSecureKeyStore(),
  );
  return LazyDatabase(() async {
    final hexKey = await keyManager.obtainKey();
    return driftDatabase(
      name: 'matome',
      native: DriftNativeOptions(
        databaseDirectory: _matomeDbDirectory,
        setup: (db) {
          db.execute(DbEncryptionKeyManager.pragmaKeyStatement(hexKey));
          final cipher = db.select('PRAGMA cipher_version');
          final version = cipher.isEmpty
              ? ''
              : (cipher.first.values.first?.toString() ?? '');
          if (version.isEmpty) {
            throw StateError(
              'SQLCipher not active: PRAGMA cipher_version returned empty. '
              'Refusing to open an unencrypted at-rest database.',
            );
          }
        },
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  });
}
