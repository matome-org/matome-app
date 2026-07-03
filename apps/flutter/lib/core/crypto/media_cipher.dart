// Per-file streaming media encryption — task #1855, plan #131 W4.
//
// Closes the real at-rest gap SQLCipher (task #1853, W3) does NOT cover:
// imported/recorded media (`import_*` / `segment_*`) lives OUTSIDE the Drift
// DB as plain files on disk. This module encrypts a media file under its own
// random FEK (File Encryption Key, wrapped by the DEK via `envelope.dart` —
// exactly `WrapperType.dekAsWrappingKey` / `PayloadType.fek`, see
// `.docs/internal/at-rest-key-flow.md` §8.2/Appendix A), streaming
// AES-256-GCM chunk by chunk so a multi-hour audio file is never fully
// buffered in RAM on either the write or the read side.
//
// ---------------------------------------------------------------------------
// ON-DISK FORMAT (frozen v1 — do NOT reorder/resize without a version bump)
// ---------------------------------------------------------------------------
//   HEADER (9 bytes):
//     offset  size  field
//     0       4     magic            ASCII 'MEC1' (Matome Encrypted Chunk v1)
//     4       1     format_version   0x01
//     5       4     file_nonce_prefix (CSPRNG, unique per file)
//
//   Then a sequence of CHUNK FRAMES, one per plaintext chunk, in order:
//     size    field
//     4       ciphertext_length (BE uint32) — always == this chunk's
//             plaintext length (AES-GCM: ciphertext_length == plaintext_length)
//     <len>   ciphertext
//     16      gcm_tag (128-bit authentication tag)
//
// The frame's length prefix lets a reader seek/skip whole chunks without
// decrypting them (every chunk but the last has a FIXED plaintext size —
// `kMediaChunkPlaintextSize` — so a random-access reader can compute a target
// chunk's byte offset directly: `kMediaHeaderLength + n * (4 + chunkSize + 16)`
// for every chunk before the last).
//
// ---------------------------------------------------------------------------
// NONCE SCHEME — why it CANNOT repeat within a file
// ---------------------------------------------------------------------------
// nonce (96-bit) = file_nonce_prefix (32-bit, CSPRNG, fixed per file)
//                  ‖ chunk_counter   (64-bit, BE, starts at 0, +1 per chunk)
//
// This is a DETERMINISTIC (not random-sampled) nonce construction, so the
// "birthday bound" that limits random-nonce AES-GCM usage (NIST SP 800-38D
// recommends capping RANDOM 96-bit nonces at ~2^32 invocations per key) does
// NOT apply here — the counter increments by exactly 1 every chunk and is
// NEVER reset within a file, so nonce(i) == nonce(j) implies i == j by
// construction, unconditionally, independent of any probability bound.
// [kMediaMaxChunks] (2^32 - 1) is a hard ASSERTION ceiling — enforced on both
// the encrypt and decrypt paths — that keeps the counter far inside its full
// 64-bit range (see [assertChunkCountWithinBound] and its dedicated unit
// test), so the counter can never wrap even in principle.
//
// Every file also gets a FRESH random FEK ([Fek.generate]), so even across
// files there is no key reuse for the nonce scheme to interact with.
//
// ---------------------------------------------------------------------------
// CHUNK SIZE + MAX FILE SIZE BOUND
// ---------------------------------------------------------------------------
// [kMediaChunkPlaintextSize] = 64 KiB. Small enough that one in-flight chunk
// (plaintext + ciphertext + a small AEAD working set) is negligible RAM even
// on a constrained mobile device; large enough to keep the per-chunk framing
// overhead (20 bytes: 4-byte length + 16-byte tag, ~0.03%) and AEAD call count
// low for multi-hour audio.
//
// [kMediaMaxChunks] (2^32 - 1) bounds a single file at
// `kMediaMaxChunks * kMediaChunkPlaintextSize` ≈ 256 TiB — many orders of
// magnitude beyond any audio/video/document this app produces, and beyond
// what most filesystems even support as a single file. [assertChunkCountWithinBound]
// throws [MediaCipherFileTooLargeException] before the counter could ever
// approach that ceiling, let alone the true 64-bit wrap point.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:cryptography/dart.dart' show DartAesGcm;

import 'envelope.dart'
    show PayloadType, WrappedEnvelope, WrapperType, unwrapKey, wrapKey;
import 'key_material.dart' show Dek, Fek, secureRandomBytes;

