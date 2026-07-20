import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_data.dart' show Uint8Buffer;
import 'package:matome_vault/matome_vault.dart' show VaultKeyMaterial;

import '../crypto/key_material.dart' show Dek, Kek;
import '../crypto/key_unwrapper.dart' show KeyUnwrapper, PasswordKeyUnwrapper;
import 'db_encryption.dart';
import 'encrypted_blob_store.dart';
import 'web_key_bundle_cache.dart';
import 'web_opfs_blob_store.dart';
import 'web_store_opener.dart';

/// Web connection — task #1860, plan #131 (web wave).
///
/// ## Two entry points, mirroring `connection_native.dart`'s
/// `openPlatformConnection` / `openEncryptedNativeConnection` split
///
/// - [openPlatformConnection] — the DEFAULT pre-unlock path. Unchanged
///   observable behavior from before this task: an **in-memory** sqlite3
///   store (`WasmDatabase.inMemory` + `InMemoryFileSystem`), re-hydrated from
///   the Core API on each load, nothing touches OPFS. Per the AC ("in-memory
///   becomes a FALLBACK, not the default"), this remains the path used when
///   no password/DEK is available yet (pre-login) or when OPFS is
///   unavailable/unsupported browsers must remain blocked; callers must never
///   substitute this plaintext/in-memory path after an encrypted open fails.
/// - [openEncryptedWebConnection] — the NEW real persistence path. Requires a
///   password (the cold-start prompt) and either a cached or freshly-fetched
///   keybundle; opens (or creates) the OPFS-encrypted store under the DEK.
///
/// **Why the split, not a single always-persistent default:** unlike native
/// (device-KEK sits in the OS keystore, already unlocked by OS login — see
/// `connection_native.dart`'s `NativeDekProvisioner`), web has no keystore.
/// The DEK can only come from the user's password (§4 of
/// `.docs/internal/at-rest-key-flow.md`), which is not known at the point
/// `openConnection()` is called today (`core/providers.dart`'s
/// `appDatabaseProvider` builds `AppDatabase()` eagerly, before any login
/// screen runs — exactly the same reason `connection_native.dart`'s
/// SQLCipher path, `openEncryptedNativeConnection`, is ALSO not wired into
/// that default provider yet, `kSqlCipherEnabled` stays `false`). Wiring a
/// cold-start password-prompt screen in front of `appDatabaseProvider` (so it
/// awaits [openEncryptedWebConnection] instead of calling
/// [openPlatformConnection] unconditionally) is the remaining integration
/// step this task's return-note flags as follow-up UI work — the mechanism
/// below is complete, tested, and ready for that wiring.
///
/// ## Real encrypted-OPFS persistence (AC option (b), the stated MVP)
///
/// A full custom page-level sqlite3 VFS (encrypt every 4096-byte page against
/// a real OPFS VFS) needs a dedicated Web Worker + `SharedArrayBuffer` +
/// cross-origin-isolation (COOP/COEP) headers — see
/// `package:sqlite3/wasm.dart`'s `SimpleOpfsFileSystem` doc comment ("only
/// available in dedicated web workers"). That infra is not added in this
/// pass. Instead: the whole decrypted DB image is held in an
/// [InMemoryFileSystem] while the store is open (tradeoff: the full DB lives
/// in page memory, same as before this task, just now ALSO durable across
/// reloads), and is persisted as one AEAD-chunked encrypted blob
/// (`core/crypto/db_image_cipher.dart`) to a single OPFS file
/// (`web_opfs_blob_store.dart`, main-thread async File System Access API —
/// confirmed working with no worker/cross-origin-isolation requirement
/// against a real Chromium tab during this task). The bytes that reach OPFS
/// are ALWAYS ciphertext — [OpfsBlobStore.write] never receives plaintext,
/// only what [WebStoreOpener.persist] already encrypted.
///
/// UPGRADE SEAM: swapping in a page-level VFS later only changes *how often*
/// and *at what granularity* `encryptDbImage`/`decryptDbImage` get called
/// (once per checkpoint here vs. once per page there); the [EncryptedBlobStore]
/// contract and the wire format stay the same.
///
/// **okt-audit SHIP-BLOCKER B1 fix (task #1862):** this Timer re-encrypts the
/// whole image under the SAME `result.dek` on every tick for the life of the
/// session — `db_image_cipher.dart`'s v2 format is what makes that safe: each
/// `encryptDbImage` call mints a FRESH per-image FEK (never the stable DEK
/// directly), so no number of repeated calls under one `dek` can ever
/// collide a (key, nonce) pair. See that module's doc comment for the full
/// nonce-reuse writeup.
///
/// The [keyStore] argument on [openPlatformConnection] is accepted for a
/// uniform cross-platform signature (`core/db/connection.dart`) but unused —
/// the in-memory fallback has no at-rest key to manage.
QueryExecutor openPlatformConnection({SecureKeyStore? keyStore}) {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
    return WasmDatabase.inMemory(sqlite3);
  });
}

