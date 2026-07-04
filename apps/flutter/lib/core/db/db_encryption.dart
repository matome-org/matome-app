/// This file implements the device-keystore branch of the envelope-encryption
/// key hierarchy (DEK / KEK / FEK) decided in **ADR-0002**
/// (`services/api/docs/adr/0002-envelope-encryption-key-hierarchy.md`) and
/// specified byte-for-byte (wire format, KDF params) in
/// `.docs/internal/at-rest-key-flow.md` Appendix A. [DeviceKeystoreKeyUnwrapper]
/// is the "device keystore key" leaf of that hierarchy; [NativeDekProvisioner]
/// is the bootstrap that mints/persists the local half of it ahead of the
/// cross-device `/keybundle` sync this ADR also describes (see this class's
/// own KNOWN GAP note below). The native-connection consumer of the DEK this
/// file produces is `connection_native.dart`; the go/no-go for keying a real
/// SQLCipher connection with it is spike **#815**
/// (`apps/flutter/tool/spike_815_sqlcipher/DECISION.md`).
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/envelope.dart'
    show PayloadType, WrappedEnvelope, WrapperType, wrapKey;
import '../crypto/key_material.dart'
    show Dek, Kek, kSymmetricKeyLength, secureRandomBytes;
import '../crypto/key_unwrapper.dart'
    show KeyUnwrapper, KeyUnwrapperUnwrap;

/// Minimal key/value contract [FlutterSecureKeyStore], [NativeDekProvisioner],
/// and [DeviceKeystoreKeyUnwrapper] need from a secure store. Abstracted so
/// tests can inject a fake in-memory store without the `flutter_secure_storage`
/// platform channel (mirrors [TokenStore]'s design).
abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// [SecureKeyStore] backed by `flutter_secure_storage`. The SQLCipher key lives
/// in the OS keystore (Keychain / Keystore / libsecret), NOT inside the DB file.
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  /// Hardened device-KEK constructor (task #1863, okt-audit SHIP-BLOCKER B2).
  ///
  /// Always backed by [buildDeviceKekSecureStorage] — i.e. `resetOnError:
  /// false` is enforced regardless of call site. Every PRODUCTION site that
  /// reads/writes the device-KEK (`connection_native.dart`'s
  /// [openPlatformConnection] default, `inbox_upload.dart`'s media-DEK
  /// source) MUST construct through this factory, never the bare default
  /// constructor above — the bare form falls through to
  /// `const FlutterSecureStorage()`, whose 10.x default silently WIPES the
  /// device-KEK on a transient Android keystore decrypt error (see
  /// [buildDeviceKekSecureStorage]'s doc for the full failure chain).
  FlutterSecureKeyStore.deviceKek() : this(buildDeviceKekSecureStorage());

  final FlutterSecureStorage _storage;

  /// Exposed so tests can assert the PRODUCTION construction path (not just
  /// the free function in isolation) carries the hardened options — see
  /// `test/db/db_encryption_test.dart`'s `FlutterSecureKeyStore.deviceKek`
  /// group.
  @visibleForTesting
  FlutterSecureStorage get debugStorage => _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Namespace for the `PRAGMA key` statement builder used to key the native
