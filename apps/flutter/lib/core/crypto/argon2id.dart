// Pure-Dart Argon2id KDF wrapper (RFC 9106) — task #1849, plan #131 W1.
//
// Uses `DartArgon2id` from `package:cryptography/dart.dart`, the forced
// pure-Dart implementation. This is deliberate: the `Dart*` classes have NO
// platform channel / dart:ffi plugin dependency, so this module runs
// identically under `flutter test` (and on web) with no device attached —
// the zero-platform-deps constraint for this crypto core layer.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:cryptography/dart.dart';

import 'kdf_params.dart';

/// Derives a key from [password] and [salt] using the given Argon2id
/// [params]. Returns exactly `params.outputLen` bytes.
///
/// Deterministic: the same (password, salt, params) triple always yields the
/// same output, which is required both for KEK re-derivation at login and
/// for the login-cost parallelization note in Appendix A.3 (auth-secret and
/// password-KEK are two independent calls to this function).
Future<Uint8List> deriveArgon2id({
  required String password,
  required Uint8List salt,
  required Argon2idParams params,
}) {
  return deriveArgon2idFromBytes(
    secret: utf8.encode(password),
    salt: salt,
    params: params,
  );
}

/// Lower-level variant that hashes raw bytes rather than a UTF-8 string.
/// Used directly by [RecoveryCode.stretch] (recovery_code.dart) so the
/// Argon2id input is the recovery code's raw 128-bit entropy, not a
/// re-encoded/case-normalized string — avoiding any ambiguity about which
/// textual representation of the code was hashed.
Future<Uint8List> deriveArgon2idFromBytes({
  required List<int> secret,
  required Uint8List salt,
  required Argon2idParams params,
}) async {
  if (salt.length != kArgon2SaltLen) {
    throw ArgumentError.value(
      salt.length,
      'salt.length',
      'salt must be exactly $kArgon2SaltLen bytes',
    );
  }

  final algorithm = DartArgon2id(
    parallelism: params.parallelism,
    memory: params.memoryKib,
    iterations: params.iterations,
    hashLength: params.outputLen,
  );

  final secretKey = await algorithm.deriveKey(
    secretKey: SecretKey(secret),
    nonce: salt,
  );
  final bytes = await secretKey.extractBytes();
  return Uint8List.fromList(bytes);
}
