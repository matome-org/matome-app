// Recovery code generator + Crockford Base32 encoding + Argon2id stretch —
// task #1849, plan #131 W1. Implements Appendix A.7.
//
// Entropy: 128-bit exactly (16 bytes, CSPRNG). Human encoding: Crockford
// Base32 (excludes ambiguous I/L/O/U), grouped in 4-character blocks
// separated by hyphens: 128 bits / 5 bits-per-char = 26 chars -> 7 groups
// (six of 4 + one of 2), e.g. `XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XX`.
import 'dart:typed_data';

import 'argon2id.dart';
import 'kdf_params.dart';
import 'key_material.dart' show secureRandomBytes;

const int kRecoveryCodeRawLength = 16; // 128 bits
const String _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A 128-bit machine-generated recovery code, plus its human-readable
/// Crockford Base32 encoding and an Argon2id-stretch to derive the
/// recovery-KEK.
class RecoveryCode {
  final Uint8List rawBytes;

  RecoveryCode(Uint8List rawBytes) : rawBytes = rawBytes {
    if (rawBytes.length != kRecoveryCodeRawLength) {
      throw ArgumentError.value(
        rawBytes.length,
        'rawBytes.length',
        'expected exactly $kRecoveryCodeRawLength bytes (128-bit)',
      );
    }
  }

  /// Generates a fresh 128-bit CSPRNG recovery code. Shown to the user ONCE
  /// at enrollment (§2 of the design doc); never stored in plaintext, never
  /// logged.
  factory RecoveryCode.generate() =>
      RecoveryCode(secureRandomBytes(kRecoveryCodeRawLength));

  /// Human-readable form: Crockford Base32, grouped in 4-char blocks
  /// separated by hyphens.
  String get formatted => _group(_encodeCrockfordBase32(rawBytes));

  /// Parses a user-entered code back into raw bytes. Tolerant of hyphens,
  /// case, and the Crockford-recommended typo substitutions (O -> 0, I/L
  /// -> 1). Throws [FormatException] if the result isn't exactly 128 bits
  /// or contains an invalid character.
  factory RecoveryCode.parse(String input) {
    final normalized = _normalizeForDecode(input);
    final decoded = _decodeCrockfordBase32(normalized);
    if (decoded.length != kRecoveryCodeRawLength) {
      throw FormatException(
        'decoded recovery code is ${decoded.length} bytes, '
        'expected $kRecoveryCodeRawLength',
        input,
      );
    }
    return RecoveryCode(decoded);
  }

  /// Argon2id-stretches the raw entropy with `salt_rec` to derive the
  /// recovery-KEK (Appendix A.2/A.3). Hashes [rawBytes] directly (not the
  /// formatted string) — see argon2id.dart's `deriveArgon2idFromBytes` doc.
  Future<Uint8List> stretch({
    required Uint8List saltRec,
    required Argon2idParams params,
  }) {
    return deriveArgon2idFromBytes(
      secret: rawBytes,
      salt: saltRec,
      params: params,
    );
  }

  @override
  String toString() => 'RecoveryCode(redacted)';
}

String _group(String flat) {
  final buffer = StringBuffer();
  for (var i = 0; i < flat.length; i += 4) {
    if (i > 0) buffer.write('-');
    final end = (i + 4 <= flat.length) ? i + 4 : flat.length;
    buffer.write(flat.substring(i, end));
  }
  return buffer.toString();
}

String _encodeCrockfordBase32(Uint8List data) {
  final sb = StringBuffer();
  var buffer = 0;
  var bitsLeft = 0;
  for (final byte in data) {
    buffer = (buffer << 8) | byte;
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      final index = (buffer >> (bitsLeft - 5)) & 0x1F;
      sb.write(_crockfordAlphabet[index]);
      bitsLeft -= 5;
      buffer &= (1 << bitsLeft) - 1;
    }
  }
  if (bitsLeft > 0) {
    final index = (buffer << (5 - bitsLeft)) & 0x1F;
    sb.write(_crockfordAlphabet[index]);
  }
  return sb.toString();
}

Uint8List _decodeCrockfordBase32(String s) {
  final bytes = <int>[];
  var buffer = 0;
  var bitsLeft = 0;
  for (var i = 0; i < s.length; i++) {
    final char = s[i];
    final value = _crockfordAlphabet.indexOf(char);
    if (value == -1) {
      throw FormatException('invalid Crockford Base32 character: $char', s, i);
    }
    buffer = (buffer << 5) | value;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      final shift = bitsLeft - 8;
      final byteVal = (buffer >> shift) & 0xFF;
      bytes.add(byteVal);
      bitsLeft -= 8;
      buffer &= (1 << bitsLeft) - 1;
    }
  }
  // Remaining bitsLeft (<8) are the zero-padding bits added at encode time;
  // discarded, not part of the payload.
  return Uint8List.fromList(bytes);
}

String _normalizeForDecode(String input) {
  final upper = input.toUpperCase();
  final buffer = StringBuffer();
  for (var i = 0; i < upper.length; i++) {
    final c = upper[i];
    if (c == '-' || c == ' ') continue;
    switch (c) {
      case 'O':
        buffer.write('0');
        break;
      case 'I':
      case 'L':
        buffer.write('1');
        break;
      default:
        buffer.write(c);
    }
  }
  return buffer.toString();
}