/// Compile-time dark-launch flag for media-at-rest encryption, mirroring the
/// exact pattern `connection_native.dart`'s `kSqlCipherEnabled` established
/// for exactly the same reason: the MECHANISM below is real and tested, but
/// flipping it on for the live write path (`inbox_upload.dart`) is NOT safe
/// yet — Core's existing `POST /api/recordings` + presigned-PUT upload and
/// server-side transcription pipeline expects real playable media bytes; it
/// has no Blobs API / wrapped_FEK storage / ciphertext-aware transcription
/// consent flow (`.docs/internal/at-rest-key-flow.md` §8.4 is the FUTURE
/// state, not built server-side today). Enabling this before that Core work
/// lands would silently break every recording upload/transcription. Stays
/// `false` until the Core Blobs API + opt-in cloud-transcription consent gate
/// ship (tracked as later-wave follow-up work, not this task).
const bool kMediaEncryptionEnabled = bool.fromEnvironment(
  'MATOME_MEDIA_ENCRYPTION',
  defaultValue: false,
);

/// 'MEC1' — Matome Encrypted Chunk, format v1.
const List<int> kMediaMagic = [0x4D, 0x45, 0x43, 0x31];

const int kMediaFormatVersion = 0x01;
const int kMediaMagicLength = 4;
const int kMediaNoncePrefixLength = 4;
const int kMediaCounterLength = 8;
const int kMediaNonceLength = kMediaNoncePrefixLength + kMediaCounterLength; // 12
const int kMediaHeaderLength =
    kMediaMagicLength + 1 /*version*/ + kMediaNoncePrefixLength; // 9

const int kMediaFrameLengthPrefix = 4;
const int kMediaTagLength = 16;

/// Plaintext bytes per chunk before encryption. See module doc "CHUNK SIZE".
const int kMediaChunkPlaintextSize = 64 * 1024;

/// Hard ceiling on chunk count per file. See module doc "NONCE SCHEME".
const int kMediaMaxChunks = 0xFFFFFFFF; // 2^32 - 1

/// Base type for every explicit media-cipher failure. Corruption, a tampered
/// chunk, or an unsupported/foreign file always surfaces as one of these
/// subtypes — never silent success, never partial/garbage plaintext.
abstract class MediaCipherException implements Exception {
  const MediaCipherException();
}

/// The on-disk blob is not a recognizable v1 media-cipher file: wrong magic,
/// wrong header length, or a chunk frame that runs out of bytes mid-frame
/// (truncated file). Distinct from [MediaChunkTamperException] — this is a
/// structural/parse failure, not an AEAD authentication failure.
class MediaCipherFormatException extends MediaCipherException {
  final String reason;
  const MediaCipherFormatException(this.reason);

  @override
  String toString() => 'MediaCipherFormatException: $reason';
}

/// The file's `format_version` byte is not one this build knows how to
/// decrypt.
class MediaCipherUnsupportedVersionException extends MediaCipherException {
  final int foundVersion;
  const MediaCipherUnsupportedVersionException(this.foundVersion);

  @override
  String toString() =>
      'MediaCipherUnsupportedVersionException: format_version=0x'
      '${foundVersion.toRadixString(16).padLeft(2, '0')} not supported';
}

/// AEAD authentication failed on chunk [chunkIndex] — the ciphertext, tag, or
/// the derived nonce (e.g. via a tampered header `file_nonce_prefix`) does not
/// check out under the unwrapped FEK. Never returns partial plaintext for the
/// tampered chunk or any chunk after it.
class MediaChunkTamperException extends MediaCipherException {
  final int chunkIndex;
  const MediaChunkTamperException(this.chunkIndex);

  @override
  String toString() =>
      'MediaChunkTamperException: chunk $chunkIndex failed AEAD authentication';
}

/// The chunk counter reached [kMediaMaxChunks] — see module doc "NONCE
/// SCHEME"/"MAX FILE SIZE BOUND". This can only happen on an astronomically
/// large file; no real media this app produces can trigger it.
class MediaCipherFileTooLargeException extends MediaCipherException {
  final int chunkCount;
  const MediaCipherFileTooLargeException(this.chunkCount);

  @override
  String toString() =>
      'MediaCipherFileTooLargeException: chunk count $chunkCount exceeds '
      'the $kMediaMaxChunks ceiling';
}

