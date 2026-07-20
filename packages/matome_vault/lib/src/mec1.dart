import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:cryptography/dart.dart' show DartAesGcm;

import 'contracts.dart' show PlaintextRange;

const List<int> mec1Magic = [0x4d, 0x45, 0x43, 0x31];
const int mec1FormatVersion = 1;
const int mec1HeaderLength = 9;
const int mec1NoncePrefixLength = 4;
const int mec1NonceLength = 12;
const int mec1FrameLengthPrefix = 4;
const int mec1TagLength = 16;
const int mec1ChunkPlaintextSize = 64 * 1024;
const int mec1MaxChunks = 0xffffffff;

const int _envelopeLength = 64;
const int _envelopeNonceLength = 12;
const int _keyLength = 32;
const List<int> _fekEnvelopeHeader = [1, 2, 0, 1];

typedef Mec1RandomBytes = Uint8List Function(int length);

/// Reopenable random-access ciphertext with half-open read bounds.
abstract interface class Mec1CiphertextSource {
  Future<int> length();

  /// Returns immutable bytes for `[start, endExclusive)` on every reopen.
  Stream<List<int>> openRead({int start = 0, int? endExclusive});
}

/// Async ciphertext destination. Awaiting [write] provides backpressure.
abstract interface class Mec1CiphertextSink {
  Future<void> write(List<int> bytes);
}

