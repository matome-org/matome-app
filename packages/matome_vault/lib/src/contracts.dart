import 'dart:async';
import 'dart:typed_data';

/// Stable, opaque account namespace. It must not contain a path or credential.
final class VaultAccountId {
  factory VaultAccountId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be blank');
    }
    return VaultAccountId._(normalized);
  }

  const VaultAccountId._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is VaultAccountId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'VaultAccountId($value)';
}

/// CSPRNG-generated opaque blob identifier, never a content hash or path.
final class VaultBlobId {
  factory VaultBlobId(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a non-empty URL-safe opaque token',
      );
    }
    return VaultBlobId._(normalized);
  }

  const VaultBlobId._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is VaultBlobId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'VaultBlobId($value)';
}

/// A platform-independent, single-consumer plaintext source for ingestion.
///
/// The app owns picker/provider/capture access and constructs this input. The
/// vault never deletes or otherwise assumes ownership of the original source.
abstract interface class MediaInput {
  String get filename;
  String? get contentType;
  int? get knownLength;

  /// Opens the source once. Implementations may reject a second call.
  Stream<List<int>> openRead();
}

/// Opaque access to already-unlocked account key material.
///
/// Passwords, passkeys, biometrics, KEKs, recovery and keybundles are app
/// concerns. Implementations must expose key bytes only for the duration of
/// [use] and make [dispose] idempotent.
abstract interface class VaultKeyMaterial {
  VaultAccountId get accountId;

  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation);

  Future<void> dispose();
}

enum VaultSessionState { unlocked, locked, closed }

enum VaultSessionCloseReason { lock, logout, accountSwitch }

/// An unlocked, account-bound capability for accessing one vault namespace.
abstract interface class VaultSession {
  VaultAccountId get accountId;
  VaultSessionState get state;
  MediaBlobStore get blobs;

  /// Allocates private temporary plaintext, primarily for recorder output.
  ///
  /// The returned location is staging, never durable Vault identity. The app
  /// must finalize the writer, ingest it through [blobs], then dispose it.
  /// Implementations reject a non-positive [ttl].
  Future<VaultPlaintextLease> createPlaintextLease({
    required VaultLeasePurpose purpose,
    required Duration ttl,
    String? suggestedFilename,
  });

  /// Invalidates new operations and releases key material and plaintext leases.
  Future<void> close(VaultSessionCloseReason reason);
}

/// Durable lifecycle state. There is no implicit fallback from [missing].
enum VaultBlobState { staging, ready, deleting, missing }

enum VaultCipherFormat { mec1 }

/// Half-open plaintext byte range `[start, endExclusive)`.
final class PlaintextRange {
  factory PlaintextRange({required int start, required int endExclusive}) {
    if (start < 0) {
      throw RangeError.range(start, 0, null, 'start');
    }
    if (endExclusive <= start) {
      throw RangeError.value(
        endExclusive,
        'endExclusive',
        'must be greater than start',
      );
    }
    return PlaintextRange._(start, endExclusive);
  }

  const PlaintextRange._(this.start, this.endExclusive);

  final int start;
  final int endExclusive;

  int get length => endExclusive - start;

  @override
  bool operator ==(Object other) =>
      other is PlaintextRange &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);
}

/// Metadata describes plaintext logically and ciphertext physically.
final class VaultBlobStat {
  VaultBlobStat({
    required this.id,
    required this.state,
    this.plaintextLength,
    this.physicalLength,
    this.plaintextSha256,
    this.cipherFormat = VaultCipherFormat.mec1,
    this.cipherVersion = 1,
  }) {
    if (physicalLength != null && physicalLength! < 0) {
      throw RangeError.range(physicalLength!, 0, null, 'physicalLength');
    }
    if (plaintextLength != null && plaintextLength! < 0) {
      throw RangeError.range(plaintextLength!, 0, null, 'plaintextLength');
    }
    if (state == VaultBlobState.ready &&
        (plaintextLength == null ||
            physicalLength == null ||
            plaintextSha256 == null)) {
      throw ArgumentError(
        'ready blobs require plaintextLength, physicalLength and plaintextSha256',
      );
    }
    final digest = plaintextSha256;
    if (digest != null && !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw ArgumentError.value(
        digest,
        'plaintextSha256',
        'must be a lowercase SHA-256 hex digest',
      );
    }
    if (cipherVersion < 1) {
      throw ArgumentError.value(
        cipherVersion,
        'cipherVersion',
        'must be positive',
      );
    }
  }

  final VaultBlobId id;
  final VaultBlobState state;
  final int? plaintextLength;
  final int? physicalLength;
  final String? plaintextSha256;
  final VaultCipherFormat cipherFormat;
  final int cipherVersion;
}

