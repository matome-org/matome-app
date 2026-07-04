// Whole-image codec for the web encrypted-DB-image-in-OPFS store — task
// #1860, plan #131 (web wave). Encrypts/decrypts an entire serialized sqlite3
// database (or any other opaque byte blob, e.g. a future media snapshot).
//
// This is the MVP persistence primitive AC (a) in #1860 falls back to: a full
// custom page-level sqlite3 VFS (encrypt-per-page on a real OPFS VFS) needs a
// dedicated Web Worker + SharedArrayBuffer + cross-origin-isolation headers
// (see `SimpleOpfsFileSystem`'s doc comment in package:sqlite3/wasm.dart) —
// infra this pass does not add. Instead, the whole decrypted DB image is held
// in memory while the store is open (the stated MVP tradeoff) and persisted
// as ONE encrypted blob. Chunked (not single-shot AEAD) so a multi-megabyte
// DB image doesn't require one gigantic GCM call, and so the wire shape
// mirrors the per-file media stream design (`media_cipher.dart`) — same
// nonce-prefix + chunk-counter construction, same "AAD binds chunk position"
// guarantee against reordering or truncation.
//
// ---------------------------------------------------------------------------
// FORMAT v2 — okt-audit SHIP-BLOCKER B1 fix (task #1862, verdict pinned on
// #1857)
// ---------------------------------------------------------------------------
// v1 (format_version 0x01, now UNSUPPORTED — decrypt rejects it outright)
// encrypted every image directly under the caller-supplied DEK, with only a
// 32-bit CSPRNG nonce_prefix distinguishing one encrypt call from the next.
// `connection_web.dart`'s ~4s auto-persist Timer re-encrypts the WHOLE image
// under that SAME stable DEK for the life of the account on that browser —
// unboundedly many calls under one unchanging key. A 32-bit random prefix
// collides at the birthday bound (~2^16 calls for 50%, non-negligible far
// earlier), and a (key, nonce) collision under AES-GCM is catastrophic: a
// keystream-XOR plaintext leak (sqlite header/schema pages are near-static
// across checkpoints, making the leak practically exploitable) PLUS GHASH
// authentication-key recovery (the AES-GCM "forbidden attack"), which lets an
// attacker forge future ciphertexts — tamper detection collapses entirely.
//
// v2 (format_version 0x02, current) fixes this the same way `media_cipher
// .dart` was already safe: mint a FRESH random FEK (File/Frame Encryption
// Key) on EVERY `encryptDbImage` call, encrypt the image under that FEK (not
// the DEK), and wrap the FEK under the caller's DEK using the same 64-byte
// authenticated envelope layout (`envelope.dart`) `media_cipher.dart` uses
// for its per-file FEK. Because the AEAD key is fresh every call, a
// nonce-prefix collision across independent calls can NEVER reuse a (key,
// nonce) pair — the birthday bound on the nonce space is irrelevant once the
// key itself is never repeated. This also happens to close the GHASH
// auth-key-recovery angle: recovering chunk 0's auth subkey for one image's
// FEK is useless against any other image, which has its own FEK.
//
// Header layout (fixed 88 bytes), all multi-byte integers big-endian:
//   0   4   magic 'MDBI'
//   4   1   format_version (0x02)
//   5   1   purpose
//   6   2   reserved (0x0000)
//   8   64  wrapped_fek — a `WrappedEnvelope` (envelope.dart) wrapping the
//           fresh per-image FEK under the caller's DEK (PayloadType.fek /
//           WrapperType.dekAsWrappingKey). Self-authenticating: an unwrap
//           failure (wrong DEK, or ANY tampered wrap byte) throws before a
//           single image chunk is even attempted.
//   72  4   nonce_prefix (CSPRNG, unique per encrypt call; scoped to the
//           fresh FEK above, so it is never reused across the KEY it pairs
//           with even though the field itself is only 32 bits)
//   76  4   chunk_size (plaintext bytes per chunk, except possibly the last)
//   80  8   plaintext_length (total plaintext bytes)
//
// nonce_prefix / chunk_size / plaintext_length are bound as AEAD
// ADDITIONAL AUTHENTICATED DATA (AAD) on chunk 0 (see `_aadFor`) — tampering
// ANY of those three header fields, even while keeping the blob structurally
// well-formed, fails chunk 0's authentication tag and surfaces as
// `DbImageTamperException(0)`. `plaintext_length` is ALSO validated
// structurally (`validateDbImagePlaintextLengthBound`) BEFORE the
// `Uint8List(plaintextLength)` output buffer is ever allocated — a forged,
// arbitrarily large `plaintext_length` can drive an out-of-memory
// allocation-only denial of service if that check is skipped (an attacker
// with write access to the persisted blob, pre-AEAD), so the bound is
// checked with pure O(1) integer arithmetic ahead of any allocation.
//
// UPGRADE SEAM: a future page-level VFS can keep this exact chunk format for
// individual 4096-byte sqlite pages (chunk_size := page size) instead of the
// whole image — the header/chunk framing above does not need to change,
// only who calls it (per-xWrite/xRead instead of once per checkpoint).
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:cryptography/dart.dart' show DartAesGcm;