sealed class Mec1Exception implements Exception {
  const Mec1Exception(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class Mec1FormatException extends Mec1Exception {
  const Mec1FormatException(super.message);
}

final class Mec1UnsupportedVersionException extends Mec1Exception {
  const Mec1UnsupportedVersionException(this.foundVersion)
    : super('unsupported MEC1 version $foundVersion');

  final int foundVersion;
}

/// Authentication failed while unwrapping the FEK or decrypting [chunkIndex].
final class Mec1AuthenticationException extends Mec1Exception {
  const Mec1AuthenticationException({this.chunkIndex})
    : super(
        chunkIndex == null
            ? 'FEK envelope authentication failed'
            : 'chunk $chunkIndex authentication failed',
      );

  final int? chunkIndex;
}

final class Mec1RangeException extends Mec1Exception {
  const Mec1RangeException(super.message);
}

final class Mec1FileTooLargeException extends Mec1Exception {
  const Mec1FileTooLargeException(int chunks)
    : super('chunk count $chunks exceeds $mec1MaxChunks');
}

final class Mec1EncryptionResult {
  Mec1EncryptionResult({
    required Uint8List wrappedFek,
    required Uint8List noncePrefix,
    required this.plaintextLength,
    required this.ciphertextLength,
  }) : wrappedFek = Uint8List.fromList(wrappedFek),
       noncePrefix = Uint8List.fromList(noncePrefix);

  final Uint8List wrappedFek;
  final Uint8List noncePrefix;
  final int plaintextLength;
  final int ciphertextLength;
}

final DartAesGcm _aes = DartAesGcm(
  secretKeyLength: _keyLength,
  nonceLength: mec1NonceLength,
);

Uint8List _secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

void _validateKey(Uint8List key, String name) {
  if (key.length != _keyLength) {
    throw ArgumentError.value(key.length, '$name.length', 'expected 32 bytes');
  }
}

Uint8List mec1NonceFor(Uint8List prefix, int chunkIndex) {
  if (prefix.length != mec1NoncePrefixLength) {
    throw ArgumentError.value(
      prefix.length,
      'prefix.length',
      'expected 4 bytes',
    );
  }
  if (chunkIndex < 0 || chunkIndex > mec1MaxChunks) {
    throw Mec1FileTooLargeException(chunkIndex);
  }
  final nonce = Uint8List(mec1NonceLength)..setRange(0, 4, prefix);
  _writeUint64(nonce, 4, chunkIndex);
  return nonce;
}

Uint8List _aadFor(int chunkIndex) {
  final aad = Uint8List(8);
  _writeUint64(aad, 0, chunkIndex);
  return aad;
}

// dart2js cannot represent JS DataView's BigInt setUint64 argument. MEC1 chunk
// indexes fit in uint32, so writing the high and low words is byte-identical.
void _writeUint64(Uint8List target, int offset, int value) {
  final data = ByteData.sublistView(target);
  data.setUint32(offset, value ~/ 0x100000000, Endian.big);
  data.setUint32(offset + 4, value & 0xffffffff, Endian.big);
}

Uint8List _uint32(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.big);
  return bytes;
}

Future<Uint8List> _wrapFek(
  Uint8List fek,
  Uint8List dek,
  Mec1RandomBytes randomBytes,
) async {
  final nonce = randomBytes(_envelopeNonceLength);
  if (nonce.length != _envelopeNonceLength) {
    throw StateError('randomBytes returned ${nonce.length}, expected 12');
  }
  final box = await _aes.encrypt(
    fek,
    secretKey: SecretKey(dek),
    nonce: nonce,
    aad: _fekEnvelopeHeader,
  );
  return Uint8List(_envelopeLength)
    ..setRange(0, 4, _fekEnvelopeHeader)
    ..setRange(4, 16, nonce)
    ..setRange(16, 48, box.cipherText)
    ..setRange(48, 64, box.mac.bytes);
}

Future<Uint8List> _unwrapFek(Uint8List wrapped, Uint8List dek) async {
  if (wrapped.length != _envelopeLength) {
    throw const Mec1FormatException('wrapped FEK must be exactly 64 bytes');
  }
  for (var i = 0; i < _fekEnvelopeHeader.length; i++) {
    if (wrapped[i] != _fekEnvelopeHeader[i]) {
      throw const Mec1FormatException('invalid wrapped FEK metadata');
    }
  }
  final box = SecretBox(
    Uint8List.sublistView(wrapped, 16, 48),
    nonce: Uint8List.sublistView(wrapped, 4, 16),
    mac: Mac(Uint8List.sublistView(wrapped, 48)),
  );
  try {
    return Uint8List.fromList(
      await _aes.decrypt(
        box,
        secretKey: SecretKey(dek),
        aad: Uint8List.sublistView(wrapped, 0, 4),
      ),
    );
  } on SecretBoxAuthenticationError {
    throw const Mec1AuthenticationException();
  }
}

/// Encrypts an arbitrarily chunked stream without materializing it in full.
Future<Mec1EncryptionResult> encryptMec1({
  required Stream<List<int>> plaintext,
  required Mec1CiphertextSink ciphertext,
  required Uint8List accountDek,
  Mec1RandomBytes randomBytes = _secureRandomBytes,
}) async {
  _validateKey(accountDek, 'accountDek');
  final fek = randomBytes(_keyLength);
  try {
    final prefix = randomBytes(mec1NoncePrefixLength);
    if (fek.length != _keyLength || prefix.length != mec1NoncePrefixLength) {
      throw StateError('randomBytes returned an invalid length');
    }
    final wrappedFek = await _wrapFek(fek, accountDek, randomBytes);
    final secretKey = SecretKey(fek);
    await ciphertext.write(
      Uint8List.fromList([...mec1Magic, mec1FormatVersion, ...prefix]),
    );

    var plaintextLength = 0;
    var ciphertextLength = mec1HeaderLength;
    var chunkIndex = 0;
    final pending = Uint8List(mec1ChunkPlaintextSize);
    var pendingLength = 0;

    Future<void> flush() async {
      if (pendingLength == 0) return;
      if (chunkIndex >= mec1MaxChunks) {
        throw Mec1FileTooLargeException(chunkIndex + 1);
      }
      final box = await _aes.encrypt(
        Uint8List.sublistView(pending, 0, pendingLength),
        secretKey: secretKey,
        nonce: mec1NonceFor(prefix, chunkIndex),
        aad: _aadFor(chunkIndex),
      );
      await ciphertext.write(_uint32(pendingLength));
      await ciphertext.write(box.cipherText);
      await ciphertext.write(box.mac.bytes);
      ciphertextLength += mec1FrameLengthPrefix + pendingLength + mec1TagLength;
      chunkIndex++;
      pendingLength = 0;
    }

    await for (final event in plaintext) {
      var offset = 0;
      while (offset < event.length) {
        final count = min(
          mec1ChunkPlaintextSize - pendingLength,
          event.length - offset,
        );
        for (var i = 0; i < count; i++) {
          final byte = event[offset + i];
          if (byte < 0 || byte > 255) {
            throw ArgumentError.value(byte, 'plaintext byte', 'must be 0..255');
          }
          pending[pendingLength + i] = byte;
        }
        pendingLength += count;
        plaintextLength += count;
        offset += count;
        if (pendingLength == mec1ChunkPlaintextSize) await flush();
      }
    }
    await flush();
    return Mec1EncryptionResult(
      wrappedFek: wrappedFek,
      noncePrefix: prefix,
      plaintextLength: plaintextLength,
      ciphertextLength: ciphertextLength,
    );
  } finally {
    fek.fillRange(0, fek.length, 0);
  }
}

final class _Layout {
  const _Layout(this.plaintextLength, this.chunkCount, this.finalChunkLength);

