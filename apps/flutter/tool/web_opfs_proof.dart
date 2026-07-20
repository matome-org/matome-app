import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:drift/drift.dart';
import 'package:matome_flutter/core/crypto/db_image_cipher.dart';
import 'package:matome_flutter/core/crypto/envelope.dart';
import 'package:matome_flutter/core/crypto/kdf_params.dart';
import 'package:matome_flutter/core/crypto/key_material.dart';
import 'package:matome_flutter/core/crypto/key_unwrapper.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/connection_web.dart';
import 'package:matome_flutter/core/db/db_encryption.dart';
import 'package:matome_flutter/core/db/encrypted_blob_store.dart';
import 'package:matome_flutter/core/db/web_key_bundle_cache.dart';
import 'package:matome_flutter/core/db/web_opfs_blob_store.dart';
import 'package:matome_flutter/core/db/web_store_opener.dart';
import 'package:web/web.dart';

const _password = 'chromium-opfs-proof-password';
const _databaseObject = 'vlt_7f6d3c2a91';
const _mediaObject = 'vlt_b84e10d572';
const _lifecycleObject = 'vlt_3e59a102cd';
const _knownFilename = 'quarterly-planning-photo.jpg';
const _databaseSentinel = 'OPFS_SQLITE_SENTINEL_2157';
const _mediaSentinel = 'OPFS_MEDIA_SENTINEL_2157';
const _phaseKey = 'matome.opfs-proof.phase';

Future<void> main() async {
  try {
    _phase('main:started');
    if (window.localStorage.getItem(_phaseKey) != 'written') {
      await _writeBeforeReload();
      window.localStorage.setItem(_phaseKey, 'written');
      window.location.reload();
      return;
    }

    final report = await _readAfterReload();
    _finish({'status': 'pass', ...report});
  } catch (error, stackTrace) {
    _finish({
      'status': 'fail',
      'error': error.toString(),
      'stack': stackTrace.toString(),
    });
  }
}

Future<void> _writeBeforeReload() async {
  final databaseStore = OpfsBlobStore(fileName: _databaseObject);
  final mediaStore = OpfsBlobStore(fileName: _mediaObject);
  _phase('opfs-delete:database:before');
  await databaseStore.delete();
  _phase('opfs-delete:database:after');
  _phase('opfs-delete:media:before');
  await mediaStore.delete();
  _phase('opfs-delete:media:after');

  final secureStore = _LocalStorageSecureStore();
  final cache = WebKeyBundleCache(secureStore);
  await cache.clear();

  final salt = Uint8List.fromList(List.generate(16, (index) => index + 17));
  final dek = Dek.generate();
  _phase('argon2-wrap:before');
  final argonStopwatch = Stopwatch()..start();
  final kek = await PasswordKeyUnwrapper(
    password: _password,
    saltEnc: salt,
  ).deriveKEK();
  _phase('argon2-wrap:after', elapsed: argonStopwatch.elapsed);
  _phase('envelope-wrap:before');
  final wrappedDek = await wrapKey(
    plaintext: dek.bytes,
    wrappingKey: kek.bytes,
    payloadType: PayloadType.dek,
    wrapperType: WrapperType.passwordKek,
  );
  _phase('envelope-wrap:after');
  kek.wipe();
  await cache.write(
    CachedKeyBundleSaltInfo(
      wrappedDekPw: wrappedDek,
      saltEnc: salt,
      kdfParams: Argon2idParams.portableV1,
    ),
  );

  _phase('encrypted-connection:before');
  final executor = await openEncryptedWebConnection(
    password: _password,
    keyBundleCache: cache,
    blobStore: databaseStore,
    autoPersistInterval: const Duration(hours: 1),
    debugPhase: (phase, elapsed) => _phase(phase, elapsed: elapsed),
  );
  _phase('encrypted-connection:after');
  final database = AppDatabase.forTesting(executor);
  _phase('sqlite-writes:before');
  await database.customStatement(
    'CREATE TABLE opfs_proof (value TEXT NOT NULL)',
  );
  await database.customInsert(
    'INSERT INTO opfs_proof (value) VALUES (?)',
    variables: [Variable.withString(_databaseSentinel)],
  );
  _phase('sqlite-writes:after');
  _phase('checkpoint:before');
  await executor.checkpoint();
  _phase('checkpoint:after');

  final mediaPlaintext = Uint8List.fromList(
    utf8.encode('$_knownFilename::$_mediaSentinel'),
  );
  await WebStoreOpener(
    blobStore: mediaStore,
  ).persist(plaintextImage: mediaPlaintext, dek: dek);
  dek.wipe();
  await database.close();
  _phase('reload:before');
}

