import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:web/web.dart'
    show
        Blob,
        DOMException,
        File,
        FileSystemDirectoryHandle,
        FileSystemGetDirectoryOptions,
        FileSystemGetFileOptions,
        FileSystemWritableFileStream,
        Navigator,
        ReadableStreamDefaultReader,
        URL;

import 'contracts.dart';
import 'mec1.dart';
import 'web_blob_store_api.dart';

export 'web_blob_store_api.dart';

const _layoutVersion = 1;

@JS('navigator')
external Navigator get _navigator;

extension type _DirectoryIterator(JSObject _) implements JSObject {
  external JSPromise<_IteratorResult> next();
}

extension type _IteratorResult(JSObject _) implements JSObject {
  external bool get done;
  external JSArray<JSAny?> get value;
}

extension type _IterableDirectory(FileSystemDirectoryHandle _)
    implements JSObject {
  external _DirectoryIterator entries();
}

Future<WebVaultCapabilityReport> probeWebMediaBlobStore() async {
  try {
    await _navigator.storage.getDirectory().toDart;
    return const WebVaultCapabilityReport(WebVaultCapability.available);
  } catch (error) {
    return WebVaultCapabilityReport(
      WebVaultCapability.opfsUnavailable,
      reason: _safeDomReason(error),
    );
  }
}

/// Account-scoped OPFS store. Handles never cross this API boundary.
final class WebMediaBlobStore implements MediaBlobStore {
  WebMediaBlobStore._({
    required this.accountId,
    required this._keyMaterial,
    required this._root,
    required this._faults,
  });

