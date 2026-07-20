// Typed DEK / KEK / FEK key material — task #1849, plan #131 W1.
//
// These are thin, type-safe wrappers around 32-byte symmetric keys so
// call sites can't accidentally pass a FEK where a DEK is expected, etc.
// CSPRNG generation uses `Random.secure()` (dart:math), which is backed by
// the OS's cryptographically secure RNG on every platform Dart supports and
// has no platform-channel dependency of its own.
import 'dart:math';
import 'dart:typed_data';

const int kSymmetricKeyLength = 32;

Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// Base type for a 32-byte (AES-256) symmetric key.
abstract class SymmetricKey32 {
  final Uint8List bytes;

  SymmetricKey32(Uint8List bytes) : bytes = bytes {
    if (bytes.length != kSymmetricKeyLength) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'expected exactly $kSymmetricKeyLength bytes',
      );
    }
  }

  /// Zeroes the key material in place. Best-effort defense-in-depth: the GC
  /// may have copied the bytes elsewhere, but this at least removes the live
  /// reference's plaintext promptly on lock/logout (§1 of the design doc).
  void wipe() {
    bytes.fillRange(0, bytes.length, 0);
  }

  @override
  bool operator ==(Object other) =>
      other is SymmetricKey32 &&
      other.runtimeType == runtimeType &&
      _constantTimeEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => '$runtimeType(${bytes.length} bytes, redacted)';
}

bool _constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Data Encryption Key — random 256-bit, the only thing that actually
/// decrypts the local store. Never leaves the device in clear (§1).
class Dek extends SymmetricKey32 {
  Dek(super.bytes);

  factory Dek.generate() => Dek(secureRandomBytes(kSymmetricKeyLength));
}

/// Key Encryption Key — wraps a DEK. May come from a password (Argon2id), a
/// recovery code (Argon2id), or an OS-keystore device key (§1). This type is
/// intentionally source-agnostic: callers construct it from whichever KDF
/// output or keystore read is appropriate for the active strategy.
class Kek extends SymmetricKey32 {
  Kek(super.bytes);
}

/// File Encryption Key — random per file, wrapped by the DEK (§8.2). Media
/// is encrypted under its own FEK rather than the DEK directly so a DEK
/// rotation only re-wraps FEKs instead of re-encrypting every file.
class Fek extends SymmetricKey32 {
  Fek(super.bytes);

  factory Fek.generate() => Fek(secureRandomBytes(kSymmetricKeyLength));
}
