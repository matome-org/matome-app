// Plaintext-scan proof for everything the web client persists into OPFS —
// task #1861, plan #131 (web wave). Extends #1860's own inline scan
// assertion (`web_store_opener_test.dart`'s "persists ciphertext ... never
// the plaintext image", one marker) into a dedicated test with MANY
// realistic plaintext markers, covering both content types the AC calls
// out:
//
//   - DB:    the whole-image codec OPFS actually writes to
//            (`db_image_cipher.dart`'s `encryptDbImage`, via the exact
//            `WebStoreOpener.persist` write path — `web_opfs_blob_store.dart`
//            never receives anything but this function's output).
//   - Media: the per-file codec (`media_cipher.dart`'s `encryptFileToFile`)
//            that encrypts imported/recorded audio at rest (#1855). Web does
//            not yet route media through its own OPFS blob store (only the
//            DB image is wired to OPFS as of #1860) — this test exercises
//            the actual production media codec directly so the claim covers
//            the real at-rest media format, not a stand-in. Documented
//            honestly rather than silently only testing the DB path.
//
// The scan itself: build a plaintext blob containing many recognizable
// "sensitive" substrings (matome titles, transcript sentences, contact
// emails, a fake recovery-code shape, a fake session-token shape) placed at
// varying offsets — including offsets that straddle a chunk boundary, since
// both codecs split large payloads into fixed-size AEAD chunks and a naive
// implementation could accidentally leak a boundary-adjacent plaintext
// fragment. Assert NONE of the markers appear anywhere in the ciphertext
// bytes, byte-for-byte, in either direction (a marker's reverse is checked
// too as a cheap extra sanity net against accidental byte-order mistakes).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/db_image_cipher.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/media_cipher.dart';
import 'package:matome_flutter/core/db/encrypted_blob_store.dart';
import 'package:matome_flutter/core/db/web_store_opener.dart';

/// Realistic plaintext content an attacker with raw OPFS-file read access
/// (the durable-XSS scenario this task hardens against) would be hunting
/// for. Deliberately varied: natural-language transcript text, an email
/// address, a matome/space title, a recovery-code-shaped token, and a
/// session-token-shaped string.
const List<String> _kPlaintextMarkers = [
  'SENSITIVE_MATOME_TITLE_Board_Meeting_Q3_Layoffs',
  'transcript: "we are going to lay off the Tokyo office next month"',
  'contact.email=cfo@matome-internal.example',
  'RECOVERY-CODE-XXXX-YYYY-ZZZZ-1234-5678-90',
  'session_token=eyJhbGciOiJIUzI1NiJ9.super.secret',
  'diagnosis: patient reports chronic condition, do not disclose',
];

/// Builds a byte blob at least [minLength] bytes long that embeds every
/// marker in [_kPlaintextMarkers] at a distinct, deterministic offset,
/// including at least one marker placed to straddle a chunk boundary
/// (multiples of [chunkSize]).
Uint8List _buildPlaintextWithMarkers({
  required int minLength,
  required int chunkSize,
}) {
  final rng = Random(1337);
  final bytes = Uint8List.fromList(
    List.generate(minLength, (_) => rng.nextInt(256)),
  );

  // Chunk boundaries strictly inside the buffer (e.g. for a 3-chunk-sized
  // buffer: chunkSize and 2*chunkSize) — every other marker is centered on
  // one of these, so a chunk-framing bug (e.g. accidentally writing a
  // chunk's tail in the clear) would be caught, not just interior placements
  // far from any boundary.
  final boundaries = [chunkSize, chunkSize * 2]
      .where((b) => b < minLength)
      .toList();

  var cursor = 64; // leave some filler before the first interior marker
  var boundaryCycle = 0;
  for (var i = 0; i < _kPlaintextMarkers.length; i++) {
    final markerBytes = utf8.encode(_kPlaintextMarkers[i]);
    final int offset;
    if (i.isOdd && boundaries.isNotEmpty) {
      final boundary = boundaries[boundaryCycle % boundaries.length];
      // Shift repeat visits to the same boundary point so markers reusing
      // it (more odd-indexed markers than boundary points) don't overlap
      // and silently clobber each other.
      final repeatShift = (boundaryCycle ~/ boundaries.length) * 256;
      boundaryCycle++;
      offset = boundary - (markerBytes.length ~/ 2) + repeatShift;
    } else {
      offset = cursor;
      cursor += markerBytes.length + 32;
    }
    final end = offset + markerBytes.length;
    assert(
      end <= bytes.length,
      'marker $i placement out of bounds for this fixture size',
    );
    bytes.setRange(offset, end, markerBytes);
  }
  return bytes;
}

