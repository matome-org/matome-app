@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:matome_vault/matome_vault.dart';
import 'package:test/test.dart';
import 'package:web/web.dart';

const _filename = 'private-browser-recording-2146.wav';
const _sentinel = 'MATOME_WEB_PLAINTEXT_SENTINEL_2146';

@JS('navigator')
external Navigator get _navigator;

void main() {
  late VaultAccountId account;
  late _TestKeys keys;

  setUp(() {
    account = VaultAccountId(
      'web-contract-${DateTime.now().microsecondsSinceEpoch}',
    );
    keys = _TestKeys(account);
  });

  tearDown(() => keys.dispose());

  test(
    'capability and reload preserve an opaque authenticated MEC1 object',
    () async {
      expect((await probeWebMediaBlobStore()).isAvailable, isTrue);
      final store = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      final plaintext = Uint8List.fromList([
        ...utf8.encode(_sentinel),
        ...List<int>.generate(140000, (index) => index & 0xff),
      ]);

      final stat = await store.ingest(_Input(plaintext));
      final reopened = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );

      expect(stat.state, VaultBlobState.ready);
      expect(stat.plaintextLength, plaintext.length);
      expect(await _read(reopened, stat.id), plaintext);
      expect(
        await _read(
          reopened,
          stat.id,
          range: PlaintextRange(start: 65530, endExclusive: 70003),
        ),
        plaintext.sublist(65530, 70003),
      );
      final scan = await _scanAccount(account);
      expect(scan.currentNames, [stat.id.value]);
      expect(scan.allNames, everyElement(isNot(contains(_filename))));
      expect(_contains(scan.bytes, utf8.encode(_filename)), isFalse);
      expect(_contains(scan.bytes, utf8.encode(_sentinel)), isFalse);
    },
  );

  test('active read and lease exclude idempotent delete', () async {
    final store = await WebMediaBlobStore.open(
      accountId: account,
      keyMaterial: keys,
    );
    final stat = await store.ingest(_Input(Uint8List(200000)));
    final read = await store.openAuthenticatedRead(stat.id);
    final subscription = read.bytes.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
    await subscription.cancel();

    final readLease = await store.acquireReadLease(stat.id);
    await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
    final range = await readLease.openAuthenticatedRead(
      range: PlaintextRange(start: 65530, endExclusive: 131079),
    );
    expect(
      await range.bytes.expand((chunk) => chunk).toList(),
      Uint8List(200000).sublist(65530, 131079),
    );
    await readLease.dispose();

    final lease = await store.createLease(
      stat.id,
      purpose: VaultLeasePurpose.playback,
      ttl: const Duration(seconds: 5),
    );
    expect(lease.location.scheme, 'blob');
    await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));
    await lease.dispose();
    await store.delete(stat.id);
    await store.delete(stat.id);
    expect((await store.stat(stat.id)).state, VaultBlobState.missing);
  });

  test('prepare delete waits for leases and blocks new Blob URLs', () async {
    final store = await WebMediaBlobStore.open(
      accountId: account,
      keyMaterial: keys,
    );
    final stat = await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
    final lease = await store.createLease(
      stat.id,
      purpose: VaultLeasePurpose.preview,
      ttl: const Duration(minutes: 1),
    );

    await expectLater(
      store.prepareDelete(stat.id),
      throwsA(isA<VaultFailure>()),
    );
    await lease.dispose();
    await store.prepareDelete(stat.id);
    await expectLater(
      store.createLease(
        stat.id,
        purpose: VaultLeasePurpose.playback,
        ttl: const Duration(minutes: 1),
      ),
      throwsA(isA<VaultFailure>()),
    );
    expect((await store.stat(stat.id)).state, VaultBlobState.ready);

    await store.delete(stat.id);
    expect((await store.stat(stat.id)).state, VaultBlobState.missing);
  });

  test(
    'audio image and document Blob URLs are revoked on store close',
    () async {
      final store = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      final stat = await store.ingest(_Input(Uint8List.fromList([1, 2, 3])));
      final leases = <VaultPlaintextLease>[];
      for (final purpose in const [
        VaultLeasePurpose.playback,
        VaultLeasePurpose.preview,
        VaultLeasePurpose.externalOpen,
      ]) {
        final lease = await store.createLease(
          stat.id,
          purpose: purpose,
          ttl: const Duration(minutes: 5),
        );
        expect(lease.location.scheme, 'blob');
        expect(await _urlReadable(lease.location), isTrue);
        leases.add(lease);
      }
      await expectLater(store.delete(stat.id), throwsA(isA<VaultFailure>()));

      await store.close();

      for (final lease in leases) {
        expect(await _urlReadable(lease.location), isFalse);
      }

      final reopened = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      await reopened.delete(stat.id);
      for (final lease in leases) {
        await lease.dispose();
      }
    },
  );

  for (final point in [
    WebVaultIoOperation.stagingCommitted,
    WebVaultIoOperation.verified,
    WebVaultIoOperation.objectCommitted,
    WebVaultIoOperation.manifestCommitted,
  ]) {
    test('reconcile converges after crash at ${point.name}', () async {
      final crashing = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
        faults: _CrashOn(point),
      );
      await expectLater(
        crashing.ingest(_Input(Uint8List.fromList(utf8.encode(_sentinel)))),
        throwsA(isA<WebVaultCrash>()),
      );
      final recovered = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      expect(await recovered.journal(), isEmpty);
      final scan = await _scanAccount(account);
      expect(scan.currentNames.length, lessThanOrEqualTo(1));
      if (scan.currentNames.isNotEmpty) {
        expect(
          await _read(recovered, VaultBlobId(scan.currentNames.single)),
          utf8.encode(_sentinel),
        );
      }
    });
  }

  for (final point in [
    WebVaultIoOperation.tombstoned,
    WebVaultIoOperation.removed,
  ]) {
    test('delete crash at ${point.name} converges to missing', () async {
      final initial = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      final stat = await initial.ingest(_Input(Uint8List(1024)));
      final crashing = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
        faults: _CrashOn(point),
      );

      await expectLater(
        crashing.delete(stat.id),
        throwsA(isA<WebVaultCrash>()),
      );
      final recovered = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );

      expect((await recovered.stat(stat.id)).state, VaultBlobState.missing);
      expect(await recovered.journal(), isEmpty);
      expect((await _scanAccount(account)).currentNames, isEmpty);
    });
  }

  test(
    'quota failure is typed and leaves no plaintext or partial object',
    () async {
      final store = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
        faults: _ThrowOnWrite(
          DOMException(
            'simulated browser quota exhaustion',
            'QuotaExceededError',
          ),
        ),
      );
      await expectLater(
        store.ingest(_Input(Uint8List.fromList(utf8.encode(_sentinel)))),
        throwsA(
          isA<VaultFailure>().having(
            (failure) => failure.code,
            'code',
            VaultFailureCode.quotaExceeded,
          ),
        ),
      );
      final reopened = await WebMediaBlobStore.open(
        accountId: account,
        keyMaterial: keys,
      );
      expect(await reopened.journal(), isEmpty);
      expect(
        _contains((await _scanAccount(account)).bytes, utf8.encode(_sentinel)),
        isFalse,
      );
    },
  );

  test('wrong DEK and tampered ciphertext fail closed', () async {
    final store = await WebMediaBlobStore.open(
      accountId: account,
      keyMaterial: keys,
    );
    final stat = await store.ingest(_Input(Uint8List(100000)));
    final wrong = _TestKeys(account, seed: 99);
    addTearDown(wrong.dispose);
    await expectLater(
      WebMediaBlobStore.open(accountId: account, keyMaterial: wrong),
      throwsA(
        isA<VaultFailure>().having(
          (failure) => failure.code,
          'code',
          VaultFailureCode.wrongKey,
        ),
      ),
    );

    await _tamperCurrent(account, stat.id);
    await expectLater(
      _read(store, stat.id),
      throwsA(
        isA<VaultFailure>().having(
          (failure) => failure.code,
          'code',
          VaultFailureCode.corruptCiphertext,
        ),
      ),
    );
    final reopened = await WebMediaBlobStore.open(
      accountId: account,
      keyMaterial: keys,
    );
    expect((await reopened.stat(stat.id)).state, VaultBlobState.missing);
  });
}

