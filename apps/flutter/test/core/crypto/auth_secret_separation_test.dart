// Tests for auth-secret / KEK separation — task #1852, plan #131 W2.
// Written FIRST per TDD.
//
// Proves the core security claim of this task (see
// .docs/internal/at-rest-key-flow.md §1/§3, Appendix A.2): the login
// credential Core verifies (`auth_secret`) and the KEK that unwraps
// `wrapped_dek_pw` are cryptographically independent, even though both are
// derived from the SAME password, because they use two different,
// independently-random salts (`salt_auth` vs `salt_enc`). A full breach of
// the login credential — the worst case for an attacker, since Core in
// reality only stores an Argon2id verifier OF `auth_secret`, never
// `auth_secret` itself — still does not unwrap a user's DEK.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/auth_secret.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';

Uint8List _salt16(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xff));

void main() {
  group('auth_secret / KEK independence (task #1852)', () {
    const password = 'correct horse battery staple';

    test('same password under distinct salt_auth/salt_enc derives two '
        'different values', () async {
      final saltAuth = _salt16(10);
      final saltEnc = _salt16(20);

      final authSecret = await deriveAuthSecret(
        password: password,
        saltAuth: saltAuth,
      );
      final kek = await PasswordKeyUnwrapper(
        password: password,
        saltEnc: saltEnc,
      ).deriveKEK();

      expect(authSecret, isNot(equals(kek.bytes)));
    });

    test('SECURITY: a fully compromised auth_secret alone does NOT unwrap '
        'the DEK', () async {
      final saltAuth = _salt16(30);
      final saltEnc = _salt16(40);
      final dek = Dek.generate();

      // Genuine enrollment: the real KEK (from salt_enc) wraps the DEK,
      // exactly as it would on-device. This KEK never leaves the client.
      final kek = await PasswordKeyUnwrapper(
        password: password,
        saltEnc: saltEnc,
      ).deriveKEK();
      final wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek.bytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      // Attacker scenario: assume the WORST case, a total breach that hands
      // the attacker `auth_secret` itself (stronger than reality, where Core
      // only ever holds an Argon2id verifier OF auth_secret). Attempt to use
      // it as the wrapping key to unwrap the DEK.
      final authSecret = await deriveAuthSecret(
        password: password,
        saltAuth: saltAuth,
      );

      expect(
        () => unwrapKey(wrapped: wrappedDekPw, wrappingKey: authSecret),
        throwsA(isA<EnvelopeTamperException>()),
      );

      // Sanity check: the genuine, never-transmitted KEK still unwraps
      // correctly — proving the failure above is specifically because
      // auth_secret != KEK, not a bug in the wrap/unwrap primitives.
      final recovered = await unwrapKey(
        wrapped: wrappedDekPw,
        wrappingKey: kek.bytes,
      );
      expect(recovered, equals(dek.bytes));
    });

    test('the safety property depends on distinct salts: colliding '
        'salt_auth/salt_enc would collapse auth_secret and KEK to the same '
        'value', () async {
      final sharedSalt = _salt16(50);

      final authSecret = await deriveAuthSecret(
        password: password,
        saltAuth: sharedSalt,
      );
      final kek = await PasswordKeyUnwrapper(
        password: password,
        saltEnc: sharedSalt,
      ).deriveKEK();

      // This is a design-invariant regression pin, not a desired behavior:
      // it demonstrates WHY Appendix A.2 mandates independently-random
      // salt_auth/salt_enc rather than reusing one salt for both purposes.
      expect(authSecret, equals(kek.bytes));
    });
  });
}
