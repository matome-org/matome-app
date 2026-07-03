// Tests for WebKeyBundleCache — task #1860, plan #131 (web wave).
//
// Proves the offline-availability contract: once written, salt_enc +
// wrapped_dek_pw + kdf_params round-trip byte-for-byte through a fake
// SecureKeyStore (no flutter_secure_storage platform channel, mirrors the
// pattern in test/db/db_encryption_test.dart), and that "never cached" reads
// back as `null` rather than throwing or fabricating a value (the CF-1 case:
// a device/browser that has never completed an online /keybundle round trip
// has nothing to read here).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:matome_flutter/core/db/web_key_bundle_cache.dart';

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
}

Uint8List _salt16(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xff));

void main() {
  group('WebKeyBundleCache', () {
    test('a fresh device/browser (never cached) reads back null', () async {
      final cache = WebKeyBundleCache(_FakeKeyStore());
      expect(await cache.read(), isNull);
    });

    test('round-trips wrapped_dek_pw, salt_enc, and kdf_params', () async {
      final store = _FakeKeyStore();
      final cache = WebKeyBundleCache(store);

      final dek = Dek.generate();
      final kek = Uint8List.fromList(List.generate(32, (i) => i));
      final wrapped = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      final saltEnc = _salt16(7);

      await cache.write(
        CachedKeyBundleSaltInfo(
          wrappedDekPw: wrapped,
          saltEnc: saltEnc,
          kdfParams: Argon2idParams.portableV1,
        ),
      );

      final read = await cache.read();
      expect(read, isNotNull);
      expect(read!.wrappedDekPw.bytes, wrapped.bytes);
      expect(read.saltEnc, saltEnc);
      expect(read.kdfParams, Argon2idParams.portableV1);
    });

    test('a second write overwrites the first (latest keybundle wins)',
        () async {
      final store = _FakeKeyStore();
      final cache = WebKeyBundleCache(store);
      final dek = Dek.generate();
      final kek = Uint8List.fromList(List.generate(32, (i) => i));

      final wrappedA = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      await cache.write(
        CachedKeyBundleSaltInfo(
          wrappedDekPw: wrappedA,
          saltEnc: _salt16(1),
          kdfParams: Argon2idParams.portableV1,
        ),
      );

      final wrappedB = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );
      await cache.write(
        CachedKeyBundleSaltInfo(
          wrappedDekPw: wrappedB,
          saltEnc: _salt16(2),
          kdfParams: Argon2idParams.portableV1,
        ),
      );

      final read = await cache.read();
      expect(read!.saltEnc, _salt16(2));
      expect(read.wrappedDekPw.bytes, wrappedB.bytes);
    });

    test('clear() makes a subsequent read() return null again', () async {
      final store = _FakeKeyStore();
      final cache = WebKeyBundleCache(store);
      final dek = Dek.generate();
      final kek = Uint8List.fromList(List.generate(32, (i) => i));
      final wrapped = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: kek,
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      await cache.write(
        CachedKeyBundleSaltInfo(
          wrappedDekPw: wrapped,
          saltEnc: _salt16(3),
          kdfParams: Argon2idParams.portableV1,
        ),
      );
      expect(await cache.read(), isNotNull);

      await cache.clear();
      expect(await cache.read(), isNull);
    });
  });
}