import 'envelope.dart'
    show
        EnvelopeUnwrapException,
        PayloadType,
        WrappedEnvelope,
        WrapperType,
        kWrappedEnvelopeLength,
        unwrapKey,
        wrapKey;
import 'key_material.dart' show Fek, secureRandomBytes;

/// 'MDBI' — Matome DB Image.
const List<int> _kMagic = [0x4D, 0x44, 0x42, 0x49];

/// v1 is the pre-fix format (whole image encrypted directly under the stable
/// DEK) — okt-audit SHIP-BLOCKER B1. No longer accepted by [decryptDbImage];
/// kept named here only so the version history/reason is discoverable.
const int kDbImageFormatVersionV1Superseded = 0x01;

/// Current format: fresh per-image FEK wrapped under the DEK. See the module
/// doc "FORMAT v2" section above.
const int kDbImageFormatVersion = 0x02;
const int kDbImagePurposeSqliteImage = 0x01;

const int _kNoncePrefixLength = 4;
const int _kChunkIndexLength = 8;
const int _kNonceLength = _kNoncePrefixLength + _kChunkIndexLength; // 12
const int _kTagLength = 16;

const int _kWrappedFekOffset = 8;
const int _kNoncePrefixOffset = _kWrappedFekOffset + kWrappedEnvelopeLength; // 72
const int _kChunkSizeOffset = _kNoncePrefixOffset + _kNoncePrefixLength; // 76
const int _kPlaintextLengthOffset = _kChunkSizeOffset + 4; // 80

/// Fixed header length — see the module doc's "Header layout" section.
/// Exposed (not private) so tests can address header-field byte offsets
/// without hardcoding a number that could silently drift from the real
/// implementation.
const int kDbImageHeaderLength = _kPlaintextLengthOffset + 8; // 88

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
/// version/purpose bytes don't match what this build understands, or a
/// header field (`plaintext_length`) is structurally impossible given the
/// actual ciphertext length (see [validateDbImagePlaintextLengthBound]).
class DbImageHeaderException extends DbImageDecryptException {
  final String reason;
  const DbImageHeaderException(this.reason);

  @override
  String toString() => 'DbImageHeaderException: $reason';
}

/// AEAD authentication failed: wrong DEK / tampered `wrapped_fek`
/// ([chunkIndex] `-1`, a header/key-level failure before any image chunk is
/// reached), or a specific chunk's ciphertext/tag/position (via AAD) was
/// tampered with/reordered/truncated ([chunkIndex] `>= 0`). Chunk 0's AAD
/// additionally binds `nonce_prefix`/`chunk_size`/`plaintext_length`, so
/// tampering any of those three header fields also surfaces here as
/// `chunkIndex == 0`.
class DbImageTamperException extends DbImageDecryptException {
  final int chunkIndex;
  const DbImageTamperException(this.chunkIndex);

