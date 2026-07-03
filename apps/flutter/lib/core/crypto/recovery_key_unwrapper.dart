// Recovery-code KeyUnwrapper backend — task #1854, plan #131 W3.
//
// Slots into the shared strategy interface from key_unwrapper.dart (#1850):
// `KEK = Argon2id(recoveryCode.rawBytes, salt_rec, kdf_params)`. Unwraps
// `wrapped_dek_recovery`. Per the invariant documented on [KeyUnwrapper],
// `unwrapDek` itself is inherited unmodified from the extension — this class
// supplies nothing but `deriveKEK()`, so the recovery path can never fork
// from the same unwrap core every other backend shares.
import 'dart:typed_data';

import 'kdf_params.dart' show Argon2idParams;
import 'key_material.dart' show Kek;
import 'key_unwrapper.dart' show KeyUnwrapper;
import 'recovery_code.dart' show RecoveryCode;

/// Recovery backend: used only during the "forgot password" reset flow
/// (.docs/internal/at-rest-key-flow.md §5) — a user who still has their
/// password never touches this class.
class RecoveryKeyUnwrapper implements KeyUnwrapper {
  RecoveryKeyUnwrapper({
    required this.recoveryCode,
    required this.saltRec,
    this.params = Argon2idParams.portableV1,
  });

  final RecoveryCode recoveryCode;
  final Uint8List saltRec;
  final Argon2idParams params;

  @override
  Future<Kek> deriveKEK() async {
    final bytes = await recoveryCode.stretch(saltRec: saltRec, params: params);
    return Kek(bytes);
  }
}
