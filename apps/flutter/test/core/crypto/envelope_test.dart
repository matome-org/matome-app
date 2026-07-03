// Tests for the frozen 64-byte authenticated wrap layout (Appendix A.4 of
// .docs/internal/at-rest-key-flow.md). Written FIRST per TDD (#1849).
//
// Layout: format_version(1) | payload_type(1) | wrapper_type(1) | alg_id(1)
//         | nonce(12) | ciphertext(32) | gcm_tag(16)  = 64 bytes total.
// The 4-byte header is bound as AEAD AAD.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';

Uint8List _key32(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (i + seed) & 0xff));

Uint8List _payload32(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (i * 7 + seed) & 0xff));

void main() {
  group('wrapKey / unwrapKey — round trip', () {
    test('wrap then unwrap yields the original 32-byte payload', () async {
      final wrappingKey = _key32(1);
      final plaintext = _payload32(2);

      final wrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      expect(wrapped.bytes.length, 64);
      expect(wrapped.bytes[0], 0x01); // format_version
      expect(wrapped.bytes[1], 0x01); // payload_type = DEK
      expect(wrapped.bytes[2], 0x01); // wrapper_type = password-KEK
      expect(wrapped.bytes[3], 0x01); // alg_id = AES-256-GCM

      final unwrapped = await unwrapKey(
        wrapped: wrapped,
        wrappingKey: wrappingKey,
      );
      expect(unwrapped, plaintext);
    });

    test('round trip works for every documented payload/wrapper combination',
        () async {
      final wrappingKey = _key32(9);
      final plaintext = _payload32(3);

      final cases = [
        (PayloadType.dek, WrapperType.passwordKek),
        (PayloadType.dek, WrapperType.recoveryKek),
        (PayloadType.dek, WrapperType.deviceKek),
        (PayloadType.fek, WrapperType.dekAsWrappingKey),
      ];

      for (final (payloadType, wrapperType) in cases) {
        final wrapped = await wrapKey(
          plaintext: plaintext,
          wrappingKey: wrappingKey,
          payloadType: payloadType,
          wrapperType: wrapperType,
        );
        final unwrapped = await unwrapKey(
          wrapped: wrapped,
          wrappingKey: wrappingKey,
        );
        expect(unwrapped, plaintext);
      }
    });

    test('two wraps of the same plaintext use distinct random nonces',
        () async {
      final wrappingKey = _key32(4);
      final plaintext = _payload32(5);

      final wrapped1 = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      final wrapped2 = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final nonce1 = wrapped1.bytes.sublist(4, 16);
      final nonce2 = wrapped2.bytes.sublist(4, 16);
      expect(nonce1, isNot(equals(nonce2)));
      // Ciphertext also differs because GCM keystream depends on the nonce.
      expect(wrapped1.bytes, isNot(equals(wrapped2.bytes)));
    });

    test('base64 transport encoding round-trips (88 chars for 64 bytes)',
        () async {
      final wrappingKey = _key32(6);
      final plaintext = _payload32(7);
      final wrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final b64 = wrapped.toBase64();
      expect(b64.length, 88);
      expect(base64.decode(b64).length, 64);

      final restored = WrappedEnvelope.fromBase64(b64);
      final unwrapped = await unwrapKey(
        wrapped: restored,
        wrappingKey: wrappingKey,
      );
      expect(unwrapped, plaintext);
    });
  });

  group('unwrapKey — tamper detection (never silent, never partial)', () {
    late Uint8List wrappingKey;
    late Uint8List plaintext;
    late WrappedEnvelope wrapped;

    setUp(() async {
      wrappingKey = _key32(10);
      plaintext = _payload32(11);
      wrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
    });

    Future<void> expectTamperDetected(Uint8List tampered) async {
      final tamperedEnvelope = WrappedEnvelope(tampered);
      await expectLater(
        unwrapKey(wrapped: tamperedEnvelope, wrappingKey: wrappingKey),
        throwsA(isA<EnvelopeTamperException>()),
      );
    }

    /// format_version and alg_id get a dedicated fast-path version check
    /// (see the "legacy-blob fixture" group below) in addition to being
    /// bound into the AEAD AAD. So tampering either byte is always an
    /// EXPLICIT failure, but the concrete exception type depends on whether
    /// the fast-path guard or the AEAD tag check fires first — both are
    /// [EnvelopeUnwrapException] subtypes. Never silent, never partial
    /// plaintext either way.
    Future<void> expectExplicitFailure(Uint8List tampered) async {
      final tamperedEnvelope = WrappedEnvelope(tampered);
      await expectLater(
        unwrapKey(wrapped: tamperedEnvelope, wrappingKey: wrappingKey),
        throwsA(isA<EnvelopeUnwrapException>()),
      );
    }

    test('flipping a byte in format_version (header) is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[0] ^= 0xff;
      await expectExplicitFailure(tampered);
    });

    test('flipping a byte in payload_type (header) is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[1] ^= 0xff;
      await expectTamperDetected(tampered);
    });

    test('flipping a byte in wrapper_type (header) is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[2] ^= 0xff;
      await expectTamperDetected(tampered);
    });

    test('flipping a byte in alg_id (header) is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[3] ^= 0xff;
      await expectExplicitFailure(tampered);
    });

    test('flipping a byte in the nonce is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[4] ^= 0xff; // first nonce byte, offset 4
      await expectTamperDetected(tampered);
    });

    test('flipping a byte in the ciphertext is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[16] ^= 0xff; // first ciphertext byte, offset 16
      await expectTamperDetected(tampered);
    });

    test('flipping a byte in the gcm_tag is detected', () async {
      final tampered = Uint8List.fromList(wrapped.bytes);
      tampered[48] ^= 0xff; // first tag byte, offset 48
      await expectTamperDetected(tampered);
    });

    test('cross-slot substitution (relabeled wrapper_type) fails via AAD',
        () async {
      // Wrap the SAME plaintext under recovery-KEK, then splice its
      // ciphertext+tag onto a header claiming password-KEK. Because the
      // header is bound as AAD, this must fail authentication even though
      // the underlying key and plaintext are identical.
      final recoveryWrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.recoveryKek,
      );
      final relabeled = Uint8List.fromList(recoveryWrapped.bytes);
      relabeled[2] = WrapperType.passwordKek.byteValue; // relabel header only
      await expectTamperDetected(relabeled);
    });

    test('unwrapping with the wrong key fails authentication', () async {
      final wrongKey = _key32(99);
      await expectLater(
        unwrapKey(wrapped: wrapped, wrappingKey: wrongKey),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });

    test('truncated blob is rejected before any crypto attempt', () async {
      final truncated = Uint8List.fromList(wrapped.bytes.sublist(0, 63));
      expect(
        () => WrappedEnvelope(truncated),
        throwsA(isA<InvalidEnvelopeLengthException>()),
      );
    });

    test('oversized blob is rejected before any crypto attempt', () async {
      final oversized = Uint8List.fromList([...wrapped.bytes, 0x00]);
      expect(
        () => WrappedEnvelope(oversized),
        throwsA(isA<InvalidEnvelopeLengthException>()),
      );
    });
  });

  group('unwrapKey — format_version mismatch (legacy-blob fixture)', () {
    test('rejects a blob whose format_version is not the supported 0x01',
        () async {
      final wrappingKey = _key32(20);
      final plaintext = _payload32(21);
      final wrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      // Fixture: simulate a legacy/future blob with an unsupported
      // format_version byte (e.g. a pre-freeze draft, or a future breaking
      // format change). Must fail loudly, not silently reinterpret bytes.
      final legacyBytes = Uint8List.fromList(wrapped.bytes);
      legacyBytes[0] = 0x00;

      await expectLater(
        unwrapKey(
          wrapped: WrappedEnvelope(legacyBytes),
          wrappingKey: wrappingKey,
        ),
        throwsA(isA<UnsupportedFormatVersionException>()),
      );
    });

    test('rejects a blob with an unrecognized alg_id', () async {
      final wrappingKey = _key32(22);
      final plaintext = _payload32(23);
      final wrapped = await wrapKey(
        plaintext: plaintext,
        wrappingKey: wrappingKey,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final futureAlg = Uint8List.fromList(wrapped.bytes);
      futureAlg[3] = 0x02; // reserved for future AES-KEYWRAP, unsupported now

      await expectLater(
        unwrapKey(
          wrapped: WrappedEnvelope(futureAlg),
          wrappingKey: wrappingKey,
        ),
        throwsA(isA<UnsupportedAlgorithmException>()),
      );
    });
  });
}
