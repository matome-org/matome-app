// Task #1855 (plan #131 W4) — TDD coverage for the streaming per-file media
// cipher: FEK wrap/unwrap round-trip, framed on-disk format, the per-chunk
// nonce construction, a plaintext-scan proof (zero plaintext markers survive
// on disk), and per-chunk tamper detection.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart' show WrapperType;
import 'package:matome_flutter/core/crypto/key_material.dart' show Dek;
import 'package:matome_flutter/core/crypto/media_cipher.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_cipher_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  Uint8List randomBytes(int length, {int seed = 42}) {
    final rng = Random(seed);
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  group('nonce construction', () {
    test('is 12 bytes: 4-byte prefix ‖ 8-byte BE counter', () {
      final prefix = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);
      final nonce = mediaNonceFor(prefix, 5);
      expect(nonce.length, 12);
      expect(nonce.sublist(0, 4), prefix);
      expect(nonce.sublist(4, 12), [0, 0, 0, 0, 0, 0, 0, 5]);
    });

    test('is deterministic for the same (prefix, counter)', () {
      final prefix = Uint8List.fromList([1, 2, 3, 4]);
      expect(mediaNonceFor(prefix, 7), mediaNonceFor(prefix, 7));
    });

    test('every counter in a long run yields a pairwise-distinct nonce', () {
      final prefix = Uint8List.fromList([9, 8, 7, 6]);
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        final nonce = mediaNonceFor(prefix, i);
        final key = base64.encode(nonce);
        expect(
          seen.add(key),
          isTrue,
          reason: 'nonce for counter=$i collided with an earlier counter',
        );
      }
    });

    test('rejects a prefix that is not exactly 4 bytes', () {
      expect(
        () => mediaNonceFor(Uint8List(3), 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('chunk-count bound (nonce cannot wrap)', () {
    test('accepts counts at/under the ceiling', () {
      expect(() => assertChunkCountWithinBound(0), returnsNormally);
      expect(() => assertChunkCountWithinBound(kMediaMaxChunks), returnsNormally);
    });

    test('throws once the ceiling is exceeded', () {
      expect(
        () => assertChunkCountWithinBound(kMediaMaxChunks + 1),
        throwsA(isA<MediaCipherFileTooLargeException>()),
      );
    });
  });

  group('round-trip', () {
    Future<Uint8List> collect(Stream<List<int>> stream) async {
      final out = BytesBuilder();
      await for (final part in stream) {
        out.add(part);
      }
      return out.takeBytes();
    }

    test('empty file round-trips to empty bytes', () async {
      final dek = Dek.generate();
      final enc = File('${tmp.path}/empty.enc');
      final result = await encryptStreamToFile(
        plaintext: const Stream<List<int>>.empty(),
        destination: enc,
        dek: dek,
      );

      final decrypted = await collect(
        decryptFileStream(source: enc, wrappedFek: result.wrappedFek, dek: dek),
      );
      expect(decrypted, isEmpty);
      // Header-only file: magic(4) + version(1) + noncePrefix(4).
      expect(await enc.length(), kMediaHeaderLength);
    });

    test('single-chunk (smaller than chunk size) file round-trips exactly', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(1024, seed: 1);
      final src = File('${tmp.path}/src_small.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/small.enc');

      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);
      final decrypted = await collect(
        decryptFileStream(source: enc, wrappedFek: result.wrappedFek, dek: dek),
      );
      expect(decrypted, plaintext);
    });

    test('multi-chunk file (several full chunks + a remainder) round-trips exactly', () async {
      final dek = Dek.generate();
      // 3.5 chunks so both full-chunk flushing and the final partial-chunk
      // flush path are exercised.
      final size = (kMediaChunkPlaintextSize * 3.5).floor();
      final plaintext = randomBytes(size, seed: 2);
      final src = File('${tmp.path}/src_multi.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/multi.enc');

      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);
      final decrypted = await collect(
        decryptFileStream(source: enc, wrappedFek: result.wrappedFek, dek: dek),
      );
      expect(decrypted.length, plaintext.length);
      expect(decrypted, plaintext);
    });

    test('exact chunk-size-multiple file round-trips exactly (no dangling empty frame)', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(kMediaChunkPlaintextSize * 2, seed: 3);
      final src = File('${tmp.path}/src_exact.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/exact.enc');

      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);
      final decrypted = await collect(
        decryptFileStream(source: enc, wrappedFek: result.wrappedFek, dek: dek),
      );
      expect(decrypted, plaintext);
    });

    test('decryptToFile streams into a real plaintext file that matches the source', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(kMediaChunkPlaintextSize + 500, seed: 4);
      final src = File('${tmp.path}/src_df.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/df.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final out = File('${tmp.path}/df.out');
      await decryptToFile(
        source: enc,
        wrappedFek: result.wrappedFek,
        dek: dek,
        destination: out,
      );
      expect(await out.readAsBytes(), plaintext);
    });

    test('wrong DEK fails to unwrap the FEK (never returns plaintext)', () async {
      final dek = Dek.generate();
      final wrongDek = Dek.generate();
      final plaintext = randomBytes(2048, seed: 5);
      final src = File('${tmp.path}/src_wrongkey.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/wrongkey.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: wrongDek,
        ).toList(),
        throwsA(isNotNull),
      );
    });
  });

  group('plaintext-scan — zero plaintext markers survive on disk', () {
    test('a known marker repeated across chunk boundaries never appears in the ciphertext file', () async {
      final dek = Dek.generate();
      const marker = 'MATOME_SECRET_MARKER_0123456789abcdef_DO_NOT_LEAK';
      final markerBytes = utf8.encode(marker);

      // Build plaintext so the marker straddles chunk boundaries multiple
      // times (not just conveniently chunk-aligned).
      final buffer = BytesBuilder();
      final filler = randomBytes(777, seed: 99);
      while (buffer.length < kMediaChunkPlaintextSize * 3) {
        buffer.add(filler);
        buffer.add(markerBytes);
      }
      final plaintext = buffer.takeBytes();

      final src = File('${tmp.path}/src_marker.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/marker.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      // Sanity: the marker really is present in the plaintext source (the
      // test would be vacuous otherwise).
      expect(_countOccurrences(plaintext, markerBytes), greaterThan(1));

      final onDisk = await enc.readAsBytes();
      expect(
        _countOccurrences(onDisk, markerBytes),
        0,
        reason: 'plaintext marker bytes leaked into the on-disk ciphertext',
      );

      // Also scan for the header's own noncePrefix leaking as a red herring
      // check that the scan itself is meaningful — the header IS expected to
      // be there (public, non-secret), decrypt still round-trips.
      final decrypted = BytesBuilder();
      await for (final part in decryptFileStream(
        source: enc,
        wrappedFek: result.wrappedFek,
        dek: dek,
      )) {
        decrypted.add(part);
      }
      expect(decrypted.takeBytes(), plaintext);
    });
  });

  group('tamper detection', () {
    test('flipping a ciphertext byte in a chunk throws MediaChunkTamperException', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(2048, seed: 11);
      final src = File('${tmp.path}/src_tamper1.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/tamper1.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final bytes = (await enc.readAsBytes()).toList();
      // First chunk's ciphertext starts right after header(9) + length-prefix(4).
      final ciphertextStart = kMediaHeaderLength + kMediaFrameLengthPrefix;
      bytes[ciphertextStart] ^= 0xFF;
      await enc.writeAsBytes(bytes);

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaChunkTamperException>()),
      );
    });

    test('flipping a tag byte throws MediaChunkTamperException', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(500, seed: 13);
      final src = File('${tmp.path}/src_tamper2.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/tamper2.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final bytes = (await enc.readAsBytes()).toList();
      bytes[bytes.length - 1] ^= 0xFF; // last byte of the GCM tag
      await enc.writeAsBytes(bytes);

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaChunkTamperException>()),
      );
    });

    test('tampering the header nonce prefix breaks every chunk (wrong nonce ⇒ auth failure)', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(1024, seed: 14);
      final src = File('${tmp.path}/src_tamper3.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/tamper3.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final bytes = (await enc.readAsBytes()).toList();
      // noncePrefix occupies header bytes [5..9).
      bytes[5] ^= 0xFF;
      await enc.writeAsBytes(bytes);

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaChunkTamperException>()),
      );
    });

    test('a second chunk is tampered independently of the first (per-chunk isolation)', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(kMediaChunkPlaintextSize * 2 + 10, seed: 15);
      final src = File('${tmp.path}/src_tamper4.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/tamper4.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final bytes = (await enc.readAsBytes()).toList();
      // Second chunk's frame starts after header + first frame
      // (4-byte length + chunkSize ciphertext + 16-byte tag).
      final firstFrameLen = kMediaFrameLengthPrefix + kMediaChunkPlaintextSize + kMediaTagLength;
      final secondChunkCiphertextStart =
          kMediaHeaderLength + firstFrameLen + kMediaFrameLengthPrefix;
      bytes[secondChunkCiphertextStart] ^= 0xFF;
      await enc.writeAsBytes(bytes);

      final stream = decryptFileStream(
        source: enc,
        wrappedFek: result.wrappedFek,
        dek: dek,
      );
      final collected = <int>[];
      await expectLater(
        () async {
          await for (final part in stream) {
            collected.addAll(part);
          }
        }(),
        throwsA(isA<MediaChunkTamperException>()),
      );
      // The first (untampered) chunk must have been yielded successfully
      // before the tampered second chunk threw.
      expect(collected.length, kMediaChunkPlaintextSize);
    });
  });

  group('format validation', () {
    test('rejects a file with bad magic bytes', () async {
      final dek = Dek.generate();
      final bogus = File('${tmp.path}/bogus.enc')
        ..writeAsBytesSync(List.filled(kMediaHeaderLength, 0));
      final fakeWrapped = (await encryptFileToFile(
        source: File('${tmp.path}/src_fake.bin')..writeAsBytesSync([1, 2, 3]),
        destination: File('${tmp.path}/fake.enc'),
        dek: dek,
      )).wrappedFek;

      expect(
        () => decryptFileStream(
          source: bogus,
          wrappedFek: fakeWrapped,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaCipherFormatException>()),
      );
    });

    test('rejects an unsupported format version byte', () async {
      final dek = Dek.generate();
      final src = File('${tmp.path}/src_ver.bin')..writeAsBytesSync([1, 2, 3, 4]);
      final enc = File('${tmp.path}/ver.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final bytes = (await enc.readAsBytes()).toList();
      bytes[kMediaMagicLength] = 0x99; // corrupt version byte
      await enc.writeAsBytes(bytes);

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaCipherUnsupportedVersionException>()),
      );
    });

    test('rejects a truncated chunk frame (cut mid-ciphertext)', () async {
      final dek = Dek.generate();
      final plaintext = randomBytes(2048, seed: 16);
      final src = File('${tmp.path}/src_trunc.bin')..writeAsBytesSync(plaintext);
      final enc = File('${tmp.path}/trunc.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      final full = await enc.readAsBytes();
      // Cut off the last 5 bytes — lands mid-tag/mid-ciphertext.
      await enc.writeAsBytes(full.sublist(0, full.length - 5));

      expect(
        () => decryptFileStream(
          source: enc,
          wrappedFek: result.wrappedFek,
          dek: dek,
        ).toList(),
        throwsA(isA<MediaCipherFormatException>()),
      );
    });
  });

  group('FEK wrap layout', () {
    test('wraps the FEK with wrapperType = dekAsWrappingKey (DEK wraps FEK)', () async {
      final dek = Dek.generate();
      final src = File('${tmp.path}/src_wrap.bin')..writeAsBytesSync([1, 2, 3]);
      final enc = File('${tmp.path}/wrap.enc');
      final result = await encryptFileToFile(source: src, destination: enc, dek: dek);

      expect(result.wrappedFek.wrapperType, WrapperType.dekAsWrappingKey.byteValue);
      expect(result.noncePrefix.length, kMediaNoncePrefixLength);
    });

    test('noncePrefix round-trips through base64 encode/decode', () {
      final prefix = Uint8List.fromList([10, 20, 30, 40]);
      final encoded = encodeNoncePrefix(prefix);
      expect(decodeNoncePrefix(encoded), prefix);
    });
  });
}

int _countOccurrences(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) count++;
  }
  return count;
}
