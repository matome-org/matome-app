// Frozen 64-byte authenticated wrap layout — task #1849, plan #131 W1.
// Implements Appendix A.4 of .docs/internal/at-rest-key-flow.md EXACTLY.
// Do NOT deviate: #1850 (KeyUnwrapper) and #1851 (/keybundle) interop
// against this byte layout.
//
//   offset  size   field
//   0       1      format_version   (0x01)
//   1       1      payload_type     (0x01 = DEK, 0x02 = FEK)
//   2       1      wrapper_type     (0x00..0x05, see WrapperType)
//   3       1      alg_id           (0x01 = AES-256-GCM)
//   4       12     nonce            (96-bit, CSPRNG, unique per wrap)
//   16      32     ciphertext       (AES-256-GCM output, 32 bytes)
//   48      16     gcm_tag          (128-bit authentication tag)
//                  total: 64 bytes
//
// The 4-byte header is passed as AES-GCM additional authenticated data
// (AAD) on every wrap/unwrap. This is what makes cross-slot substitution
// (e.g. relabeling a wrapped_dek_recovery blob as wrapped_dek_pw) fail tag
// verification instead of silently succeeding.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart'
    show Mac, SecretBox, SecretBoxAuthenticationError, SecretKey;
import 'package:cryptography/dart.dart' show DartAesGcm;

import 'key_material.dart' show secureRandomBytes;

const int kFormatVersionV1 = 0x01;
const int kHeaderLength = 4;
const int kNonceLength = 12;
const int kCiphertextLength = 32;
const int kTagLength = 16;
const int kWrappedEnvelopeLength =
    kHeaderLength + kNonceLength + kCiphertextLength + kTagLength; // 64

/// `payload_type` — what kind of 32-byte key is being wrapped.
enum PayloadType {
  dek(0x01),
  fek(0x02);

  final int byteValue;
  const PayloadType(this.byteValue);
}

/// `wrapper_type` — what wrapped the payload. Slots 0x04/0x05 are reserved
/// (passkey-KEK, space-KEK) for future use per Appendix A.4; not exercised
/// by this task, but numbered here so a future implementation needs no
/// `format_version` bump.
enum WrapperType {
  dekAsWrappingKey(0x00),
  passwordKek(0x01),
  recoveryKek(0x02),
  deviceKek(0x03),
  passkeyKekReserved(0x04),
  spaceKekReserved(0x05);

  final int byteValue;
  const WrapperType(this.byteValue);
}

/// `alg_id` — the AEAD algorithm used for the wrap.
enum AlgId {
  aes256Gcm(0x01);

  final int byteValue;
  const AlgId(this.byteValue);
}

/// Base type for every explicit unwrap failure. Tampering ANY byte of a
/// wrapped envelope — header, nonce, ciphertext, or tag — always surfaces
/// as one of this hierarchy's subtypes. Never a silent success, never
/// partial plaintext.
abstract class EnvelopeUnwrapException implements Exception {
  const EnvelopeUnwrapException();
}

/// AEAD authentication failed: wrong key, or the ciphertext/tag/header (via
/// AAD) was tampered with. This is the generic "wrap doesn't check out"
/// failure once the fast-path format/alg checks have already passed.
class EnvelopeTamperException extends EnvelopeUnwrapException {
  final String reason;
  const EnvelopeTamperException([this.reason = 'authentication failed']);

  @override
  String toString() => 'EnvelopeTamperException: $reason';
}

/// The blob's `format_version` byte is not one this build knows how to
/// unwrap (Appendix A.1 — the wrap-layout version axis, independent of the
/// KDF-params axis in kdf_params.dart).
class UnsupportedFormatVersionException extends EnvelopeUnwrapException {
  final int foundVersion;
  const UnsupportedFormatVersionException(this.foundVersion);

  @override
  String toString() =>
      'UnsupportedFormatVersionException: format_version=0x'
      '${foundVersion.toRadixString(16).padLeft(2, '0')} not supported '
      '(expected 0x${kFormatVersionV1.toRadixString(16).padLeft(2, '0')})';
}

/// The blob's `alg_id` byte names an algorithm this build does not
/// implement (e.g. the reserved future AES-KEYWRAP `0x02`).
class UnsupportedAlgorithmException extends EnvelopeUnwrapException {
  final int foundAlgId;
  const UnsupportedAlgorithmException(this.foundAlgId);

  @override
  String toString() => 'UnsupportedAlgorithmException: alg_id=0x'
      '${foundAlgId.toRadixString(16).padLeft(2, '0')} not supported';
}

/// A byte blob that is not exactly [kWrappedEnvelopeLength] bytes long can
/// never be a valid wrapped envelope — rejected before any crypto is
/// attempted.
class InvalidEnvelopeLengthException implements Exception {
  final int foundLength;
  const InvalidEnvelopeLengthException(this.foundLength);

  @override
  String toString() => 'InvalidEnvelopeLengthException: got $foundLength '
      'bytes, expected exactly $kWrappedEnvelopeLength';
}

