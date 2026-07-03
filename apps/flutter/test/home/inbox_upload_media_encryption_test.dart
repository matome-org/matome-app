// Task #1855 (plan #131 W4) — wiring test for the real "write NEW media as
// ciphertext" path: `encryptedDurableImportCopy` is the function
// `durableImportCopy` calls once `kMediaEncryptionEnabled` flips on. Tested
// directly (independent of that compile-time flag) so the wiring is verified
// without a `--dart-define` build.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/crypto/envelope.dart' show WrappedEnvelope;
import 'package:matome_flutter/core/crypto/key_material.dart' show Dek;
import 'package:matome_flutter/core/crypto/media_cipher.dart'
    show decodeNoncePrefix, decryptFileStream;
import 'package:matome_flutter/features/home/inbox_upload.dart';

/// [Dek.wipe] zeroes the instance it's called on — production's
/// `NativeDekProvisioner.obtainDek()` mints a FRESH `Dek` per call, so
/// `encryptedDurableImportCopy` wiping the one it receives is safe. A test
/// `dekSource` that hands out the SAME shared instance must copy it first,
/// mirroring that "fresh instance per call" contract.
Dek _freshCopy(Dek dek) => Dek(Uint8List.fromList(dek.bytes));

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('inbox_upload_media_enc_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('writes a .enc ciphertext file and returns the wrap metadata', () async {
    final dek = Dek.generate();
    const plaintext = 'MATOME_IMPORT_PLAINTEXT_MARKER_abcdef0123456789';
    final source = File('${tmp.path}/source.m4a')
      ..writeAsStringSync(plaintext * 200); // span multiple chunks' worth
    final destDir = Directory('${tmp.path}/dest')..createSync();

    final picked = PickedUpload(
      file: source,
      title: 'Voice memo',
      mediaType: 'audio',
    );

    final durable = await encryptedDurableImportCopy(
      picked,
      dir: destDir,
      dekSource: () async => _freshCopy(dek),
    );

    // 1. The durable file is a NEW `.enc` file, not the source.
    expect(durable.file.path, endsWith('.enc'));
    expect(durable.file.path, isNot(source.path));
    expect(durable.title, 'Voice memo');
    expect(durable.mediaType, 'audio');

    // 2. Wrap metadata is present and well-formed (round-trips through the
    //    same base64 transport the DB row stores).
    expect(durable.wrappedFekBase64, isNotNull);
    expect(durable.fileNoncePrefixBase64, isNotNull);
    final wrappedFek = WrappedEnvelope.fromBase64(durable.wrappedFekBase64!);
    expect(decodeNoncePrefix(durable.fileNoncePrefixBase64!).length, 4);

    // 3. PLAINTEXT-SCAN: the marker must not survive on disk in the ciphertext.
    final onDisk = await durable.file.readAsBytes();
    expect(
      utf8.decode(onDisk, allowMalformed: true).contains(plaintext),
      isFalse,
      reason: 'plaintext import bytes leaked into the durable .enc file',
    );

    // 4. Round-trip: decrypting the durable file with the SAME dek recovers
    //    the exact original bytes.
    final decrypted = <int>[];
    await for (final part in decryptFileStream(
      source: durable.file,
      wrappedFek: wrappedFek,
      dek: dek,
    )) {
      decrypted.addAll(part);
    }
    expect(utf8.decode(decrypted), plaintext * 200);
  });

  test('a wrong dek at decrypt time never recovers the plaintext', () async {
    final dek = Dek.generate();
    final wrongDek = Dek.generate();
    final source = File('${tmp.path}/source2.m4a')
      ..writeAsStringSync('hello world');
    final destDir = Directory('${tmp.path}/dest2')..createSync();

    final durable = await encryptedDurableImportCopy(
      PickedUpload(file: source, title: 't', mediaType: 'audio'),
      dir: destDir,
      dekSource: () async => _freshCopy(dek),
    );
    final wrappedFek = WrappedEnvelope.fromBase64(durable.wrappedFekBase64!);

    expect(
      () => decryptFileStream(
        source: durable.file,
        wrappedFek: wrappedFek,
        dek: wrongDek,
      ).toList(),
      throwsA(isNotNull),
    );
  });
}
