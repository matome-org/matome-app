import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:path/path.dart' as p;

import 'contracts.dart';
import 'mec1.dart';
import 'native_blob_store_api.dart';

export 'native_blob_store_api.dart';

const _layoutVersion = 1;

final class NativeMediaBlobStore implements MediaBlobStore {
  NativeMediaBlobStore._({
    required this.accountId,
    required this._keyMaterial,
    required this._root,
    required this._faults,
  });

  static Future<NativeMediaBlobStore> open({
    required String applicationSupportRoot,
    required VaultAccountId accountId,
    required VaultKeyMaterial keyMaterial,
    NativeVaultFaultInjector faults = const NoNativeVaultFaults(),
  }) async {
    if (keyMaterial.accountId != accountId) {
      throw ArgumentError('key material belongs to another account namespace');
    }
    if (!p.isAbsolute(applicationSupportRoot)) {
      throw ArgumentError('applicationSupportRoot must be absolute');
    }
    final requestedSupportRoot = p.normalize(
      p.absolute(applicationSupportRoot),
    );
    try {
      final supportRoot = await _validateSupportRoot(
        requestedSupportRoot,
        faults,
      );
      final namespace = sha256.convert(utf8.encode(accountId.value)).toString();
      final root = p.join(supportRoot, 'matome_vault', 'v2', namespace);
      await _prepareRoot(supportRoot, root, faults);
      final store = NativeMediaBlobStore._(
        accountId: accountId,
        keyMaterial: keyMaterial,
        root: root,
        faults: faults,
      );
      await store.reconcile();
      return store;
    } on FileSystemException catch (error, stack) {
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
  }

  @override
  final VaultAccountId accountId;
  final VaultKeyMaterial _keyMaterial;
  final String _root;
  final NativeVaultFaultInjector _faults;
  final Map<VaultBlobId, int> _references = {};
  final Set<VaultBlobId> _pendingDeletes = {};
  final Set<_NativeBlobReadLease> _readLeases = {};
  final Set<_NativePlaintextLease> _plaintextLeases = {};
  Future<void> _mutationTail = Future.value();
  bool _closed = false;

  String get _objects => p.join(_root, 'objects');
  String get _staging => p.join(_root, 'staging');
  String get _metadata => p.join(_root, 'metadata');
  String get _leases => p.join(_root, 'leases');
  String get _quarantine => p.join(_root, 'quarantine');
  String _objectPath(VaultBlobId id) => p.join(_objects, '${id.value}.mec1');
  String _stagePath(VaultBlobId id) => p.join(_staging, '${id.value}.part');
  String _manifestPath(VaultBlobId id, int slot) =>
      p.join(_metadata, '${id.value}.$slot.json');

  static Future<String> _validateSupportRoot(
    String root,
    NativeVaultFaultInjector faults,
  ) async {
    if (await Link(root).exists()) {
      throw ArgumentError('applicationSupportRoot must not be a symlink');
    }
    faults.before(NativeVaultIoOperation.createDirectory, null);
    await Directory(root).create(recursive: true);
    // Pin all subsequent operations to the canonical target. Platform-owned
    // aliases (notably Android's /data/user) cannot redirect the pinned path.
    return p.normalize(await Directory(root).resolveSymbolicLinks());
  }

  static Future<void> _prepareRoot(
    String supportRoot,
    String root,
    NativeVaultFaultInjector faults,
  ) async {
    var current = supportRoot;
    for (final component in p.split(p.relative(root, from: supportRoot))) {
      current = p.join(current, component);
      if (await Link(current).exists()) {
        throw ArgumentError('vault layout must not contain symlinks');
      }
      faults.before(NativeVaultIoOperation.createDirectory, null);
      await Directory(current).create();
    }
    final rootDirectory = Directory(root);
    final resolved = p.normalize(await rootDirectory.resolveSymbolicLinks());
    if (resolved != root) {
      throw ArgumentError('vault root must not be a symlink');
    }
    for (final name in const [
      'objects',
      'staging',
      'metadata',
      'leases',
      'quarantine',
    ]) {
      final path = p.join(root, name);
      if (await Link(path).exists()) {
        throw ArgumentError('vault layout must not contain symlinks');
      }
      faults.before(NativeVaultIoOperation.createDirectory, null);
      await Directory(path).create();
      final childResolved = p.normalize(
        await Directory(path).resolveSymbolicLinks(),
      );
      if (childResolved != path || !p.isWithin(root, childResolved)) {
        throw ArgumentError('vault layout escapes its private root');
      }
    }
  }

  Future<void> _assertSafeLayout() async {
    if (p.normalize(await Directory(_root).resolveSymbolicLinks()) != _root) {
      throw const VaultFailure(
        VaultFailureCode.backendUnavailable,
        'Native vault layout is unsafe.',
      );
    }
    for (final path in [_objects, _staging, _metadata, _leases, _quarantine]) {
      if (await Link(path).exists() ||
          p.normalize(await Directory(path).resolveSymbolicLinks()) != path ||
          !p.isWithin(_root, path)) {
        throw const VaultFailure(
          VaultFailureCode.backendUnavailable,
          'Native vault layout is unsafe.',
        );
      }
    }
  }

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    final previous = _mutationTail;
    final done = Completer<void>();
    _mutationTail = done.future;
    await previous;
    try {
      await _assertSafeLayout();
      return await operation();
    } catch (error, stack) {
      if (error is NativeVaultCrash || error is VaultFailure) rethrow;
      Error.throwWithStackTrace(_vaultError(error), stack);
    } finally {
      done.complete();
    }
  }

