// Whole-image codec for the web encrypted-DB-image-in-OPFS store — task
// #1860, plan #131 (web wave). Encrypts/decrypts an entire serialized sqlite3
// database (or any other opaque byte blob, e.g. a future media snapshot)
// under the DEK directly (not wrapped through a KEK — this is a bulk-data
// AEAD stream, not a key-wrap; see envelope.dart for the 64-byte key-wrap
// layout used for `wrapped_dek_*`).
//
// This is the MVP persistence primitive AC (a) in #1860 falls back to: a full
// custom page-level sqlite3 VFS (encrypt-per-page on a real OPFS VFS) needs a
// dedicated Web Worker + SharedArrayBuffer + cross-origin-isolation headers
// (see `SimpleOpfsFileSystem`'s doc comment in package:sqlite3/wasm.dart) —
// infra this pass does not add. Instead, the whole decrypted DB image is held
// in memory while the store is open (the stated MVP tradeoff) and persisted
// as ONE encrypted blob. Chunked (not single-shot AEAD) so a multi-megabyte
// DB image doesn't require one gigantic GCM call, and so the wire shape
// mirrors the already-frozen per-file media stream design (Appendix A.5 of
// .docs/internal/at-rest-key-flow.md) — same nonce-prefix + chunk-counter
// construction, same "AAD binds chunk position" guarantee against reordering
// or truncation.
//
// UPGRADE SEAM: a future page-level VFS can keep this exact chunk format for
// individual 4096-byte sqlite pages (chunk_size := page size) instead of the
// whole image — the header/chunk framing below does not need to change,
// only who calls it (per-xWrite/xRead instead of once per checkpoint).
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:cryptography/dart.dart' show DartAesGcm;

import 'key_material.dart' show secureRandomBytes;

/// 'MDBI' — Matome DB Image.
const List<int> _kMagic = [0x4D, 0x44, 0x42, 0x49];
const int kDbImageFormatVersion = 0x01;
const int kDbImagePurposeSqliteImage = 0x01;

const int _kNoncePrefixLength = 4;
const int _kChunkIndexLength = 8;
const int _kNonceLength = _kNoncePrefixLength + _kChunkIndexLength; // 12
const int _kTagLength = 16;

/// Header layout (fixed 24 bytes), all multi-byte integers big-endian:
///   0   4   magic 'MDBI'
///   4   1   format_version
///   5   1   purpose
///   6   2   reserved (0x0000)
///   8   4   nonce_prefix (CSPRNG)
///   12  4   chunk_size (plaintext bytes per chunk, except possibly the last)
///   16  8   plaintext_length (total, so the last chunk's exact length is
///           unambiguous even though ciphertext length == plaintext length
///           for AES-GCM)
const int _kHeaderLength = 24;

/// Plaintext chunk size — 64 KiB. Large enough to keep chunk-count (and thus
/// AEAD call count) reasonable for multi-MB DB images, small enough that a
/// single chunk is a trivial in-memory copy.
const int kDefaultChunkSize = 64 * 1024;

/// Base type for every explicit decrypt failure from this codec. Tampering
/// ANY byte — header, a chunk's ciphertext, or its tag — always surfaces as
/// one of this hierarchy's subtypes. Never a silent success, never partial
/// plaintext, never a fallback to "treat as empty database".
abstract class DbImageDecryptException implements Exception {
  const DbImageDecryptException();
}

/// The blob is too short to even contain a header, or its magic/format
/// version/purpose bytes don't match what this build understands.
class DbImageHeaderException extends DbImageDecryptException {
  final String reason;
  const DbImageHeaderException(this.reason);

  @override
  String toString() => 'DbImageHeaderException: $reason';
}

/// AEAD authentication failed on a chunk: wrong DEK, or the ciphertext/tag
/// for that chunk (or its position, via AAD) was tampered with/reordered/
/// truncated.
class DbImageTamperException extends DbImageDecryptException {
  final int chunkIndex;
  const DbImageTamperException(this.chunkIndex);

  @override
  String toString() =>
      'DbImageTamperException: chunk $chunkIndex failed authentication';
}

final DartAesGcm _aesGcm = DartAesGcm(
  secretKeyLength: 32,
  nonceLength: _kNonceLength,
);

Uint8List _beBytes(int value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = v & 0xff;
    v >>= 8;
  }
  return out;
}

int _beToInt(Uint8List bytes) {
  var v = 0;
  for (final b in bytes) {
    v = (v << 8) | b;
  }
  return v;
}

