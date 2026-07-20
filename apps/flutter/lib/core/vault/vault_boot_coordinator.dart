import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_vault/matome_vault.dart';

import '../db/app_database.dart';
import 'account_store_opener.dart';
import 'vault_retention_service.dart';

enum VaultBootPhase { closed, opening, ready, failedClosed }

final class VaultOpenedStores {
  VaultOpenedStores({
    required this.database,
    required this.blobs,
    Future<void> Function()? close,
    Future<void> Function()? checkpoint,
  }) : _platformClose = close,
       _platformCheckpoint = checkpoint;

  final AppDatabase database;
  final MediaBlobStore blobs;
  final Future<void> Function()? _platformClose;
  final Future<void> Function()? _platformCheckpoint;
  Future<void>? _closeFuture;

  Future<void> close() => _closeFuture ??= _close();

  Future<void> checkpoint() async {
    if (_closeFuture != null) return;
    if (_platformCheckpoint != null) {
      await _platformCheckpoint();
    } else {
      await database.customStatement('PRAGMA wal_checkpoint(PASSIVE)');
    }
  }

  Future<void> _close() async {
    try {
      await blobs.close();
      await _platformClose?.call();
    } finally {
      await database.close();
    }
  }
}

final class VaultBootSnapshot {
  const VaultBootSnapshot(
    this.phase, {
    this.accountId,
    this.stores,
    this.error,
  });

  final VaultBootPhase phase;
  final VaultAccountId? accountId;
  final VaultOpenedStores? stores;
  final Object? error;
}

typedef VaultStoreOpener =
    Future<VaultOpenedStores> Function(VaultKeyMaterial material);

/// Owns the physical account store lifecycle. Resources are published only
/// after both stores open and Drift has completed migrations and integrity
/// validation.
final class VaultBootCoordinator extends StateNotifier<VaultBootSnapshot> {
  VaultBootCoordinator({VaultStoreOpener? openStores})
    : _openStores = openStores ?? openAccountStores,
      super(const VaultBootSnapshot(VaultBootPhase.closed));

  final VaultStoreOpener _openStores;
  VaultOpenedStores? _stores;
  Future<void>? _transition;
  int _generation = 0;

  Future<void> open(VaultKeyMaterial material) {
    final generation = ++_generation;
    state = VaultBootSnapshot(
      VaultBootPhase.opening,
      accountId: material.accountId,
    );
    final transition = _open(generation, material, _transition);
    _transition = transition;
    return transition;
  }

  Future<void> _open(
    int generation,
    VaultKeyMaterial material,
    Future<void>? previous,
  ) async {
    await previous?.catchError((_) {});
    await _closeCurrent();
    if (generation != _generation) return;
    VaultOpenedStores? candidate;
    try {
      candidate = await _openStores(material);
      await _reconcileMediaReferences(candidate);
      if (generation != _generation) {
        await candidate.close();
        return;
      }
      _stores = candidate;
      state = VaultBootSnapshot(
        VaultBootPhase.ready,
        accountId: material.accountId,
        stores: candidate,
      );
    } catch (error) {
      await candidate?.close();
      if (generation == _generation) {
        state = VaultBootSnapshot(
          VaultBootPhase.failedClosed,
          accountId: material.accountId,
          error: error,
        );
      }
      rethrow;
    }
  }

  Future<void> close() async {
    ++_generation;
    state = const VaultBootSnapshot(VaultBootPhase.closed);
    final pending = _transition;
    _transition = null;
    await pending?.catchError((_) {});
    await _closeCurrent();
  }

  Future<void> checkpoint() async {
    final stores = state.phase == VaultBootPhase.ready ? _stores : null;
    await stores?.checkpoint();
  }

  Future<void> _closeCurrent() async {
    final stores = _stores;
    _stores = null;
    if (stores != null) await stores.close();
  }
}

Future<void> _reconcileMediaReferences(VaultOpenedStores stores) async {
  await VaultRetentionService(
    stores.database,
    stores.blobs,
  ).reconcileAndCollect();
}

final vaultBootCoordinatorProvider =
    StateNotifierProvider<VaultBootCoordinator, VaultBootSnapshot>(
      (ref) => VaultBootCoordinator(),
    );