  @override
  Future<VaultBlobStat> ingest(MediaInput input) => _mutate(() async {
    final id = _newId();
    var manifest = _Manifest.staging(id);
    var preserveForRecovery = false;
    try {
      manifest = await _writeManifest(manifest);
      final digestSink = _DigestSink();
      final digestInput = sha256.startChunkedConversion(digestSink);
      final sink = _FileCiphertextSink(File(_stagePath(id)), id, _faults);
      late final Mec1EncryptionResult encrypted;
      try {
        encrypted = await _keyMaterial.use(
          (dek) => encryptMec1(
            plaintext: _hashingStream(input.openRead(), digestInput),
            ciphertext: sink,
            accountDek: dek,
          ),
        );
        digestInput.close();
        await sink.flushAndClose();
        _faults.before(NativeVaultIoOperation.stagingDurable, id);
      } catch (_) {
        digestInput.close();
        await sink.abort();
        rethrow;
      }
      final digest = digestSink.value.toString();
      manifest = manifest.copyWith(
        phase: VaultJournalPhase.started,
        plaintextLength: encrypted.plaintextLength,
        physicalLength: encrypted.ciphertextLength,
        plaintextSha256: digest,
        wrappedFek: base64Encode(encrypted.wrappedFek),
        noncePrefix: base64Encode(encrypted.noncePrefix),
      );
      manifest = await _writeManifest(manifest);
      _faults.before(NativeVaultIoOperation.verification, id);
      await _verify(_stagePath(id), manifest);
      _faults.before(NativeVaultIoOperation.verified, id);
      final object = File(_objectPath(id));
      if (await object.exists()) {
        throw StateError('opaque blob identifier collision');
      }
      _faults.before(NativeVaultIoOperation.objectCommit, id);
      await File(_stagePath(id)).rename(object.path);
      preserveForRecovery = true;
      _faults.before(NativeVaultIoOperation.objectCommitted, id);
      manifest = await _writeManifest(
        manifest.copyWith(phase: VaultJournalPhase.objectDurable),
      );
      manifest = await _writeManifest(
        manifest.copyWith(
          state: VaultBlobState.ready,
          phase: VaultJournalPhase.metadataCommitted,
        ),
      );
      return manifest.toStat();
    } catch (error, stack) {
      if (error is NativeVaultCrash) rethrow;
      if (!preserveForRecovery) {
        await _bestEffortDelete(File(_stagePath(id)), id);
        await _removeManifests(id);
      }
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
  });

  Stream<List<int>> _hashingStream(
    Stream<List<int>> source,
    ByteConversionSink digest,
  ) async* {
    await for (final chunk in source) {
      digest.add(chunk);
      yield chunk;
    }
  }

  @override
  Future<VaultBlobStat> stat(VaultBlobId id) async {
    return _guardFilesystem(() async {
      await _assertSafeLayout();
      final manifest = await _readManifest(id);
      return manifest?.toStat() ??
          VaultBlobStat(id: id, state: VaultBlobState.missing);
    });
  }

  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  }) async {
    return _guardFilesystem(() async {
      _requireOpen();
      await _assertSafeLayout();
      final manifest = await _requireReady(id);
      if (range != null && range.endExclusive > manifest.plaintextLength!) {
        throw VaultFailure(
          VaultFailureCode.invalidRange,
          'Range is outside the blob.',
        );
      }
      return _NativeAuthenticatedRead(
        () => _readStream(manifest, range),
        blobId: id,
        range: range,
        plaintextLength: manifest.plaintextLength!,
      );
    });
  }

  Stream<List<int>> _readStream(_Manifest manifest, PlaintextRange? range) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var acquired = false;
    var cancelled = false;
    var released = false;
    void release() {
      if (!acquired || released) return;
      released = true;
      final count = (_references[manifest.id] ?? 1) - 1;
      if (count == 0) {
        _references.remove(manifest.id);
      } else {
        _references[manifest.id] = count;
      }
    }

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        unawaited(
          _mutate(() async {
                if (cancelled) return false;
                _requireOpen();
                await _requireReady(manifest.id);
                _references.update(
                  manifest.id,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
                acquired = true;
                return true;
              })
              .then((shouldRead) {
                if (!shouldRead) return null;
                return _keyMaterial.use((dek) async {
                  final stream = decryptMec1(
                    source: _FileCiphertextSource(
                      File(_objectPath(manifest.id)),
                    ),
                    wrappedFek: base64Decode(manifest.wrappedFek!),
                    noncePrefix: base64Decode(manifest.noncePrefix!),
                    accountDek: dek,
                    range: range,
                  );
                  final complete = Completer<void>();
                  subscription = stream.listen(
                    controller.add,
                    onError: (Object error, StackTrace stack) {
                      controller.addError(_vaultError(error), stack);
                      if (!complete.isCompleted) complete.complete();
                    },
                    onDone: () {
                      if (!complete.isCompleted) complete.complete();
                    },
                    cancelOnError: true,
                  );
                  await complete.future;
                });
              })
              .then((_) => controller.close())
              .catchError((Object error, StackTrace stack) {
                controller.addError(_vaultError(error), stack);
                return controller.close();
              })
              .whenComplete(release),
        );
      },
      onCancel: () async {
        cancelled = true;
        await subscription?.cancel();
        release();
      },
    );
    return controller.stream;
  }

  @override
  Future<VaultBlobReadLease> acquireReadLease(VaultBlobId id) =>
      _mutate(() async {
        _requireOpen();
        await _requireReady(id);
        _references.update(id, (value) => value + 1, ifAbsent: () => 1);
        late final _NativeBlobReadLease lease;
        lease = _NativeBlobReadLease(
          id,
          ({PlaintextRange? range}) => openAuthenticatedRead(id, range: range),
          () {
            _readLeases.remove(lease);
            final count = (_references[id] ?? 1) - 1;
            if (count == 0) {
              _references.remove(id);
            } else {
              _references[id] = count;
            }
          },
        );
        _readLeases.add(lease);
        return lease;
      });

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final reads = _readLeases.toList(growable: false);
    final plaintext = _plaintextLeases.toList(growable: false);
    await Future.wait([
      ...reads.map((lease) => lease.dispose()),
      ...plaintext.map((lease) => lease.dispose()),
    ]);
  }

  void _requireOpen() {
    if (_closed) {
      throw const VaultFailure(VaultFailureCode.locked, 'Vault is locked.');
    }
  }

  @override
  Future<VaultPlaintextLease> createLease(
    VaultBlobId id, {
    required VaultLeasePurpose purpose,
    required Duration ttl,
  }) => _mutate(() async {
    _requireOpen();
    if (ttl <= Duration.zero) {
      throw ArgumentError.value(ttl, 'ttl', 'must be positive');
    }
    final manifest = await _requireReady(id);
    final token = _randomToken(12);
    final path = p.join(_leases, '${id.value}.$token.lease');
    final file = File(path);
    final output = await file.open(mode: FileMode.writeOnly);
    try {
      await _keyMaterial.use((dek) async {
        await for (final chunk in decryptMec1(
          source: _FileCiphertextSource(File(_objectPath(id))),
          wrappedFek: base64Decode(manifest.wrappedFek!),
          noncePrefix: base64Decode(manifest.noncePrefix!),
          accountDek: dek,
        )) {
          _faults.before(NativeVaultIoOperation.stagingWrite, id);
          await output.writeFrom(chunk);
        }
      });
      _faults.before(NativeVaultIoOperation.stagingFlush, id);
      await output.flush();
      await output.close();
    } catch (error, stack) {
      await output.close();
      await _bestEffortDelete(file, id);
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
    _references.update(id, (value) => value + 1, ifAbsent: () => 1);
    late final _NativePlaintextLease lease;
    lease = _NativePlaintextLease(
      () async {
        await _bestEffortDelete(file, id);
        _plaintextLeases.remove(lease);
        final count = (_references[id] ?? 1) - 1;
        if (count == 0) {
          _references.remove(id);
        } else {
          _references[id] = count;
        }
      },
      blobId: id,
      purpose: purpose,
      location: file.uri,
      expiresAt: DateTime.now().toUtc().add(ttl),
    );
    _plaintextLeases.add(lease);
    lease.expiryTimer = Timer(ttl, () => unawaited(lease.dispose()));
    return lease;
  });

  @override
  Future<void> prepareDelete(VaultBlobId id) => _mutate(() async {
    _requireOpen();
    if (_pendingDeletes.contains(id)) return;
    final manifest = await _readManifest(id);
    if (manifest == null || manifest.state == VaultBlobState.missing) return;
    if (manifest.state != VaultBlobState.ready || (_references[id] ?? 0) > 0) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob has an active authenticated reader or plaintext lease.',
      );
    }
    _pendingDeletes.add(id);
  });

  @override
  Future<void> delete(VaultBlobId id) => _mutate(() async {
    if ((_references[id] ?? 0) > 0) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob has an active authenticated reader or plaintext lease.',
      );
    }
    var manifest = await _readManifest(id);
    if (manifest == null) {
      _pendingDeletes.remove(id);
      return;
    }
    if (manifest.state != VaultBlobState.deleting) {
      _faults.before(NativeVaultIoOperation.tombstone, id);
      manifest = await _writeManifest(
        manifest.copyWith(
          state: VaultBlobState.deleting,
          operation: VaultJournalOperation.delete,
          phase: VaultJournalPhase.cleanupPending,
        ),
      );
      _faults.before(NativeVaultIoOperation.tombstoned, id);
    }
    _faults.before(NativeVaultIoOperation.unlink, id);
    await _deleteIfExists(File(_objectPath(id)));
    await _deleteIfExists(File(_stagePath(id)));
    _faults.before(NativeVaultIoOperation.unlinked, id);
    await _removeManifests(id, newestGeneration: manifest.generation);
    _pendingDeletes.remove(id);
  });

  @override
  Future<List<VaultJournalEntry>> journal() async {
    return _guardFilesystem(() async {
      await _assertSafeLayout();
      final entries = <VaultJournalEntry>[];
      for (final manifest in await _allManifests()) {
        if (manifest.state == VaultBlobState.staging ||
            manifest.state == VaultBlobState.deleting) {
          entries.add(manifest.toJournal());
        }
      }
      entries.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      return entries;
    });
  }

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => _guardFilesystem(() async {
    await _assertSafeLayout();
    return (await _allManifests())
        .where((manifest) => manifest.state == VaultBlobState.ready)
        .map((manifest) => manifest.id)
        .toSet();
  });

  @override
  Future<VaultReconciliationReport> reconcile() => _mutate(() async {
    final records = <VaultReconciliationRecord>[];
    for (final entity in await Directory(_leases).list().toList()) {
      if (entity is Link) {
        await entity.delete();
        continue;
      }
      if (entity is File) {
        await _deleteIfExists(entity);
        final id = _idFromFilename(p.basename(entity.path));
        if (id != null) {
          records.add(
            VaultReconciliationRecord(
              blobId: id,
              issue: VaultReconciliationIssue.expiredLease,
              action: VaultReconciliationAction.revokedLease,
            ),
          );
        }
      }
    }

    final manifests = await _allManifests();
    final known = manifests.map((m) => m.id).toSet();
    for (final manifest in manifests) {
      final object = File(_objectPath(manifest.id));
      final stage = File(_stagePath(manifest.id));
      if (manifest.state == VaultBlobState.deleting) {
        await _deleteIfExists(object);
        await _deleteIfExists(stage);
        await _removeManifests(
          manifest.id,
          newestGeneration: manifest.generation,
        );
        records.add(
          VaultReconciliationRecord(
            blobId: manifest.id,
            issue: VaultReconciliationIssue.interruptedDelete,
            action: VaultReconciliationAction.completedDelete,
          ),
        );
        continue;
      }
      if (manifest.state == VaultBlobState.staging) {
        if (await object.exists() && manifest.hasObjectMetadata) {
          try {
            await _verify(object.path, manifest);
            await _writeManifest(
              manifest.copyWith(
                state: VaultBlobState.ready,
                phase: VaultJournalPhase.metadataCommitted,
              ),
            );
          } catch (error) {
            if (!_isQuarantinable(error)) rethrow;
            await _quarantineFile(object, manifest.id);
            await _writeManifest(
              manifest.copyWith(state: VaultBlobState.missing),
            );
            records.add(
              VaultReconciliationRecord(
                blobId: manifest.id,
                issue: VaultReconciliationIssue.sizeMismatch,
                action: VaultReconciliationAction.quarantinedObject,
              ),
            );
          }
        } else {
          await _deleteIfExists(object);
          await _deleteIfExists(stage);
          await _removeManifests(manifest.id);
          records.add(
            VaultReconciliationRecord(
              blobId: manifest.id,
              issue: VaultReconciliationIssue.orphanedStaging,
              action: VaultReconciliationAction.removedStaging,
            ),
          );
        }
        continue;
      }
      if (manifest.state == VaultBlobState.ready) {
        if (!await object.exists()) {
          await _writeManifest(
            manifest.copyWith(state: VaultBlobState.missing),
          );
          records.add(
            VaultReconciliationRecord(
              blobId: manifest.id,
              issue: VaultReconciliationIssue.missingObject,
              action: VaultReconciliationAction.markedMissing,
            ),
          );
          continue;
        }
        try {
          await _verify(object.path, manifest);
        } catch (error) {
          if (!_isQuarantinable(error)) rethrow;
          await _quarantineFile(object, manifest.id);
          await _writeManifest(
            manifest.copyWith(state: VaultBlobState.missing),
          );
          records.add(
            VaultReconciliationRecord(
              blobId: manifest.id,
              issue: VaultReconciliationIssue.sizeMismatch,
              action: VaultReconciliationAction.quarantinedObject,
            ),
          );
        }
      }
      if (manifest.state == VaultBlobState.missing && await object.exists()) {
        await _quarantineUnknown(object, manifest.id);
        records.add(
          VaultReconciliationRecord(
            blobId: manifest.id,
            issue: VaultReconciliationIssue.unreferencedReadyObject,
            action: VaultReconciliationAction.preservedUnreferencedObject,
          ),
        );
      }
    }

    await for (final entity in Directory(_metadata).list()) {
      if (entity is Link) {
        await entity.delete();
      } else if (entity is File && entity.path.endsWith('.tmp')) {
        await _deleteIfExists(entity);
      }
    }

    for (final entity in await Directory(_staging).list().toList()) {
      if (entity is Link) {
        await entity.delete();
        continue;
      }
      if (entity is! File) continue;
      final id = _idFromFilename(p.basename(entity.path));
      if (id == null || !known.contains(id)) {
        await _deleteIfExists(entity);
        if (id == null) continue;
        records.add(
          VaultReconciliationRecord(
            blobId: id,
            issue: VaultReconciliationIssue.orphanedStaging,
            action: VaultReconciliationAction.removedStaging,
          ),
        );
      }
    }
    for (final entity in await Directory(_objects).list().toList()) {
      if (entity is Link) {
        await entity.delete();
        continue;
      }
      if (entity is! File) continue;
      final id = _idFromFilename(p.basename(entity.path));
      if (id == null || !known.contains(id)) {
        await _quarantineUnknown(entity, id);
        if (id == null) continue;
        records.add(
          VaultReconciliationRecord(
            blobId: id,
            issue: VaultReconciliationIssue.unreferencedReadyObject,
            action: VaultReconciliationAction.preservedUnreferencedObject,
          ),
        );
      }
    }
    return VaultReconciliationReport(records);
  });

  Future<_Manifest> _requireReady(VaultBlobId id) async {
    if (_pendingDeletes.contains(id)) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob is pending deletion.',
      );
    }
    final manifest = await _readManifest(id);
    if (manifest == null || manifest.state == VaultBlobState.missing) {
      throw const VaultFailure(
        VaultFailureCode.blobMissing,
        'Blob is missing.',
      );
    }
    if (manifest.state != VaultBlobState.ready) {
      throw const VaultFailure(
        VaultFailureCode.blobNotReady,
        'Blob is not ready.',
      );
    }
    return manifest;
  }

  Future<void> _verify(String path, _Manifest manifest) async {
    if (await Link(path).exists()) {
      throw const VaultFailure(
        VaultFailureCode.backendUnavailable,
        'Native vault object is unsafe.',
      );
    }
    final file = File(path);
    if (!await file.exists() ||
        await file.length() != manifest.physicalLength) {
      throw const VaultFailure(
        VaultFailureCode.corruptCiphertext,
        'Ciphertext size mismatch.',
      );
    }
    final digestSink = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestSink);
    var length = 0;
    await _keyMaterial.use((dek) async {
      await for (final chunk in decryptMec1(
        source: _FileCiphertextSource(file),
        wrappedFek: base64Decode(manifest.wrappedFek!),
        noncePrefix: base64Decode(manifest.noncePrefix!),
        accountDek: dek,
      )) {
        length += chunk.length;
        digestInput.add(chunk);
      }
    });
    digestInput.close();
    if (length != manifest.plaintextLength ||
        digestSink.value.toString() != manifest.plaintextSha256) {
      throw const VaultFailure(
        VaultFailureCode.corruptCiphertext,
        'Plaintext verification failed.',
      );
    }
  }

  Future<_Manifest> _writeManifest(_Manifest manifest) async {
    final next = manifest.copyWith(
      generation: manifest.generation + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    final slot = next.generation & 1;
    final target = File(_manifestPath(next.id, slot));
    final temp = File('${target.path}.${_randomToken(6)}.tmp');
    final bytes = utf8.encode(jsonEncode(next.toJson()));
    RandomAccessFile? output;
    try {
      _faults.before(NativeVaultIoOperation.journalWrite, next.id);
      output = await temp.open(mode: FileMode.writeOnly);
      await output.writeFrom(bytes);
      _faults.before(NativeVaultIoOperation.journalFlush, next.id);
      await output.flush();
      await output.close();
      output = null;
      if (await target.exists()) await target.delete();
      _faults.before(NativeVaultIoOperation.journalCommit, next.id);
      await temp.rename(target.path);
      _faults.before(NativeVaultIoOperation.journalCommitted, next.id);
      return next;
    } finally {
      await output?.close();
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<_Manifest?> _readManifest(VaultBlobId id) async {
    final candidates = <_Manifest>[];
    Object? invalid;
    for (var slot = 0; slot < 2; slot++) {
      final file = File(_manifestPath(id, slot));
      if (await Link(file.path).exists()) {
        throw const VaultFailure(
          VaultFailureCode.backendUnavailable,
          'Native vault metadata is unsafe.',
        );
      }
      if (!await file.exists()) continue;
      final contents = await file.readAsString();
      try {
        final candidate = _Manifest.fromJson(
          jsonDecode(contents) as Map<String, Object?>,
        );
        if (candidate.id != id) throw const FormatException('blob id mismatch');
        candidates.add(candidate);
      } catch (error) {
        invalid = error;
      }
    }
    if (invalid != null) {
      throw VaultFailure(
        VaultFailureCode.corruptCiphertext,
        'Blob metadata is corrupt.',
      );
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.generation.compareTo(a.generation));
    return candidates.first;
  }

  Future<List<_Manifest>> _allManifests() async {
    final ids = <VaultBlobId>{};
    await for (final entity in Directory(_metadata).list()) {
      if (entity is! File) continue;
      final id = _idFromFilename(p.basename(entity.path));
      if (id != null) ids.add(id);
    }
    final manifests = <_Manifest>[];
    for (final id in ids) {
      final manifest = await _readManifest(id);
      if (manifest != null) manifests.add(manifest);
    }
    return manifests;
  }

  VaultBlobId? _idFromFilename(String filename) {
    final value = filename.split('.').first;
    try {
      return VaultBlobId(value);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _removeManifests(VaultBlobId id, {int? newestGeneration}) async {
    final newestSlot = newestGeneration == null ? null : newestGeneration & 1;
    final slots = newestSlot == null
        ? const [0, 1]
        : [newestSlot ^ 1, newestSlot];
    for (final slot in slots) {
      _faults.before(NativeVaultIoOperation.journalCleanup, id);
      await _deleteIfExists(File(_manifestPath(id, slot)));
    }
  }

  Future<void> _quarantineFile(File file, VaultBlobId id) async {
    if (!await file.exists()) return;
    final target = p.join(_quarantine, '${id.value}-${_randomToken(6)}.mec1');
    await file.rename(target);
  }

  Future<void> _quarantineUnknown(File file, VaultBlobId? id) async {
    final name = id?.value ?? _randomToken(24);
    await file.rename(p.join(_quarantine, '$name-${_randomToken(6)}.orphan'));
  }

  Future<void> _bestEffortDelete(File file, VaultBlobId id) async {
    try {
      if (await file.exists()) {
        _faults.before(NativeVaultIoOperation.unlink, id);
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _deleteIfExists(File file) async {
    if (await Link(file.path).exists() || await file.exists()) {
      await file.delete();
    }
  }

  Future<T> _guardFilesystem<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FileSystemException catch (error, stack) {
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
  }
}

final class _FileCiphertextSink implements Mec1CiphertextSink {
  _FileCiphertextSink(this.file, this.id, this.faults);
  final File file;
  final VaultBlobId id;
  final NativeVaultFaultInjector faults;
  RandomAccessFile? _output;

  @override
  Future<void> write(List<int> bytes) async {
    faults.before(NativeVaultIoOperation.stagingWrite, id);
    _output ??= await file.open(mode: FileMode.writeOnly);
    await _output!.writeFrom(bytes);
  }

  Future<void> flushAndClose() async {
    _output ??= await file.open(mode: FileMode.writeOnly);
    faults.before(NativeVaultIoOperation.stagingFlush, id);
    await _output!.flush();
    await _output!.close();
    _output = null;
  }

  Future<void> abort() async {
    await _output?.close();
    _output = null;
  }
}

final class _FileCiphertextSource implements Mec1CiphertextSource {
  const _FileCiphertextSource(this.file);
  final File file;

  @override
  Future<int> length() => file.length();

  @override
  Stream<List<int>> openRead({int start = 0, int? endExclusive}) =>
      file.openRead(start, endExclusive);
}

final class _NativeAuthenticatedRead implements AuthenticatedPlaintextRead {
  const _NativeAuthenticatedRead(
    this._streamFactory, {
    required this.blobId,
    required this.range,
    required this.plaintextLength,
  });

  @override
  final VaultBlobId blobId;
  @override
  final PlaintextRange? range;
  @override
  final int plaintextLength;
  final Stream<List<int>> Function() _streamFactory;

  @override
  Stream<List<int>> get bytes => _streamFactory();
}

final class _NativePlaintextLease implements VaultPlaintextLease {
  _NativePlaintextLease(
    this._disposeCallback, {
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
  Future<void> Function()? _disposeCallback;
  Timer? expiryTimer;

  @override
  Future<void> dispose() async {
    final callback = _disposeCallback;
    _disposeCallback = null;
    expiryTimer?.cancel();
    expiryTimer = null;
    await callback?.call();
  }
}

final class _NativeBlobReadLease implements VaultBlobReadLease {
  _NativeBlobReadLease(this.blobId, this._open, this._release);

  @override
  final VaultBlobId blobId;
  final Future<AuthenticatedPlaintextRead> Function({PlaintextRange? range})
  _open;
  void Function()? _release;
  final Set<StreamSubscription<List<int>>> _subscriptions = {};
  final Set<StreamController<List<int>>> _controllers = {};

  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead({
    PlaintextRange? range,
  }) async {
    if (_release == null) {
      throw const VaultFailure(
        VaultFailureCode.locked,
        'Read lease was revoked.',
      );
    }
    final read = await _open(range: range);
    if (_release == null) {
      throw const VaultFailure(
        VaultFailureCode.locked,
        'Read lease was revoked.',
      );
    }
    return _NativeAuthenticatedRead(
      () => _guard(read.bytes),
      blobId: read.blobId,
      range: read.range,
      plaintextLength: read.plaintextLength,
    );
  }

  Stream<List<int>> _guard(Stream<List<int>> source) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (_release == null) {
          controller.addError(
            const VaultFailure(
              VaultFailureCode.locked,
              'Read lease was revoked.',
            ),
          );
          unawaited(controller.close());
          return;
        }
        _controllers.add(controller);
        late final StreamSubscription<List<int>> active;
        active = source.listen(
          controller.add,
          onError: (Object error, StackTrace stack) {
            _subscriptions.remove(active);
            _controllers.remove(controller);
            controller.addError(error, stack);
            unawaited(controller.close());
          },
          onDone: () {
            _subscriptions.remove(active);
            _controllers.remove(controller);
            unawaited(controller.close());
          },
          cancelOnError: true,
        );
        subscription = active;
        _subscriptions.add(active);
      },
      onCancel: () async {
        final active = subscription;
        if (active != null) {
          _subscriptions.remove(active);
          await active.cancel();
        }
        _controllers.remove(controller);
      },
    );
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    final release = _release;
    if (release == null) return;
    _release = null;
    final subscriptions = _subscriptions.toList(growable: false);
    final controllers = _controllers.toList(growable: false);
    _subscriptions.clear();
    _controllers.clear();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    for (final controller in controllers) {
      controller.addError(
        const VaultFailure(VaultFailureCode.locked, 'Read lease was revoked.'),
      );
      unawaited(controller.close());
    }
    release();
  }
}

final class _Manifest {
  const _Manifest({
    required this.id,
    required this.generation,
    required this.state,
    required this.operation,
    required this.phase,
    required this.updatedAt,
    this.plaintextLength,
    this.physicalLength,
    this.plaintextSha256,
    this.wrappedFek,
    this.noncePrefix,
  });

  factory _Manifest.staging(VaultBlobId id) => _Manifest(
    id: id,
    generation: 0,
    state: VaultBlobState.staging,
    operation: VaultJournalOperation.ingest,
    phase: VaultJournalPhase.started,
    updatedAt: DateTime.now().toUtc(),
  );

  factory _Manifest.fromJson(Map<String, Object?> json) {
    if (json['layoutVersion'] != _layoutVersion) {
      throw const FormatException('layout version');
    }
    return _Manifest(
      id: VaultBlobId(json['blobId']! as String),
      generation: json['generation']! as int,
      state: VaultBlobState.values.byName(json['state']! as String),
      operation: VaultJournalOperation.values.byName(
        json['operation']! as String,
      ),
      phase: VaultJournalPhase.values.byName(json['phase']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
      plaintextLength: json['plaintextLength'] as int?,
      physicalLength: json['physicalLength'] as int?,
      plaintextSha256: json['plaintextSha256'] as String?,
      wrappedFek: json['wrappedFek'] as String?,
      noncePrefix: json['noncePrefix'] as String?,
    );
  }

  final VaultBlobId id;
  final int generation;
  final VaultBlobState state;
  final VaultJournalOperation operation;
  final VaultJournalPhase phase;
  final DateTime updatedAt;
  final int? plaintextLength;
  final int? physicalLength;
  final String? plaintextSha256;
  final String? wrappedFek;
  final String? noncePrefix;

  bool get hasObjectMetadata =>
      plaintextLength != null &&
      physicalLength != null &&
      plaintextSha256 != null &&
      wrappedFek != null &&
      noncePrefix != null;

  _Manifest copyWith({
    int? generation,
    VaultBlobState? state,
    VaultJournalOperation? operation,
    VaultJournalPhase? phase,
    DateTime? updatedAt,
    int? plaintextLength,
    int? physicalLength,
    String? plaintextSha256,
    String? wrappedFek,
    String? noncePrefix,
  }) => _Manifest(
    id: id,
    generation: generation ?? this.generation,
    state: state ?? this.state,
    operation: operation ?? this.operation,
    phase: phase ?? this.phase,
    updatedAt: updatedAt ?? this.updatedAt,
    plaintextLength: plaintextLength ?? this.plaintextLength,
    physicalLength: physicalLength ?? this.physicalLength,
    plaintextSha256: plaintextSha256 ?? this.plaintextSha256,
    wrappedFek: wrappedFek ?? this.wrappedFek,
    noncePrefix: noncePrefix ?? this.noncePrefix,
  );

  Map<String, Object?> toJson() => {
    'layoutVersion': _layoutVersion,
    'blobId': id.value,
    'generation': generation,
    'state': state.name,
    'operation': operation.name,
    'phase': phase.name,
    'updatedAt': updatedAt.toIso8601String(),
    'plaintextLength': plaintextLength,
    'physicalLength': physicalLength,
    'plaintextSha256': plaintextSha256,
    'wrappedFek': wrappedFek,
    'noncePrefix': noncePrefix,
  };

  VaultBlobStat toStat() => VaultBlobStat(
    id: id,
    state: state,
    plaintextLength: state == VaultBlobState.ready ? plaintextLength : null,
    physicalLength: state == VaultBlobState.ready ? physicalLength : null,
    plaintextSha256: state == VaultBlobState.ready ? plaintextSha256 : null,
  );

  VaultJournalEntry toJournal() => VaultJournalEntry(
    blobId: id,
    operation: operation,
    phase: phase,
    updatedAt: updatedAt,
  );
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('digest is not complete'));

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

VaultBlobId _newId() => VaultBlobId(_randomToken(24));

String _randomToken(int length) {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(length, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

VaultFailure _vaultError(Object error) {
  if (error is VaultFailure) return error;
  if (error is Mec1AuthenticationException && error.chunkIndex == null) {
    return const VaultFailure(
      VaultFailureCode.wrongKey,
      'Account key could not unwrap this blob.',
    );
  }
  if (error is Mec1AuthenticationException || error is Mec1FormatException) {
    return VaultFailure(
      VaultFailureCode.corruptCiphertext,
      'Ciphertext authentication failed.',
      cause: error,
    );
  }
  if (error is Mec1UnsupportedVersionException) {
    return VaultFailure(
      VaultFailureCode.unsupportedFormat,
      'Ciphertext format is unsupported.',
      cause: error,
    );
  }
  if (error is Mec1RangeException || error is RangeError) {
    return VaultFailure(
      VaultFailureCode.invalidRange,
      'Plaintext range is invalid.',
      cause: error,
    );
  }
  return VaultFailure(
    VaultFailureCode.backendUnavailable,
    'Native vault operation failed.',
  );
}

bool _isQuarantinable(Object error) =>
    error is FormatException ||
    error is Mec1FormatException ||
    error is Mec1UnsupportedVersionException ||
    (error is Mec1AuthenticationException && error.chunkIndex != null) ||
    (error is VaultFailure && error.code == VaultFailureCode.corruptCiphertext);
