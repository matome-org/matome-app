// Task #1866 (okt-audit media-read warning, pinned verdict on #1857) — TDD
// coverage for the playback SOURCE-RESOLUTION seam this task adds.
//
// The gap: `inbox_upload.dart` already writes encrypted media (`.enc` +
// wrapped FEK) once `kMediaEncryptionEnabled` flips on, and
// `media_cipher.dart` already has `decryptFileStream`/`decryptToFile` — but
// nothing on the READ side ever called them (only `media_migration.dart`'s
// rollback path decrypts, and that is a one-shot restore, not playback).
// `details_controller.dart`'s `_resolveAudioSource` opened `row.audioFilePath`
// straight as a plaintext file. Flipping the write flag today would make
// every newly-imported recording open as undecodable ciphertext garbage.
//
// This module is the resolution seam, written FIRST per this task's TDD
// requirement: given a stored path + the row's (nullable) `wrapped_fek`,
// decide whether a decrypt pass is needed before a player opens the file.
//   wrapped_fek == null -> passthrough, byte-identical to today's behavior.
//   wrapped_fek != null -> decrypt-to-scratch-file BEFORE returning a path.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/key_material.dart' show Dek;
import 'package:matome_flutter/core/crypto/media_cipher.dart'
    show
        encryptFileToFile,
        kMediaChunkPlaintextSize,
        kMediaFrameLengthPrefix,
        kMediaHeaderLength;
import 'package:matome_flutter/core/crypto/media_playback_resolver.dart';