/// Throws [MediaCipherFileTooLargeException] once [chunkCounter] would exceed
/// [kMediaMaxChunks]. Split out from the encrypt/decrypt loops so the bound
/// itself is directly unit-testable without fabricating a multi-hundred-
/// terabyte file.
void assertChunkCountWithinBound(int chunkCounter) {
  if (chunkCounter > kMediaMaxChunks) {
    throw MediaCipherFileTooLargeException(chunkCounter);
  }
}

/// Builds the 96-bit per-chunk nonce: [noncePrefix] (4 bytes, fixed per file)
/// ‖ [chunkIndex] (8 bytes, big-endian). Exposed (not private) so tests can
/// verify the construction directly — see module doc "NONCE SCHEME" for why
/// this can never repeat within one file.
Uint8List mediaNonceFor(Uint8List noncePrefix, int chunkIndex) {
  if (noncePrefix.length != kMediaNoncePrefixLength) {
    throw ArgumentError.value(
      noncePrefix.length,
      'noncePrefix.length',
      'expected exactly $kMediaNoncePrefixLength bytes',
    );
  }
  final out = Uint8List(kMediaNonceLength);
  out.setRange(0, kMediaNoncePrefixLength, noncePrefix);
  final counterBytes = ByteData(kMediaCounterLength)
    ..setUint64(0, chunkIndex, Endian.big);
  out.setRange(
    kMediaNoncePrefixLength,
    kMediaNonceLength,
    counterBytes.buffer.asUint8List(),
  );
  return out;
}

/// The AAD bound to each chunk's AEAD call: the 8-byte big-endian chunk
/// index, matching `.docs/internal/at-rest-key-flow.md` §8.3's
/// `aad=chunk_index`. Cross-chunk substitution (splicing chunk 5's ciphertext
/// into chunk 3's slot) fails authentication because the AAD no longer
/// matches the position it is decrypted at.
Uint8List mediaAadFor(int chunkIndex) {
  final bd = ByteData(kMediaCounterLength)
    ..setUint64(0, chunkIndex, Endian.big);
  return bd.buffer.asUint8List();
}

final DartAesGcm _aesGcm = DartAesGcm(
  secretKeyLength: 32,
  nonceLength: kMediaNonceLength,
);

/// The wrapped FEK + the public per-file nonce prefix — everything the DB row
/// needs to persist (`wrapped_fek` + `file_nonce_prefix` columns) alongside
/// the encrypted media path. The prefix is also embedded in the file's own
/// header (self-contained ciphertext), so this is a convenience mirror of
/// that header field for the DB row per `.docs/internal/at-rest-key-flow.md`
/// Appendix A / §8.3 (`INSERT {id, path, wrapped_FEK, file_nonce_prefix, …}`).
class EncryptedMediaResult {
  const EncryptedMediaResult({
    required this.wrappedFek,
    required this.noncePrefix,
  });

  final WrappedEnvelope wrappedFek;
  final Uint8List noncePrefix;
}

Uint8List _buildHeader(Uint8List noncePrefix) {
  final out = Uint8List(kMediaHeaderLength);
  out.setRange(0, kMediaMagicLength, kMediaMagic);
  out[kMediaMagicLength] = kMediaFormatVersion;
  out.setRange(kMediaMagicLength + 1, kMediaHeaderLength, noncePrefix);
  return out;
}

/// Validates a 9-byte header and returns the embedded `file_nonce_prefix`.
Uint8List _parseHeader(Uint8List header) {
  if (header.length != kMediaHeaderLength) {
    throw MediaCipherFormatException(
      'bad header length: got ${header.length}, expected $kMediaHeaderLength',
    );
  }
  for (var i = 0; i < kMediaMagicLength; i++) {
    if (header[i] != kMediaMagic[i]) {
      throw const MediaCipherFormatException('bad magic bytes');
    }
  }
  final version = header[kMediaMagicLength];
  if (version != kMediaFormatVersion) {
    throw MediaCipherUnsupportedVersionException(version);
  }
  return header.sublist(kMediaMagicLength + 1, kMediaHeaderLength);
}

