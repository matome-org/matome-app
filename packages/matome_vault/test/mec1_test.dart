import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:matome_vault/matome_vault.dart';
import 'package:test/test.dart';

final class _MemoryCiphertext
    implements Mec1CiphertextSource, Mec1CiphertextSink {
  _MemoryCiphertext([List<int>? value, this.readEventSize])
    : bytes = [...?value];

  final List<int> bytes;
  final int? readEventSize;
  final writes = <int>[];
  final reads = <({int start, int end})>[];

  @override
  Future<void> write(List<int> value) async {
    writes.add(value.length);
    bytes.addAll(value);
  }

  @override
  Future<int> length() async => bytes.length;

  @override
  Stream<List<int>> openRead({int start = 0, int? endExclusive}) {
    final end = endExclusive ?? bytes.length;
    reads.add((start: start, end: end));
    final eventSize = readEventSize;
    if (eventSize == null) return Stream.value(bytes.sublist(start, end));
    return Stream.fromIterable([
      for (var offset = start; offset < end; offset += eventSize)
        bytes.sublist(offset, min(offset + eventSize, end)),
    ]);
  }
}

Uint8List _bytes(int length, [int seed = 1]) {
  final random = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final result = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    result.add(chunk);
  }
  return result.takeBytes();
}

Future<({Mec1EncryptionResult result, _MemoryCiphertext store})> _encrypt(
  Uint8List plain, {
  Stream<List<int>>? stream,
  Mec1RandomBytes? randomBytes,
}) async {
  final store = _MemoryCiphertext();
  final result = await encryptMec1(
    plaintext: stream ?? Stream.value(plain),
    ciphertext: store,
    accountDek: Uint8List.fromList(List.generate(32, (i) => i)),
    randomBytes: randomBytes ?? ((length) => _bytes(length, length)),
  );
  return (result: result, store: store);
}

Stream<List<int>> _decrypt(
  _MemoryCiphertext store,
  Mec1EncryptionResult result, {
  PlaintextRange? range,
  Uint8List? dek,
}) => decryptMec1(
  source: store,
  wrappedFek: result.wrappedFek,
  noncePrefix: result.noncePrefix,
  accountDek: dek ?? Uint8List.fromList(List.generate(32, (i) => i)),
  range: range,
);

