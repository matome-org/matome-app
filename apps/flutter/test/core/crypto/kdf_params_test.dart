// Tests for the frozen Argon2id KDF parameter profile (Appendix A.3 of
// .docs/internal/at-rest-key-flow.md). Written FIRST per TDD (#1849).
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';

void main() {
  group('Argon2idParams.portableV1 (frozen profile)', () {
    test('matches the frozen argon2id-v1-portable spec exactly', () {
      const params = Argon2idParams.portableV1;
      expect(params.profile, 'argon2id-v1-portable');
      expect(params.algorithm, 'argon2id');
      expect(params.version, 19); // Argon2 spec version 0x13
      expect(params.memoryKib, 19456);
      expect(params.iterations, 2);
      expect(params.parallelism, 1);
      expect(params.outputLen, 32);
      expect(params.saltLen, 16);
    });

    test('toJson round-trips through fromJson', () {
      const params = Argon2idParams.portableV1;
      final decoded = Argon2idParams.fromJson(params.toJson());
      expect(decoded, params);
    });
  });

  group('Argon2idParams.fromJson — version-mismatch detection', () {
    test('accepts a legacy JSON blob whose fields match the known profile', () {
      final legacyButValid = {
        'profile': 'argon2id-v1-portable',
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kib': 19456,
        'iterations': 2,
        'parallelism': 1,
        'output_len': 32,
      };
      expect(Argon2idParams.fromJson(legacyButValid), Argon2idParams.portableV1);
    });

    test(
        'throws KdfProfileMismatchException when a legacy blob claims a known '
        'profile name but carries different (weaker) cost params', () {
      // Fixture: a hypothetical legacy keybundle that names the current
      // profile but was actually produced under old/weaker parameters
      // (e.g. a downgrade attack, or corrupted storage). This MUST be
      // detected explicitly rather than silently deriving with the wrong
      // strength.
      final legacyBlob = {
        'profile': 'argon2id-v1-portable',
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kib': 4096, // weaker than frozen 19456
        'iterations': 1, // weaker than frozen 2
        'parallelism': 1,
        'output_len': 32,
      };
      expect(
        () => Argon2idParams.fromJson(legacyBlob),
        throwsA(isA<KdfProfileMismatchException>()),
      );
    });

    test('throws KdfProfileMismatchException on Argon2 spec version mismatch',
        () {
      final legacyBlob = {
        'profile': 'argon2id-v1-portable',
        'algorithm': 'argon2id',
        'version': 16, // pre-RFC9106 draft version, not 19 (0x13)
        'memory_kib': 19456,
        'iterations': 2,
        'parallelism': 1,
        'output_len': 32,
      };
      expect(
        () => Argon2idParams.fromJson(legacyBlob),
        throwsA(isA<KdfProfileMismatchException>()),
      );
    });

    test('throws UnknownKdfProfileException for an unregistered profile name',
        () {
      final futureBlob = {
        'profile': 'argon2id-v2-portable',
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kib': 65536,
        'iterations': 3,
        'parallelism': 1,
        'output_len': 32,
      };
      expect(
        () => Argon2idParams.fromJson(futureBlob),
        throwsA(isA<UnknownKdfProfileException>()),
      );
    });

    test('throws KdfProfileMismatchException when algorithm field is wrong',
        () {
      final badBlob = {
        'profile': 'argon2id-v1-portable',
        'algorithm': 'argon2i', // wrong variant
        'version': 19,
        'memory_kib': 19456,
        'iterations': 2,
        'parallelism': 1,
        'output_len': 32,
      };
      expect(
        () => Argon2idParams.fromJson(badBlob),
        throwsA(isA<KdfProfileMismatchException>()),
      );
    });
  });
}