/// Encrypts [plaintext] (an arbitrarily-chunked byte stream — never buffered
/// in full) into [destination] as a v1 framed ciphertext file, under a FRESH
/// per-file FEK wrapped by [dek]. Returns the wrapped FEK + nonce prefix for
/// the caller to persist on the media's DB row.
///
/// Streaming: only ONE chunk's plaintext/ciphertext (≤ [kMediaChunkPlaintextSize]
/// + a small AEAD working set) is ever resident in memory — [plaintext] is
/// consumed incrementally and [destination] is written incrementally via
/// [File.openWrite], never via `writeAsBytes`/a fully-materialized buffer.
Future<EncryptedMediaResult> encryptStreamToFile({
  required Stream<List<int>> plaintext,
  required File destination,
  required Dek dek,
}) async {
  final fek = Fek.generate();
  final noncePrefix = secureRandomBytes(kMediaNoncePrefixLength);
  final secretKey = SecretKey(fek.bytes);

  final sink = destination.openWrite();
  try {
    sink.add(_buildHeader(noncePrefix));

    var counter = 0;
    // Bounded accumulator: at most one incoming stream event's worth of bytes
    // over `kMediaChunkPlaintextSize` is ever pending here, not the whole file.
    final pending = <int>[];

    Future<void> flushChunk(int end) async {
      final chunk = Uint8List.fromList(pending.sublist(0, end));
      pending.removeRange(0, end);
      final nonce = mediaNonceFor(noncePrefix, counter);
      final aad = mediaAadFor(counter);
      final box = await _aesGcm.encrypt(
        chunk,
        secretKey: secretKey,
        nonce: nonce,
        aad: aad,
      );
      final lenBytes = ByteData(kMediaFrameLengthPrefix)
        ..setUint32(0, box.cipherText.length, Endian.big);
      sink.add(lenBytes.buffer.asUint8List());
      sink.add(box.cipherText);
      sink.add(box.mac.bytes);
      counter++;
      assertChunkCountWithinBound(counter);
    }

    await for (final part in plaintext) {
      pending.addAll(part);
      while (pending.length >= kMediaChunkPlaintextSize) {
        await flushChunk(kMediaChunkPlaintextSize);
      }
    }
    if (pending.isNotEmpty) {
      await flushChunk(pending.length);
    }

    await sink.flush();
  } finally {
    await sink.close();
  }

  // Wrap BEFORE wiping — wiping first would wrap an all-zero key instead of
  // the FEK that actually encrypted the chunks above.
  final wrapped = await wrapKey(
    plaintext: fek.bytes,
    wrappingKey: dek.bytes,
    payloadType: PayloadType.fek,
    wrapperType: WrapperType.dekAsWrappingKey,
  );
  fek.wipe();
  return EncryptedMediaResult(wrappedFek: wrapped, noncePrefix: noncePrefix);
}

/// Convenience: encrypts an existing [source] file into [destination].
/// Streams via [File.openRead] — the source is never fully read into memory
/// either.
Future<EncryptedMediaResult> encryptFileToFile({
  required File source,
  required File destination,
  required Dek dek,
}) => encryptStreamToFile(
  plaintext: source.openRead(),
  destination: destination,
  dek: dek,
);

/// Buffers a byte [Stream] just enough to serve exact-length reads
/// ([readExactly]) without ever holding more than the current frame's worth
/// of bytes — the streaming counterpart of [File.openRead] for a framed
/// format that needs to consume N bytes at a time rather than
/// stream-shaped chunks.
class _ChunkedByteReader {
  _ChunkedByteReader(Stream<List<int>> stream)
    : _iterator = StreamIterator<List<int>>(stream);

  final StreamIterator<List<int>> _iterator;
  Uint8List _leftover = Uint8List(0);

  /// Reads exactly [n] bytes, or returns `null` if the stream ended with
  /// ZERO bytes available (a clean end-of-file exactly on a frame boundary).
  /// If the stream ends after SOME (but fewer than [n]) bytes were gathered,
  /// throws [MediaCipherFormatException] — a partial frame is corruption, not
  /// a valid end-of-file.
  Future<Uint8List?> readExactly(int n) async {
    final out = BytesBuilder(copy: true);
    var needed = n;

    if (_leftover.isNotEmpty) {
      if (_leftover.length >= needed) {
        out.add(_leftover.sublist(0, needed));
        _leftover = Uint8List.sublistView(_leftover, needed);
        return out.takeBytes();
      }
      out.add(_leftover);
      needed -= _leftover.length;
      _leftover = Uint8List(0);
    }

    while (needed > 0) {
      final hasNext = await _iterator.moveNext();
      if (!hasNext) {
        final gathered = out.takeBytes();
        if (gathered.isEmpty) return null;
        throw MediaCipherFormatException(
          'truncated stream: expected $n bytes, got only ${gathered.length}',
        );
      }
      final data = Uint8List.fromList(_iterator.current);
      if (data.length <= needed) {
        out.add(data);
        needed -= data.length;
      } else {
        out.add(data.sublist(0, needed));
        _leftover = Uint8List.sublistView(data, needed);
        needed = 0;
      }
    }
    return out.takeBytes();
  }

