// Recovery enrollment + "forgot password" reset flow — task #1854, plan #131
// W3. This is the SAFETY NET for the device-KEK's `resetOnError:false`
// posture (Appendix A.7 / §5 of .docs/internal/at-rest-key-flow.md): a
// decrypt error there is a hard failure, not a silent wipe, so a user with
// no recovery path is locked out permanently. Recovery must exist alongside
// native encryption, not be deferred.
//
// Both entry points here are pure crypto-core logic — no network, no
// storage, no platform channel — so they run identically on every platform
// (the "unified login UI" AC is a consequence of this: there is nothing here
// for a platform fork to attach to).
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'argon2id.dart' show deriveArgon2id;
import 'envelope.dart' show PayloadType, WrappedEnvelope, WrapperType, wrapKey;
import 'kdf_params.dart' show Argon2idParams, kArgon2SaltLen;
import 'key_material.dart' show Dek, Kek, secureRandomBytes;
import 'key_unwrapper.dart' show KeyUnwrapperUnwrap;
import 'recovery_code.dart' show RecoveryCode;
import 'recovery_key_unwrapper.dart' show RecoveryKeyUnwrapper;

/// Output of enrolling (or rotating) recovery for a DEK: the fresh code that
/// must be shown to the user EXACTLY ONCE (never persisted in plaintext —
/// callers must not log or cache [code] beyond that single display), the
/// salt it was stretched with, and the wrapped envelope to upload as
/// `wrapped_dek_recovery`.
class RecoveryEnrollment {
  const RecoveryEnrollment({
    required this.code,
    required this.saltRec,
    required this.wrappedDekRecovery,
  });

  final RecoveryCode code;
  final Uint8List saltRec;
  final WrappedEnvelope wrappedDekRecovery;
}

/// Enrolls (or re-enrolls/rotates) recovery for [dek]: generates a fresh
/// 128-bit recovery code + `salt_rec`, and wraps the SAME [dek] under the
/// resulting recovery-KEK. Never mutates or regenerates [dek] — enrollment
/// (and later rotation) is always a re-wrap, never a re-encrypt.
Future<RecoveryEnrollment> enrollRecovery({
  required Dek dek,
  Argon2idParams params = Argon2idParams.portableV1,
}) async {
  final code = RecoveryCode.generate();
  final saltRec = secureRandomBytes(kArgon2SaltLen);

  final unwrapper = RecoveryKeyUnwrapper(
    recoveryCode: code,
    saltRec: saltRec,
    params: params,
  );
  final Kek kek = await unwrapper.deriveKEK();
  try {
    final wrapped = await wrapKey(
      plaintext: dek.bytes,
      wrappingKey: kek.bytes,
      payloadType: PayloadType.dek,
      wrapperType: WrapperType.recoveryKek,
    );
    return RecoveryEnrollment(
      code: code,
      saltRec: saltRec,
      wrappedDekRecovery: wrapped,
    );
  } finally {
    kek.wipe();
  }
}

/// Result of a successful "forgot password" reset via recovery code: the
/// recovered DEK (byte-identical to what was enrolled — this is a re-wrap,
/// never a re-encrypt of the underlying store), the new password wrap, and
/// a freshly ROTATED recovery enrollment. The old recovery code stops
/// working the moment [rotatedRecovery] is uploaded in place of the old
/// `wrapped_dek_recovery`/`salt_rec` — see task #1854 AC "single-use /
/// rotation".
class RecoveryResetResult {
  const RecoveryResetResult({
    required this.dek,
    required this.saltEnc,
    required this.wrappedDekPw,
    required this.rotatedRecovery,
  });

  /// The recovered DEK. Identical bytes to whatever was enrolled — never
  /// regenerated.
  final Dek dek;

  /// Freshly generated `salt_enc` for the new password-KEK.
  final Uint8List saltEnc;

  /// The SAME [dek], re-wrapped under the new password-KEK. Upload this as
  /// the new `wrapped_dek_pw`.
  final WrappedEnvelope wrappedDekPw;

  /// A brand-new recovery enrollment (new code, new `salt_rec`, new
  /// `wrapped_dek_recovery`) — upload alongside [wrappedDekPw] so the code
  /// the user just used can never be replayed.
  final RecoveryEnrollment rotatedRecovery;
}

/// Executes the "forgot password" reset core (§5 of the design doc): unwrap
/// the DEK via the user-entered recovery code, re-wrap the SAME DEK under a
/// brand-new password-KEK (never a bulk re-encryption of the store — the DEK
/// itself does not change), and rotate recovery (new code + new `salt_rec` +
/// new `wrapped_dek_recovery`) so the just-used code can never unwrap again.
///
/// Throws whatever `unwrapDek` throws (an `EnvelopeUnwrapException` subtype,
/// see envelope.dart) on a wrong/garbled recovery code or a tampered
/// [wrappedDekRecovery] blob — never a silent or partial result, mirroring
/// the `resetOnError:false` posture this flow exists to back up.
Future<RecoveryResetResult> resetPasswordWithRecoveryCode({
  required RecoveryCode enteredCode,
  required Uint8List saltRec,
  required WrappedEnvelope wrappedDekRecovery,
  required String newPassword,
  Argon2idParams params = Argon2idParams.portableV1,
  // Test-only fault-injection seam (okt-audit B3 info follow-up): when
  // non-null, invoked with the just-recovered [dek] right after the
  // recovery-code unwrap succeeds, before any later step runs. Lets tests
  // deterministically exercise "a later step throws after the DEK is
  // already recovered" without needing to break the KDF/wrap primitives
  // themselves. Must never be set outside test code — mirrors the
  // `timerFactory`/`dekSource` injection pattern already used in
  // `dek_session_guard.dart`/`inbox_upload.dart`.
  @visibleForTesting
  Future<void> Function(Dek dek)? debugFailAfterRecoveryUnwrap,
}) async {
  final unwrapper = RecoveryKeyUnwrapper(
    recoveryCode: enteredCode,
    saltRec: saltRec,
    params: params,
  );
  final dek = await unwrapper.unwrapDek(wrappedDekRecovery);

  try {
    if (debugFailAfterRecoveryUnwrap != null) {
      await debugFailAfterRecoveryUnwrap(dek);
    }

    final newSaltEnc = secureRandomBytes(kArgon2SaltLen);
    final newKekBytes = await deriveArgon2id(
      password: newPassword,
      salt: newSaltEnc,
      params: params,
    );
    final newKek = Kek(newKekBytes);
    late final WrappedEnvelope wrappedDekPw;
    try {
      wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: newKek.bytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
    } finally {
      newKek.wipe();
    }

    // Single-use / rotation: a brand-new code + salt_rec replace the one
    // the user just spent, so it can never be replayed against the
    // server's (now-updated) wrapped_dek_recovery.
    final rotatedRecovery = await enrollRecovery(dek: dek, params: params);

    return RecoveryResetResult(
      dek: dek,
      saltEnc: newSaltEnc,
      wrappedDekPw: wrappedDekPw,
      rotatedRecovery: rotatedRecovery,
    );
  } catch (_) {
    // The recovered DEK must not be left live with no reachable owner if
    // ANY step after the recovery-unwrap fails (okt-audit B3 info
    // follow-up: the old code only wiped intermediate KEKs in `finally`,
    // never this DEK). On the success path above, `dek` is returned live
    // to the caller (who needs it to open the store) — it is deliberately
    // NOT wiped there.
    dek.wipe();
    rethrow;
  }
}
