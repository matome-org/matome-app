// Tests for DEK/KEK/FEK typed key material + CSPRNG generation.
// Written FIRST per TDD (#1849).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';

void main() {
  group('Dek.generate', () {
    test('produces 32 random bytes', () {
      final dek = Dek.generate();
      expect(dek.bytes.length, 32);
    });

    test('two generated DEKs are not equal (CSPRNG, not deterministic)', () {
      final a = Dek.generate();
      final b = Dek.generate();
      expect(a.bytes, isNot(equals(b.bytes)));
    });
  });

  group('Kek', () {
    test('wraps arbitrary 32-byte key material', () {
      final bytes = Uint8List(32);
      final kek = Kek(bytes);
      expect(kek.bytes, bytes);
    });

    test('rejects non-32-byte material', () {
      expect(() => Kek(Uint8List(16)), throwsArgumentError);
    });
  });

  group('Fek.generate', () {
    test('produces 32 random bytes', () {
      final fek = Fek.generate();
      expect(fek.bytes.length, 32);
    });

    test('two generated FEKs are not equal', () {
      final a = Fek.generate();
      final b = Fek.generate();
      expect(a.bytes, isNot(equals(b.bytes)));
    });
  });

  group('wipe', () {
    test('zeroes out the underlying bytes in place', () {
      final dek = Dek.generate();
      final before = Uint8List.fromList(dek.bytes);
      expect(before.any((b) => b != 0), isTrue);
      dek.wipe();
      expect(dek.bytes.every((b) => b == 0), isTrue);
    });
  });
}