  @override
  String toString() => chunkIndex < 0
      ? 'DbImageTamperException: header/wrapped-FEK failed authentication '
          '(wrong DEK, or a tampered wrapped_fek)'
      : 'DbImageTamperException: chunk $chunkIndex failed authentication';
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

/// The AAD bound to each chunk's AEAD call. Chunk 0 additionally binds
/// [noncePrefix]/[chunkSize]/[plaintextLength] (the header fields that are
/// otherwise only structurally parsed, never cryptographically checked) —
/// this is what turns "tamper the header" into an AEAD authentication
/// failure instead of a silent misparse. Every other chunk's AAD is just its
/// own big-endian chunk index, exactly as before (still enough to defeat
/// cross-chunk reordering/substitution).
Uint8List _aadFor(
  int chunkIndex, {
  required Uint8List noncePrefix,
  required int chunkSize,
  required int plaintextLength,
}) {
  final chunkIndexBytes = _beBytes(chunkIndex, _kChunkIndexLength);
  if (chunkIndex != 0) {
    return chunkIndexBytes;
  }
  final out = Uint8List(_kChunkIndexLength + _kNoncePrefixLength + 4 + 8);
  var offset = 0;
  out.setRange(offset, offset + _kChunkIndexLength, chunkIndexBytes);
  offset += _kChunkIndexLength;
  out.setRange(offset, offset + _kNoncePrefixLength, noncePrefix);
  offset += _kNoncePrefixLength;
  out.setRange(offset, offset + 4, _beBytes(chunkSize, 4));
  offset += 4;
  out.setRange(offset, offset + 8, _beBytes(plaintextLength, 8));
  return out;
}

/// Validates that a header-declared [plaintextLength] (combined with
/// [chunkSize]) is even POSSIBLE given [availableCipherBytes] (the ciphertext
/// bytes actually present after the fixed header) — BEFORE
/// [decryptDbImage] allocates its `Uint8List(plaintextLength)` output buffer.
///
/// Every plaintext chunk of [chunkSize] bytes costs at least
/// `chunkSize + tagLength` ciphertext bytes (AES-GCM: ciphertext length ==
/// plaintext length, plus a fixed 16-byte tag per chunk), so a declared
/// [plaintextLength] that would require MORE ciphertext than actually exists
/// is unconditionally a forgery — never the legitimate output of
/// [encryptDbImage] — and is rejected here using only O(1) integer
/// arithmetic, with NO allocation proportional to the attacker-controlled
/// [plaintextLength]. Exposed (not private) so this guard is directly
/// unit-testable without needing to actually attempt a multi-gigabyte
/// allocation in a test.
void validateDbImagePlaintextLengthBound({
  required int plaintextLength,
  required int chunkSize,
  required int availableCipherBytes,
}) {
  if (chunkSize <= 0) {
    throw const DbImageHeaderException('chunk_size must be positive');
  }
  if (plaintextLength < 0) {
    throw const DbImageHeaderException(
      'plaintext_length must be non-negative',
    );
  }
  final chunkCount = plaintextLength == 0
      ? 0
      : (plaintextLength + chunkSize - 1) ~/ chunkSize;
  final requiredCipherBytes = plaintextLength + chunkCount * _kTagLength;
  if (requiredCipherBytes > availableCipherBytes) {
    throw DbImageHeaderException(
      'forged plaintext_length ($plaintextLength bytes, implying '
      '$chunkCount chunk(s)) would require $requiredCipherBytes ciphertext '
      'bytes but only $availableCipherBytes are present -- rejected before '
      'any Uint8List(plaintextLength) allocation',
    );
  }
}

/// Encrypts an entire byte image (typically a serialized sqlite3 database)
/// so it is safe to persist to OPFS. Returns the framed v2 ciphertext — this
/// is exactly the bytes that are safe to write (never the plaintext
/// [plaintext] itself).
///
/// A FRESH random FEK is minted on every call and used as the actual AEAD
/// key for the image; [dek] only wraps that FEK in the header (see the
/// module doc "FORMAT v2" section — this is the okt-audit SHIP-BLOCKER B1
/// fix: it is what makes repeated calls under the same stable [dek] safe,
/// since the AEAD key itself is never repeated).
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

  final fek = Fek.generate();
  final noncePrefix = secureRandomBytes(_kNoncePrefixLength);
  final secretKey = SecretKey(fek.bytes);

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

    final aad = _aadFor(
      i,
      noncePrefix: noncePrefix,
      chunkSize: chunkSize,
      plaintextLength: plaintext.length,
    );

    final box = await _aesGcm.encrypt(
      chunkPlaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    final framed = Uint8List(box.cipherText.length + _kTagLength)
      ..setRange(0, box.cipherText.length, box.cipherText)
      ..setRange(box.cipherText.length, box.cipherText.length + _kTagLength, box.mac.bytes);
    encryptedChunks.add(framed);
    totalCipherLen += framed.length;
  }

