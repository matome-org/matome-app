// Tests for WebStoreOpener — task #1860, plan #131 (web wave).
//
// This is the security-relevant orchestration logic behind the web cold-start
// flow (§3/§4 of .docs/internal/at-rest-key-flow.md): unwrap DEK via the
// SHARED KeyUnwrapper core (no web fork) -> read persisted ciphertext ->
// decrypt. Exercised here against an in-memory EncryptedBlobStore fake, so it
// runs under plain `flutter test` with no browser/OPFS dependency — the
// real OPFS wiring lives in web_opfs_blob_store.dart (web-only, verified
// separately; see the task return-note for what's unit- vs browser-verified).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/db_image_cipher.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/db/encrypted_blob_store.dart';
import 'package:matome_flutter/core/db/web_store_opener.dart';

Uint8List _salt16(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xff));

void main() {
  group('WebStoreOpener.open — cold start', () {
    test(
      'fresh install (no persisted blob yet): unwraps the DEK but '
      'reports plaintextImage == null (never fabricates an empty image)',
      () async {
        const password = 'first ever login on this browser';
        final saltEnc = _salt16(1);
        final dek = Dek.generate();
        final wrappedDekPw = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: await _kekFor(password, saltEnc),
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );

        final opener = WebStoreOpener(blobStore: InMemoryBlobStore());
        final result = await opener.open(
          unwrapper: PasswordKeyUnwrapper(password: password, saltEnc: saltEnc),
          wrappedDekPw: wrappedDekPw,
        );

        expect(result.plaintextImage, isNull);
        expect(result.dek.bytes, dek.bytes);
      },
    );

    test(
      'returning user: correct password decrypts the persisted image',
      () async {
        const password = 'correct horse battery staple';
        final saltEnc = _salt16(2);
        final dek = Dek.generate();
        final wrappedDekPw = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: await _kekFor(password, saltEnc),
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );

        final blobStore = InMemoryBlobStore();
        final plaintextImage = Uint8List.fromList(
          utf8.encode('SQLite format 3 fake db bytes'),
        );
        await blobStore.write(
          await encryptDbImage(plaintext: plaintextImage, dek: dek.bytes),
        );

        final opener = WebStoreOpener(blobStore: blobStore);
        final result = await opener.open(
          unwrapper: PasswordKeyUnwrapper(password: password, saltEnc: saltEnc),
          wrappedDekPw: wrappedDekPw,
        );

        expect(result.plaintextImage, plaintextImage);
      },
    );

    test('fails closed: wrong password throws and does NOT open an empty '
        'store (no fallback branch)', () async {
      const rightPassword = 'right password';
      final saltEnc = _salt16(3);
      final dek = Dek.generate();
      final wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: await _kekFor(rightPassword, saltEnc),
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final blobStore = InMemoryBlobStore();
      await blobStore.write(
        await encryptDbImage(
          plaintext: Uint8List.fromList(utf8.encode('real data')),
          dek: dek.bytes,
        ),
      );

      final opener = WebStoreOpener(blobStore: blobStore);
      final wrongUnwrapper = PasswordKeyUnwrapper(
        password: 'totally wrong password',
        saltEnc: saltEnc,
      );

      await expectLater(
        () =>
            opener.open(unwrapper: wrongUnwrapper, wrappedDekPw: wrappedDekPw),
        throwsA(isA<EnvelopeTamperException>()),
      );
    });

    test(
      'fails closed: a corrupted persisted blob throws (even with the '
      'correct password) — never silently drops to an empty database',
      () async {
        const password = 'right password 2';
        final saltEnc = _salt16(4);
        final dek = Dek.generate();
        final wrappedDekPw = await wrapKey(
          plaintext: dek.bytes,
          wrappingKey: await _kekFor(password, saltEnc),
          payloadType: PayloadType.dek,
          wrapperType: WrapperType.passwordKek,
        );

        final blobStore = InMemoryBlobStore();
        final cipher = await encryptDbImage(
          plaintext: Uint8List.fromList(utf8.encode('real data')),
          dek: dek.bytes,
        );
        cipher[cipher.length - 1] ^= 0xff; // corrupt the last tag byte
        await blobStore.write(cipher);

        final opener = WebStoreOpener(blobStore: blobStore);

        await expectLater(
          () => opener.open(
            unwrapper: PasswordKeyUnwrapper(
              password: password,
              saltEnc: saltEnc,
            ),
            wrappedDekPw: wrappedDekPw,
          ),
          throwsA(isA<DbImageDecryptException>()),
        );
      },
    );
  });

  group('WebStoreOpener.persist', () {
    test('persists ciphertext (never the plaintext image) into the blob '
        'store, decryptable again via open()', () async {
      const password = 'persist round trip';
      final saltEnc = _salt16(5);
      final dek = Dek.generate();
      final wrappedDekPw = await wrapKey(
        plaintext: dek.bytes,
        wrappingKey: await _kekFor(password, saltEnc),
        payloadType: PayloadType.dek,
        wrapperType: WrapperType.passwordKek,
      );

      final blobStore = InMemoryBlobStore();
      final opener = WebStoreOpener(blobStore: blobStore);

      const marker = 'PLAINTEXT_SHOULD_NEVER_HIT_THE_BLOB_STORE_RAW';
      final plaintextImage = Uint8List.fromList(utf8.encode(marker));

      await opener.persist(plaintextImage: plaintextImage, dek: dek);

      final stored = await blobStore.read();
      expect(stored, isNotNull);
      expect(String.fromCharCodes(stored!).contains(marker), isFalse);

      final reopened = await opener.open(
        unwrapper: PasswordKeyUnwrapper(password: password, saltEnc: saltEnc),
        wrappedDekPw: wrappedDekPw,
      );
      expect(reopened.plaintextImage, plaintextImage);
    });
  });
}

Future<Uint8List> _kekFor(String password, Uint8List saltEnc) {
  return PasswordKeyUnwrapper(
    password: password,
    saltEnc: saltEnc,
  ).deriveKEK().then((kek) => kek.bytes);
}