/// A plaintext stream whose emitted events have already passed authentication.
///
/// Implementations may decrypt expanded cipher-chunk boundaries internally but
/// must emit exactly [range] (or the full blob when null). They must authenticate
/// each chunk before emitting any plaintext from that chunk. Authentication or
/// structural failure terminates with [VaultFailure] and never emits bytes from
/// the failing chunk.
abstract interface class AuthenticatedPlaintextRead {
  VaultBlobId get blobId;
  PlaintextRange? get range;
  int get plaintextLength;
  Stream<List<int>> get bytes;
}

/// Revocable, account-scoped authority to read one immutable ready blob.
///
/// The lease pins the encrypted object against delete/GC from acquisition until
/// [dispose]. Closing the owning store revokes the lease and cancels active
/// streams, so an old account executor cannot continue plaintext egress.
abstract interface class VaultBlobReadLease {
  VaultBlobId get blobId;

  Future<AuthenticatedPlaintextRead> openAuthenticatedRead({
    PlaintextRange? range,
  });

  Future<void> dispose();
}

enum VaultLeasePurpose {
  playback,
  preview,
  externalOpen,
  explicitExport,
  recorderFinalization,
}

/// Time-bounded access to materialized plaintext.
///
/// [location] is a private file URI or an ephemeral browser object URI. It is
/// not durable identity. Implementations revoke/delete it on [dispose], expiry,
/// session close and startup reconciliation.
abstract interface class VaultPlaintextLease {
  /// The encrypted source, or null for pre-ingest recorder staging.
  VaultBlobId? get blobId;
  VaultLeasePurpose get purpose;
  Uri get location;
  DateTime get expiresAt;

  Future<void> dispose();
}

enum VaultJournalOperation { ingest, delete, lease }

enum VaultJournalPhase {
  started,
  objectDurable,
  metadataCommitted,
  cleanupPending,
}

/// Backend-neutral durable evidence used to recover non-atomic boundaries.
final class VaultJournalEntry {
  const VaultJournalEntry({
    required this.blobId,
    required this.operation,
    required this.phase,
    required this.updatedAt,
  });

  final VaultBlobId blobId;
  final VaultJournalOperation operation;
  final VaultJournalPhase phase;
  final DateTime updatedAt;
}

enum VaultReconciliationIssue {
  orphanedStaging,
  missingObject,
  unreferencedReadyObject,
  interruptedDelete,
  expiredLease,
  sizeMismatch,
}

enum VaultReconciliationAction {
  removedStaging,
  markedMissing,
  preservedUnreferencedObject,
  completedDelete,
  revokedLease,
  quarantinedObject,
}

final class VaultReconciliationRecord {
  const VaultReconciliationRecord({
    required this.blobId,
    required this.issue,
    required this.action,
  });

  final VaultBlobId blobId;
  final VaultReconciliationIssue issue;
  final VaultReconciliationAction action;
}

final class VaultReconciliationReport {
  VaultReconciliationReport(Iterable<VaultReconciliationRecord> records)
    : records = List.unmodifiable(records);

  final List<VaultReconciliationRecord> records;

  bool get changed => records.isNotEmpty;
}

enum VaultFailureCode {
  locked,
  wrongKey,
  keyUnavailable,
  corruptCiphertext,
  unsupportedFormat,
  backendUnavailable,
  quotaExceeded,
  crashRecoveryRequired,
  blobMissing,
  blobNotReady,
  invalidRange,
  leaseExpired,
}

/// Expected vault failure. Every security-sensitive condition fails closed.
final class VaultFailure implements Exception {
  const VaultFailure(this.code, this.message, {this.cause});

  final VaultFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'VaultFailure(${code.name}): $message';
}

/// Account-scoped encrypted blob operations.
abstract interface class MediaBlobStore {
  VaultAccountId get accountId;

  /// Encrypts to staging, durably journals, then publishes as [VaultBlobState.ready].
  Future<VaultBlobStat> ingest(MediaInput input);

  Future<VaultBlobStat> stat(VaultBlobId id);

  /// Pins one ready blob and returns revocable authenticated-read authority.
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id);

  /// Enumerates durable ready identities for application-reference recovery.
  /// The identities are opaque and reveal no physical storage location.
  Future<Set<VaultBlobId>> readyBlobIds();

  /// Opens only [VaultBlobState.ready] blobs and authenticates before emission.
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  });

  /// Materializes plaintext only for an explicit purpose and positive TTL.
  Future<VaultPlaintextLease> createLease(
    VaultBlobId id, {
    required VaultLeasePurpose purpose,
    required Duration ttl,
  });

  /// Waits for existing readers, then blocks new leases before remote delete.
  /// No ciphertext is removed. Idempotent for an already-prepared blob.
  Future<void> prepareDelete(VaultBlobId id);

  /// Persists a deleting tombstone before ciphertext removal. Idempotent.
  Future<void> delete(VaultBlobId id);

  /// Returns durable in-flight operations for diagnostics and recovery UI.
  Future<List<VaultJournalEntry>> journal();

  /// Repairs to a safe state without inventing data or plaintext fallback.
  Future<VaultReconciliationReport> reconcile();

  /// Revokes active read capabilities. Idempotent; no new access is accepted.
  Future<void> close();
}