/// Encrypts an entire byte image (typically a serialized sqlite3 database)
/// under [dek] (32 raw bytes). Returns the framed ciphertext — this is
/// exactly the bytes that are safe to persist to OPFS (never the plaintext
/// [plaintext] itself).
///
/// A fresh CSPRNG nonce prefix is generated per call — never reuse a nonce
/// prefix with the same key across independent encrypt calls.
Future<Uint8List> encryptDbImage({
  required Uint8List plaintext,
  required Uint8List dek,
  int chunkSize = kDefaultChunkSize,
}) async {
  if (dek.length != 32) {
    throw ArgumentError.value(dek.length, 'dek.length', 'expected 32 bytes');
  }
  if (chunkSize <= 0) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
  }

  final noncePrefix = secureRandomBytes(_kNoncePrefixLength);
  final secretKey = SecretKey(dek);

  final chunkCount = plaintext.isEmpty ? 0 : (plaintext.length / chunkSize).ceil();
  final encryptedChunks = <Uint8List>[];
  var totalCipherLen = 0;

  for (var i = 0; i < chunkCount; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize > plaintext.length) ? plaintext.length : start + chunkSize;
    final chunkPlaintext = plaintext.sublist(start, end);

    final chunkIndexBytes = _beBytes(i, _kChunkIndexLength);
    final nonce = Uint8List(_kNonceLength)
      ..setRange(0, _kNoncePrefixLength, noncePrefix)
      ..setRange(_kNoncePrefixLength, _kNonceLength, chunkIndexBytes);

    final box = await _aesGcm.encrypt(
      chunkPlaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: chunkIndexBytes,
    );

    final framed = Uint8List(box.cipherText.length + _kTagLength)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + _kTagLength, box.mac.bytes);
    encryptedChunks.add(framed);
    totalCipherLen += framed.length;
  }

  final out = Uint8List(_kHeaderLength + totalCipherLen);
  out.setRange(0, 4, _kMagic);
  out[4] = kDbImageFormatVersion;
  out[5] = kDbImagePurposeSqliteImage;
  out[6] = 0;
  out[7] = 0;
  out.setRange(8, 12, noncePrefix);
  out.setRange(12, 16, _beBytes(chunkSize, 4));
  out.setRange(16, 24, _beBytes(plaintext.length, 8));

  var offset = _kHeaderLength;
  for (final chunk in encryptedChunks) {
    out.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }

  return out;
}

/// Decrypts a blob produced by [encryptDbImage] under [dek], returning the
/// original plaintext image bytes.
///
/// Fails EXPLICITLY (throws a [DbImageDecryptException] subtype) on a
/// malformed header, a wrong [dek], or ANY tampered/reordered/truncated
/// chunk. Never returns partial or garbage plaintext, and never silently
/// treats a decrypt failure as "no existing database" — callers must
/// propagate this as a hard failure (wrong password / corrupted store), not
/// fall back to opening a fresh empty database.
Future<Uint8List> decryptDbImage({
  required Uint8List ciphertext,
  required Uint8List dek,
}) async {
  if (dek.length != 32) {
    throw ArgumentError.value(dek.length, 'dek.length', 'expected 32 bytes');
  }
  if (ciphertext.length < _kHeaderLength) {
    throw const DbImageHeaderException('blob shorter than the fixed header');
  }
  for (var i = 0; i < 4; i++) {
    if (ciphertext[i] != _kMagic[i]) {
      throw const DbImageHeaderException('bad magic — not a matome db image');
    }
  }
  final formatVersion = ciphertext[4];
  if (formatVersion != kDbImageFormatVersion) {
    throw DbImageHeaderException('unsupported format_version $formatVersion');
  }
  final purpose = ciphertext[5];
  if (purpose != kDbImagePurposeSqliteImage) {
    throw DbImageHeaderException('unsupported purpose byte $purpose');
  }

  final noncePrefix = ciphertext.sublist(8, 12);
  final chunkSize = _beToInt(ciphertext.sublist(12, 16));
  final plaintextLength = _beToInt(ciphertext.sublist(16, 24));

  final secretKey = SecretKey(dek);
  final out = Uint8List(plaintextLength);

  var readOffset = _kHeaderLength;
  var writeOffset = 0;
  var chunkIndex = 0;
  while (writeOffset < plaintextLength) {
    final remainingPlaintext = plaintextLength - writeOffset;
    final thisChunkPlaintextLen =
        remainingPlaintext < chunkSize ? remainingPlaintext : chunkSize;
    final framedLen = thisChunkPlaintextLen + _kTagLength;

    if (readOffset + framedLen > ciphertext.length) {
      throw DbImageTamperException(chunkIndex);
    }

    final chunkCiphertext =
        ciphertext.sublist(readOffset, readOffset + thisChunkPlaintextLen);
    final tag = ciphertext.sublist(
      readOffset + thisChunkPlaintextLen,
      readOffset + framedLen,
    );

    final chunkIndexBytes = _beBytes(chunkIndex, _kChunkIndexLength);
    final nonce = Uint8List(_kNonceLength)
      ..setRange(0, _kNoncePrefixLength, noncePrefix)
      ..setRange(_kNoncePrefixLength, _kNonceLength, chunkIndexBytes);

    final box = SecretBox(chunkCiphertext, nonce: nonce, mac: Mac(tag));

    final List<int> chunkPlaintext;
    try {
      chunkPlaintext = await _aesGcm.decrypt(
        box,
        secretKey: secretKey,
        aad: chunkIndexBytes,
      );
    } on SecretBoxAuthenticationError {
      throw DbImageTamperException(chunkIndex);
    }

    out.setRange(writeOffset, writeOffset + chunkPlaintext.length, chunkPlaintext);

    readOffset += framedLen;
    writeOffset += thisChunkPlaintextLen;
    chunkIndex++;
  }

  // Trailing garbage after the last expected chunk is itself a form of
  // tampering (an attacker appending extra bytes) — reject rather than
  // silently ignore.
  if (readOffset != ciphertext.length) {
    throw DbImageTamperException(chunkIndex);
  }

  return out;
}
