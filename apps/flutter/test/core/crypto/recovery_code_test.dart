// Tests for the recovery code generator + Crockford Base32 encoding +
// Argon2id stretch (Appendix A.7). Written FIRST per TDD (#1849).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';
import 'package:matome_flutter/core/crypto/recovery_code.dart';

void main() {
  group('RecoveryCode.generate', () {
    test('has exactly 128 bits (16 bytes) of raw entropy', () {
      final code = RecoveryCode.generate();
      expect(code.rawBytes.length, 16);
    });

    test('two generated codes are not equal (CSPRNG)', () {
      final a = RecoveryCode.generate();
      final b = RecoveryCode.generate();
      expect(a.rawBytes, isNot(equals(b.rawBytes)));
    });

    test('formatted string uses Crockford Base32 grouped in 4-char blocks', () {
      final code = RecoveryCode.generate();
      final formatted = code.formatted;
      final groups = formatted.split('-');
      // 128 bits / 5 bits-per-char = 26 chars -> 6 groups of 4 + 1 group of 2.
      expect(groups.length, 7);
      expect(groups.take(6).every((g) => g.length == 4), isTrue);
      expect(groups.last.length, 2);
      const crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      for (final ch in formatted.replaceAll('-', '').split('')) {
        expect(
          crockfordAlphabet.contains(ch),
          isTrue,
          reason: '$ch is not a valid Crockford Base32 character',
        );
      }
      // Ambiguous characters must never appear.
      for (final banned in ['I', 'L', 'O', 'U']) {
        expect(formatted.contains(banned), isFalse);
      }
    });
  });

  group('RecoveryCode parse/format round trip', () {
    test('formatted() -> parse() recovers the same raw bytes', () {
      final code = RecoveryCode.generate();
      final reparsed = RecoveryCode.parse(code.formatted);
      expect(reparsed.rawBytes, code.rawBytes);
    });

    test('parse accepts input without hyphens too', () {
      final code = RecoveryCode.generate();
      final noHyphens = code.formatted.replaceAll('-', '');
      final reparsed = RecoveryCode.parse(noHyphens);
      expect(reparsed.rawBytes, code.rawBytes);
    });

    test('parse is case-insensitive', () {
      final code = RecoveryCode.generate();
      final lower = code.formatted.toLowerCase();
      final reparsed = RecoveryCode.parse(lower);
      expect(reparsed.rawBytes, code.rawBytes);
    });
  });

  group('RecoveryCode.stretch (Argon2id)', () {
    test('stretching with the same salt+params is deterministic', () async {
      final code = RecoveryCode.generate();
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final a = await code.stretch(
        saltRec: salt,
        params: Argon2idParams.portableV1,
      );
      final b = await code.stretch(
        saltRec: salt,
        params: Argon2idParams.portableV1,
      );
      expect(a, b);
      expect(a.length, 32);
    });

    test('different recovery codes stretch to different KEKs', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final codeA = RecoveryCode.generate();
      final codeB = RecoveryCode.generate();
      final a = await codeA.stretch(
        saltRec: salt,
        params: Argon2idParams.portableV1,
      );
      final b = await codeB.stretch(
        saltRec: salt,
        params: Argon2idParams.portableV1,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