/// How often the open store's current bytes are re-encrypted and rewritten
/// to OPFS. A timer-based checkpoint rather than a per-write hook (the
/// `DelegatedDatabase`/`WasmDatabase` surface doesn't expose an "after every
/// statement" callback without more invasive wrapping) — the stated MVP
/// tradeoff: durability lags live writes by up to this interval instead of
/// being synchronous. A crash/tab-close within this window loses only that
/// window's writes, never corrupts the previously-persisted (still valid
/// ciphertext) image.
const Duration kWebAutoPersistInterval = Duration(seconds: 4);

const String _kDbPath = '/database';

/// Opens the REAL encrypted web store (task #1860): unwraps the DEK from
/// [password] via the shared [PasswordKeyUnwrapper]/`KeyUnwrapper` core (NO
/// web-specific fork of the unwrap logic — same class every platform's
/// password backend uses), then decrypts (or, on a fresh install, prepares to
/// create) the OPFS-persisted image.
///
/// [keyBundleCache] supplies `salt_enc` + `wrapped_dek_pw` + `kdf_params`
/// offline, if this device+browser has logged in online before
/// (`web_key_bundle_cache.dart`). If nothing is cached yet,
/// [fetchKeyBundleOnline] is called (the real `/keybundle` HTTP fetch is the
/// caller's job — this function has no HTTP client dependency) and its
/// result is cached for next time. If neither a cache hit nor
/// [fetchKeyBundleOnline] is available, this throws [StateError] — the CF-1
/// gap flagged in this task: a browser that has NEVER completed an online
/// `/keybundle` round trip cannot cold-start offline. A RETURNING user (one
/// prior online login) works fully offline from here on.
///
/// **Fails closed** — a wrong [password] or a tampered/corrupted persisted
/// blob makes [WebStoreOpener.open] throw (see that method's doc comment for
/// the exact exception types); this function does not catch those and fall
/// back to a fresh empty database. Callers (the password-prompt UI) must
/// surface the error, not retry with a silently-substituted empty store.
/// [debugPhase] is reserved for browser test harness diagnostics and should be
/// omitted by application callers.
Future<WebEncryptedQueryExecutor> openEncryptedWebConnection({
  required String password,
  required WebKeyBundleCache keyBundleCache,
  EncryptedBlobStore? blobStore,
  Future<CachedKeyBundleSaltInfo> Function()? fetchKeyBundleOnline,
  Duration autoPersistInterval = kWebAutoPersistInterval,
  void Function(String phase, Duration? elapsed)? debugPhase,
}) async {
  final store = blobStore ?? OpfsBlobStore();

  var info = await keyBundleCache.read();
  if (info == null) {
    if (fetchKeyBundleOnline == null) {
      throw StateError(
        'No cached keybundle on this device/browser and no online fetch '
        'was supplied. This is the CF-1 gap: a browser that has never '
        'completed an online GET/PUT /keybundle round trip has no '
        'salt_enc to derive a password-KEK from, so a true first-ever '
        'cold start cannot be fully offline. Pass fetchKeyBundleOnline '
        'so first login can populate the cache for every later offline '
        'cold start.',
      );
    }
    info = await fetchKeyBundleOnline();
    await keyBundleCache.write(info);
  }

  KeyUnwrapper unwrapper = PasswordKeyUnwrapper(
    password: password,
    saltEnc: info.saltEnc,
    params: info.kdfParams,
  );
  if (debugPhase != null) {
    unwrapper = _DiagnosticKeyUnwrapper(unwrapper, debugPhase);
  }

  final opener = WebStoreOpener(blobStore: store);
  // Fails closed inside `opener.open` (see its doc comment): propagates on a
  // wrong password or a tampered persisted blob — no catch-and-fallback here.
  final result = await opener.open(
    unwrapper: unwrapper,
    wrappedDekPw: info.wrappedDekPw,
  );
  debugPhase?.call('envelope-unlock:after', null);

  debugPhase?.call('wasm-load:before', null);
  final wasmStopwatch = Stopwatch()..start();
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  debugPhase?.call('wasm-load:after', wasmStopwatch.elapsed);
  final vfs = InMemoryFileSystem();
  final plaintextImage = result.plaintextImage;
  if (plaintextImage != null) {
    vfs.fileData[_kDbPath] = Uint8Buffer()..addAll(plaintextImage);
  }
  sqlite3.registerVirtualFileSystem(vfs, makeDefault: true);

  debugPhase?.call('sqlite-open:before', null);
  final db = WasmDatabase(sqlite3: sqlite3, path: _kDbPath);
  debugPhase?.call('sqlite-open:after', null);

  return WebEncryptedQueryExecutor._(
    db,
    vfs,
    opener,
    result.dek,
    autoPersistInterval,
  );
}

