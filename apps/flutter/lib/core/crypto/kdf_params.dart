// Argon2id KDF parameter profiles — the KDF-cost axis of the frozen wire
// format (Appendix A.1/A.3, .docs/internal/at-rest-key-flow.md, task #1848).
//
// This axis is independent of `format_version` (see envelope.dart): bumping
// the KDF profile only requires re-deriving KEKs, never touches the wrap
// layout. Frozen values below MUST NOT change in place — a cost-parameter
// change requires a NEW profile name (e.g. `argon2id-v2-portable`).
library;

/// Salt length for every Argon2id profile (Appendix A.2) — 16 bytes,
/// constant across profiles, so it lives outside the versioned profile
/// data rather than being duplicated in each one.
const int kArgon2SaltLen = 16;

/// Thrown when a parsed `kdf_params` blob names a *known* profile but its
/// concrete field values do not match that profile's frozen definition.
///
/// This is the "param-version mismatch" the plan's AC calls out: a legacy or
/// tampered keybundle that claims `argon2id-v1-portable` while actually
/// carrying different (e.g. weaker) cost parameters must be rejected
/// explicitly instead of silently deriving a weaker/wrong key.
class KdfProfileMismatchException implements Exception {
  final String profile;
  final String reason;

  const KdfProfileMismatchException(this.profile, this.reason);

  @override
  String toString() =>
      'KdfProfileMismatchException: profile "$profile" — $reason';
}

/// Thrown when a `kdf_params` blob names a profile this build does not
/// recognize at all (e.g. a future `argon2id-v2-portable` on an old client).
class UnknownKdfProfileException implements Exception {
  final String profile;

  const UnknownKdfProfileException(this.profile);

  @override
  String toString() => 'UnknownKdfProfileException: unknown profile "$profile"';
}

/// Versioned Argon2id parameter set, as carried in the `/keybundle`
/// `kdf_params` JSON object (Appendix A.6). Immutable value type.
///
/// Salt length is fixed at 16 bytes for every profile (Appendix A.2) — not
/// carried in the JSON itself, so it's exposed as [kArgon2SaltLen] (a
/// top-level constant, since it doesn't vary per profile) and mirrored as
/// the instance getter [saltLen] for convenience at call sites that already
/// hold an `Argon2idParams` value.
class Argon2idParams {
  final String profile;
  final String algorithm;
  final int version;
  final int memoryKib;
  final int iterations;
  final int parallelism;
  final int outputLen;

  int get saltLen => kArgon2SaltLen;

  const Argon2idParams({
    required this.profile,
    required this.algorithm,
    required this.version,
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.outputLen,
  });

  /// The frozen, platform-portable profile (Appendix A.3). Applies
  /// identically to `salt_enc`, `salt_rec`, and `salt_auth`.
  static const Argon2idParams portableV1 = Argon2idParams(
    profile: 'argon2id-v1-portable',
    algorithm: 'argon2id',
    version: 19, // Argon2 spec version 0x13, RFC 9106
    memoryKib: 19456, // 19 MiB
    iterations: 2,
    parallelism: 1,
    outputLen: 32,
  );

  /// Registry of every profile this build recognizes. Extending this with a
  /// new named profile (e.g. `argon2id-v2-portable`) is a KDF-axis bump only
  /// — it does NOT require a `format_version` change in envelope.dart.
  static const Map<String, Argon2idParams> _knownProfiles = {
    'argon2id-v1-portable': portableV1,
  };

  /// Parses and validates a `kdf_params` JSON object.
  ///
  /// - Unknown `profile` name → [UnknownKdfProfileException].
  /// - Known `profile` name whose fields don't match the frozen definition
  ///   → [KdfProfileMismatchException] (covers legacy/downgraded/corrupted
  ///   blobs that claim a profile they don't actually match).
  factory Argon2idParams.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as String;
    final known = _knownProfiles[profile];
    if (known == null) {
      throw UnknownKdfProfileException(profile);
    }

    final algorithm = json['algorithm'] as String;
    final version = (json['version'] as num).toInt();
    final memoryKib = (json['memory_kib'] as num).toInt();
    final iterations = (json['iterations'] as num).toInt();
    final parallelism = (json['parallelism'] as num).toInt();
    final outputLen = (json['output_len'] as num).toInt();

    if (algorithm != known.algorithm) {
      throw KdfProfileMismatchException(
        profile,
        'algorithm "$algorithm" != expected "${known.algorithm}"',
      );
    }
    if (version != known.version) {
      throw KdfProfileMismatchException(
        profile,
        'argon2 version $version != expected ${known.version}',
      );
    }
    if (memoryKib != known.memoryKib) {
      throw KdfProfileMismatchException(
        profile,
        'memory_kib $memoryKib != expected ${known.memoryKib}',
      );
    }
    if (iterations != known.iterations) {
      throw KdfProfileMismatchException(
        profile,
        'iterations $iterations != expected ${known.iterations}',
      );
    }
    if (parallelism != known.parallelism) {
      throw KdfProfileMismatchException(
        profile,
        'parallelism $parallelism != expected ${known.parallelism}',
      );
    }
    if (outputLen != known.outputLen) {
      throw KdfProfileMismatchException(
        profile,
        'output_len $outputLen != expected ${known.outputLen}',
      );
    }

    return known;
  }

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'algorithm': algorithm,
        'version': version,
        'memory_kib': memoryKib,
        'iterations': iterations,
        'parallelism': parallelism,
        'output_len': outputLen,
      };

  @override
  bool operator ==(Object other) =>
      other is Argon2idParams &&
      other.profile == profile &&
      other.algorithm == algorithm &&
      other.version == version &&
      other.memoryKib == memoryKib &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.outputLen == outputLen;

  @override
  int get hashCode => Object.hash(
        profile,
        algorithm,
        version,
        memoryKib,
        iterations,
        parallelism,
        outputLen,
      );

  @override
  String toString() => 'Argon2idParams($profile)';
}