  static Future<WebMediaBlobStore> open({
    required VaultAccountId accountId,
    required VaultKeyMaterial keyMaterial,
    WebVaultFaultInjector faults = const NoWebVaultFaults(),
  }) async {
    if (keyMaterial.accountId != accountId) {
      throw ArgumentError('key material belongs to another account namespace');
    }
    try {
      final opfs = await _navigator.storage.getDirectory().toDart;
      final packageRoot = await _directory(opfs, 'matome_media_v1');
      final namespace = sha256.convert(utf8.encode(accountId.value)).toString();
      final root = await _directory(packageRoot, namespace);
      for (final name in const ['current', 'next', 'manifest', 'quarantine']) {
        await _directory(root, name);
      }
      final store = WebMediaBlobStore._(
        accountId: accountId,
        keyMaterial: keyMaterial,
        root: root,
        faults: faults,
      );
      await store.reconcile();
      return store;
    } catch (error, stack) {
      if (error is VaultFailure || error is WebVaultCrash) rethrow;
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
  }

  @override
  final VaultAccountId accountId;
  final VaultKeyMaterial _keyMaterial;
  final FileSystemDirectoryHandle _root;
  final WebVaultFaultInjector _faults;
  final Map<VaultBlobId, int> _references = {};
  final Set<VaultBlobId> _pendingDeletes = {};
  final Set<_WebBlobReadLease> _readLeases = {};
  final Set<_WebPlaintextLease> _plaintextLeases = {};
  Future<void> _mutationTail = Future.value();
  bool _closed = false;

  Future<FileSystemDirectoryHandle> get _current =>
      _existingDirectory(_root, 'current');
  Future<FileSystemDirectoryHandle> get _next =>
      _existingDirectory(_root, 'next');
  Future<FileSystemDirectoryHandle> get _manifests =>
      _existingDirectory(_root, 'manifest');
  Future<FileSystemDirectoryHandle> get _quarantine =>
      _existingDirectory(_root, 'quarantine');

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    final previous = _mutationTail;
    final done = Completer<void>();
    _mutationTail = done.future;
    await previous;
    try {
      return await operation();
    } catch (error, stack) {
      if (error is VaultFailure || error is WebVaultCrash) rethrow;
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
    final next = await _next;
    try {
      manifest = await _writeManifest(manifest);
      final digestSink = _DigestSink();
      final digestInput = sha256.startChunkedConversion(digestSink);
      final sink = await _OpfsCiphertextSink.open(next, id.value, id, _faults);
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
        await sink.close();
        _faults.before(WebVaultIoOperation.stagingCommitted, id);
      } catch (_) {
        digestInput.close();
        await sink.abort();
        rethrow;
      }
      manifest = await _writeManifest(
        manifest.copyWith(
          plaintextLength: encrypted.plaintextLength,
          physicalLength: encrypted.ciphertextLength,
          plaintextSha256: digestSink.value.toString(),
          wrappedFek: base64Encode(encrypted.wrappedFek),
          noncePrefix: base64Encode(encrypted.noncePrefix),
        ),
      );
      _faults.before(WebVaultIoOperation.verification, id);
      await _verify(next, manifest);
      _faults.before(WebVaultIoOperation.verified, id);

      _faults.before(WebVaultIoOperation.objectWrite, id);
      await _copyFile(next, id.value, await _current, id.value);
      preserveForRecovery = true;
      _faults.before(WebVaultIoOperation.objectCommitted, id);
      manifest = await _writeManifest(
        manifest.copyWith(phase: VaultJournalPhase.objectDurable),
      );
      manifest = await _writeManifest(
        manifest.copyWith(
          state: VaultBlobState.ready,
          phase: VaultJournalPhase.metadataCommitted,
        ),
      );
      await _remove(next, id.value);
      return manifest.toStat();
    } catch (error, stack) {
      if (error is WebVaultCrash) rethrow;
      if (!preserveForRecovery) {
        await _bestEffortRemove(next, id.value);
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
    try {
      final manifest = await _readManifest(id);
      return manifest?.toStat() ??
          VaultBlobStat(id: id, state: VaultBlobState.missing);
    } catch (error, stack) {
      if (error is VaultFailure) rethrow;
      Error.throwWithStackTrace(_vaultError(error), stack);
    }
  }

  @override
  Future<AuthenticatedPlaintextRead> openAuthenticatedRead(
    VaultBlobId id, {
    PlaintextRange? range,
  }) async {
    _requireOpen();
    final manifest = await _requireReady(id);
    if (range != null && range.endExclusive > manifest.plaintextLength!) {
      throw const VaultFailure(
        VaultFailureCode.invalidRange,
        'Range is outside the blob.',
      );
    }
    return _WebAuthenticatedRead(
      () => _readStream(manifest, range),
      blobId: id,
      range: range,
      plaintextLength: manifest.plaintextLength!,
    );
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
              .then((read) async {
                if (!read) return;
                await _keyMaterial.use((dek) async {
                  final source = await _OpfsCiphertextSource.open(
                    await _current,
                    manifest.id.value,
                  );
                  final complete = Completer<void>();
                  subscription =
                      decryptMec1(
                        source: source,
                        wrappedFek: base64Decode(manifest.wrappedFek!),
                        noncePrefix: base64Decode(manifest.noncePrefix!),
                        accountDek: dek,
                        range: range,
                      ).listen(
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
        late final _WebBlobReadLease lease;
        lease = _WebBlobReadLease(
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
    final output = BytesBuilder(copy: false);
    await _keyMaterial.use((dek) async {
      final source = await _OpfsCiphertextSource.open(await _current, id.value);
      await for (final chunk in decryptMec1(
        source: source,
        wrappedFek: base64Decode(manifest.wrappedFek!),
        noncePrefix: base64Decode(manifest.noncePrefix!),
        accountDek: dek,
      )) {
        output.add(chunk);
      }
    });
    final blob = Blob(<JSAny>[output.takeBytes().toJS].toJS);
    final location = Uri.parse(URL.createObjectURL(blob));
    _references.update(id, (value) => value + 1, ifAbsent: () => 1);
    late final _WebPlaintextLease lease;
    lease = _WebPlaintextLease(
      () {
        URL.revokeObjectURL(location.toString());
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
      location: location,
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
      _faults.before(WebVaultIoOperation.tombstone, id);
      manifest = await _writeManifest(
        manifest.copyWith(
          state: VaultBlobState.deleting,
          operation: VaultJournalOperation.delete,
          phase: VaultJournalPhase.cleanupPending,
        ),
      );
      _faults.before(WebVaultIoOperation.tombstoned, id);
    }
    _faults.before(WebVaultIoOperation.remove, id);
    await _remove(await _current, id.value);
    await _remove(await _next, id.value);
    _faults.before(WebVaultIoOperation.removed, id);
    await _removeManifests(id, newestGeneration: manifest.generation);
    _pendingDeletes.remove(id);
  });

  @override
  Future<List<VaultJournalEntry>> journal() async {
    final entries = <VaultJournalEntry>[];
    for (final manifest in await _allManifests()) {
      if (manifest.state == VaultBlobState.staging ||
          manifest.state == VaultBlobState.deleting) {
        entries.add(manifest.toJournal());
      }
    }
    entries.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return entries;
  }

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => (await _allManifests())
      .where((manifest) => manifest.state == VaultBlobState.ready)
      .map((manifest) => manifest.id)
      .toSet();

  @override
  Future<VaultReconciliationReport> reconcile() => _mutate(() async {
    final records = <VaultReconciliationRecord>[];
    final manifests = await _allManifests();
    final known = manifests.map((manifest) => manifest.id.value).toSet();
    final current = await _current;
    final next = await _next;
    for (final manifest in manifests) {
      if (manifest.state == VaultBlobState.deleting) {
        await _remove(current, manifest.id.value);
        await _remove(next, manifest.id.value);
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
        if (await _exists(current, manifest.id.value) &&
            manifest.hasObjectMetadata) {
          try {
            await _verify(current, manifest);
            await _writeManifest(
              manifest.copyWith(
                state: VaultBlobState.ready,
                phase: VaultJournalPhase.metadataCommitted,
              ),
            );
          } catch (error) {
            if (!_isQuarantinable(error)) rethrow;
            await _quarantineFile(current, manifest.id.value);
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
          await _remove(current, manifest.id.value);
          await _remove(next, manifest.id.value);
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
        if (!await _exists(current, manifest.id.value)) {
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
          await _verify(current, manifest);
        } catch (error) {
          if (!_isQuarantinable(error)) rethrow;
          await _quarantineFile(current, manifest.id.value);
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
      if (manifest.state == VaultBlobState.missing &&
          await _exists(current, manifest.id.value)) {
        await _quarantineFile(current, manifest.id.value);
        records.add(
          VaultReconciliationRecord(
            blobId: manifest.id,
            issue: VaultReconciliationIssue.unreferencedReadyObject,
            action: VaultReconciliationAction.preservedUnreferencedObject,
          ),
        );
      }
      await _remove(next, manifest.id.value);
    }

    for (final name in await _entryNames(next)) {
      if (known.contains(name)) continue;
      await _remove(next, name);
      final id = _tryId(name);
      if (id != null) {
        records.add(
          VaultReconciliationRecord(
            blobId: id,
            issue: VaultReconciliationIssue.orphanedStaging,
            action: VaultReconciliationAction.removedStaging,
          ),
        );
      }
    }
    for (final name in await _entryNames(current)) {
      if (known.contains(name)) continue;
      final id = _tryId(name);
      await _quarantineFile(current, name);
      if (id != null) {
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

  Future<void> _verify(
    FileSystemDirectoryHandle directory,
    _Manifest manifest,
  ) async {
    final source = await _OpfsCiphertextSource.open(
      directory,
      manifest.id.value,
    );
    if (await source.length() != manifest.physicalLength) {
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
        source: source,
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
    _faults.before(WebVaultIoOperation.manifestWrite, next.id);
    await _writeBytes(
      await _manifests,
      '${next.id.value}.${next.generation & 1}',
      utf8.encode(jsonEncode(next.toJson())),
    );
    _faults.before(WebVaultIoOperation.manifestCommitted, next.id);
    return next;
  }

  Future<_Manifest?> _readManifest(VaultBlobId id) async {
    final candidates = <_Manifest>[];
    Object? invalid;
    for (var slot = 0; slot < 2; slot++) {
      final bytes = await _readBytes(await _manifests, '${id.value}.$slot');
      if (bytes == null) continue;
      try {
        final candidate = _Manifest.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
        );
        if (candidate.id != id) throw const FormatException('blob id mismatch');
        candidates.add(candidate);
      } catch (error) {
        invalid = error;
      }
    }
    if (invalid != null) {
      throw const VaultFailure(
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
    for (final name in await _entryNames(await _manifests)) {
      final id = _tryId(name.split('.').first);
      if (id != null) ids.add(id);
    }
    final manifests = <_Manifest>[];
    for (final id in ids) {
      final manifest = await _readManifest(id);
      if (manifest != null) manifests.add(manifest);
    }
    return manifests;
  }

  Future<void> _removeManifests(VaultBlobId id, {int? newestGeneration}) async {
    final newestSlot = newestGeneration == null ? null : newestGeneration & 1;
    final slots = newestSlot == null
        ? const [0, 1]
        : [newestSlot ^ 1, newestSlot];
    for (final slot in slots) {
      await _remove(await _manifests, '${id.value}.$slot');
    }
  }

  Future<void> _quarantineFile(
    FileSystemDirectoryHandle source,
    String name,
  ) async {
    if (!await _exists(source, name)) return;
    final opaque = '${_randomToken(24)}.${_randomToken(6)}';
    await _copyFile(source, name, await _quarantine, opaque);
    await _remove(source, name);
  }
}

final class _OpfsCiphertextSink implements Mec1CiphertextSink {
  _OpfsCiphertextSink._(this._stream, this._id, this._faults);

  static Future<_OpfsCiphertextSink> open(
    FileSystemDirectoryHandle directory,
    String name,
    VaultBlobId id,
    WebVaultFaultInjector faults,
  ) async {
    final handle = await directory
        .getFileHandle(name, FileSystemGetFileOptions(create: true))
        .toDart;
    return _OpfsCiphertextSink._(
      await handle.createWritable().toDart,
      id,
      faults,
    );
  }

  FileSystemWritableFileStream? _stream;
  final VaultBlobId _id;
  final WebVaultFaultInjector _faults;

  @override
  Future<void> write(List<int> bytes) async {
    _faults.before(WebVaultIoOperation.stagingWrite, _id);
    await _stream!.write(Uint8List.fromList(bytes).toJS).toDart;
  }

  Future<void> close() async {
    final stream = _stream;
    _stream = null;
    await stream?.close().toDart;
  }

  Future<void> abort() async {
    final stream = _stream;
    _stream = null;
    try {
      await stream?.abort().toDart;
    } catch (_) {}
  }
}

final class _OpfsCiphertextSource implements Mec1CiphertextSource {
  const _OpfsCiphertextSource(this._file);

  static Future<_OpfsCiphertextSource> open(
    FileSystemDirectoryHandle directory,
    String name,
  ) async {
    final handle = await directory.getFileHandle(name).toDart;
    return _OpfsCiphertextSource(await handle.getFile().toDart);
  }

  final File _file;

  @override
  Future<int> length() async => _file.size;

  @override
  Stream<List<int>> openRead({int start = 0, int? endExclusive}) async* {
    final slice = _file.slice(start, endExclusive ?? _file.size);
    final reader = ReadableStreamDefaultReader(slice.stream());
    var completed = false;
    try {
      while (true) {
        final result = await reader.read().toDart;
        if (result.done) {
          completed = true;
          break;
        }
        final value = result.value;
        if (value == null) {
          throw const FormatException('OPFS stream returned an empty chunk');
        }
        yield (value as JSUint8Array).toDart;
      }
    } finally {
      if (!completed) await reader.cancel().toDart;
      reader.releaseLock();
    }
  }
}

final class _WebAuthenticatedRead implements AuthenticatedPlaintextRead {
  const _WebAuthenticatedRead(
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

final class _WebPlaintextLease implements VaultPlaintextLease {
  _WebPlaintextLease(
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
  void Function()? _disposeCallback;
  Timer? expiryTimer;

  @override
  Future<void> dispose() async {
    final callback = _disposeCallback;
    _disposeCallback = null;
    expiryTimer?.cancel();
    expiryTimer = null;
    callback?.call();
  }
}

final class _WebBlobReadLease implements VaultBlobReadLease {
  _WebBlobReadLease(this.blobId, this._open, this._release);

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
    return _WebAuthenticatedRead(
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

Future<FileSystemDirectoryHandle> _directory(
  FileSystemDirectoryHandle parent,
  String name,
) => parent
    .getDirectoryHandle(name, FileSystemGetDirectoryOptions(create: true))
    .toDart;

Future<FileSystemDirectoryHandle> _existingDirectory(
  FileSystemDirectoryHandle parent,
  String name,
) => parent.getDirectoryHandle(name).toDart;

Future<void> _writeBytes(
  FileSystemDirectoryHandle directory,
  String name,
  List<int> bytes,
) async {
  final handle = await directory
      .getFileHandle(name, FileSystemGetFileOptions(create: true))
      .toDart;
  final output = await handle.createWritable().toDart;
  try {
    await output.write(Uint8List.fromList(bytes).toJS).toDart;
    await output.close().toDart;
  } catch (_) {
    try {
      await output.abort().toDart;
    } catch (_) {}
    rethrow;
  }
}

Future<Uint8List?> _readBytes(
  FileSystemDirectoryHandle directory,
  String name,
) async {
  try {
    final handle = await directory.getFileHandle(name).toDart;
    final file = await handle.getFile().toDart;
    return (await file.arrayBuffer().toDart).toDart.asUint8List();
  } catch (error) {
    if (_isDomError(error, 'NotFoundError')) return null;
    rethrow;
  }
}

Future<void> _copyFile(
  FileSystemDirectoryHandle source,
  String sourceName,
  FileSystemDirectoryHandle target,
  String targetName,
) async {
  final sourceHandle = await source.getFileHandle(sourceName).toDart;
  final file = await sourceHandle.getFile().toDart;
  final targetHandle = await target
      .getFileHandle(targetName, FileSystemGetFileOptions(create: true))
      .toDart;
  final output = await targetHandle.createWritable().toDart;
  try {
    for (var offset = 0; offset < file.size; offset += mec1ChunkPlaintextSize) {
      final end = min(offset + mec1ChunkPlaintextSize, file.size);
      final bytes = (await file.slice(offset, end).arrayBuffer().toDart).toDart
          .asUint8List();
      await output.write(bytes.toJS).toDart;
    }
    await output.close().toDart;
  } catch (_) {
    try {
      await output.abort().toDart;
    } catch (_) {}
    rethrow;
  }
}

Future<bool> _exists(FileSystemDirectoryHandle directory, String name) async {
  try {
    await directory.getFileHandle(name).toDart;
    return true;
  } catch (error) {
    if (_isDomError(error, 'NotFoundError')) return false;
    rethrow;
  }
}

Future<void> _remove(FileSystemDirectoryHandle directory, String name) async {
  try {
    await directory.removeEntry(name).toDart;
  } catch (error) {
    if (!_isDomError(error, 'NotFoundError')) rethrow;
  }
}

Future<void> _bestEffortRemove(
  FileSystemDirectoryHandle directory,
  String name,
) async {
  try {
    await _remove(directory, name);
  } catch (_) {}
}

Future<List<String>> _entryNames(FileSystemDirectoryHandle directory) async {
  final iterator = _IterableDirectory(directory).entries();
  final names = <String>[];
  while (true) {
    final result = await iterator.next().toDart;
    if (result.done) return names;
    final pair = result.value.toDart;
    names.add((pair[0]! as JSString).toDart);
  }
}

VaultBlobId? _tryId(String value) {
  try {
    return VaultBlobId(value);
  } on ArgumentError {
    return null;
  }
}

VaultBlobId _newId() => VaultBlobId(_randomToken(24));

String _randomToken(int length) {
  final random = Random.secure();
  return base64UrlEncode(
    List<int>.generate(length, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

bool _isDomError(Object error, String name) {
  try {
    final jsError = error as JSAny;
    return jsError.isA<DOMException>() &&
        (jsError as DOMException).name == name;
  } catch (_) {
    return false;
  }
}

String _safeDomReason(Object error) {
  if (_isDomError(error, 'SecurityError')) return 'OPFS is blocked by context.';
  if (_isDomError(error, 'NotAllowedError')) return 'OPFS access was denied.';
  return 'OPFS is unavailable in this browser.';
}

VaultFailure _vaultError(Object error) {
  if (error is VaultFailure) return error;
  if (_isDomError(error, 'QuotaExceededError')) {
    return const VaultFailure(
      VaultFailureCode.quotaExceeded,
      'Browser storage quota was exceeded.',
    );
  }
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
  return const VaultFailure(
    VaultFailureCode.backendUnavailable,
    'Web vault operation failed.',
  );
}

bool _isQuarantinable(Object error) =>
    error is FormatException ||
    error is Mec1FormatException ||
    error is Mec1UnsupportedVersionException ||
    (error is Mec1AuthenticationException && error.chunkIndex != null) ||
    (error is VaultFailure && error.code == VaultFailureCode.corruptCiphertext);
