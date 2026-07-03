// Tests for the pure-Dart Argon2id KDF wrapper. Written FIRST per TDD (#1849).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/argon2id.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';

void main() {
  group('deriveArgon2id', () {
    test('is deterministic for the same password + salt + params', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await deriveArgon2id(
        password: 'correct horse battery staple',
        salt: salt,
        params: Argon2idParams.portableV1,
      );
      final b = await deriveArgon2id(
        password: 'correct horse battery staple',
        salt: salt,
        params: Argon2idParams.portableV1,
      );
      expect(a, b);
      expect(a.length, 32);
    });

    test('different salts produce different output (domain separation)',
        () async {
      final saltA = Uint8List.fromList(List.generate(16, (i) => i));
      final saltB = Uint8List.fromList(List.generate(16, (i) => i + 1));
      final a = await deriveArgon2id(
        password: 'same-password',
        salt: saltA,
        params: Argon2idParams.portableV1,
      );
      final b = await deriveArgon2id(
        password: 'same-password',
        salt: saltB,
        params: Argon2idParams.portableV1,
      );
      expect(a, isNot(equals(b)));
    });

    test('different passwords produce different output', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await deriveArgon2id(
        password: 'password-one',
        salt: salt,
        params: Argon2idParams.portableV1,
      );
      final b = await deriveArgon2id(
        password: 'password-two',
        salt: salt,
        params: Argon2idParams.portableV1,
      );
      expect(a, isNot(equals(b)));
    });

    test('output length matches params.outputLen', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final out = await deriveArgon2id(
        password: 'p',
        salt: salt,
        params: Argon2idParams.portableV1,
      );
      expect(out.length, Argon2idParams.portableV1.outputLen);
    });

    test('rejects a salt of the wrong length', () async {
      final badSalt = Uint8List(8);
      expect(
        () => deriveArgon2id(
          password: 'p',
          salt: badSalt,
          params: Argon2idParams.portableV1,
        ),
        throwsArgumentError,
      );
    });
  });
}