/// Opens encrypted account-scoped OPFS using the DEK already unlocked by the
/// Vault session. No password or KEK enters this layer.
Future<WebEncryptedQueryExecutor> openEncryptedWebConnectionWithKeyMaterial({
  required VaultKeyMaterial keyMaterial,
  required EncryptedBlobStore blobStore,
  Duration autoPersistInterval = kWebAutoPersistInterval,
}) async {
  final dek = await keyMaterial.use((bytes) => Dek(Uint8List.fromList(bytes)));
  final opener = WebStoreOpener(blobStore: blobStore);
  try {
    final result = await opener.openWithDek(dek);
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final vfs = InMemoryFileSystem();
    final plaintextImage = result.plaintextImage;
    if (plaintextImage != null) {
      vfs.fileData[_kDbPath] = Uint8Buffer()..addAll(plaintextImage);
    }
    sqlite3.registerVirtualFileSystem(vfs, makeDefault: true);
    final db = WasmDatabase(sqlite3: sqlite3, path: _kDbPath);
    return WebEncryptedQueryExecutor._(
      db,
      vfs,
      opener,
      result.dek,
      autoPersistInterval,
    );
  } catch (_) {
    dek.wipe();
    rethrow;
  }
}

final class _DiagnosticKeyUnwrapper implements KeyUnwrapper {
  _DiagnosticKeyUnwrapper(this._inner, this._report);

  final KeyUnwrapper _inner;
  final void Function(String phase, Duration? elapsed) _report;

  @override
  Future<Kek> deriveKEK() async {
    _report('argon2-unlock:before', null);
    final stopwatch = Stopwatch()..start();
    final kek = await _inner.deriveKEK();
    _report('argon2-unlock:after', stopwatch.elapsed);
    _report('envelope-unlock:before', null);
    return kek;
  }
}

/// Owns one decrypted in-memory SQLite session and its encrypted OPFS
/// checkpoints. Checkpoints are serialized so a slow older write can never
/// replace a newer snapshot. [close] cancels the timer and performs one final
/// flush before closing SQLite and wiping the session DEK.
final class WebEncryptedQueryExecutor implements QueryExecutor {
  WebEncryptedQueryExecutor._(
    this._inner,
    this._vfs,
    this._opener,
    this._dek,
    Duration autoPersistInterval,
  ) {
    _timer = Timer.periodic(autoPersistInterval, (_) {
      unawaited(
        checkpoint().catchError((Object error, StackTrace stackTrace) {
          _lastTimerError = (error, stackTrace);
        }),
      );
    });
  }

  final QueryExecutor _inner;
  final InMemoryFileSystem _vfs;
  final WebStoreOpener _opener;
  final Dek _dek;
  late final Timer _timer;
  Future<void> _checkpointTail = Future.value();
  Uint8List? _lastPersisted;
  (Object, StackTrace)? _lastTimerError;
  Future<void>? _closeFuture;
  bool _closed = false;

  /// Immediately schedules a durable encrypted snapshot after every earlier
  /// checkpoint. Timer failures are surfaced by the next explicit checkpoint
  /// or [close], rather than becoming unhandled asynchronous errors.
  Future<void> checkpoint() {
    if (_closed) {
      return Future.error(StateError('Encrypted web store is already closed'));
    }

    return _enqueueCheckpoint();
  }

  Future<void> _enqueueCheckpoint() {
    final previous = _checkpointTail;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // The caller of the failed checkpoint received that error. A later
        // checkpoint must still be able to persist a newer valid snapshot.
      }

      final timerError = _lastTimerError;
      _lastTimerError = null;

      final buffer = _vfs.fileData[_kDbPath];
      if (buffer != null) {
        final current = buffer.buffer.asUint8List(0, buffer.length);
        if (_lastPersisted == null || !_bytesEqual(current, _lastPersisted!)) {
          final snapshot = Uint8List.fromList(current);
          await _opener.persist(plaintextImage: snapshot, dek: _dek);
          _lastPersisted = snapshot;
        }
      }

      if (timerError != null) {
        Error.throwWithStackTrace(timerError.$1, timerError.$2);
      }
    }();
    _checkpointTail = next;
    return next;
  }

  @override
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;

    _closed = true;
    _timer.cancel();
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    Object? checkpointError;
    StackTrace? checkpointStack;
    try {
      await _enqueueCheckpoint();
    } catch (error, stackTrace) {
      checkpointError = error;
      checkpointStack = stackTrace;
    }
    try {
      await _inner.close();
    } finally {
      _dek.wipe();
    }
    if (checkpointError != null) {
      Error.throwWithStackTrace(checkpointError, checkpointStack!);
    }
  }

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _inner.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _inner.runInsert(statement, args);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) => _inner.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
