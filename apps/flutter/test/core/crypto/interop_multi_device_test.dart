// Multi-device interop fixture — task #1857, plan #131 Wave 5 (verify-only).
//
// This is the AC's key new artifact: proof that the SAME DEK, wrapped under
// THREE independent KEKs (one password-KEK, and two INDEPENDENT device-KEKs
// standing in for two different physical devices enrolled on the same
// account), unwraps to byte-identical plaintext through every backend. This
// is the entire multi-device model: the server only ever stores/relays
// opaque `wrapped_dek_*` blobs (proven separately by
// `key_bundle_controller_test.exs`'s opaque-only test); it is the SAME DEK
// underneath every wrap that lets two devices — or a device and a
// password-recovery flow — decrypt the same at-rest data.
//
// No new production code is added by this test — [PasswordKeyUnwrapper],
// [DeviceKeystoreKeyUnwrapper], and the shared `KeyUnwrapper.unwrapDek` core
// already exist (tasks #1849/#1850/#1853). This file only proves an
// interop property those units didn't individually assert: that DIFFERENT
// backends, wrapping the SAME DEK under DIFFERENT keys, are interoperable
// through the ONE shared unwrap core (`key_unwrapper.dart`'s INVARIANT:
// `unwrapDek` cannot be overridden per-backend).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';

/// Minimal in-memory [SecureKeyStore] — one instance per simulated device,
/// so device A's and device B's OS-keystore-backed device-KEK never share
/// storage (mirrors two independent phones/laptops, not two callers against
/// the same keystore).
class _FakeDeviceSecureStore implements SecureKeyStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

Uint8List _salt16(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xff));

void main() {
  group('Interop fixture — one account, one DEK, three independent wraps', () {
    test('password-KEK wrap + TWO different device-KEK wraps (device A, device '
        'B) all unwrap to the SAME DEK bytes', () async {
      // The account's single DEK — this is the key that actually
      // encrypts the at-rest DB/media on every device. It is generated
      // ONCE and never regenerated for this fixture; every wrap below
      // wraps THIS SAME 32 bytes.
      final dek = Dek.generate();
      final originalDekBytes = Uint8List.fromList(dek.bytes);

      // --- Wrap 1: password-KEK (the cross-device "primary" unlock path,
      // §4 of at-rest-key-flow.md — this is what a NEW device re-derives
      // from the user's password + the server-issued salt_enc to join the
      // same account). ---
      const password = 'the account holder\'s real password';
      final saltEnc = _salt16(11);
      final passwordUnwrapper = PasswordKeyUnwrapper(
        password: password,
        saltEnc: saltEnc,
      );
      final passwordKek = await passwordUnwrapper.deriveKEK();
      final wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: passwordKek.bytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      // --- Wrap 2 & 3: two INDEPENDENT device-KEKs, simulating two
      // separate physical devices (e.g. a phone and a laptop) enrolled on
      // the same account. Each device generates its OWN device-KEK,
      // entirely locally (OS keystore), and wraps the SAME account DEK
      // under it — never generating a device-local DEK of its own. This
      // is precisely the multi-device model: N devices, N independent
      // device-KEKs, ONE shared DEK. ---
      final storeDeviceA = _FakeDeviceSecureStore();
      final deviceKekA = Uint8List.fromList(
        List.generate(32, (i) => (i * 3 + 1) & 0xff),
      );
      await storeDeviceA.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hexEncodeKeyBytes(deviceKekA),
      );
      final wrappedDekDeviceA = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: deviceKekA,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );

      final storeDeviceB = _FakeDeviceSecureStore();
      final deviceKekB = Uint8List.fromList(
        List.generate(32, (i) => (i * 7 + 5) & 0xff),
      );
      await storeDeviceB.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hexEncodeKeyBytes(deviceKekB),
      );
      final wrappedDekDeviceB = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: deviceKekB,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );

      // Sanity: the two device-KEKs really are different (otherwise the
      // "two different devices" premise of this fixture would be
      // vacuous) and the wrapped blobs differ too (fresh nonce per wrap,
      // never mind the different keys).
      expect(deviceKekA, isNot(equals(deviceKekB)));
      expect(wrappedDekDeviceA.bytes, isNot(equals(wrappedDekDeviceB.bytes)));
      expect(wrappedDekPw.bytes, isNot(equals(wrappedDekDeviceA.bytes)));

      // --- The actual interop assertion: unwrap EACH of the three
      // envelopes through the shared `KeyUnwrapper.unwrapDek` core (no
      // per-backend fork — see key_unwrapper.dart's INVARIANT), and
      // assert every recovered DEK is byte-identical to the original AND
      // to each other. This is what makes "log in from device A" and
      // "log in from device B" (or the password path) all decrypt the
      // SAME account data. ---
      final recoveredFromPassword = await passwordUnwrapper.unwrapDek(
        wrappedDekPw,
      );
      final recoveredFromDeviceA = await DeviceKeystoreKeyUnwrapper(
        storeDeviceA,
      ).unwrapDek(wrappedDekDeviceA);
      final recoveredFromDeviceB = await DeviceKeystoreKeyUnwrapper(
        storeDeviceB,
      ).unwrapDek(wrappedDekDeviceB);

      expect(recoveredFromPassword.bytes, originalDekBytes);
      expect(recoveredFromDeviceA.bytes, originalDekBytes);
      expect(recoveredFromDeviceB.bytes, originalDekBytes);

      // Redundant-but-explicit pairwise checks — the AC's literal wording
      // ("ALL unwrap to the SAME DEK bytes"), spelled out rather than
      // left implicit in the shared-constant comparisons above.
      expect(recoveredFromPassword.bytes, recoveredFromDeviceA.bytes);
      expect(recoveredFromDeviceA.bytes, recoveredFromDeviceB.bytes);
      expect(recoveredFromPassword.bytes, recoveredFromDeviceB.bytes);
    });

    test('cross-device substitution fails closed: device B can never unwrap '
        'device A\'s wrapped envelope (proves the two device-KEKs are '
        'genuinely independent, not silently interchangeable)', () async {
      final dek = Dek.generate();

      final storeDeviceA = _FakeDeviceSecureStore();
      final deviceKekA = Uint8List.fromList(
        List.generate(32, (i) => (i * 11 + 2) & 0xff),
      );
      await storeDeviceA.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hexEncodeKeyBytes(deviceKekA),
      );
      final wrappedDekDeviceA = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: deviceKekA,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );

      final storeDeviceB = _FakeDeviceSecureStore();
      final deviceKekB = Uint8List.fromList(
        List.generate(32, (i) => (i * 13 + 9) & 0xff),
      );
      await storeDeviceB.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hexEncodeKeyBytes(deviceKekB),
      );

      // Device B attempts to unwrap device A's wrapped blob using ITS OWN
      // (wrong, for this blob) device-KEK. Must fail explicitly via the
      // shared AEAD core — never silently succeed with garbage plaintext.
      await expectLater(
        () => DeviceKeystoreKeyUnwrapper(
          storeDeviceB,
        ).unwrapDek(wrappedDekDeviceA),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });
  });
}
