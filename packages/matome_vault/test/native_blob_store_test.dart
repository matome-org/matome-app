@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:matome_vault/matome_vault.dart';
import 'package:test/test.dart';

const _account = 'account/../../opaque:user';
const _filenameSentinel = 'private family recording 2026.wav';
const _plaintextSentinel = 'MATOME_NATIVE_PLAINTEXT_SENTINEL_2145';

void main() {
  late Directory support;
  late _TestKeyMaterial keys;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('matome-vault-native-');
    keys = _TestKeyMaterial(VaultAccountId(_account));
  });

  tearDown(() async {
    await keys.dispose();
    if (await support.exists()) await support.delete(recursive: true);
  });

  test(
    'streams one opaque MEC1 object and supports stat, full and range reads',
    () async {
      final store = await _open(support, keys);
      final plaintext = Uint8List.fromList([
        ...utf8.encode(_plaintextSentinel),
        ...List<int>.generate(140000, (index) => index & 0xff),
      ]);

      final stat = await store.ingest(_Input(plaintext));

      expect(stat.state, VaultBlobState.ready);
      expect(stat.plaintextLength, plaintext.length);
      expect(stat.physicalLength, greaterThan(plaintext.length));
      expect(stat.id.value, matches(RegExp(r'^[A-Za-z0-9_-]{32}$')));
      expect((await store.stat(stat.id)).physicalLength, stat.physicalLength);
      expect(await _read(store, stat.id), plaintext);
      expect(
        await _read(
          store,
          stat.id,
          range: PlaintextRange(start: 65530, endExclusive: 70003),
        ),
        plaintext.sublist(65530, 70003),
      );

      final files = await _files(support);
      expect(files.where((file) => file.path.endsWith('.mec1')), hasLength(1));
      expect(
        files.map((file) => file.path),
        isNot(contains(contains(_filenameSentinel))),
      );
      final durableBytes = await Future.wait(
        files.map((file) => file.readAsBytes()),
      );
      for (final bytes in durableBytes) {
        expect(_contains(bytes, utf8.encode(_plaintextSentinel)), isFalse);
        expect(_contains(bytes, utf8.encode(_filenameSentinel)), isFalse);
      }
    },
  );

  test(
    'isolates opaque account namespaces without using account text as a path',
    () async {
      final otherKeys = _TestKeyMaterial(VaultAccountId('another/account'));
      addTearDown(otherKeys.dispose);
      final first = await _open(support, keys);
      final second = await _open(support, otherKeys);

      final stat = await first.ingest(_Input(Uint8List.fromList([1, 2, 3])));

      expect((await second.stat(stat.id)).state, VaultBlobState.missing);
      expect(
        (await _files(support)).map((file) => file.path),
        everyElement(isNot(contains(_account))),
      );
    },
  );

  test('rejects relative and symlinked application support roots', () async {
    await expectLater(
      NativeMediaBlobStore.open(
        applicationSupportRoot: 'relative',
        accountId: keys.accountId,
        keyMaterial: keys,
      ),
      throwsArgumentError,
    );
    final target = await Directory.systemTemp.createTemp(
      'matome-vault-target-',
    );
    final link = Link('${support.path}/support-link');
    await link.create(target.path);
    addTearDown(() async {
      if (await target.exists()) await target.delete(recursive: true);
    });

    await expectLater(
      NativeMediaBlobStore.open(
        applicationSupportRoot: link.path,
        accountId: keys.accountId,
        keyMaterial: keys,
      ),
      throwsArgumentError,
    );

    final nestedTarget = await Directory.systemTemp.createTemp(
      'matome-vault-nested-target-',
    );
    final nestedLink = Link('${support.path}/nested-link');
    await nestedLink.create(nestedTarget.path);
    addTearDown(() async {
      if (await nestedTarget.exists()) {
        await nestedTarget.delete(recursive: true);
      }
    });
    final canonicalized = await NativeMediaBlobStore.open(
      applicationSupportRoot: '${nestedLink.path}/child',
      accountId: keys.accountId,
      keyMaterial: keys,
    );
    expect(
      (await canonicalized.ingest(_Input(Uint8List.fromList([1])))).state,
      VaultBlobState.ready,
    );
  });

  test(
    'cancellation and write failure leave no visible partial blob',
    () async {
      final cancelled = await _open(support, keys);
      await expectLater(
        cancelled.ingest(_FailingInput()),
        throwsA(isA<VaultFailure>()),
      );
      expect(await cancelled.journal(), isEmpty);

      final fullDisk = await _open(
        support,
        keys,
        faults: _ThrowOn(
          NativeVaultIoOperation.stagingWrite,
          FileSystemException('disk full', '/secret/vault-path'),
        ),
      );
      await expectLater(
        fullDisk.ingest(_Input(Uint8List(1024))),
        throwsA(
          isA<VaultFailure>()
              .having((failure) => failure.cause, 'cause', isNull)
              .having(
                (failure) => failure.toString(),
                'redacted error',
                isNot(contains('/secret/vault-path')),
              ),
        ),
      );
      final recovered = await _open(support, keys);
      await recovered.reconcile();
      expect(await recovered.journal(), isEmpty);
      expect(
        (await _files(support)).where((file) => file.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  for (final crash in [
    (NativeVaultIoOperation.stagingWrite, 1),
    (NativeVaultIoOperation.stagingFlush, 1),
    (NativeVaultIoOperation.stagingDurable, 1),
    (NativeVaultIoOperation.verification, 1),
    (NativeVaultIoOperation.verified, 1),
    (NativeVaultIoOperation.objectCommit, 1),
    (NativeVaultIoOperation.objectCommitted, 1),
    (NativeVaultIoOperation.journalWrite, 3),
    (NativeVaultIoOperation.journalFlush, 3),
    (NativeVaultIoOperation.journalCommit, 3),
    (NativeVaultIoOperation.journalCommitted, 3),
  ]) {
    test(
      'ingest crash at ${crash.$1.name} #${crash.$2} reconciles safely',
      () async {
        final crashing = await _open(
          support,
          keys,
          faults: _CrashOn(crash.$1, crash.$2),
        );
        await expectLater(
          crashing.ingest(
            _Input(Uint8List.fromList(utf8.encode(_plaintextSentinel))),
          ),
          throwsA(isA<NativeVaultCrash>()),
        );

        final recovered = await _open(support, keys);
        final report = await recovered.reconcile();
        expect(await recovered.journal(), isEmpty);
        final objects = (await _files(
          support,
        )).where((file) => file.path.endsWith('.mec1')).toList();
        expect(objects.length, lessThanOrEqualTo(1));
        expect(report.records.length, lessThanOrEqualTo(1));
        if (objects.isNotEmpty) {
          final id = VaultBlobId(
            objects.single.uri.pathSegments.last.split('.').first,
          );
          expect((await recovered.stat(id)).state, VaultBlobState.ready);
          expect(await _read(recovered, id), utf8.encode(_plaintextSentinel));
        }
      },
    );
  }

  test(
    'active readers and leases exclude delete; repeated delete is idempotent',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List(200000)));
      final read = await store.openAuthenticatedRead(stat.id);
      final subscription = read.bytes.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
      await subscription.cancel();
      final lease = await store.createLease(
        stat.id,
        purpose: VaultLeasePurpose.playback,
        ttl: const Duration(seconds: 5),
      );
      expect(await File.fromUri(lease.location).exists(), isTrue);
      await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
      await lease.dispose();
      await store.delete(stat.id);
      await store.delete(stat.id);
      expect((await store.stat(stat.id)).state, VaultBlobState.missing);
    },
  );

  test(
    'immediate reader cancellation does not retain a delete reference',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List(200000)));
      final read = await store.openAuthenticatedRead(stat.id);

      await read.bytes.listen((_) {}).cancel();
      await store.delete(stat.id);

      expect((await store.stat(stat.id)).state, VaultBlobState.missing);
    },
  );

  test('read lease pins delete and is revoked when the store closes', () async {
    final store = await _open(support, keys);
    final plaintext = Uint8List.fromList(
      List<int>.generate(200000, (index) => index & 0xff),
    );
    final stat = await store.ingest(_Input(plaintext));
    final lease = await store.acquireReadLease(stat.id);

    await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
    final read = await lease.openAuthenticatedRead(
      range: PlaintextRange(start: 65530, endExclusive: 131079),
    );
    expect(
      await read.bytes.expand((chunk) => chunk).toList(),
      plaintext.sublist(65530, 131079),
    );

    final cancellable = await lease.openAuthenticatedRead();
    final firstChunk = Completer<void>();
    final revoked = Completer<VaultFailure>();
    var chunks = 0;
    late final StreamSubscription<List<int>> subscription;
    subscription = cancellable.bytes.listen((_) {
      chunks++;
      if (chunks == 1) {
        subscription.pause();
        firstChunk.complete();
      }
    }, onError: (Object error) => revoked.complete(error as VaultFailure));
    await firstChunk.future;

    await store.close();
    subscription.resume();
    expect((await revoked.future).code, VaultFailureCode.locked);
    expect(chunks, 1, reason: 'revocation cancels an active plaintext stream');
    await expectLater(
      lease.openAuthenticatedRead(),
      throwsA(
        isA<VaultFailure>().having(
          (failure) => failure.code,
          'code',
          VaultFailureCode.locked,
        ),
      ),
    );
    await lease.dispose();

    final reopened = await _open(support, keys);
    await reopened.delete(stat.id);
  });

  test('prepare delete waits for leases and blocks new readers', () async {
    final store = await _open(support, keys);
    final stat = await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
    final lease = await store.acquireReadLease(stat.id);

    await expectLater(
      store.prepareDelete(stat.id),
      throwsA(isA<VaultFailure>()),
    );
    await lease.dispose();
    await store.prepareDelete(stat.id);
    await expectLater(
      store.acquireReadLease(stat.id),
      throwsA(isA<VaultFailure>()),
    );
    expect((await store.stat(stat.id)).state, VaultBlobState.ready);

    await store.delete(stat.id);
    expect((await store.stat(stat.id)).state, VaultBlobState.missing);
  });

  test(
    'store close revokes and removes materialized plaintext leases',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
      final lease = await store.createLease(
        stat.id,
        purpose: VaultLeasePurpose.externalOpen,
        ttl: const Duration(minutes: 5),
      );
      final plaintext = File.fromUri(lease.location);
      expect(await plaintext.exists(), isTrue);

      await store.close();

      expect(await plaintext.exists(), isFalse);
      await expectLater(
        store.createLease(
          stat.id,
          purpose: VaultLeasePurpose.playback,
          ttl: const Duration(minutes: 1),
        ),
        throwsA(
          isA<VaultFailure>().having(
            (failure) => failure.code,
            'code',
            VaultFailureCode.locked,
          ),
        ),
      );
      await lease.dispose();
    },
  );

  test(
    'lease expires and reconcile removes plaintext left by restart',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List.fromList([9, 8, 7])));
      final expiring = await store.createLease(
        stat.id,
        purpose: VaultLeasePurpose.preview,
        ttl: const Duration(milliseconds: 20),
      );
      final expiringFile = File.fromUri(expiring.location);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await expiringFile.exists(), isFalse);

      final abandoned = await store.createLease(
        stat.id,
        purpose: VaultLeasePurpose.preview,
        ttl: const Duration(minutes: 1),
      );
      final abandonedFile = File.fromUri(abandoned.location);
      final reopened = await _open(support, keys);
      expect(await abandonedFile.exists(), isFalse);
      expect((await reopened.stat(stat.id)).state, VaultBlobState.ready);
      await abandoned.dispose();
    },
  );

  test(
    'corruption is authenticated and reconcile quarantines the object',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List(100000)));
      final object = (await _files(
        support,
      )).singleWhere((file) => file.path.endsWith('.mec1'));
      final handle = await object.open(mode: FileMode.append);
      await handle.writeByte(1);
      await handle.close();

      await expectLater(_read(store, stat.id), throwsA(isA<VaultFailure>()));
      await store.reconcile();
      expect((await store.stat(stat.id)).state, VaultBlobState.missing);
      expect(await store.reconcile().then((report) => report.changed), isFalse);
    },
  );

  test(
    'wrong account key fails closed without quarantining ciphertext',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List.fromList([7, 8, 9])));
      final object = (await _files(
        support,
      )).singleWhere((file) => file.path.endsWith('.mec1'));
      final wrongKeys = _TestKeyMaterial(keys.accountId, seed: 99);
      addTearDown(wrongKeys.dispose);

      await expectLater(
        _open(support, wrongKeys),
        throwsA(
          isA<VaultFailure>().having(
            (failure) => failure.code,
            'code',
            VaultFailureCode.wrongKey,
          ),
        ),
      );

      expect(await object.exists(), isTrue);
      final recovered = await _open(support, keys);
      expect(await _read(recovered, stat.id), [7, 8, 9]);
    },
  );

  test(
    'unreferenced object is quarantined once and reconcile is idempotent',
    () async {
      final store = await _open(support, keys);
      await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
      final object = (await _files(
        support,
      )).singleWhere((file) => file.path.endsWith('.mec1'));
      final orphan = File('${object.parent.path}/${'A' * 32}.mec1');
      await orphan.writeAsBytes([1, 2, 3], flush: true);

      final first = await store.reconcile();
      final second = await store.reconcile();

      expect(
        first.records,
        contains(
          isA<VaultReconciliationRecord>().having(
            (record) => record.issue,
            'issue',
            VaultReconciliationIssue.unreferencedReadyObject,
          ),
        ),
      );
      expect(await orphan.exists(), isFalse);
      expect(second.changed, isFalse);
    },
  );

  test('manifest identity mismatch fails closed', () async {
    final store = await _open(support, keys);
    final stat = await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
    final manifests = (await _files(
      support,
    )).where((file) => file.path.endsWith('.json')).toList();
    for (final manifest in manifests) {
      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, Object?>;
      json['blobId'] = 'B' * 32;
      await manifest.writeAsString(jsonEncode(json), flush: true);
    }

    await expectLater(
      store.stat(stat.id),
      throwsA(
        isA<VaultFailure>().having(
          (failure) => failure.code,
          'code',
          VaultFailureCode.corruptCiphertext,
        ),
      ),
    );
  });

  test(
    'delete keeps tombstone durable until manifest cleanup completes',
    () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List(1024)));
      final crashing = await _open(
        support,
        keys,
        faults: _CrashOn(NativeVaultIoOperation.journalCleanup, 1),
      );

      await expectLater(
        crashing.delete(stat.id),
        throwsA(isA<NativeVaultCrash>()),
      );
      final recovered = await _open(support, keys);
      expect((await recovered.stat(stat.id)).state, VaultBlobState.missing);
      expect((await recovered.reconcile()).changed, isFalse);
    },
  );

  test('crash after tombstone converges to deleted', () async {
    final store = await _open(support, keys);
    final stat = await store.ingest(_Input(Uint8List(1024)));
    final crashing = await _open(
      support,
      keys,
      faults: _CrashOn(NativeVaultIoOperation.unlink, 1),
    );

    await expectLater(
      crashing.delete(stat.id),
      throwsA(isA<NativeVaultCrash>()),
    );
    final recovered = await _open(support, keys);
    expect((await recovered.stat(stat.id)).state, VaultBlobState.missing);
    await recovered.delete(stat.id);
    expect(
      await recovered.reconcile().then((report) => report.changed),
      isFalse,
    );
  });

  test('crash before tombstone preserves the ready blob', () async {
    final store = await _open(support, keys);
    final stat = await store.ingest(_Input(Uint8List.fromList([4, 5, 6])));
    final crashing = await _open(
      support,
      keys,
      faults: _CrashOn(NativeVaultIoOperation.tombstone, 1),
    );

    await expectLater(
      crashing.delete(stat.id),
      throwsA(isA<NativeVaultCrash>()),
    );
    final recovered = await _open(support, keys);
    expect((await recovered.stat(stat.id)).state, VaultBlobState.ready);
    expect(await _read(recovered, stat.id), [4, 5, 6]);
  });

  for (final operation in [
    NativeVaultIoOperation.tombstoned,
    NativeVaultIoOperation.unlink,
    NativeVaultIoOperation.unlinked,
  ]) {
    test('delete crash at ${operation.name} converges to deleted', () async {
      final store = await _open(support, keys);
      final stat = await store.ingest(_Input(Uint8List(1024)));
      final crashing = await _open(
        support,
        keys,
        faults: _CrashOn(operation, 1),
      );

      await expectLater(
        crashing.delete(stat.id),
        throwsA(isA<NativeVaultCrash>()),
      );
      final recovered = await _open(support, keys);
      expect((await recovered.stat(stat.id)).state, VaultBlobState.missing);
      expect(
        await recovered.reconcile().then((report) => report.changed),
        isFalse,
      );
    });
  }
}