Uint8List _randomBytes(int length, {int seed = 1}) {
  final rng = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('media_playback_resolver_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('resolvePlaybackPath', () {
    test(
      'wrappedFekBase64 == null returns sourcePath unchanged (today\'s exact '
      'behavior) and never touches the dekSource or scratch dir',
      () async {
        var dekSourceCalls = 0;
        var scratchDirCalls = 0;

        final resolved = await resolvePlaybackPath(
          recordingId: 'rec_plain',
          sourcePath: '/some/plain/path.m4a',
          wrappedFekBase64: null,
          dekSource: () async {
            dekSourceCalls++;
            return Dek.generate();
          },
          scratchDirSource: () async {
            scratchDirCalls++;
            return tmp;
          },
        );

        expect(resolved, '/some/plain/path.m4a');
        expect(dekSourceCalls, 0);
        expect(scratchDirCalls, 0);
      },
    );

    test(
      'wrappedFekBase64 != null decrypts to a scratch file and returns THAT '
      'path — never hands back the raw ciphertext path',
      () async {
        final dek = Dek.generate();
        final plaintext = _randomBytes(200 * 1024, seed: 7); // multi-chunk
        final sourceFile = File('${tmp.path}/rec_enc.enc');
        final result = await encryptFileToFile(
          source: File('${tmp.path}/plain.bin')
            ..writeAsBytesSync(plaintext),
          destination: sourceFile,
          dek: dek,
        );

        final scratchDir = Directory('${tmp.path}/scratch');

        final resolved = await resolvePlaybackPath(
          recordingId: 'rec_enc',
          sourcePath: sourceFile.path,
          wrappedFekBase64: result.wrappedFek.toBase64(),
          dekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
          scratchDirSource: () async => scratchDir,
        );

        expect(resolved, isNot(sourceFile.path));
        expect(resolved, startsWith(scratchDir.path));
        final resolvedBytes = await File(resolved).readAsBytes();
        expect(resolvedBytes, plaintext);
      },
    );

    test(
      'creates the scratch dir if missing',
      () async {
        final dek = Dek.generate();
        final plaintext = _randomBytes(10, seed: 3);
        final sourceFile = File('${tmp.path}/rec2.enc');
        final result = await encryptFileToFile(
          source: File('${tmp.path}/plain2.bin')
            ..writeAsBytesSync(plaintext),
          destination: sourceFile,
          dek: dek,
        );

        final scratchDir = Directory('${tmp.path}/does_not_exist_yet');
        expect(await scratchDir.exists(), isFalse);

        await resolvePlaybackPath(
          recordingId: 'rec2',
          sourcePath: sourceFile.path,
          wrappedFekBase64: result.wrappedFek.toBase64(),
          dekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
          scratchDirSource: () async => scratchDir,
        );

        expect(await scratchDir.exists(), isTrue);
      },
    );

    test(
      'repeat resolution for the same recordingId overwrites rather than '
      'accumulating scratch files',
      () async {
        final dek = Dek.generate();
        final plainFile = File('${tmp.path}/plain3.bin')
          ..writeAsBytesSync(_randomBytes(50, seed: 4));
        final sourceFile = File('${tmp.path}/rec3.enc');
        final result = await encryptFileToFile(
          source: plainFile,
          destination: sourceFile,
          dek: dek,
        );

        final scratchDir = Directory('${tmp.path}/scratch3');

        final first = await resolvePlaybackPath(
          recordingId: 'rec3',
          sourcePath: sourceFile.path,
          wrappedFekBase64: result.wrappedFek.toBase64(),
          dekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
          scratchDirSource: () async => scratchDir,
        );
        final second = await resolvePlaybackPath(
          recordingId: 'rec3',
          sourcePath: sourceFile.path,
          wrappedFekBase64: result.wrappedFek.toBase64(),
          dekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
          scratchDirSource: () async => scratchDir,
        );

        expect(first, second);
        final entries = await scratchDir.list().toList();
        expect(entries, hasLength(1));
      },
    );

    test(
      'okt-audit PASS-2 FINDING-1: a decrypt failure at the FEK-unwrap stage '
      '(wrong DEK) leaves NO scratch file behind — not even the zero-byte '
      'stray `File.openWrite()` creates the instant it opens the destination',
      () async {
        final rightDek = Dek.generate();
        final wrongDek = Dek.generate();
        final sourceFile = File('${tmp.path}/rec_wrongdek.enc');
        final result = await encryptFileToFile(
          source: File('${tmp.path}/plain_wrongdek.bin')
            ..writeAsBytesSync(_randomBytes(64, seed: 11)),
          destination: sourceFile,
          dek: rightDek,
        );

        final scratchDir = Directory('${tmp.path}/scratch_wrongdek');

        await expectLater(
          resolvePlaybackPath(
            recordingId: 'rec_wrongdek',
            sourcePath: sourceFile.path,
            wrappedFekBase64: result.wrappedFek.toBase64(),
            dekSource: () async => Dek(Uint8List.fromList(wrongDek.bytes)),
            scratchDirSource: () async => scratchDir,
          ),
          throwsA(anything),
        );

        final stray = File('${scratchDir.path}/rec_wrongdek.playback');
        expect(await stray.exists(), isFalse,
            reason: 'a failed FEK unwrap must not leave any scratch file, '
                'not even an empty one');
      },
    );

    test(
      'okt-audit PASS-2 FINDING-1: a decrypt failure MID-STREAM (a later '
      'chunk tampered, so an earlier chunk already wrote real plaintext to '
      'the scratch file) still leaves NO partial plaintext behind',
      () async {
        final dek = Dek.generate();
        // 3 chunks: two full 64 KiB chunks + a short tail, so chunk 0
        // succeeds and writes real plaintext before chunk 1's tamper fires.
        final plaintext = _randomBytes(
          kMediaChunkPlaintextSize * 2 + 1024,
          seed: 13,
        );
        final sourceFile = File('${tmp.path}/rec_midtamper.enc');
        final result = await encryptFileToFile(
          source: File('${tmp.path}/plain_midtamper.bin')
            ..writeAsBytesSync(plaintext),
          destination: sourceFile,
          dek: dek,
        );

        // Flip one ciphertext byte inside chunk 1's frame (chunk 0 is left
        // intact so it decrypts fine and is written to the scratch sink
        // before chunk 1's AEAD check fails).
        final bytes = await sourceFile.readAsBytes();
        final chunk0FrameSize =
            kMediaFrameLengthPrefix + kMediaChunkPlaintextSize + 16;
        final chunk1CiphertextStart =
            kMediaHeaderLength + chunk0FrameSize + kMediaFrameLengthPrefix;
        final tampered = Uint8List.fromList(bytes);
        tampered[chunk1CiphertextStart] ^= 0xFF;
        await sourceFile.writeAsBytes(tampered);

        final scratchDir = Directory('${tmp.path}/scratch_midtamper');

        await expectLater(
          resolvePlaybackPath(
            recordingId: 'rec_midtamper',
            sourcePath: sourceFile.path,
            wrappedFekBase64: result.wrappedFek.toBase64(),
            dekSource: () async => Dek(Uint8List.fromList(dek.bytes)),
            scratchDirSource: () async => scratchDir,
          ),
          throwsA(anything),
        );

        final partial = File('${scratchDir.path}/rec_midtamper.playback');
        expect(await partial.exists(), isFalse,
            reason: 'chunk 0\'s real plaintext must not survive a later '
                'chunk\'s tamper failure');
      },
    );

    test('wipes the Dek it receives from dekSource before returning', () async {
      final dek = Dek.generate();
      final sourceFile = File('${tmp.path}/rec4.enc');
      final result = await encryptFileToFile(
        source: File('${tmp.path}/plain4.bin')
          ..writeAsBytesSync(_randomBytes(20, seed: 5)),
        destination: sourceFile,
        dek: dek,
      );

      late Dek handedOut;
      await resolvePlaybackPath(
        recordingId: 'rec4',
        sourcePath: sourceFile.path,
        wrappedFekBase64: result.wrappedFek.toBase64(),
        dekSource: () async {
          handedOut = Dek(Uint8List.fromList(dek.bytes));
          return handedOut;
        },
        scratchDirSource: () async => Directory('${tmp.path}/scratch4'),
      );

      expect(handedOut.bytes, everyElement(0));
    });
  });

  group('evictPlaybackScratch', () {
    test('deletes the one recording\'s scratch file', () async {
      final scratchDir = Directory('${tmp.path}/evict_one');
      await scratchDir.create(recursive: true);
      final target = File('${scratchDir.path}/rec_a.playback')
        ..writeAsBytesSync([1, 2, 3]);
      final other = File('${scratchDir.path}/rec_b.playback')
        ..writeAsBytesSync([4, 5, 6]);

      await evictPlaybackScratch(
        recordingId: 'rec_a',
        scratchDirSource: () async => scratchDir,
      );

      expect(await target.exists(), isFalse);
      expect(await other.exists(), isTrue,
          reason: 'eviction is scoped to ONE recordingId, not the whole dir');
    });

    test('is a no-op (does not throw) when the file was never resolved',
        () async {
      final scratchDir = Directory('${tmp.path}/evict_missing');

      await evictPlaybackScratch(
        recordingId: 'rec_never_resolved',
        scratchDirSource: () async => scratchDir,
      );
    });
  });

  group('evictAllPlaybackScratch', () {
    test(
        'deletes the ENTIRE scratch cache directory — every recording, not '
        'just one (the logout/account-switch sweep)', () async {
      final scratchDir = Directory('${tmp.path}/evict_all');
      await scratchDir.create(recursive: true);
      File('${scratchDir.path}/rec_a.playback').writeAsBytesSync([1]);
      File('${scratchDir.path}/rec_b.playback').writeAsBytesSync([2]);

      await evictAllPlaybackScratch(scratchDirSource: () async => scratchDir);

      expect(await scratchDir.exists(), isFalse);
    });

    test('is a no-op (does not throw) when the cache dir never existed',
        () async {
      final scratchDir = Directory('${tmp.path}/evict_all_missing');

      await evictAllPlaybackScratch(scratchDirSource: () async => scratchDir);
    });
  });
}
