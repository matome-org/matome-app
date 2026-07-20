import 'package:crypto/crypto.dart';
import 'package:matome_vault/matome_vault.dart';

final class FakeMediaBlobStore implements MediaBlobStore {
  int _next = 0;
  final Set<VaultBlobId> deleted = {};
  final Map<VaultBlobId, VaultBlobStat> _blobs = {};
  final Map<VaultBlobId, List<int>> _plaintext = {};
  final Set<_FakeReadLease> _leases = {};
  final Set<_FakePlaintextLease> _plaintextLeases = {};
  final Set<VaultBlobId> _pendingDeletes = {};
  final List<PlaintextRange?> openedRanges = [];
  Object? readFailure;
  bool _closed = false;

  int get activeLeaseCount => _leases.length + _plaintextLeases.length;

  @override
  VaultAccountId get accountId => VaultAccountId('test-account');

  @override
  Future<VaultBlobStat> ingest(MediaInput input) async {
    final bytes = await input.openRead().expand((chunk) => chunk).toList();
    final stat = VaultBlobStat(
      id: VaultBlobId('test-blob-${++_next}'),
      state: VaultBlobState.ready,
      plaintextLength: bytes.length,
      physicalLength: bytes.length + 64,
      plaintextSha256: sha256.convert(bytes).toString(),
    );
    _blobs[stat.id] = stat;
    _plaintext[stat.id] = bytes;
    return stat;
  }

  @override
  Future<void> delete(VaultBlobId id) async {
    if (_leases.any((lease) => lease.blobId == id && lease.isActive) ||
        _plaintextLeases.any((lease) => lease.blobId == id && lease.isActive)) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob has an active read lease.',
      );
    }
    deleted.add(id);
    _pendingDeletes.remove(id);
    _blobs.remove(id);
    _plaintext.remove(id);
  }

  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) async {
    _requireOpen();
    if (!_blobs.containsKey(id) || _pendingDeletes.contains(id)) {
      throw const VaultFailure(
        VaultFailureCode.blobMissing,
        'Blob is missing.',
      );
    }
    late final _FakeReadLease lease;
    lease = _FakeReadLease(id, (range) async {
      _requireOpen();
      final bytes = _plaintext[id];
      if (bytes == null) {
        throw const VaultFailure(
          VaultFailureCode.blobMissing,
          'Blob is missing.',
        );
      }
      final start = range?.start ?? 0;
      final end = range?.endExclusive ?? bytes.length;
      if (end > bytes.length) {
        throw const VaultFailure(
          VaultFailureCode.invalidRange,
          'Range is outside the blob.',
        );
      }
      openedRanges.add(range);
      final failure = readFailure;
      if (failure != null) {
        return _FakeAuthenticatedRead(
          id,
          range,
          bytes.length,
          Stream.error(failure),
        );
      }
      return _FakeAuthenticatedRead(
        id,
        range,
        bytes.length,
        Stream.value(bytes.sublist(start, end)),
      );
    }, () => _leases.remove(lease));
    _leases.add(lease);
    return lease;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(_leases.toList().map((lease) => lease.dispose()));
    await Future.wait(
      _plaintextLeases.toList().map((lease) => lease.dispose()),
    );
  }

  @override
  Future<VaultReconciliationReport> reconcile() async =>
      VaultReconciliationReport(const []);
  @override
  Future<List<VaultJournalEntry>> journal() async => const [];
  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => _blobs.keys.toSet();
  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async =>
      _blobs[id] ?? VaultBlobStat(id: id, state: VaultBlobState.missing);
  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  }) => throw UnimplementedError();
  @override
  Future<VaultPlaintextLease> createLease(
    VaultBlobId id, {
    required VaultLeasePurpose purpose,
    required Duration ttl,
  }) async {
    _requireOpen();
    if (!_blobs.containsKey(id) || _pendingDeletes.contains(id)) {
      throw const VaultFailure(
        VaultFailureCode.blobMissing,
        'Blob is missing.',
      );
    }
    late final _FakePlaintextLease lease;
    lease = _FakePlaintextLease(
      () => _plaintextLeases.remove(lease),
      blobId: id,
      purpose: purpose,
      location: Uri.parse('blob:https://test.invalid/${id.value}'),
      expiresAt: DateTime.now().toUtc().add(ttl),
    );
    _plaintextLeases.add(lease);
    return lease;
  }

  @override
  Future<void> prepareDelete(VaultBlobId id) async {
    _requireOpen();
    if (_pendingDeletes.contains(id) || !_blobs.containsKey(id)) return;
    if (_leases.any((lease) => lease.blobId == id && lease.isActive) ||
        _plaintextLeases.any((lease) => lease.blobId == id && lease.isActive)) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob has an active read lease.',
      );
    }
    _pendingDeletes.add(id);
  }

  void _requireOpen() {
    if (_closed) {
      throw const VaultFailure(VaultFailureCode.locked, 'Vault is locked.');
    }
  }
}

final class _FakePlaintextLease implements VaultPlaintextLease {
  _FakePlaintextLease(
    this._release, {
    required this.blobId,
    required this.purpose,
    required this.location,
    required this.expiresAt,
  });

  @override
  final VaultBlobId blobId;
  @override
  final VaultLeasePurpose purpose;
  @override
  final Uri location;
  @override
  final DateTime expiresAt;
  void Function()? _release;

  bool get isActive => _release != null;

  @override
  Future<void> dispose() async {
    final release = _release;
    _release = null;
    release?.call();
  }
}

final class _FakeAuthenticatedRead implements AuthenticatedPlaintextRead {
  const _FakeAuthenticatedRead(
    this.blobId,
    this.range,
    this.plaintextLength,
    this.bytes,
  );

  @override
  final VaultBlobId blobId;
  @override
  final PlaintextRange? range;
  @override
  final int plaintextLength;
  @override
  final Stream<List<int>> bytes;
}

final class _FakeReadLease implements VaultBlobReadLease {
  _FakeReadLease(this.blobId, this._open, this._release);

  @override
  final VaultBlobId blobId;
  final Future<AuthenticatedPlaintextRead> Function(PlaintextRange? range)
  _open;
  void Function()? _release;

  bool get isActive => _release != null;

  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead({
    PlaintextRange? range,
  }) {
    if (!isActive) {
      throw const VaultFailure(
        VaultFailureCode.locked,
        'Read lease was revoked.',
      );
    }
    return _open(range);
  }

  @override
  Future<void> dispose() async {
    final release = _release;
    _release = null;
    release?.call();
  }
}