Future<bool> _urlReadable(Uri uri) async {
  try {
    final response = await window.fetch(uri.toString().toJS).toDart;
    return response.ok;
  } catch (_) {
    return false;
  }
}

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

final class _Input implements MediaInput {
  const _Input(this.bytes);
  final Uint8List bytes;
  @override
  String? get contentType => 'audio/wav';
  @override
  String get filename => _filename;
  @override
  int get knownLength => bytes.length;
  @override
  Stream<List<int>> openRead() => Stream.value(bytes);
}

final class _TestKeys implements VaultKeyMaterial {
  _TestKeys(this.accountId, {int seed = 7})
    : _bytes = Uint8List.fromList(
        List<int>.generate(32, (index) => (seed + index) & 0xff),
      );
  @override
  final VaultAccountId accountId;
  Uint8List? _bytes;
  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) {
    final bytes = _bytes;
    if (bytes == null) {
      throw const VaultFailure(VaultFailureCode.locked, 'locked');
    }
    return Future.sync(() => operation(bytes));
  }

  @override
  Future<void> dispose() async {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
  }
}

final class _CrashOn implements WebVaultFaultInjector {
  _CrashOn(this.operation);
  final WebVaultIoOperation operation;
  bool _thrown = false;
  @override
  void before(WebVaultIoOperation operation, VaultBlobId? blobId) {
    if (!_thrown && operation == this.operation) {
      _thrown = true;
      throw WebVaultCrash(operation.name);
    }
  }
}