Future<Map<String, Object?>> _readAfterReload() async {
  _phase('reload:after');
  final databaseStore = OpfsBlobStore(fileName: _databaseObject);
  final mediaStore = OpfsBlobStore(fileName: _mediaObject);
  final cache = WebKeyBundleCache(_LocalStorageSecureStore());

  final executor = await openEncryptedWebConnection(
    password: _password,
    keyBundleCache: cache,
    blobStore: databaseStore,
    autoPersistInterval: const Duration(hours: 1),
  );
  final database = AppDatabase.forTesting(executor);
  final rows = await database
      .customSelect('SELECT value FROM opfs_proof')
      .get();
  _expect(rows.single.data['value'] == _databaseSentinel, 'SQLite reload read');

  final info = (await cache.read())!;
  final mediaResult = await WebStoreOpener(blobStore: mediaStore).open(
    unwrapper: PasswordKeyUnwrapper(
      password: _password,
      saltEnc: info.saltEnc,
      params: info.kdfParams,
    ),
    wrappedDekPw: info.wrappedDekPw,
  );
  final mediaText = utf8.decode(mediaResult.plaintextImage!);
  _expect(
    mediaText == '$_knownFilename::$_mediaSentinel',
    'opaque blob reload read',
  );
  mediaResult.dek.wipe();

  final databaseCiphertext = (await databaseStore.read())!;
  final mediaCiphertext = (await mediaStore.read())!;
  for (final ciphertext in [databaseCiphertext, mediaCiphertext]) {
    _expect(
      !_contains(ciphertext, utf8.encode('SQLite format 3')),
      'SQLite header hidden',
    );
    _expect(
      !_contains(ciphertext, utf8.encode(_knownFilename)),
      'filename hidden',
    );
    _expect(
      !_contains(ciphertext, utf8.encode(_databaseSentinel)),
      'DB sentinel hidden',
    );
    _expect(
      !_contains(ciphertext, utf8.encode(_mediaSentinel)),
      'blob sentinel hidden',
    );
  }
  _expect(
    !_databaseObject.contains(_knownFilename),
    'opaque database object name',
  );
  _expect(!_mediaObject.contains(_knownFilename), 'opaque media object name');

  await _expectThrows(
    () => openEncryptedWebConnection(
      password: 'wrong-password',
      keyBundleCache: cache,
      blobStore: databaseStore,
    ),
    (error) => error is EnvelopeUnwrapException,
    'wrong password blocks instead of first run',
  );

  final tampered = Uint8List.fromList(mediaCiphertext)..last ^= 0xff;
  await mediaStore.write(tampered);
  await _expectThrows(
    () => WebStoreOpener(blobStore: mediaStore).open(
      unwrapper: PasswordKeyUnwrapper(
        password: _password,
        saltEnc: info.saltEnc,
        params: info.kdfParams,
      ),
      wrappedDekPw: info.wrappedDekPw,
    ),
    (error) => error is DbImageDecryptException,
    'tamper blocks instead of first run',
  );

  final quotaError = DOMException(
    'simulated browser quota exhaustion',
    'QuotaExceededError',
  );
  final quotaDek = Dek.generate();
  try {
    await _expectThrows(
      () => WebStoreOpener(blobStore: _ThrowingStore(quotaError)).persist(
        plaintextImage: Uint8List.fromList(utf8.encode('must-not-fallback')),
        dek: quotaDek,
      ),
      (error) => _domExceptionName(error) == 'QuotaExceededError',
      'quota write failure propagates',
    );
  } finally {
    quotaDek.wipe();
  }

  await _expectThrows(
    () => openEncryptedWebConnection(
      password: _password,
      keyBundleCache: cache,
      blobStore: const _ThrowingStore(
        OpfsUnavailableException('simulated unavailable API'),
      ),
    ),
    (error) => error is OpfsUnavailableException,
    'OPFS unavailable produces blocking state',
  );

  final lifecycle = await _proveCloseLifecycle(cache);
  await database.close();
  return {
    'reload': true,
    'secureContext': window.isSecureContext,
    'origin': window.location.origin,
    'databaseCipherBytes': databaseCiphertext.length,
    'mediaCipherBytes': mediaCiphertext.length,
    'objectNames': [_databaseObject, _mediaObject],
    'wrongPassword': 'blocked',
    'tamper': 'blocked',
    'quotaWrite': 'blocked-simulated-domexception',
    'opfsUnavailable': 'blocked-simulated-api',
    ...lifecycle,
  };
}

