import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:matome_vault/matome_vault.dart';

final class _MemoryInput implements MediaInput {
  @override
  String? get contentType => 'application/octet-stream';

  @override
  String get filename => 'smoke.bin';

  @override
  int get knownLength => 3;

  @override
  Stream<List<int>> openRead() => Stream.value(Uint8List.fromList([1, 2, 3]));
}

final class _MemoryCiphertext
    implements Mec1CiphertextSource, Mec1CiphertextSink {
  final _bytes = <int>[];

  @override
  Future<void> write(List<int> bytes) async => _bytes.addAll(bytes);

  @override
  Future<int> length() async => _bytes.length;

  @override
  Stream<List<int>> openRead({int start = 0, int? endExclusive}) =>
      Stream.value(_bytes.sublist(start, endExclusive ?? _bytes.length));
}

Future<void> main() async {
  final input = _MemoryInput();
  final bytes = await input.openRead().expand((chunk) => chunk).toList();
  final range = PlaintextRange(start: 0, endExclusive: bytes.length);
  final stat = VaultBlobStat(
    id: VaultBlobId('smoke-blob'),
    state: VaultBlobState.ready,
    plaintextLength: bytes.length,
    physicalLength: bytes.length + 29,
    plaintextSha256: '0' * 64,
  );
  if (range.length != stat.plaintextLength) {
    throw StateError('public API smoke check failed');
  }
  final ciphertext = _MemoryCiphertext();
  final dek = Uint8List(32);
  var randomByte = 0;
  final encrypted = await encryptMec1(
    plaintext: input.openRead(),
    ciphertext: ciphertext,
    accountDek: dek,
    randomBytes: (length) =>
        Uint8List.fromList(List.generate(length, (_) => randomByte++ & 0xff)),
  );
  final roundTrip = await decryptMec1(
    source: ciphertext,
    wrappedFek: encrypted.wrappedFek,
    noncePrefix: encrypted.noncePrefix,
    accountDek: dek,
  ).expand((chunk) => chunk).toList();
  if (roundTrip.length != 3) throw StateError('MEC1 smoke check failed');
  final vector = base64.encode(ciphertext._bytes);
  if (vector != 'TUVDMQEgISIjAAAAA5kcLqFZKUQw6ea92qVBjIyFNaE=') {
    throw StateError('MEC1 compatibility vector changed: $vector');
  }
}
