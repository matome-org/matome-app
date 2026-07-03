import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/sqlite3.dart';

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
/// **Currently `false`** by default. The KEYING MECHANISM below
/// ([openEncryptedNativeConnection]) is real and tested (task #1853, plan
/// #131 W3) — it is not a stub. What is still missing is the PRODUCTION
/// PACKAGING of a real per-platform SQLCipher shared library
/// (`.so`/`.aar`/framework) built by this repo's own build pipeline;
/// `sqlcipher_flutter_libs` cannot be co-built with `drift_flutter` in the
/// current version set (Android plugin namespace collision; Linux
/// static-OpenSSL requirement — see `tool/spike_815_sqlcipher/DECISION.md`),
/// and no replacement build step (Gradle/CMake) has landed yet. Until it
/// does, flipping this flag to `true` in a shipped build has no library to
/// point `package:sqlite3`'s `open.overrideFor` at, so the lab build keeps
/// relying on OS full-disk encryption (FDE) as the at-rest interim.
///
/// Spike #815 (task #1847, plan #131 Wave 0) proved the mechanism end-to-end
/// on Linux desktop: `package:sqlite3` + `open.overrideFor` + a SQLCipher
/// build + `PRAGMA key`/`cipher_version` round-trips correctly. Task #1853
/// (this file) wires that proven mechanism into the LIVE open path via
/// [openEncryptedNativeConnection] and the [NativeDekProvisioner] /
/// [KeyUnwrapper] key chain, and adds a real decrypt probe so a wrong key is
/// caught at open time (`cipher_version` alone does NOT prove key
/// correctness — it is a build-time constant SQLCipher reports regardless of
/// the key). Tests exercise this directly with a lib built by
/// `build_libsqlcipher.sh`; see `test/db/sqlcipher_encrypted_open_test.dart`.
///
/// Android round-trip remains UNVERIFIED (no device/emulator available) —
/// the Dart-level mechanism is platform-agnostic (same `open.overrideFor`
/// call, parameterized by `OperatingSystem`), which lowers but does not
/// eliminate that risk. This flag stays `false` by default until (1) a real
/// per-platform library is packaged and (2) the Android round-trip is
/// actually run on a device/emulator.
const bool kSqlCipherEnabled = bool.fromEnvironment(
  'MATOME_SQLCIPHER',
  defaultValue: false,
);

/// Native (Android/iOS/macOS/Linux/Windows) connection.
///
/// When [kSqlCipherEnabled] is `false` (current default), opens a plain
/// `drift_flutter` native connection — at-rest protection comes from OS FDE.
///
/// When enabled, delegates to [openEncryptedNativeConnection], which derives
/// the DEK via [NativeDekProvisioner] (the [KeyUnwrapper] device-keystore
/// backend) and keys a hand-rolled `package:sqlite3` connection with it.
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

  final store = keyStore ?? FlutterSecureKeyStore();
  // Kept as a LazyDatabase so the async key fetch + file open defer to the
  // first actual use of the connection, matching the unencrypted branch's
  // laziness.
  return LazyDatabase(
    () => openEncryptedNativeConnection(
      keyStore: store,
      databaseDirectory: _matomeDbDirectory,
    ),
  );
}

/// Opens the SQLCipher-encrypted native connection (task #1853, plan #131
/// W3): DEK from [NativeDekProvisioner] (the [KeyUnwrapper] device-keystore
/// backend, `core/crypto/key_unwrapper.dart`) -> raw `PRAGMA key` -> a
/// hand-rolled `package:sqlite3` [Database] handed to
/// [NativeDatabase.opened]. Per spike #815's DECISION.md: the connection is
/// opened directly in this isolate (not via `drift_flutter`'s
/// isolate-hosted `driftDatabase(...)`), which is what lets a test point
/// `package:sqlite3`'s `open.overrideFor` at a SQLCipher build and exercise
/// the exact same code path production would use.
///
/// A top-level function (not folded into [openPlatformConnection]) so a
/// test can call it directly — independent of the [kSqlCipherEnabled]
/// compile-time flag, no `--dart-define` needed.
///
/// **Fails closed — there is no plaintext-fallback branch in this
/// function.** Three explicit guards, none of which degrade to opening an
/// unencrypted database:
/// 1. [NativeDekProvisioner.obtainDek] throws (via the shared
///    `KeyUnwrapperUnwrap.unwrapDek` core in `key_unwrapper.dart`) on a
///    missing/wrong device-KEK or a tampered wrapped blob — propagates,
///    never regenerates a replacement DEK.
/// 2. An empty `PRAGMA cipher_version` means the loaded sqlite3 library has
///    no SQLCipher support compiled in — throws [StateError] instead of
///    silently continuing with a plain (unencrypted) engine.
/// 3. `cipher_version` alone does NOT prove the key is correct — it is a
///    build-time constant SQLCipher reports regardless of key correctness
///    (confirmed by the spike's own negative controls: an unkeyed reopen
///    still reported a version, only a real `SELECT` failed). A wrong key
///    is only caught when SQLCipher actually decrypts a page, so this
///    function runs a real read (`SELECT ... FROM sqlite_master`) right
///    after keying, BEFORE returning the connection to drift/DAOs. On a
///    freshly-created (empty) file this trivially succeeds — there is no
///    prior key to be wrong against. On an EXISTING keyed file, a wrong DEK
///    makes the probe throw [SqliteException]; the half-opened [Database]
///    handle is disposed (`_disposeOnFailure`, never returned to the
///    caller) and the exception propagates to whoever awaited this
///    function — no caller of [openPlatformConnection] can observe a
///    partially-keyed or plaintext connection.
Future<QueryExecutor> openEncryptedNativeConnection({
  required SecureKeyStore keyStore,
  required Future<String> Function() databaseDirectory,
}) async {
  final dek = await NativeDekProvisioner(keyStore).obtainDek();
  final String hexKey;
  try {
    hexKey = hexEncodeKeyBytes(dek.bytes);
  } finally {
    // Best-effort: the live DEK reference is wiped the moment the (still
    // secret-equivalent) hex form has been captured for the PRAGMA below.
    dek.wipe();
  }

  final dirPath = await databaseDirectory();
  final path = '$dirPath/matome.sqlite';
  final db = sqlite3.open(path);
  var keyed = false;
  try {
    db.execute(DbEncryptionKeyManager.pragmaKeyStatement(hexKey));
    final cipherRows = db.select('PRAGMA cipher_version;');
    final version = cipherRows.isEmpty
        ? ''
        : (cipherRows.first.values.first?.toString() ?? '');
    if (version.isEmpty) {
      throw StateError(
        'SQLCipher not active: PRAGMA cipher_version returned empty. '
        'Refusing to open an unencrypted at-rest database.',
      );
    }
    // Real decrypt probe (fails-closed guard 3, doc above) — a wrong key
    // passes PRAGMA key and cipher_version silently; only an actual read
    // surfaces the HMAC/page-decrypt failure.
    db.select('SELECT count(*) FROM sqlite_master;');
    keyed = true;
  } finally {
    if (!keyed) db.dispose();
  }
  return NativeDatabase.opened(db);
}