  Future<void> cancel() => _iterator.cancel();
}

/// Decrypts a v1 media-cipher [source] file into a lazily-produced plaintext
/// byte stream. Never buffers the whole file: at most one chunk frame's worth
/// of ciphertext (≤ [kMediaChunkPlaintextSize] + framing overhead) is held at
/// a time, read incrementally via [File.openRead] / [_ChunkedByteReader] and
/// decrypted+yielded chunk by chunk.
///
/// Throws (never silently truncates or returns garbage plaintext):
///  - [MediaCipherFormatException] — foreign/corrupt/truncated file.
///  - [MediaCipherUnsupportedVersionException] — unknown format version.
///  - [MediaChunkTamperException] — a chunk fails AEAD authentication (wrong
///    key, or ANY tampered byte in that chunk's length/ciphertext/tag, or a
///    tampered header `file_nonce_prefix` feeding the wrong nonce).
Stream<List<int>> decryptFileStream({
  required File source,
  required WrappedEnvelope wrappedFek,
  required Dek dek,
}) async* {
  final fekBytes = await unwrapKey(wrapped: wrappedFek, wrappingKey: dek.bytes);
  final fek = Fek(fekBytes);
  final secretKey = SecretKey(fek.bytes);
  final reader = _ChunkedByteReader(source.openRead());

  try {
    final header = await reader.readExactly(kMediaHeaderLength);
    if (header == null) {
      throw const MediaCipherFormatException('empty file: missing header');
    }
    final noncePrefix = _parseHeader(header);

    var counter = 0;
    while (true) {
      final lenBytes = await reader.readExactly(kMediaFrameLengthPrefix);
      if (lenBytes == null) break; // clean EOF exactly on a frame boundary

      final ciphertextLen = ByteData.sublistView(lenBytes).getUint32(0);
      final ciphertext = await reader.readExactly(ciphertextLen);
      final tag = await reader.readExactly(kMediaTagLength);
      if (ciphertext == null || tag == null) {
        throw const MediaCipherFormatException(
          'truncated chunk frame: missing ciphertext or tag',
        );
      }

      final nonce = mediaNonceFor(noncePrefix, counter);
      final aad = mediaAadFor(counter);
      final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));
      try {
        final plain = await _aesGcm.decrypt(
          box,
          secretKey: secretKey,
          aad: aad,
        );
        yield plain;
      } on SecretBoxAuthenticationError {
        throw MediaChunkTamperException(counter);
      }

      counter++;
      assertChunkCountWithinBound(counter);
    }
  } finally {
    await reader.cancel();
    fek.wipe();
  }
}

/// Convenience: decrypts [source] into a plaintext [destination] file,
/// streaming throughout (see [decryptFileStream]). Used by legacy playback
/// consumers that need a real plaintext file path rather than a `Stream` —
/// KNOWN TRADE-OFF: the destination is transiently plaintext-on-disk for the
/// player's use; callers are responsible for placing it under a private
/// cache dir and deleting it once playback ends. Not exercised by the
/// (currently dark, [kMediaEncryptionEnabled] = false) write path this task
/// wires up; provided so a future playback-integration task has a ready
/// building block.
Future<File> decryptToFile({
  required File source,
  required WrappedEnvelope wrappedFek,
  required Dek dek,
  required File destination,
}) async {
  final sink = destination.openWrite();
  try {
    await sink.addStream(
      decryptFileStream(source: source, wrappedFek: wrappedFek, dek: dek),
    );
    await sink.flush();
  } finally {
    await sink.close();
  }
  return destination;
}

/// Base64-encodes [bytes] — the transport form persisted in the DB row's
/// `file_nonce_prefix` column, mirroring [WrappedEnvelope.toBase64].
String encodeNoncePrefix(Uint8List bytes) => base64.encode(bytes);

/// Inverse of [encodeNoncePrefix].
Uint8List decodeNoncePrefix(String encoded) =>
    Uint8List.fromList(base64.decode(encoded));
