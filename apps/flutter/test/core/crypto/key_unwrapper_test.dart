// Tests for the KeyUnwrapper strategy interface — task #1850, plan #131 W1.
// Written FIRST per TDD.
//
// Implements §3 of .docs/internal/at-rest-key-flow.md: "the core — obtain
// wrapped DEK -> derive/obtain a KEK -> unwrap DEK -> open DB — is
// byte-identical everywhere. The ONLY branch is where the KEK comes from."
//
// This file proves that invariant for the two backends that don't need a
// platform channel (password always; a fake device-keystore backend here —
// the real flutter_secure_storage-backed one is covered in
// test/db/db_encryption_test.dart). It also drives the password backend
// against the real Argon2id + envelope primitives from #1849 end to end.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/argon2id.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/crypto/recovery_code.dart';
import 'package:matome_flutter/core/crypto/recovery_key_unwrapper.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';

Uint8List _salt16(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xff));

/// A minimal second [KeyUnwrapper] backend, standing in for the
/// device-keystore backend without touching flutter_secure_storage. Its
/// only job is to hand back a fixed KEK — proving that `unwrapDek` (the
/// shared core) works identically no matter which backend supplies the KEK.
class _FixedKekUnwrapper implements KeyUnwrapper {
  _FixedKekUnwrapper(this._kekBytes);
  final Uint8List _kekBytes;

  @override
  Future<Kek> deriveKEK() async => Kek(_kekBytes);
}

/// Spy backend (okt-audit B3): captures the exact [Kek] instance it hands
/// back from [deriveKEK] so the test can inspect *that same object's* bytes
/// after `unwrapDek` returns — the only way to observe an in-place wipe
/// rather than merely asserting the interface didn't crash.
class _SpyKekUnwrapper implements KeyUnwrapper {
  _SpyKekUnwrapper(this._kekBytesFactory);
  final Uint8List Function() _kekBytesFactory;

  /// The most recent [Kek] this backend derived. Non-null after
  /// [deriveKEK] has been awaited at least once.
  Kek? lastKek;

  @override
  Future<Kek> deriveKEK() async {
    final kek = Kek(_kekBytesFactory());
    lastKek = kek;
    return kek;
  }
}

/// In-memory [SecureKeyStore] double, local to this file so the
/// `DeviceKeystoreKeyUnwrapper` regression test below doesn't need
/// `flutter_secure_storage`'s platform channel.
class _FakeSecureKeyStore implements SecureKeyStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

