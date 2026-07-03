// KeyUnwrapper strategy interface — task #1850, plan #131 W1.
//
// This is the unified spine every platform's disk-decryption path shares
// (§3 of .docs/internal/at-rest-key-flow.md): obtain a wrapped DEK ->
// derive/obtain a KEK -> unwrap the DEK -> (caller) open the encrypted DB.
// That whole path is byte-identical on every platform; the ONLY thing that
// varies is *where the KEK comes from*.
//
// INVARIANT (zero per-platform fork of the unwrap logic): `unwrapDek` below
// is declared as an *extension* on [KeyUnwrapper], not as a method on the
// interface. Extension methods cannot be overridden by implementing
// classes in Dart, so no backend — password, device-keystore, or any
// future one (recovery, passkey, space-KEK) — can shadow or fork the
// unwrap core. Only `deriveKEK()` is virtual; that is deliberate and it is
// the entire surface where backends differ.
//
// #1853 (native SQLCipher open path), #1854 (recovery backend), and #1860
// (web OPFS store) all consume this interface. This file does not wire into
// the live Drift open path — that's #1853's job — so it stays revertible.
import 'dart:typed_data';

import 'argon2id.dart' show deriveArgon2id;
import 'envelope.dart' show WrappedEnvelope, unwrapKey;
import 'kdf_params.dart' show Argon2idParams;
import 'key_material.dart' show Dek, Kek;

/// Strategy interface: the KEK source is the only thing a backend supplies.
///
/// Implementations in this codebase:
/// - [PasswordKeyUnwrapper] (this file) — all platforms, always available.
/// - `DeviceKeystoreKeyUnwrapper` (`core/db/db_encryption.dart`) — native
///   only; lives there because it depends on that file's [SecureKeyStore]
///   abstraction rather than duplicating it here.
abstract class KeyUnwrapper {
  /// Derives or obtains the Key Encryption Key. Always a fresh call — never
  /// caches plaintext KEK bytes across invocations. Backend-specific: this
  /// is the ENTIRE difference between platforms.
  Future<Kek> deriveKEK();
}

/// The single shared unwrap core (§3 of the design doc). Every
/// [KeyUnwrapper] backend gets this for free and cannot override it — see
/// the INVARIANT note above. Delegates to #1849's [unwrapKey], so a wrong
/// KEK or a tampered `wrapped` blob always fails explicitly via
/// [EnvelopeUnwrapException] (never a silent/partial result).
extension KeyUnwrapperUnwrap on KeyUnwrapper {
  Future<Dek> unwrapDek(WrappedEnvelope wrappedDek) async {
    final kek = await deriveKEK();
    try {
      final plaintext = await unwrapKey(
        wrapped: wrappedDek,
        wrappingKey: kek.bytes,
      );
      return Dek(plaintext);
    } finally {
      // Best-effort: promptly clear the live KEK reference once the DEK is
      // recovered (§1 of the design doc's wipe-on-use posture).
      kek.wipe();
    }
  }
}

/// Password backend (all platforms, always available):
/// `KEK = Argon2id(password, salt_enc, kdf_params)`. Unwraps
/// `wrapped_dek_pw`. This is also the backend web conforms to — nothing
/// here precludes a future OPFS-cached password flow (#1860); it just
/// isn't wired to any storage yet, on purpose.
class PasswordKeyUnwrapper implements KeyUnwrapper {
  PasswordKeyUnwrapper({
    required this.password,
    required this.saltEnc,
    this.params = Argon2idParams.portableV1,
  });

  final String password;
  final Uint8List saltEnc;
  final Argon2idParams params;

  @override
  Future<Kek> deriveKEK() async {
    final bytes = await deriveArgon2id(
      password: password,
      salt: saltEnc,
      params: params,
    );
    return Kek(bytes);
  }
}