void _expectNoPlaintextMarkers(Uint8List ciphertext, {required String label}) {
  final asLatin1 = String.fromCharCodes(ciphertext);
  for (final marker in _kPlaintextMarkers) {
    expect(
      asLatin1.contains(marker),
      isFalse,
      reason: '$label ciphertext leaked plaintext marker "$marker"',
    );
    expect(
      asLatin1.contains(marker.split('').reversed.join()),
      isFalse,
      reason:
          '$label ciphertext leaked a byte-reversed plaintext marker '
          '"$marker" (sanity check against accidental byte-order bugs)',
    );
  }
}

void main() {
  group('OPFS plaintext-scan — DB image', () {
    test(
      'the exact bytes WebStoreOpener.persist writes to the OPFS blob store '
      'contain zero plaintext markers, including markers straddling a chunk '
      'boundary',
      () async {
        final dek = Dek.generate();
        final plaintext = _buildPlaintextWithMarkers(
          minLength: kDefaultChunkSize * 3, // spans multiple 64KiB chunks
          chunkSize: kDefaultChunkSize,
        );

        final blobStore = InMemoryBlobStore();
        final opener = WebStoreOpener(blobStore: blobStore);
        await opener.persist(plaintextImage: plaintext, dek: dek);

        final persisted = await blobStore.read();
        expect(persisted, isNotNull);
        _expectNoPlaintextMarkers(persisted!, label: 'DB image (OPFS)');

        // Round-trip proof that this really is the SAME plaintext (i.e. the
        // scan above is meaningful — it is not merely scanning empty/wrong
        // bytes).
        final reopened = await decryptDbImage(
          ciphertext: persisted,
          dek: dek.bytes,
        );
        expect(reopened, plaintext);
      },
    );

    test('an empty DB image (fresh install edge case) still round-trips '
        'with no marker leakage (vacuous but must not crash the scan)',
        () async {
      final dek = Dek.generate();
      final blobStore = InMemoryBlobStore();
      final opener = WebStoreOpener(blobStore: blobStore);

      await opener.persist(
        plaintextImage: Uint8List(0),
        dek: dek,
      );

      final persisted = await blobStore.read();
      expect(persisted, isNotNull);
      _expectNoPlaintextMarkers(persisted!, label: 'empty DB image (OPFS)');
    });
  });

  group('OPFS plaintext-scan — media', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('opfs_plaintext_scan_media_');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test(
      'the on-disk ciphertext produced by the media codec (the format used '
      'for imported/recorded audio at rest) contains zero plaintext markers, '
      'including markers straddling a chunk boundary',
      () async {
        final dek = Dek.generate();
        final plaintext = _buildPlaintextWithMarkers(
          minLength: kMediaChunkPlaintextSize * 3,
          chunkSize: kMediaChunkPlaintextSize,
        );

        final source = File('${tmp.path}/plaintext_media.bin');
        await source.writeAsBytes(plaintext);
        final destination = File('${tmp.path}/encrypted_media.enc');

        await encryptFileToFile(
          source: source,
          destination: destination,
          dek: dek,
        );

        final ciphertextBytes = await destination.readAsBytes();
        _expectNoPlaintextMarkers(
          Uint8List.fromList(ciphertextBytes),
          label: 'media file',
        );

        // The source plaintext file itself obviously still has the markers
        // (it's the input) — assert that as a sanity check the markers
        // really were present before encryption, so the scan above isn't
        // vacuously true against an empty/garbled input.
        final sourceBytes = await source.readAsBytes();
        final sourceAsLatin1 = String.fromCharCodes(sourceBytes);
        for (final marker in _kPlaintextMarkers) {
          expect(
            sourceAsLatin1.contains(marker),
            isTrue,
            reason: 'test setup bug: marker "$marker" missing from the '
                'plaintext fixture itself',
          );
        }
      },
    );
  });
}