Future<NativeMediaBlobStore> _open(
  Directory support,
  _TestKeyMaterial keys, {
  NativeVaultFaultInjector faults = const NoNativeVaultFaults(),
}) => NativeMediaBlobStore.open(
  applicationSupportRoot: support.path,
  accountId: keys.accountId,
  keyMaterial: keys,
  faults: faults,
);

Future<Uint8List> _read(
  MediaBlobStore store,
  VaultBlobId id, {
  PlaintextRange? range,
}) async {
  final read = await store.openAuthenticatedRead(id, range: range);
  final output = BytesBuilder(copy: false);
  await for (final chunk in read.bytes) {
    output.add(chunk);
  }
  return output.takeBytes();
}

Future<List<File>> _files(Directory root) async => root
    .list(recursive: true, followLinks: false)
    .where((entity) => entity is File)
    .cast<File>()
    .toList();

bool _contains(List<int> haystack, List<int> needle) {
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

final class _Input implements MediaInput {
  _Input(this.data);
  final Uint8List data;

  @override
  String? get contentType => 'audio/wav';
  @override
  String get filename => _filenameSentinel;
  @override
  int get knownLength => data.length;
  @override
  Stream<List<int>> openRead() async* {
    for (var offset = 0; offset < data.length; offset += 8192) {
      yield data.sublist(offset, (offset + 8192).clamp(0, data.length));
    }
  }
}

final class _FailingInput implements MediaInput {
  @override
  String? get contentType => null;
  @override
  String get filename => _filenameSentinel;
  @override
  int? get knownLength => null;
  @override
  Stream<List<int>> openRead() async* {
    yield Uint8List(32);
    throw StateError('source cancelled');
  }
}

final class _TestKeyMaterial implements VaultKeyMaterial {
  _TestKeyMaterial(this.accountId, {int seed = 1})
    : _bytes = Uint8List.fromList(
        List<int>.generate(32, (index) => index + seed),
      );

  @override
  final VaultAccountId accountId;
  final Uint8List _bytes;

  @override
  Future<void> dispose() async {
    _bytes.fillRange(0, _bytes.length, 0);
  }

  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) async {
    return await operation(_bytes);
  }
}

final class _CrashOn implements NativeVaultFaultInjector {
  _CrashOn(this.operation, this.occurrence);
  final NativeVaultIoOperation operation;
  final int occurrence;
  int _seen = 0;

  @override
  void before(NativeVaultIoOperation operation, VaultBlobId? blobId) {
    if (operation == this.operation && ++_seen == occurrence) {
      throw NativeVaultCrash('${operation.name} #$occurrence');
    }
  }
}

final class _ThrowOn implements NativeVaultFaultInjector {
  _ThrowOn(this.operation, this.error);
  final NativeVaultIoOperation operation;
  final Object error;

  @override
  void before(NativeVaultIoOperation operation, VaultBlobId? blobId) {
    if (operation == this.operation) throw error;
  }
}