void main() {
  group('MEC1 streaming', () {
    for (final size in [0, 17, mec1ChunkPlaintextSize * 3 + 91]) {
      test('round-trips $size bytes', () async {
        final plain = _bytes(size, size + 1);
        final encrypted = await _encrypt(plain);
        expect(
          await _collect(_decrypt(encrypted.store, encrypted.result)),
          plain,
        );
        expect(encrypted.result.plaintextLength, size);
        expect(encrypted.result.ciphertextLength, encrypted.store.bytes.length);
      });
    }

    test('bounds output while consuming one oversized input event', () async {
      final plain = _bytes(mec1ChunkPlaintextSize * 5 + 7);
      final encrypted = await _encrypt(plain, stream: Stream.value(plain));
      expect(
        encrypted.store.writes,
        everyElement(lessThanOrEqualTo(mec1ChunkPlaintextSize)),
      );
      final emitted = <int>[];
      await for (final chunk in _decrypt(encrypted.store, encrypted.result)) {
        emitted.add(chunk.length);
      }
      expect(emitted, everyElement(lessThanOrEqualTo(mec1ChunkPlaintextSize)));
    });

    test('reopens deterministically for retry', () async {
      final encrypted = await _encrypt(_bytes(mec1ChunkPlaintextSize + 1));
      final first = await _collect(_decrypt(encrypted.store, encrypted.result));
      final second = await _collect(
        _decrypt(encrypted.store, encrypted.result),
      );
      expect(second, first);
      expect(encrypted.store.reads.length, 4);
    });

    test('accepts arbitrarily fragmented ciphertext events', () async {
      final plain = _bytes(mec1ChunkPlaintextSize + 31);
      final encrypted = await _encrypt(plain);
      final fragmented = _MemoryCiphertext(encrypted.store.bytes, 7);
      expect(await _collect(_decrypt(fragmented, encrypted.result)), plain);
    });
  });

  group('authenticated ranges', () {
    final cases = <({int start, int end})>[
      (start: 0, end: 1),
      (start: 0, end: mec1ChunkPlaintextSize),
      (start: mec1ChunkPlaintextSize, end: mec1ChunkPlaintextSize * 2),
      (start: 13, end: 997),
      (start: mec1ChunkPlaintextSize - 3, end: mec1ChunkPlaintextSize + 5),
      (start: mec1ChunkPlaintextSize * 2, end: mec1ChunkPlaintextSize * 2 + 19),
    ];
    for (final value in cases) {
      test('[${value.start}, ${value.end})', () async {
        final plain = _bytes(mec1ChunkPlaintextSize * 2 + 19, 22);
        final encrypted = await _encrypt(plain);
        final actual = await _collect(
          _decrypt(
            encrypted.store,
            encrypted.result,
            range: PlaintextRange(start: value.start, endExclusive: value.end),
          ),
        );
        expect(actual, plain.sublist(value.start, value.end));
      });
    }

    test('rejects bounds outside plaintext', () async {
      final encrypted = await _encrypt(_bytes(10));
      expect(
        () => _collect(
          _decrypt(
            encrypted.store,
            encrypted.result,
            range: PlaintextRange(start: 9, endExclusive: 11),
          ),
        ),
        throwsA(isA<Mec1RangeException>()),
      );
    });
  });

  group('strict validation', () {
    test('wrong DEK emits no plaintext', () async {
      final encrypted = await _encrypt(_bytes(100));
      final emitted = <int>[];
      await expectLater(
        _decrypt(
          encrypted.store,
          encrypted.result,
          dek: Uint8List(32),
        ).forEach(emitted.addAll),
        throwsA(isA<Mec1AuthenticationException>()),
      );
      expect(emitted, isEmpty);
    });

    test('rejects bad magic, version and nonce metadata', () async {
      final encrypted = await _encrypt(_bytes(100));
      for (final index in [0, 4, 5]) {
        final altered = _MemoryCiphertext(encrypted.store.bytes)
          ..bytes[index] ^= 0xff;
        expect(
          () => _collect(_decrypt(altered, encrypted.result)),
          throwsA(
            index == 4
                ? isA<Mec1UnsupportedVersionException>()
                : isA<Mec1FormatException>(),
          ),
        );
      }
    });

    test('tag tamper emits no bytes from failing chunk', () async {
      final plain = _bytes(mec1ChunkPlaintextSize * 2);
      final encrypted = await _encrypt(plain);
      encrypted.store.bytes.last ^= 1;
      final emitted = <int>[];
      await expectLater(
        _decrypt(encrypted.store, encrypted.result).forEach(emitted.addAll),
        throwsA(isA<Mec1AuthenticationException>()),
      );
      expect(emitted.length, mec1ChunkPlaintextSize);
    });

    test(
      'ciphertext tamper emits no plaintext from the failing chunk',
      () async {
        final encrypted = await _encrypt(_bytes(100));
        encrypted.store.bytes[mec1HeaderLength + mec1FrameLengthPrefix] ^= 1;
        final emitted = <int>[];
        await expectLater(
          _decrypt(encrypted.store, encrypted.result).forEach(emitted.addAll),
          throwsA(isA<Mec1AuthenticationException>()),
        );
        expect(emitted, isEmpty);
      },
    );

    test('chunk reorder fails AAD authentication', () async {
      final encrypted = await _encrypt(_bytes(mec1ChunkPlaintextSize * 2));
      const frame = 4 + mec1ChunkPlaintextSize + 16;
      final first = encrypted.store.bytes.sublist(9, 9 + frame);
      final second = encrypted.store.bytes.sublist(9 + frame);
      encrypted.store.bytes.replaceRange(9, 9 + frame, second);
      encrypted.store.bytes.replaceRange(9 + frame, 9 + frame * 2, first);
      expect(
        () => _collect(_decrypt(encrypted.store, encrypted.result)),
        throwsA(isA<Mec1AuthenticationException>()),
      );
    });

    test('rejects truncation and oversized frame before allocation', () async {
      final encrypted = await _encrypt(_bytes(100));
      final truncatedBytes = [...encrypted.store.bytes]..removeLast();
      expect(
        () => _collect(
          _decrypt(_MemoryCiphertext(truncatedBytes), encrypted.result),
        ),
        throwsA(isA<Mec1FormatException>()),
      );
      final oversized = _MemoryCiphertext(encrypted.store.bytes);
      final length = ByteData(4)
        ..setUint32(0, mec1ChunkPlaintextSize + 1, Endian.big);
      oversized.bytes.replaceRange(9, 13, length.buffer.asUint8List());
      expect(
        () => _collect(_decrypt(oversized, encrypted.result)),
        throwsA(isA<Mec1FormatException>()),
      );
    });
  });

  test('deterministic vector freezes app-compatible MEC1 structure', () async {
    var next = 0;
    Uint8List deterministic(int length) =>
        Uint8List.fromList(List.generate(length, (_) => next++ & 0xff));
    final encrypted = await _encrypt(
      Uint8List.fromList(utf8.encode('Matome MEC1 vector')),
      randomBytes: deterministic,
    );
    expect(
      base64.encode(encrypted.store.bytes),
      'TUVDMQEgISIjAAAAEtV/WSDTQ7xsr0MhU60umHU97vs4deUYxZrFo/i9j2Txuzk=',
    );
    expect(encrypted.result.wrappedFek.length, 64);
    expect(encrypted.result.wrappedFek.sublist(0, 4), [1, 2, 0, 1]);
  });

  test('nonce is prefix plus big-endian counter', () {
    expect(mec1NonceFor(Uint8List.fromList([1, 2, 3, 4]), 5), [
      1,
      2,
      3,
      4,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      5,
    ]);
  });
}
