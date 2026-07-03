import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/key_material.dart' show Kek;
import '../crypto/key_unwrapper.dart' show KeyUnwrapper;

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
    final bytes = List<int>.generate(_keyBytes, (_) => _random.nextInt(256));
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
  static String pragmaKeyStatement(String hexKey) =>
      "PRAGMA key = \"x'$hexKey'\"";
}

/// Builds the [FlutterSecureStorage] instance backing the device-KEK slot
/// (task #1850, plan #131 W1) — used by [DeviceKeystoreKeyUnwrapper].
///
/// CRITICAL: flutter_secure_storage 10.x's `AndroidOptions.resetOnError`
/// defaults to `true` — on a platform decrypt error the backend WIPES the
/// stored value instead of throwing (see [DbEncryptionKeyManager.obtainKey]
/// doc above for the same footgun on the SQLCipher passphrase). For the
/// device-KEK a silent wipe is even worse: it is the ONLY key that unwraps
/// `wrapped_dek_device` for the passwordless native unlock path, so losing
/// it is an unrecoverable lockout unless the user also has their password
/// or recovery code enrolled. This constructor MUST always pass
/// `resetOnError: false` — never rely on the package default.
///
/// `resetOnError` is Android-specific in flutter_secure_storage's API (see
/// `AndroidOptions`); iOS/macOS Keychain and the Linux/Windows backends this
/// package uses have no equivalent "wipe on decrypt error" behavior to begin
/// with, so there is nothing to disable on those platforms.
FlutterSecureStorage buildDeviceKekSecureStorage() =>
    const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    );

/// [KeyUnwrapper] backend — device-keystore (task #1850, plan #131 W1).
///
/// Passwordless unlock: the device-KEK bytes live in the OS keystore
/// (Keychain / Keystore / DPAPI / libsecret), read via [SecureKeyStore] —
/// never derived from anything the user types. Unwraps `wrapped_dek_device`.
///
/// Construct with a [FlutterSecureKeyStore] built over
/// [buildDeviceKekSecureStorage] (not the bare default `FlutterSecureStorage`)
/// so `resetOnError: false` is enforced. This class only *reads* the
/// device-KEK — writing it happens at enrollment time, out of scope here
/// (see #1853/#1854).
///
/// The unwrap itself is NOT reimplemented here: [deriveKEK] is the only
/// backend-specific piece; the actual unwrap runs through the shared
/// `KeyUnwrapper.unwrapDek` extension in `core/crypto/key_unwrapper.dart`,
/// identically to [PasswordKeyUnwrapper] — see that file's INVARIANT note.
class DeviceKeystoreKeyUnwrapper implements KeyUnwrapper {
  DeviceKeystoreKeyUnwrapper(this._store);

  final SecureKeyStore _store;

  /// Secure-store key under which the raw device-KEK (hex-encoded, 32
  /// bytes) is kept.
  static const String storageKey = 'matome.db.device_kek';

  @override
  Future<Kek> deriveKEK() async {
    final hex = await _store.read(storageKey);
    if (hex == null || hex.isEmpty) {
      throw StateError(
        'device KEK not found in secure store — the device-keystore '
        'backend requires prior enrollment (wrapped_dek_device + device '
        'KEK write); no silent fallback or regeneration is performed',
      );
    }
    return Kek(_hexDecode(hex));
  }
}

Uint8List _hexDecode(String hexString) {
  if (hexString.length.isOdd) {
    throw FormatException(
      'hex string must have an even length',
      hexString,
    );
  }
  final bytes = Uint8List(hexString.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