/// An immutable, length-validated 64-byte wrapped blob. Construction is the
/// only place blob length is checked, so every other code path can assume
/// `bytes.length == kWrappedEnvelopeLength`.
class WrappedEnvelope {
  final Uint8List bytes;

  WrappedEnvelope(Uint8List bytes) : bytes = bytes {
    if (bytes.length != kWrappedEnvelopeLength) {
      throw InvalidEnvelopeLengthException(bytes.length);
    }
  }

  Uint8List get header => bytes.sublist(0, kHeaderLength);
  Uint8List get nonce =>
      bytes.sublist(kHeaderLength, kHeaderLength + kNonceLength);
  Uint8List get ciphertext => bytes.sublist(
        kHeaderLength + kNonceLength,
        kHeaderLength + kNonceLength + kCiphertextLength,
      );
  Uint8List get tag => bytes.sublist(
        kHeaderLength + kNonceLength + kCiphertextLength,
        kWrappedEnvelopeLength,
      );

  int get formatVersion => bytes[0];
  int get payloadType => bytes[1];
  int get wrapperType => bytes[2];
  int get algId => bytes[3];

  /// Transport encoding: standard, padded base64 (Appendix A.4). 64 raw
  /// bytes -> 88 base64 chars.
  String toBase64() => base64.encode(bytes);

  factory WrappedEnvelope.fromBase64(String encoded) =>
      WrappedEnvelope(Uint8List.fromList(base64.decode(encoded)));

  @override
  String toString() => 'WrappedEnvelope(${bytes.length} bytes, redacted)';
}

final DartAesGcm _aesGcm = DartAesGcm(
  secretKeyLength: 32,
  nonceLength: kNonceLength,
);

/// Wraps [plaintext] (a 32-byte DEK or FEK) under [wrappingKey] (a 32-byte
/// KEK, or the DEK itself when wrapping a FEK), producing the frozen
/// 64-byte authenticated layout.
///
/// A fresh CSPRNG nonce is generated per call — never reuse a nonce with the
/// same key.
Future<WrappedEnvelope> wrapKey({
  required Uint8List plaintext,
  required Uint8List wrappingKey,
  required PayloadType payloadType,
  required WrapperType wrapperType,
  AlgId algId = AlgId.aes256Gcm,
}) async {
  if (plaintext.length != kCiphertextLength) {
    throw ArgumentError.value(
      plaintext.length,
      'plaintext.length',
      'expected exactly $kCiphertextLength bytes',
    );
  }
  if (wrappingKey.length != 32) {
    throw ArgumentError.value(
      wrappingKey.length,
      'wrappingKey.length',
      'expected exactly 32 bytes',
    );
  }

  final header = Uint8List.fromList([
    kFormatVersionV1,
    payloadType.byteValue,
    wrapperType.byteValue,
    algId.byteValue,
  ]);
  final nonce = secureRandomBytes(kNonceLength);

  final secretBox = await _aesGcm.encrypt(
    plaintext,
    secretKey: SecretKey(wrappingKey),
    nonce: nonce,
    aad: header,
  );

  final out = Uint8List(kWrappedEnvelopeLength);
  out.setRange(0, kHeaderLength, header);
  out.setRange(kHeaderLength, kHeaderLength + kNonceLength, secretBox.nonce);
  out.setRange(
    kHeaderLength + kNonceLength,
    kHeaderLength + kNonceLength + kCiphertextLength,
    secretBox.cipherText,
  );
  out.setRange(
    kHeaderLength + kNonceLength + kCiphertextLength,
    kWrappedEnvelopeLength,
    secretBox.mac.bytes,
  );
  return WrappedEnvelope(out);
}

/// Unwraps [wrapped] under [wrappingKey], returning the original 32-byte
/// plaintext.
///
/// Fails EXPLICITLY (throws an [EnvelopeUnwrapException] subtype) on any
/// tamper — header, nonce, ciphertext, or tag — or on a wrong key. Never
/// returns partial or garbage plaintext.
Future<Uint8List> unwrapKey({
  required WrappedEnvelope wrapped,
  required Uint8List wrappingKey,
}) async {
  // Fast-path guards on the two versioning axes owned by this layer (the
  // wrap-layout version and the AEAD algorithm id) — checked before any
  // crypto is attempted.
  if (wrapped.formatVersion != kFormatVersionV1) {
    throw UnsupportedFormatVersionException(wrapped.formatVersion);
  }
  if (wrapped.algId != AlgId.aes256Gcm.byteValue) {
    throw UnsupportedAlgorithmException(wrapped.algId);
  }

  final secretBox = SecretBox(
    wrapped.ciphertext,
    nonce: wrapped.nonce,
    mac: Mac(wrapped.tag),
  );

  try {
    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(wrappingKey),
      aad: wrapped.header,
    );
    return Uint8List.fromList(plaintext);
  } on SecretBoxAuthenticationError {
    throw const EnvelopeTamperException();
  }
}