  final int plaintextLength;
  final int chunkCount;
  final int finalChunkLength;
}

_Layout _layoutFor(int physicalLength) {
  if (physicalLength < mec1HeaderLength) {
    throw const Mec1FormatException(
      'ciphertext is shorter than the MEC1 header',
    );
  }
  final payloadLength = physicalLength - mec1HeaderLength;
  if (payloadLength == 0) return const _Layout(0, 0, 0);
  const fullFrame =
      mec1FrameLengthPrefix + mec1ChunkPlaintextSize + mec1TagLength;
  final fullChunks = payloadLength ~/ fullFrame;
  final remainder = payloadLength % fullFrame;
  final chunkCount = fullChunks + (remainder == 0 ? 0 : 1);
  if (chunkCount > mec1MaxChunks) throw Mec1FileTooLargeException(chunkCount);
  if (remainder != 0 && remainder <= mec1FrameLengthPrefix + mec1TagLength) {
    throw const Mec1FormatException('final frame has no ciphertext');
  }
  final finalLength = remainder == 0
      ? mec1ChunkPlaintextSize
      : remainder - mec1FrameLengthPrefix - mec1TagLength;
  return _Layout(
    (chunkCount - 1) * mec1ChunkPlaintextSize + finalLength,
    chunkCount,
    finalLength,
  );
}

int _frameOffset(int chunkIndex) =>
    mec1HeaderLength +
    chunkIndex *
        (mec1FrameLengthPrefix + mec1ChunkPlaintextSize + mec1TagLength);

final class _ExactReader {
  _ExactReader(Stream<List<int>> stream) : _iterator = StreamIterator(stream);

  final StreamIterator<List<int>> _iterator;
  List<int>? _event;
  int _eventOffset = 0;

  Future<Uint8List> read(int count) async {
    final result = Uint8List(count);
    var written = 0;
    while (written < count) {
      if (_event == null || _eventOffset == _event!.length) {
        if (!await _iterator.moveNext()) {
          throw Mec1FormatException(
            'truncated input: expected $count bytes, got $written',
          );
        }
        _event = _iterator.current;
        _eventOffset = 0;
        if (_event!.isEmpty) continue;
      }
      final take = min(count - written, _event!.length - _eventOffset);
      for (var i = 0; i < take; i++) {
        final byte = _event![_eventOffset + i];
        if (byte < 0 || byte > 255) {
          throw const Mec1FormatException(
            'ciphertext contains a non-byte value',
          );
        }
        result[written + i] = byte;
      }
      written += take;
      _eventOffset += take;
    }
    return result;
  }

  Future<void> ensureDone() async {
    if (_event != null && _eventOffset < _event!.length) {
      throw const Mec1FormatException(
        'source emitted bytes past requested bound',
      );
    }
    while (await _iterator.moveNext()) {
      if (_iterator.current.isNotEmpty) {
        throw const Mec1FormatException(
          'source emitted bytes past requested bound',
        );
      }
    }
  }

