import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
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
/// This flag and the [NativeDekProvisioner]/[KeyUnwrapper] chain below key
/// into the envelope-encryption hierarchy (DEK wrapped by a password-KEK,
/// recovery-KEK, or — the branch this file uses — a device-keystore KEK)
/// decided in **ADR-0002**
/// (`services/api/docs/adr/0002-envelope-encryption-key-hierarchy.md`) and
/// specified byte-for-byte in `.docs/internal/at-rest-key-flow.md`. Read
/// those first if this flag's *purpose* (not just its current `false`
/// value) is unclear — this doc comment only covers what is or isn't wired
/// on the native platform specifically.
///
/// **Currently `false`** by default. The keying mechanism below and the Linux
/// production-shaped package are real and tested. Linux CMake replaces the
/// stock sqlite3_flutter_libs target with a pinned SQLCipher amalgamation and
/// installs it beside the app. Other native platforms remain unpackaged and
/// are deliberately unsupported by the encrypted branch in this task; see
/// `tool/spike_815_sqlcipher/DECISION.md`.
///
/// Spike #815 (task #1847, plan #131 Wave 0) proved the mechanism end-to-end
/// on Linux desktop: `package:sqlite3` + `open.overrideFor` + a SQLCipher
/// build + `PRAGMA key`/`cipher_version` round-trips correctly. Task #1853
/// (this file) wires that proven mechanism into the LIVE open path via
/// [openEncryptedNativeConnection] and the [NativeDekProvisioner] /
/// [KeyUnwrapper] key chain, and adds a real decrypt probe so a wrong key is
/// caught at open time (`cipher_version` alone does NOT prove key
/// correctness — it is a build-time constant SQLCipher reports regardless of
/// the key). Linux packaging and the real-process acceptance gate live in
/// `linux/CMakeLists.txt` and `integration_test/sqlcipher_linux_bundle_test.dart`.
///
/// Android packages the fixed sqlcipher-android AAR and explicitly opens its
/// libsqlcipher.so. Task #2153 proves encrypted Drift persistence across an
/// actual force-stopped process, wrong-key and tamper rejection, and ciphertext
/// scanning on the pixel7 emulator. The flag remains `false` by default until
/// product rollout and plaintext migration are separately approved.
const bool kSqlCipherEnabled = bool.fromEnvironment(
  'MATOME_SQLCIPHER',
  defaultValue: false,
);

bool _bundledSqlCipherLoaded = false;

/// Points package:sqlite3 at the SQLCipher DSO installed beside the Linux app.
///
/// The library is resolved only from [Platform.resolvedExecutable]. There is
/// deliberately no injectable path, system-library lookup, or stock fallback.
void loadBundledLinuxSqlCipher() {
  if (_bundledSqlCipherLoaded) return;
  if (!Platform.isLinux) {
    throw UnsupportedError(
      'Bundled SQLCipher is currently implemented on Linux only.',
    );
  }

  final executable = File(Platform.resolvedExecutable);
  final library = File('${executable.parent.path}/lib/libmatome_sqlcipher.so');
  if (!library.existsSync()) {
    throw StateError(
      'Bundled SQLCipher library missing at ${library.path}; refusing a stock '
      'SQLite fallback.',
    );
  }

  sqlite3_open.open.overrideFor(
    sqlite3_open.OperatingSystem.linux,
    () => DynamicLibrary.open(library.path),
  );
  _bundledSqlCipherLoaded = true;
}

/// Points package:sqlite3 at the SQLCipher DSO packaged by sqlcipher-android.
///
/// The fixed Android AAR is an app dependency rather than a Flutter plugin, so
/// it cannot collide with sqlite3_flutter_libs' plugin namespace. Opening the
/// distinct DSO by its exact soname isolates Matome from libsqlite3.so even
/// when Android framework or plugin code has loaded stock SQLite for itself.
/// DynamicLibrary.open throws when the DSO is absent; no process or stock
/// SQLite lookup is attempted as a fallback.
void loadBundledAndroidSqlCipher() {
  if (_bundledSqlCipherLoaded) return;
  if (!Platform.isAndroid) {
    throw UnsupportedError(
      'Bundled Android SQLCipher can only be loaded on Android.',
    );
  }

  sqlite3_open.open.overrideFor(
    sqlite3_open.OperatingSystem.android,
    () => DynamicLibrary.open('libsqlcipher.so'),
  );
  _bundledSqlCipherLoaded = true;
}

void _loadBundledNativeSqlCipher() {
  if (Platform.isLinux) {
    loadBundledLinuxSqlCipher();
    return;
  }
  if (Platform.isAndroid) {
    loadBundledAndroidSqlCipher();
    return;
  }
  throw UnsupportedError(
    'Bundled SQLCipher is currently implemented on Linux and Android only.',
  );
}

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

  final store = keyStore ?? FlutterSecureKeyStore.deviceKek();
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
  try {
    return await openEncryptedNativeConnectionWithKey(
      databaseKey: dek.bytes,
      databaseDirectory: databaseDirectory,
    );
  } finally {
    dek.wipe();
  }
}

/// Production Vault-ready SQLCipher open. The caller supplies a versioned
/// account-DEK-derived key and retains ownership of wiping those bytes.
Future<QueryExecutor> openEncryptedNativeConnectionWithKey({
  required Uint8List databaseKey,
  required Future<String> Function() databaseDirectory,
}) async {
  _loadBundledNativeSqlCipher();
  final hexKey = hexEncodeKeyBytes(databaseKey);

  final dirPath = await databaseDirectory();
  await Directory(dirPath).create(recursive: true);
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