String _hexEncode(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// A deliberately misbehaving backend that declares its OWN `unwrapDek`
/// method — the exact shadow the old doc claimed was "mechanically
/// impossible". It exists only to prove *when* Dart actually picks the
/// shadow vs. the shared extension core (okt-audit B3 warning).
class _ShadowingUnwrapper implements KeyUnwrapper {
  _ShadowingUnwrapper(this._kekBytes);
  final Uint8List _kekBytes;

  @override
  Future<Kek> deriveKEK() async => Kek(Uint8List.fromList(_kekBytes));

  /// Same name/signature as the extension method. On a *concrete-typed*
  /// reference this instance method wins over the extension — proving the
  /// fork is possible. It intentionally returns an all-zero sentinel DEK so
  /// the test can tell "the shadow ran" apart from "the shared core ran".
  Future<Dek> unwrapDek(WrappedEnvelope wrappedDek) async {
    return Dek(Uint8List(kSymmetricKeyLength));
  }
}

void main() {
  group('KeyUnwrapper interface + unwrapDek shared core', () {
    test(
      'PasswordKeyUnwrapper derives KEK via Argon2id and unwraps the DEK',
      () async {
        const password = 'correct horse battery staple';
        final saltEnc = _salt16(1);
        final dek = Dek.generate();

        final kekBytes = await deriveArgon2id(
          password: password,
          salt: saltEnc,
          params: Argon2idParams.portableV1,
        );
        final wrappedDekPw = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: kekBytes,
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );

        final unwrapper = PasswordKeyUnwrapper(
          password: password,
          saltEnc: saltEnc,
        );

        final recovered = await unwrapper.unwrapDek(wrappedDekPw);

        expect(recovered.bytes, dek.bytes);
      },
    );

    test(
      'PasswordKeyUnwrapper with the wrong password fails explicitly',
      () async {
        final saltEnc = _salt16(2);
        final dek = Dek.generate();

        final kekBytes = await deriveArgon2id(
          password: 'right password',
          salt: saltEnc,
          params: Argon2idParams.portableV1,
        );
        final wrappedDekPw = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: kekBytes,
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );

        final unwrapper = PasswordKeyUnwrapper(
          password: 'wrong password',
          saltEnc: saltEnc,
        );

        expect(
          () => unwrapper.unwrapDek(wrappedDekPw),
          throwsA(isA<EnvelopeTamperException>()),
        );
      },
    );

    test('invariant: the SAME unwrap core (unwrapDek) drives both the '
        'password backend and an independent KEK-source backend', () async {
      final dek = Dek.generate();

      // Backend A: password -> Argon2id KEK.
      const password = 'hunter2 hunter2';
      final saltEnc = _salt16(3);
      final kekPwBytes = await deriveArgon2id(
        password: password,
        salt: saltEnc,
        params: Argon2idParams.portableV1,
      );
      final wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kekPwBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      final KeyUnwrapper passwordBackend = PasswordKeyUnwrapper(
        password: password,
        saltEnc: saltEnc,
      );

      // Backend B: an entirely different KEK source (stands in for
      // device-keystore) — different key material, different class.
      final kekDeviceBytes = secureRandomBytes(kSymmetricKeyLength);
      final wrappedDekDevice = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kekDeviceBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );
      final KeyUnwrapper deviceBackend = _FixedKekUnwrapper(kekDeviceBytes);

      // Both backends are driven through the exact same `unwrapDek` method
      // — declared once, as an extension on the interface, so neither
      // backend class can shadow or fork it — yet both recover the
      // identical original DEK from their own wrapped blob.
      final recoveredViaPassword = await passwordBackend.unwrapDek(
        wrappedDekPw,
      );
      final recoveredViaDevice = await deviceBackend.unwrapDek(
        wrappedDekDevice,
      );

      expect(recoveredViaPassword.bytes, dek.bytes);
      expect(recoveredViaDevice.bytes, dek.bytes);
      expect(recoveredViaPassword.bytes, recoveredViaDevice.bytes);
    });

    test('unwrapDek wipes the derived KEK after use — the KEK bytes are '
        'actually zeroed, not just "didn\'t crash" (okt-audit B3: this must '
        'go RED if the wipe in key_unwrapper.dart is ever removed)', () async {
      final dek = Dek.generate();
      final kekBytes = await deriveArgon2id(
        password: 'ephemeral kek check',
        salt: _salt16(4),
        params: Argon2idParams.portableV1,
      );
      // Independent snapshot taken BEFORE the spy hands its (separate) copy
      // to unwrapDek, so we have something non-zero to contrast against.
      final originalKekBytes = Uint8List.fromList(kekBytes);
      final wrapped = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kekBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      // The spy hands unwrapDek a fresh Kek wrapping a COPY of kekBytes, and
      // keeps a reference to that exact Kek instance so we can inspect it
      // after unwrapDek returns.
      final spy = _SpyKekUnwrapper(() => Uint8List.fromList(kekBytes));

      final recovered = await spy.unwrapDek(wrapped);
      expect(recovered.bytes, dek.bytes);

      final derivedKek = spy.lastKek;
      expect(derivedKek, isNotNull, reason: 'deriveKEK must have been called');
      expect(
        derivedKek!.bytes,
        everyElement(0),
        reason:
            'unwrapDek must zero the KEK it derived internally once the '
            'DEK has been recovered — a non-zero byte here means the wipe '
            'was skipped or removed',
      );
      expect(
        derivedKek.bytes,
        isNot(equals(originalKekBytes)),
        reason:
            'sanity check: the pre-wipe KEK was genuinely non-zero, so the '
            'all-zero assertion above is meaningful and not vacuous',
      );
    });
  });

  group('extension invariant (okt-audit B3 warning)', () {
    test('a backend that declares its own unwrapDek member CAN shadow the '
        'shared core when called through a concrete-typed reference — the '
        'old "mechanically impossible to fork" doc claim was false', () async {
      final dek = Dek.generate();
      final kekBytes = await deriveArgon2id(
        password: 'shadow demo password',
        salt: _salt16(5),
        params: Argon2idParams.portableV1,
      );
      final wrapped = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kekBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final concrete = _ShadowingUnwrapper(kekBytes);

      // Concrete-typed reference: Dart resolves the class's OWN `unwrapDek`
      // instance method ahead of the extension, so the shadow runs and
      // returns its all-zero sentinel instead of the real DEK.
      final viaConcreteType = await concrete.unwrapDek(wrapped);
      expect(
        viaConcreteType.bytes,
        everyElement(0),
        reason:
            'the concrete-typed call must hit the shadow method, proving a '
            'backend really can fork unwrapDek if referenced by its own '
            'type',
      );

      // KeyUnwrapper-typed reference: the interface itself never declared
      // unwrapDek (only the extension provides it for that static type), so
      // the shared core runs regardless of the shadow method existing on
      // the runtime type.
      final KeyUnwrapper viaInterfaceType = concrete;
      final viaInterface = await viaInterfaceType.unwrapDek(wrapped);
      expect(
        viaInterface.bytes,
        dek.bytes,
        reason:
            'calling through a KeyUnwrapper-typed variable is what actually '
            'enforces the shared unwrap core — that is the real, narrower '
            'guarantee the doc now states',
      );
    });

    test('regression: none of the real backends (Password, DeviceKeystore, '
        'Recovery) shadow unwrapDek — calling each through its own concrete '
        'type still matches the shared core', () async {
      final dek = Dek.generate();

      // Password backend.
      final saltEnc = _salt16(6);
      final pwKekBytes = await deriveArgon2id(
        password: 'concrete-type regression password',
        salt: saltEnc,
        params: Argon2idParams.portableV1,
      );
      final wrappedPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: pwKekBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      final PasswordKeyUnwrapper passwordConcrete = PasswordKeyUnwrapper(
        password: 'concrete-type regression password',
        saltEnc: saltEnc,
      );
      expect((await passwordConcrete.unwrapDek(wrappedPw)).bytes, dek.bytes);

      // Device-keystore backend.
      final store = _FakeSecureKeyStore();
      final deviceKekBytes = secureRandomBytes(kSymmetricKeyLength);
      await store.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        _hexEncode(deviceKekBytes),
      );
      final wrappedDevice = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: deviceKekBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );
      final DeviceKeystoreKeyUnwrapper deviceConcrete =
          DeviceKeystoreKeyUnwrapper(store);
      expect((await deviceConcrete.unwrapDek(wrappedDevice)).bytes, dek.bytes);

      // Recovery backend.
      final saltRec = _salt16(7);
      final code = RecoveryCode.generate();
      final recoveryKekBytes = await code.stretch(
        saltRec: saltRec,
        params: Argon2idParams.portableV1,
      );
      final wrappedRecovery = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: recoveryKekBytes,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.recoveryKek,
      );
      final RecoveryKeyUnwrapper recoveryConcrete = RecoveryKeyUnwrapper(
        recoveryCode: code,
        saltRec: saltRec,
      );
      expect(
        (await recoveryConcrete.unwrapDek(wrappedRecovery)).bytes,
        dek.bytes,
      );
    });
  });
}
