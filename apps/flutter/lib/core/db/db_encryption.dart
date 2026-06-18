import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value contract the [DbEncryptionKeyManager] needs from a secure
/// store. Abstracted so tests can inject a fake in-memory store without the
/// `flutter_secure_storage` platform channel (mirrors [TokenStore]'s design).
abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// [SecureKeyStore] backed by `flutter_secure_storage`. The SQLCipher key lives
/// in the OS keystore (Keychain / Keystore / libsecret), NOT inside the DB file.
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Generates (once, on first boot) and persists the 256-bit SQLCipher passphrase
/// used to encrypt the native Drift database at-rest.
///
/// First boot: a 32-byte key is drawn from [Random.secure], hex-encoded, and
/// written to the secure store. Every subsequent boot reads the same key back,
/// so the existing encrypted DB keeps opening. The key never touches the DB file
/// or app logs.
///
/// The passphrase is applied as a raw key (`PRAGMA key = "x'<hex>'"`) so
/// SQLCipher uses the bytes verbatim — no PBKDF key-derivation salt collision
/// and a deterministic round-trip across boots.
class DbEncryptionKeyManager {
  DbEncryptionKeyManager(this._store, {Random? random})
      : _random = random ?? Random.secure();

  final SecureKeyStore _store;
  final Random _random;

  /// Secure-store key under which the hex passphrase is kept.
  static const String storageKey = 'matome.db.sqlcipher_key';

  static const int _keyBytes = 32; // 256-bit

  /// NOTE (flutter_secure_storage 10.x): `AndroidOptions.resetOnError` now
  /// defaults to `true` — on a platform decrypt error the backend WIPES the
  /// stored value instead of throwing. For the JWT (token_store) that only
  /// forces a re-login, but for THIS SQLCipher passphrase a silent wipe is
  /// unrecoverable: [obtainKey] would then read empty, generate a *new* key,
  /// and the existing encrypted Drift DB could never be reopened. When at-rest
  /// encryption is switched on (`kSqlCipherEnabled`), construct the backing
  /// [FlutterSecureStorage] with `aOptions: AndroidOptions(resetOnError: false)`
  /// so a transient read error degrades to an explicit failure, not data loss.
  ///
  /// Returns the persisted passphrase, generating + storing one on first boot.
  Future<String> obtainKey() async {
    final existing = await _store.read(storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateHexKey();
    await _store.write(storageKey, generated);
    return generated;
  }

  String _generateHexKey() {
    final bytes =
        List<int>.generate(_keyBytes, (_) => _random.nextInt(256));
    return _hex(bytes);
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Builds the `PRAGMA key` statement for a raw hex passphrase. SQLCipher reads
  /// `x'...'` as the literal key bytes (no KDF), giving a stable round-trip.
  static String pragmaKeyStatement(String hexKey) => "PRAGMA key = \"x'$hexKey'\"";
}