Future<Map<String, Object?>> _proveCloseLifecycle(
  WebKeyBundleCache cache,
) async {
  final delegate = OpfsBlobStore(fileName: _lifecycleObject);
  await delegate.delete();
  final store = _BlockingWriteStore(delegate)..blockNextWrite();
  final executor = await openEncryptedWebConnection(
    password: _password,
    keyBundleCache: cache,
    blobStore: store,
    autoPersistInterval: const Duration(milliseconds: 5),
  );
  final database = AppDatabase.forTesting(executor);
  await database.customStatement(
    'CREATE TABLE lifecycle_proof (value TEXT NOT NULL)',
  );
  await database.customInsert(
    'INSERT INTO lifecycle_proof (value) VALUES (?)',
    variables: [Variable.withString('final-flush')],
  );

  final firstClose = executor.close();
  await store.writeStarted;
  final secondClose = executor.close();
  _expect(identical(firstClose, secondClose), 'close is idempotent');
  await _expectThrows(
    executor.checkpoint,
    (error) => error is StateError,
    'close rejects concurrent checkpoint admission',
  );
  store.releaseWrite();
  await firstClose;

  final writesAfterClose = store.writeCount;
  await Future<void>.delayed(const Duration(milliseconds: 25));
  _expect(store.writeCount == writesAfterClose, 'timer canceled after close');
  _expect(await delegate.read() != null, 'close performs final OPFS flush');
  return {
    'closeIdempotent': true,
    'concurrentCheckpoint': 'blocked',
    'timerAfterClose': 'canceled',
    'finalFlush': true,
  };
}

void _finish(Map<String, Object?> report) {
  final output = document.createElement('pre') as HTMLElement
    ..id = 'result'
    ..textContent = jsonEncode(report);
  document.body?.replaceChildren(output);
}

void _phase(String name, {Duration? elapsed}) {
  final report = jsonEncode({
    'name': name,
    'elapsedMs': elapsed?.inMilliseconds,
    'at': DateTime.now().toUtc().toIso8601String(),
  });
  var output = document.getElementById('phase');
  if (output == null) {
    output = document.createElement('pre')..id = 'phase';
    document.body?.append(output);
  }
  output.textContent = report;
  console.log('OPFS_PROOF_PHASE $report'.toJS);
}

void _expect(bool condition, String label) {
  if (!condition) throw StateError('proof assertion failed: $label');
}

Future<void> _expectThrows(
  Future<Object?> Function() action,
  bool Function(Object error) predicate,
  String label,
) async {
  try {
    await action();
  } catch (error) {
    if (predicate(error)) return;
    throw StateError('$label threw unexpected ${error.runtimeType}: $error');
  }
  throw StateError('$label did not throw');
}

bool _contains(Uint8List haystack, List<int> needle) {
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

String? _domExceptionName(Object error) {
  try {
    final jsError = error as JSAny;
    return jsError.isA<DOMException>() ? (jsError as DOMException).name : null;
  } catch (_) {
    return null;
  }
}

final class _LocalStorageSecureStore implements SecureKeyStore {
  @override
  Future<String?> read(String key) async => window.localStorage.getItem(key);

  @override
  Future<void> write(String key, String value) async {
    window.localStorage.setItem(key, value);
  }
}

final class _ThrowingStore implements EncryptedBlobStore {
  const _ThrowingStore(this.error);

  final Object error;

  @override
  Future<void> delete() async => throw error;

  @override
  Future<Uint8List?> read() async => throw error;

  @override
  Future<void> write(Uint8List bytes) async => throw error;
}

final class _BlockingWriteStore implements EncryptedBlobStore {
  _BlockingWriteStore(this.delegate);

  final EncryptedBlobStore delegate;
  Completer<void>? _writeRelease;
  Completer<void>? _writeStarted;
  int writeCount = 0;

  Future<void> get writeStarted => _writeStarted!.future;

  void blockNextWrite() {
    _writeRelease = Completer<void>();
    _writeStarted = Completer<void>();
  }

  void releaseWrite() {
    _writeRelease?.complete();
    _writeRelease = null;
  }

  @override
  Future<void> delete() => delegate.delete();

  @override
  Future<Uint8List?> read() => delegate.read();

  @override
  Future<void> write(Uint8List bytes) async {
    writeCount++;
    _writeStarted?.complete();
    final release = _writeRelease;
    if (release != null) await release.future;
    await delegate.write(bytes);
  }
}