/// SQLCipher connection.
///
/// HISTORY / STALE-DOC FIX (okt-audit info follow-up, #1866): this class
/// used to ALSO generate + persist its own ad-hoc 256-bit passphrase
/// (`obtainKey`/`_generateHexKey`, keyed under `storageKey` in a
/// [SecureKeyStore]) as a standalone SQLCipher-key bootstrap. That instance
/// code was superseded by [NativeDekProvisioner] (the [KeyUnwrapper]
/// device-keystore chain wired into `connection_native.dart`'s
/// [openEncryptedNativeConnection]) — which derives the real DEK through the
/// shared envelope-encryption hierarchy instead of a one-off local secret —
/// and became DEAD: no production call site ever constructed
/// `DbEncryptionKeyManager(...)`. It has been removed. The only piece still
/// used in production is the static [pragmaKeyStatement] helper below
/// (`connection_native.dart:154`), kept as a class member purely so that
/// call site's `DbEncryptionKeyManager.pragmaKeyStatement(...)` reference
/// did not need to change.
class DbEncryptionKeyManager {
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
/// stored value instead of throwing (the same footgun the removed
/// `DbEncryptionKeyManager` instance code used to carry a NOTE about, see
/// that class's doc above). For the device-KEK a silent wipe is even worse:
/// it is the ONLY key that unwraps
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
/// Construct with a [FlutterSecureKeyStore.deviceKek] (built over
/// [buildDeviceKekSecureStorage], not the bare default `FlutterSecureStorage`)
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

/// Lowercase hex encoding shared by every raw key material this file
/// produces: the [NativeDekProvisioner] device-KEK bootstrap, and (via
/// `connection_native.dart`) the final DEK handed to `PRAGMA key`. One
/// implementation so the wire shape (`^[0-9a-f]+$`, even length) can't drift
/// between call sites.
String hexEncodeKeyBytes(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Provisions -- bootstraps once, then reuses -- the DEK that keys the live
/// native SQLCipher connection (task #1853, plan #131 W3), entirely through
/// the shared [KeyUnwrapper] core in `key_unwrapper.dart` that W1
/// ([DeviceKeystoreKeyUnwrapper], [WrappedEnvelope]) built but did not yet
/// wire into the open path.
///
/// **No enrollment/login flow exists yet** to sync a server-issued
/// `wrapped_dek_pw` down to this device -- `/keybundle` (task #1851) is a
/// separate Core API concern from this native storage layer, and the actual
/// password-entry UI is a later wave. So on a device that has never
/// unlocked before, [obtainDek] bootstraps entirely OFFLINE: it generates a
/// fresh device-KEK (if the OS keystore doesn't already have one under
/// [DeviceKeystoreKeyUnwrapper.storageKey]) and a fresh [Dek], wraps the DEK
/// under that device-KEK (`wrapper_type = deviceKek`, the same
/// [WrappedEnvelope] layout `wrapped_dek_device` uses everywhere else in the
/// design), and persists the wrapped blob locally under
/// [wrappedDekStorageKey]. Every later call reuses that SAME wrapped blob
/// through [DeviceKeystoreKeyUnwrapper.unwrapDek] (the `KeyUnwrapperUnwrap`
/// extension -- the one unwrap core every backend shares, see that file's
/// INVARIANT note) — so a missing/corrupted device-KEK or a tampered
/// wrapped blob throws EXPLICITLY (a [StateError] or
/// [EnvelopeTamperException]) instead of silently regenerating a new DEK,
/// which would orphan the existing encrypted database. There is no
/// plaintext-fallback branch anywhere in this class.
///
/// **KNOWN GAP (flagged, not silently swallowed):** this bootstrap does not
/// sync the DEK to any other device via the server-side `wrapped_dek_pw` --
/// a second device enrolling today would mint its OWN independent DEK, not
/// the account's shared one, and it does not migrate an existing PLAINTEXT
/// `matome.sqlite` written before [kSqlCipherEnabled] was ever turned on for
/// this install (flipping the flag on a device with an existing plaintext
/// file would try to open it with a key it was never written with --
/// SQLCipher would reject it, which is fails-closed but not a migration).
/// Both are out of this task's scope: cross-device DEK sync needs the
/// login/password UI flow (task #1851 and beyond); an existing-plaintext-DB
/// migration is not covered by any task in this plan today and should be
/// tracked before [kSqlCipherEnabled] ever flips on for a real user install.
class NativeDekProvisioner {
  NativeDekProvisioner(this._store);

  final SecureKeyStore _store;

  /// Secure-store key under which the base64 [WrappedEnvelope] wrapping the
  /// DEK under the device-KEK is kept. The blob is ciphertext (AEAD output),
  /// so storing it alongside the device-KEK in the OS keystore is
  /// belt-and-suspenders, not a secrecy requirement of the blob itself.
  static const String wrappedDekStorageKey = 'matome.db.wrapped_dek_device';

  Future<Dek> obtainDek() async {
    final existing = await _store.read(wrappedDekStorageKey);
    if (existing != null && existing.isNotEmpty) {
      // Already enrolled (this boot or a prior one): unwrap through the
      // SHARED core -- fails closed on a missing/wrong device-KEK or a
      // tampered blob, never regenerates. No network involved (offline
      // cold-start, #1853 AC).
      final wrapped = WrappedEnvelope.fromBase64(existing);
      return DeviceKeystoreKeyUnwrapper(_store).unwrapDek(wrapped);
    }

    // First-ever unlock on this device: bootstrap entirely offline (no
    // network / no /keybundle round-trip -- see class doc KNOWN GAP).
    final kekBytes = await _obtainOrCreateDeviceKek();
    final dek = Dek.generate();
    final wrapped = await wrapKey(
      plaintext: dek.bytes,
      wrappingKey: kekBytes,
      payloadType: PayloadType.dek,
      wrapperType: WrapperType.deviceKek,
    );
    await _store.write(wrappedDekStorageKey, wrapped.toBase64());
    return dek;
  }

  Future<Uint8List> _obtainOrCreateDeviceKek() async {
    final existingHex =
        await _store.read(DeviceKeystoreKeyUnwrapper.storageKey);
    if (existingHex != null && existingHex.isNotEmpty) {
      return _hexDecode(existingHex);
    }
    final bytes = secureRandomBytes(kSymmetricKeyLength);
    await _store.write(
      DeviceKeystoreKeyUnwrapper.storageKey,
      hexEncodeKeyBytes(bytes),
    );
    return bytes;
  }
}
