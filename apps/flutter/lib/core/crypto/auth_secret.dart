// Auth-secret derivation — task #1852, plan #131 W2.
//
// Splits the login credential from the encryption secret so a breach of the
// auth verifier alone can never unwrap a user's data (see
// .docs/internal/at-rest-key-flow.md §1/§3 and Appendix A.2/A.3):
//
//   auth_secret = Argon2id(password, salt_auth, portableV1)  -- sent to Core
//   KEK         = Argon2id(password, salt_enc,  portableV1)  -- NEVER sent
//
// Both hash the SAME password, but under two independently-random salts
// (`salt_auth` vs `salt_enc`), so the two outputs are cryptographically
// unrelated: neither can be computed from the other, only re-derived from
// the password itself, which never leaves the client.
//
// THE BOUNDARY (this is the actual security control, not just a convention):
// this file is the ONLY place `auth_secret` is derived, and it returns a
// plain `Uint8List` that IS eligible to be sent to Core (as `auth_secret` on
// `/api/auth/register` / `/api/auth/login`). [PasswordKeyUnwrapper.deriveKEK]
// in key_unwrapper.dart is the ONLY place the KEK is derived, and it returns
// a [Kek] — a type with no JSON encoder and no reference anywhere in
// `AuthRepository`/networking code, so it is structurally not on a path that
// could serialize it onto the wire. Neither function is ever composed from
// the other's output, and nothing in this file imports key_unwrapper.dart
// or vice versa.
import 'dart:typed_data';

import 'argon2id.dart' show deriveArgon2id;
import 'kdf_params.dart' show Argon2idParams;

/// Derives the login credential Core verifies (`auth_secret`) from
/// [password] and `salt_auth`. This — never the raw password, never the
/// KEK — is what a migrated client puts on the wire for authentication.
Future<Uint8List> deriveAuthSecret({
  required String password,
  required Uint8List saltAuth,
  Argon2idParams params = Argon2idParams.portableV1,
}) {
  return deriveArgon2id(password: password, salt: saltAuth, params: params);
}