  // Wrap the FEK under the DEK using the same envelope.dart layout
  // media_cipher.dart uses for its per-file FEK. Wrap BEFORE wipe: wiping
  // first would wrap an all-zero key instead of the FEK that actually
  // encrypted the chunks above.
  final wrappedFek = await wrapKey(
    plaintext: fek.bytes,
    wrappingKey: dek,
    payloadType: PayloadType.fek,
    wrapperType: WrapperType.dekAsWrappingKey,
  );
  fek.wipe();

  final out = Uint8List(kDbImageHeaderLength + totalCipherLen);
  out.setRange(0, 4, _kMagic);
  out[4] = kDbImageFormatVersion;
  out[5] = kDbImagePurposeSqliteImage;
  out[6] = 0;
  out[7] = 0;
  out.setRange(
    _kWrappedFekOffset,
    _kWrappedFekOffset + kWrappedEnvelopeLength,
    wrappedFek.bytes,
  );
  out.setRange(
    _kNoncePrefixOffset,
    _kNoncePrefixOffset + _kNoncePrefixLength,
    noncePrefix,
  );
  out.setRange(_kChunkSizeOffset, _kChunkSizeOffset + 4, _beBytes(chunkSize, 4));
  out.setRange(
    _kPlaintextLengthOffset,
    kDbImageHeaderLength,
    _beBytes(plaintext.length, 8),
  );

  var offset = kDbImageHeaderLength;
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
/// malformed header, a structurally-impossible `plaintext_length`, a wrong
/// [dek], a tampered `wrapped_fek`, or ANY tampered/reordered/truncated
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
  if (ciphertext.length < kDbImageHeaderLength) {
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

  final wrappedFekBytes = ciphertext.sublist(
    _kWrappedFekOffset,
    _kWrappedFekOffset + kWrappedEnvelopeLength,
  );
  final noncePrefix = ciphertext.sublist(
    _kNoncePrefixOffset,
    _kNoncePrefixOffset + _kNoncePrefixLength,
  );
  final chunkSize = _beToInt(
    ciphertext.sublist(_kChunkSizeOffset, _kChunkSizeOffset + 4),
  );
  final plaintextLength = _beToInt(
    ciphertext.sublist(_kPlaintextLengthOffset, kDbImageHeaderLength),
  );

  // Reject a structurally-impossible header BEFORE `out` is allocated below
  // — see [validateDbImagePlaintextLengthBound]'s doc for why this must run
  // ahead of any Uint8List(plaintextLength) allocation (pre-AEAD OOM DoS).
  validateDbImagePlaintextLengthBound(
    plaintextLength: plaintextLength,
    chunkSize: chunkSize,
    availableCipherBytes: ciphertext.length - kDbImageHeaderLength,
  );

  final Uint8List unwrappedFekBytes;
  try {
    unwrappedFekBytes = await unwrapKey(
      wrapped: WrappedEnvelope(wrappedFekBytes),
      wrappingKey: dek,
    );
  } on EnvelopeUnwrapException {
    // Wrong DEK, or a tampered wrapped_fek — surfaced through this codec's
    // own exception hierarchy (chunkIndex -1 denotes a header/key-level
    // failure, before any image chunk is even reached) rather than leaking
    // envelope.dart's exception type across this module's boundary.
    throw const DbImageTamperException(-1);
  }
  // Wrapped in a Fek (not used bare) so it's wiped in the `finally` below —
  // mirrors media_cipher.dart's decrypt-side posture: the unwrapped key is
  // only ever live for the duration of this call.
  final fek = Fek(unwrappedFekBytes);
  final secretKey = SecretKey(fek.bytes);

  try {
    final out = Uint8List(plaintextLength);

    var readOffset = kDbImageHeaderLength;
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

      final aad = _aadFor(
        chunkIndex,
        noncePrefix: noncePrefix,
        chunkSize: chunkSize,
        plaintextLength: plaintextLength,
      );

      final box = SecretBox(chunkCiphertext, nonce: nonce, mac: Mac(tag));

      final List<int> chunkPlaintext;
      try {
        chunkPlaintext = await _aesGcm.decrypt(
          box,
          secretKey: secretKey,
          aad: aad,
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
  } finally {
    fek.wipe();
  }
}
