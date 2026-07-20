import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/vault/media_ingest_service.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  test('publishes only after a ready Vault ingest', () async {
    final store = _Store();
    final service = MediaIngestService(store);
    VaultBlobStat? committed;

    final result = await service.ingestAndCommit(
      _Input(),
      commit: (stat) async => committed = stat,
    );

    expect(committed, same(result));
    expect(store.deleted, isEmpty);
  });

  test('Drift commit failure removes the sealed blob', () async {
    final store = _Store();
    final service = MediaIngestService(store);

    await expectLater(
      service.ingestAndCommit(
        _Input(),
        commit: (_) async => throw StateError('injected Drift failure'),
      ),
      throwsStateError,
    );

    expect(store.deleted, [store.blobStat.id]);
    expect(store.reconcileCalls, 1);
  });

  test('non-ready ingest never invokes Drift commit', () async {
    final store = _Store(state: VaultBlobState.staging);
    final service = MediaIngestService(store);
    var committed = false;

    await expectLater(
      service.ingestAndCommit(_Input(), commit: (_) async => committed = true),
      throwsA(isA<VaultFailure>()),
    );

    expect(committed, isFalse);
    expect(store.deleted, [store.blobStat.id]);
  });
}

final class _Input implements MediaInput {
  @override
  String? get contentType => 'application/octet-stream';

  @override
  String get filename => 'fixture.bin';

  @override
  int? get knownLength => 3;

  @override
  Stream<List<int>> openRead() => Stream.value(Uint8List.fromList([1, 2, 3]));
}

final class _Store implements MediaBlobStore {
  _Store({VaultBlobState state = VaultBlobState.ready})
    : blobStat = VaultBlobStat(
        id: VaultBlobId('opaque-test-blob'),
        state: state,
        plaintextLength: state == VaultBlobState.ready ? 3 : null,
        physicalLength: state == VaultBlobState.ready ? 99 : null,
        plaintextSha256: state == VaultBlobState.ready ? 'a' * 64 : null,
      );

  final VaultBlobStat blobStat;
  final List<VaultBlobId> deleted = [];
  int reconcileCalls = 0;

  @override
  VaultAccountId get accountId => VaultAccountId('account');

  @override
  Future<VaultBlobStat> ingest(MediaInput input) async => blobStat;

  @override
  Future<void> delete(VaultBlobId id) async => deleted.add(id);

  @override
  Future<void> prepareDelete(VaultBlobId id) async {}

  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {}

  @override
  Future<VaultReconciliationReport> reconcile() async {
    reconcileCalls++;
    return VaultReconciliationReport(const []);
  }

  @override
  Future<List<VaultJournalEntry>> journal() async => const [];

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async =>
      blobStat.state == VaultBlobState.ready ? {blobStat.id} : {};

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
  }) => throw UnimplementedError();

  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async => blobStat;
}
