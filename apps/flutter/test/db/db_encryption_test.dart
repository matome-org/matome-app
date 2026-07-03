import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';

// ---------------------------------------------------------------------------
// SQLCipher key lifecycle (SEC audit-fix #815).
//
// Proves the first-boot-generates / subsequent-boot-reuses contract against a
// fake in-memory secure store (no flutter_secure_storage platform channel), and
// the PRAGMA key statement shape.
// ---------------------------------------------------------------------------

/// In-memory [SecureKeyStore] for tests; counts writes to assert persistence.
class _FakeKeyStore implements SecureKeyStore {
  final Map<String, String> _data = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    _data[key] = value;
  }

  /// Test-only helper (not part of [SecureKeyStore]): simulates an OS
  /// keystore entry vanishing (e.g. the `resetOnError` wipe footgun).
  Future<void> remove(String key) async => _data.remove(key);
}

/// Deterministic Random so the generated key is predictable in tests.
class _SeededRandom implements Random {
  _SeededRandom(this._delegate);
  final Random _delegate;
  @override
  int nextInt(int max) => _delegate.nextInt(max);
  @override
  bool nextBool() => _delegate.nextBool();
  @override
  double nextDouble() => _delegate.nextDouble();
}

void main() {
  group('DbEncryptionKeyManager', () {
    test('first boot generates a 256-bit key and persists it', () async {
      final store = _FakeKeyStore();
      final mgr = DbEncryptionKeyManager(store);

      final key = await mgr.obtainKey();

      // 32 bytes -> 64 hex chars.
      expect(key, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
      // Persisted under the documented key, exactly one write.
      expect(store.writes, 1);
      expect(await store.read(DbEncryptionKeyManager.storageKey), key);
    });

    test('subsequent boot reuses the stored key (no regenerate, no new write)',
        () async {
      final store = _FakeKeyStore();

      final first = await DbEncryptionKeyManager(store).obtainKey();
      // Fresh manager instance == a fresh app boot reading the same store.
      final second = await DbEncryptionKeyManager(store).obtainKey();

      expect(second, first); // same key -> the encrypted DB keeps opening
      expect(store.writes, 1); // only the first boot wrote
    });

    test('two independent stores generate different keys (entropy sanity)',
        () async {
      final a = await DbEncryptionKeyManager(_FakeKeyStore()).obtainKey();
      final b = await DbEncryptionKeyManager(_FakeKeyStore()).obtainKey();
      expect(a, isNot(b));
    });

    test('an empty stored value is treated as missing and regenerated',
        () async {
      final store = _FakeKeyStore();
      await store.write(DbEncryptionKeyManager.storageKey, '');

      final key = await DbEncryptionKeyManager(store).obtainKey();
      expect(key, isNotEmpty);
      expect(key, hasLength(64));
    });

    test('respects an injected Random for deterministic generation', () async {
      final store = _FakeKeyStore();
      final mgr =
          DbEncryptionKeyManager(store, random: _SeededRandom(Random(42)));
      final mgr2 = DbEncryptionKeyManager(
        _FakeKeyStore(),
        random: _SeededRandom(Random(42)),
      );
      expect(await mgr.obtainKey(), await mgr2.obtainKey());
    });

    test('pragmaKeyStatement wraps the hex key as a raw SQLCipher key', () {
      const hex = 'deadbeef';
      expect(
        DbEncryptionKeyManager.pragmaKeyStatement(hex),
        'PRAGMA key = "x\'deadbeef\'"',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // DeviceKeystoreKeyUnwrapper — task #1850, plan #131 W1.
  //
  // Passwordless native backend for the KeyUnwrapper strategy interface
  // (core/crypto/key_unwrapper.dart): the device-KEK bytes come from the OS
  // keystore via SecureKeyStore/FlutterSecureKeyStore, never from anything
  // the user types. Unwraps `wrapped_dek_device`.
  // ---------------------------------------------------------------------------
  group('DeviceKeystoreKeyUnwrapper', () {
    Uint8List key32(int seed) =>
        Uint8List.fromList(List.generate(32, (i) => (i + seed) & 0xff));

    String hex(Uint8List bytes) {
      final sb = StringBuffer();
      for (final b in bytes) {
        sb.write(b.toRadixString(16).padLeft(2, '0'));
      }
      return sb.toString();
    }

    test('deriveKEK reads the device-KEK hex from the secure store and '
        'unwrapDek recovers the DEK from wrapped_dek_device', () async {
      final store = _FakeKeyStore();
      final deviceKek = key32(9);
      await store.write(DeviceKeystoreKeyUnwrapper.storageKey, hex(deviceKek));

      final dek = Dek.generate();
      final wrappedDekDevice = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: deviceKek,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );

      final unwrapper = DeviceKeystoreKeyUnwrapper(store);
      final recovered = await unwrapper.unwrapDek(wrappedDekDevice);

      expect(recovered.bytes, dek.bytes);
    });

    test('deriveKEK throws explicitly when no device KEK has been '
        'enrolled yet (no silent fallback)', () async {
      final unwrapper = DeviceKeystoreKeyUnwrapper(_FakeKeyStore());
      expect(unwrapper.deriveKEK(), throwsA(isA<StateError>()));
    });

    test('unwrapDek fails explicitly (does not silently wipe/regenerate) '
        'when the stored device KEK is wrong for the wrapped blob', () async {
      final store = _FakeKeyStore();
      await store.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        hex(key32(1)),
      );

      final dek = Dek.generate();
      final wrappedDekDevice = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: key32(2), // different key than what's stored
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.deviceKek,
      );

      final unwrapper = DeviceKeystoreKeyUnwrapper(store);
      expect(
        () => unwrapper.unwrapDek(wrappedDekDevice),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // resetOnError: false — CRITICAL for the device-KEK secure store.
  //
  // flutter_secure_storage 10.x's AndroidOptions.resetOnError defaults to
  // `true`: on a platform decrypt error it silently WIPES the stored value.
  // For the DEK-wrapping key (unlike the JWT/token_store case) that is an
  // unrecoverable lockout, so buildDeviceKekSecureStorage() MUST always
  // construct AndroidOptions with resetOnError: false.
  // ---------------------------------------------------------------------------
  group('buildDeviceKekSecureStorage', () {
    test('constructs AndroidOptions with resetOnError: false', () {
      final storage = buildDeviceKekSecureStorage();
      final androidOptions = storage.aOptions;
      expect(androidOptions.toMap()['resetOnError'], 'false');
    });
  });

  // ---------------------------------------------------------------------------
  // NativeDekProvisioner — task #1853, plan #131 W3.
  //
  // The DEK source the LIVE native SQLCipher open path (connection_native.dart
  // `openEncryptedNativeConnection`) actually calls. Proves the bootstrap /
  // reuse / fails-closed contract at the key-material layer, independent of
  // SQLCipher itself (the SQLCipher-level wrong-key proof lives in
  // sqlcipher_encrypted_open_test.dart, gated on a built native lib).
  // ---------------------------------------------------------------------------
  group('NativeDekProvisioner', () {
    test('first call (no prior enrollment) bootstraps a device-KEK + wrapped '
        'DEK entirely offline, and persists both', () async {
      final store = _FakeKeyStore();
      final dek = await NativeDekProvisioner(store).obtainDek();

      expect(dek.bytes, hasLength(32));
      expect(
        await store.read(DeviceKeystoreKeyUnwrapper.storageKey),
        isNotNull,
        reason: 'a device-KEK must be minted on first boot',
      );
      expect(
        await store.read(NativeDekProvisioner.wrappedDekStorageKey),
        isNotNull,
        reason: 'the DEK must be persisted wrapped, never raw',
      );
    });

    test('subsequent calls against the same store reuse the SAME DEK '
        '(no silent regeneration on every open)', () async {
      final store = _FakeKeyStore();
      final first = await NativeDekProvisioner(store).obtainDek();
      final second = await NativeDekProvisioner(store).obtainDek();

      expect(second.bytes, first.bytes);
    });

    test('two independent stores bootstrap different DEKs (entropy sanity)',
        () async {
      final a = await NativeDekProvisioner(_FakeKeyStore()).obtainDek();
      final b = await NativeDekProvisioner(_FakeKeyStore()).obtainDek();
      expect(a.bytes, isNot(b.bytes));
    });

    test('fails closed: an enrolled device (wrapped DEK present) whose '
        'device-KEK has vanished from the keystore throws — NEVER mints a '
        'replacement DEK that would orphan the existing encrypted database',
        () async {
      final store = _FakeKeyStore();
      await NativeDekProvisioner(store).obtainDek(); // enroll once
      await store.remove(DeviceKeystoreKeyUnwrapper.storageKey); // simulate
      // a wiped/corrupted OS keystore entry (e.g. the resetOnError footgun).

      expect(
        NativeDekProvisioner(store).obtainDek(),
        throwsA(isA<StateError>()),
      );
    });

    test('fails closed: an enrolled device whose device-KEK bytes changed '
        '(tampered/wrong) throws on unwrap — never silently regenerates',
        () async {
      final store = _FakeKeyStore();
      await NativeDekProvisioner(store).obtainDek(); // enroll once
      // Overwrite the device-KEK with different, well-formed hex bytes —
      // simulates a corrupted keystore entry that still *reads* successfully
      // but no longer unwraps the previously-wrapped DEK.
      await store.write(
        DeviceKeystoreKeyUnwrapper.storageKey,
        'ff' * 32,
      );

      expect(
        NativeDekProvisioner(store).obtainDek(),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });
  });
}