final class _ThrowOnWrite implements WebVaultFaultInjector {
  const _ThrowOnWrite(this.error);
  final Object error;
  @override
  void before(WebVaultIoOperation operation, VaultBlobId? blobId) {
    if (operation == WebVaultIoOperation.stagingWrite) throw error;
  }
}

final class _StorageScan {
  const _StorageScan(this.currentNames, this.allNames, this.bytes);
  final List<String> currentNames;
  final List<String> allNames;
  final Uint8List bytes;
}

Future<FileSystemDirectoryHandle> _accountRoot(VaultAccountId account) async {
  final root = await _navigator.storage.getDirectory().toDart;
  final packageRoot = await root.getDirectoryHandle('matome_media_v1').toDart;
  final namespace = sha256.convert(utf8.encode(account.value)).toString();
  return packageRoot.getDirectoryHandle(namespace).toDart;
}

Future<_StorageScan> _scanAccount(VaultAccountId account) async {
  final root = await _accountRoot(account);
  final names = <String>[];
  final currentNames = <String>[];
  final bytes = BytesBuilder(copy: false);
  for (final directoryName in const [
    'current',
    'next',
    'manifest',
    'quarantine',
  ]) {
    final directory = await root.getDirectoryHandle(directoryName).toDart;
    for (final entry in await _entries(directory)) {
      names.add(entry.$1);
      if (directoryName == 'current') currentNames.add(entry.$1);
      if (entry.$2.kind == 'file') {
        final file = await (entry.$2 as FileSystemFileHandle).getFile().toDart;
        bytes.add((await file.arrayBuffer().toDart).toDart.asUint8List());
      }
    }
  }
  return _StorageScan(currentNames, names, bytes.takeBytes());
}

Future<void> _tamperCurrent(VaultAccountId account, VaultBlobId id) async {
  final root = await _accountRoot(account);
  final current = await root.getDirectoryHandle('current').toDart;
  final handle = await current.getFileHandle(id.value).toDart;
  final file = await handle.getFile().toDart;
  final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
  bytes[bytes.length - 1] ^= 0xff;
  final output = await handle.createWritable().toDart;
  await output.write(bytes.toJS).toDart;
  await output.close().toDart;
}

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

Future<List<(String, FileSystemHandle)>> _entries(
  FileSystemDirectoryHandle directory,
) async {
  final iterator = _IterableDirectory(directory).entries();
  final entries = <(String, FileSystemHandle)>[];
  while (true) {
    final result = await iterator.next().toDart;
    if (result.done) return entries;
    final pair = result.value.toDart;
    entries.add(((pair[0]! as JSString).toDart, pair[1]! as FileSystemHandle));
  }
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var match = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