  Future<void> cancel() => _iterator.cancel();
}

Future<Uint8List> _readHeader(
  Mec1CiphertextSource source,
  Uint8List expectedPrefix,
) async {
  if (expectedPrefix.length != mec1NoncePrefixLength) {
    throw ArgumentError.value(
      expectedPrefix.length,
      'noncePrefix.length',
      'expected 4 bytes',
    );
  }
  final reader = _ExactReader(
    source.openRead(start: 0, endExclusive: mec1HeaderLength),
  );
  try {
    final header = await reader.read(mec1HeaderLength);
    await reader.ensureDone();
    for (var i = 0; i < mec1Magic.length; i++) {
      if (header[i] != mec1Magic[i]) {
        throw const Mec1FormatException('bad MEC1 magic');
      }
    }
    if (header[4] != mec1FormatVersion) {
      throw Mec1UnsupportedVersionException(header[4]);
    }
    for (var i = 0; i < mec1NoncePrefixLength; i++) {
      if (header[5 + i] != expectedPrefix[i]) {
        throw const Mec1FormatException(
          'header nonce prefix does not match metadata',
        );
      }
    }
    return Uint8List.sublistView(header, 5);
  } finally {
    await reader.cancel();
  }
}

/// Returns authenticated plaintext for a full blob or a half-open range.
///
/// A range reopens [source] at the first touched frame's calculable offset.
/// No bytes are yielded before their complete chunk passes GCM verification.
Stream<List<int>> decryptMec1({
  required Mec1CiphertextSource source,
  required Uint8List wrappedFek,
  required Uint8List noncePrefix,
  required Uint8List accountDek,
  PlaintextRange? range,
}) async* {
  _validateKey(accountDek, 'accountDek');
  final physicalLength = await source.length();
  final layout = _layoutFor(physicalLength);
  final start = range?.start ?? 0;
  final end = range?.endExclusive ?? layout.plaintextLength;
  if (start < 0 || end <= start || end > layout.plaintextLength) {
    if (range == null && layout.plaintextLength == 0) {
      await _readHeader(source, noncePrefix);
      final fek = await _unwrapFek(wrappedFek, accountDek);
      fek.fillRange(0, fek.length, 0);
      return;
    }
    throw Mec1RangeException(
      'range [$start, $end) is outside plaintext length '
      '${layout.plaintextLength}',
    );
  }

  final prefix = await _readHeader(source, noncePrefix);
  final fek = await _unwrapFek(wrappedFek, accountDek);
  final firstChunk = start ~/ mec1ChunkPlaintextSize;
  final lastChunk = (end - 1) ~/ mec1ChunkPlaintextSize;
  final readStart = _frameOffset(firstChunk);
  final readEnd = lastChunk == layout.chunkCount - 1
      ? physicalLength
      : _frameOffset(lastChunk + 1);
  final reader = _ExactReader(
    source.openRead(start: readStart, endExclusive: readEnd),
  );
  try {
    for (var chunkIndex = firstChunk; chunkIndex <= lastChunk; chunkIndex++) {
      final expectedLength = chunkIndex == layout.chunkCount - 1
          ? layout.finalChunkLength
          : mec1ChunkPlaintextSize;
      final lengthBytes = await reader.read(mec1FrameLengthPrefix);
      final foundLength = ByteData.sublistView(
        lengthBytes,
      ).getUint32(0, Endian.big);
      if (foundLength != expectedLength ||
          foundLength > mec1ChunkPlaintextSize) {
        throw Mec1FormatException(
          'chunk $chunkIndex length $foundLength, expected $expectedLength',
        );
      }
      final cipherText = await reader.read(foundLength);
      final tag = await reader.read(mec1TagLength);
      final box = SecretBox(
        cipherText,
        nonce: mec1NonceFor(prefix, chunkIndex),
        mac: Mac(tag),
      );
      final List<int> plain;
      try {
        plain = await _aes.decrypt(
          box,
          secretKey: SecretKey(fek),
          aad: _aadFor(chunkIndex),
        );
      } on SecretBoxAuthenticationError {
        throw Mec1AuthenticationException(chunkIndex: chunkIndex);
      }
      final chunkStart = chunkIndex * mec1ChunkPlaintextSize;
      final emitStart = max(start - chunkStart, 0);
      final emitEnd = min(end - chunkStart, plain.length);
      if (emitStart < emitEnd) {
        yield Uint8List.fromList(plain.sublist(emitStart, emitEnd));
      }
    }
    await reader.ensureDone();
  } finally {
    await reader.cancel();
    fek.fillRange(0, fek.length, 0);
  }
}
