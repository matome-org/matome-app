import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/vault/vault_boot_coordinator.dart';
import 'package:matome_vault/matome_vault.dart';

void main() {
  test(
    'does not publish the database before account stores are ready',
    () async {
      final opened = Completer<void>();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = VaultBootCoordinator(
        openStores: (material) async {
          await opened.future;
          return VaultOpenedStores(
            database: db,
            blobs: _FakeBlobStore(material.accountId),
          );
        },
      );
      final container = ProviderContainer(
        overrides: [
          vaultBootCoordinatorProvider.overrideWith((ref) => coordinator),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(appDatabaseProvider), throwsStateError);
      final opening = coordinator.open(_FakeKeyMaterial('account-a'));
      expect(coordinator.state.phase, VaultBootPhase.opening);
      expect(() => container.read(appDatabaseProvider), throwsStateError);

      opened.complete();
      await opening;
      expect(coordinator.state.phase, VaultBootPhase.ready);
      expect(container.read(appDatabaseProvider), same(db));
    },
  );

  test(
    'account switch closes old stores before publishing the new account',
    () async {
      final events = <String>[];
      final databases = <AppDatabase>[];
      final coordinator = VaultBootCoordinator(
        openStores: (material) async {
          events.add('open:${material.accountId.value}');
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          databases.add(db);
          return VaultOpenedStores(
            database: db,
            blobs: _FakeBlobStore(material.accountId),
            close: () async => events.add('close:${material.accountId.value}'),
          );
        },
      );

      await coordinator.open(_FakeKeyMaterial('account-a'));
      await coordinator.open(_FakeKeyMaterial('account-b'));

      expect(events, ['open:account-a', 'close:account-a', 'open:account-b']);
      expect(coordinator.state.accountId, VaultAccountId('account-b'));
      await coordinator.close();
    },
  );

  test('failed open stays fail-closed and publishes no resources', () async {
    final coordinator = VaultBootCoordinator(
      openStores: (_) async => throw StateError('wrong key'),
    );

    await expectLater(
      coordinator.open(_FakeKeyMaterial('account-a')),
      throwsStateError,
    );

    expect(coordinator.state.phase, VaultBootPhase.failedClosed);
    expect(coordinator.state.stores, isNull);
  });

  test(
    'reconciles Drift references and preserves unknown ready orphans',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.validateReady();
      for (final entry in const {
        'file-ready': 'blob-ready',
        'file-missing': 'blob-missing',
      }.entries) {
        await db.customStatement(
          'INSERT INTO file_blobs '
          '(id, filename, byte_size, media_type, blob_id, '
          'blob_state, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [entry.key, 'fixture.bin', 3, 'document', entry.value, 'ready', 1, 1],
        );
      }
      final blobs = _ReconcilingBlobStore();
      final coordinator = VaultBootCoordinator(
        openStores: (_) async => VaultOpenedStores(database: db, blobs: blobs),
      );

      await coordinator.open(_FakeKeyMaterial('account-a'));

      final rows = await db
          .customSelect('SELECT id, blob_state FROM file_blobs ORDER BY id')
          .get();
      expect(
        {
          for (final row in rows)
            row.read<String>('id'): row.read<String>('blob_state'),
        },
        {'file-missing': 'missing', 'file-ready': 'ready'},
      );
      expect(blobs.deleted, isEmpty);
      final decision = await (db.select(
        db.blobGcDecisions,
      )..where((row) => row.blobId.equals('blob-orphan'))).getSingle();
      expect(decision.blobId, 'blob-orphan');
      expect(decision.decision, 'preserve');
      expect(decision.reason, 'missing_metadata');
      await coordinator.close();
    },
  );
}

final class _FakeKeyMaterial implements VaultKeyMaterial {
  _FakeKeyMaterial(String account) : accountId = VaultAccountId(account);

  @override
  final VaultAccountId accountId;

  @override
  Future<void> dispose() async {}

  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) =>
      Future.sync(() => operation(Uint8List(32)));
}

final class _FakeBlobStore implements MediaBlobStore {
  _FakeBlobStore(this.accountId);

  @override
  final VaultAccountId accountId;

  @override
  Future<void> delete(VaultBlobId id) => throw UnimplementedError();

  @override
  Future<void> prepareDelete(VaultBlobId id) => throw UnimplementedError();

  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) =>
      throw UnimplementedError();

  @override
  Future<void> close() async {}

  @override
  Future<VaultBlobStat> ingest(MediaInput input) => throw UnimplementedError();

  @override
  Future<List<VaultJournalEntry>> journal() => throw UnimplementedError();

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => {};

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
  Future<VaultReconciliationReport> reconcile() async =>
      VaultReconciliationReport(const []);

  @override
  Future<VaultBlobStat> stat(VaultBlobId id) => throw UnimplementedError();
}

final class _ReconcilingBlobStore implements MediaBlobStore {
  final deleted = <VaultBlobId>{};

  @override
  VaultAccountId get accountId => VaultAccountId('account-a');

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => {
    VaultBlobId('blob-ready'),
    VaultBlobId('blob-orphan'),
  };

  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async {
    if (id == VaultBlobId('blob-missing')) {
      throw const VaultFailure(VaultFailureCode.blobMissing, 'missing');
    }
    return VaultBlobStat(
      id: id,
      state: VaultBlobState.ready,
      plaintextLength: 3,
      physicalLength: 67,
      plaintextSha256: 'a' * 64,
    );
  }

  @override
  Future<void> delete(VaultBlobId id) async => deleted.add(id);

  @override
  Future<void> close() async {}

  @override
  Future<VaultReconciliationReport> reconcile() async =>
      VaultReconciliationReport(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('operation is outside this test');
}
