// Tests for the recovery enrollment + reset flow — task #1854, plan #131 W3.
// Written FIRST per TDD (red before recovery_flow.dart/recovery_key_unwrapper.dart
// exist).
//
// This is the SAFETY NET for #1849/#1850's `resetOnError:false` device-KEK
// posture (.docs/internal/at-rest-key-flow.md §5, Appendix A.7): a decrypt
// error there is a hard failure, not a silent wipe, so a user with no
// recovery path is locked out permanently. These tests prove the round trip
// that makes recovery actually work end to end, purely against the crypto
// core (no network) — enroll -> forget password -> reset via recovery code
// -> store reopens with the DEK intact — plus the "re-wrap, not re-encrypt"
// and single-use/rotation invariants called out in the task AC.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/crypto/recovery_code.dart';
import 'package:matome_flutter/core/crypto/recovery_flow.dart';
import 'package:matome_flutter/core/crypto/recovery_key_unwrapper.dart';

void main() {
  group('recovery enrollment + reset round trip', () {
    test(
        'enroll -> forget password -> reset with recovery code -> DEK bytes '
        'intact (re-wrap, not re-encrypt)', () async {
      final dek = Dek.generate();
      final originalDekBytes = Uint8List.fromList(dek.bytes);

      // 1. Enrollment: generate a recovery code, wrap the DEK under it.
      final enrollment = await enrollRecovery(dek: dek);
      expect(enrollment.code.rawBytes.length, kRecoveryCodeRawLength);

      // 2. "Forget password" — nothing to do; the password-KEK path is
      // simply never consulted for the rest of this test.

      // 3. Reset: the user enters the recovery code shown at enrollment.
      final result = await resetPasswordWithRecoveryCode(
        enteredCode: RecoveryCode.parse(enrollment.code.formatted),
        saltRec: enrollment.saltRec,
        wrappedDekRecovery: enrollment.wrappedDekRecovery,
        newPassword: 'a brand new password 42',
      );

      // The DEK recovered via the recovery code is byte-identical to the
      // one enrolled — the reset RE-WRAPPED it, it did not generate a new
      // DEK (which would have required re-encrypting the whole store).
      expect(result.dek.bytes, originalDekBytes);

      // 4. Store reopens with the DEK intact via the NEW password.
      final reopened = await PasswordKeyUnwrapper(
        password: 'a brand new password 42',
        saltEnc: result.saltEnc,
      ).unwrapDek(result.wrappedDekPw);
      expect(reopened.bytes, originalDekBytes);
    });

    test('single-use / rotation: the old recovery code cannot unwrap the '
        'rotated wrapped_dek_recovery after a reset', () async {
      final dek = Dek.generate();
      final enrollment = await enrollRecovery(dek: dek);

      final result = await resetPasswordWithRecoveryCode(
        enteredCode: enrollment.code,
        saltRec: enrollment.saltRec,
        wrappedDekRecovery: enrollment.wrappedDekRecovery,
        newPassword: 'another new password 7',
      );

      // A fresh code + fresh salt_rec were generated and uploaded in place
      // of the old ones.
      expect(
        result.rotatedRecovery.code.formatted,
        isNot(enrollment.code.formatted),
      );
      expect(result.rotatedRecovery.saltRec, isNot(enrollment.saltRec));

      // The OLD code, replayed against the NEW wrapped_dek_recovery, must
      // fail explicitly — never silently unwrap, never partial plaintext.
      final oldUnwrapper = RecoveryKeyUnwrapper(
        recoveryCode: enrollment.code,
        saltRec: result.rotatedRecovery.saltRec,
      );
      expect(
        () => oldUnwrapper.unwrapDek(result.rotatedRecovery.wrappedDekRecovery),
        throwsA(isA<EnvelopeTamperException>()),
      );

      // The NEW code recovers the SAME DEK from the rotated envelope.
      final newUnwrapper = RecoveryKeyUnwrapper(
        recoveryCode: result.rotatedRecovery.code,
        saltRec: result.rotatedRecovery.saltRec,
      );
      final recovered = await newUnwrapper.unwrapDek(
        result.rotatedRecovery.wrappedDekRecovery,
      );
      expect(recovered.bytes, dek.bytes);
    });

    test('wrong recovery code fails explicitly during reset (no fallback to '
        'plaintext, no silent success)', () async {
      final dek = Dek.generate();
      final enrollment = await enrollRecovery(dek: dek);
      final wrongCode = RecoveryCode.generate();

      expect(
        () => resetPasswordWithRecoveryCode(
          enteredCode: wrongCode,
          saltRec: enrollment.saltRec,
          wrappedDekRecovery: enrollment.wrappedDekRecovery,
          newPassword: 'irrelevant password',
        ),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });

    test('RecoveryKeyUnwrapper is a KeyUnwrapper backend like PasswordKeyUnwrapper '
        '— no per-platform fork of the unwrap core', () async {
      final dek = Dek.generate();
      final enrollment = await enrollRecovery(dek: dek);

      final KeyUnwrapper backend = RecoveryKeyUnwrapper(
        recoveryCode: enrollment.code,
        saltRec: enrollment.saltRec,
      );
      final recovered = await backend.unwrapDek(enrollment.wrappedDekRecovery);
      expect(recovered.bytes, dek.bytes);
    });
  });
}
