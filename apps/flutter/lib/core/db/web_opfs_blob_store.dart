// Real OPFS-backed [EncryptedBlobStore] — task #1860, plan #131 (web wave).
//
// **Web-only.** This file is only ever imported by `connection_web.dart`,
// which is itself gated behind the `dart.library.js_interop` conditional
// import in `connection.dart`, so it never loads under `flutter test`'s
// Dart-VM target. The security-relevant decision logic that consumes this
// class (`web_store_opener.dart`) is tested separately against the
// [InMemoryBlobStore] fake in `encrypted_blob_store.dart` — see that file's
// doc comment for why the split exists.
//
// Deliberately uses the MAIN-THREAD ASYNC File System Access API
// (`getDirectory()` / `getFileHandle()` / `createWritable()` /
// `getFile()`) rather than the synchronous `createSyncAccessHandle()` API
// that `package:sqlite3`'s `SimpleOpfsFileSystem` uses. The sync API is only
// available inside a dedicated Web Worker (see that class's doc comment) and
// requires `crossOriginIsolated` (COOP/COEP headers + SharedArrayBuffer) —
// infra this pass does not add (no worker, no header changes). The async
// whole-file write/read used here works from the ordinary UI-thread
// JavaScript context with no such requirement — confirmed against a real
// Chromium tab in this task's browser check (`crossOriginIsolated: false`,
// `hasSyncAccessHandle: false`, plain main-thread write/read/delete
// round-trip still succeeds).
//
// UPGRADE SEAM: a future page-level VFS would replace this whole-file
// read/write with per-page xRead/xWrite calls against
// `SimpleOpfsFileSystem`/`WasmVfs` from a dedicated worker — this class's
// [EncryptedBlobStore] contract (opaque ciphertext in, opaque ciphertext
// out) does not need to change for that migration.
import 'dart:js_interop';

import 'dart:typed_data';

import 'package:web/web.dart'
    show
        DOMException,
        FileSystemDirectoryHandle,
        FileSystemFileHandle,
        FileSystemGetFileOptions,
        Navigator,
        StorageManager;

import 'encrypted_blob_store.dart' show EncryptedBlobStore;

@JS('navigator')
external Navigator get _navigator;

/// Thrown when `navigator.storage` (and therefore OPFS) isn't available at
/// all in the current browsing context. Encrypted startup must surface this as
/// a blocking state; it must not fall back to an in-memory/plaintext store.
class OpfsUnavailableException implements Exception {
  final String reason;
  const OpfsUnavailableException(this.reason);

  @override
  String toString() => 'OpfsUnavailableException: $reason';
}

StorageManager? _storageManagerOrNull() {
  try {
    return _navigator.storage;
  } catch (_) {
    return null;
  }
}

/// Persists the encrypted DB image as one file (default name
/// `matome_encrypted.db`) directly under the OPFS root
/// (`navigator.storage.getDirectory()`). Every byte that lands here is
/// whatever [encryptDbImage] (`core/crypto/db_image_cipher.dart`) produced —
/// this class has no knowledge of, and never receives, plaintext.
class OpfsBlobStore implements EncryptedBlobStore {
  OpfsBlobStore({this.fileName = 'matome_encrypted.db'});

  final String fileName;

  Future<FileSystemDirectoryHandle> _root() async {
    final storage = _storageManagerOrNull();
    if (storage == null) {
      throw const OpfsUnavailableException(
        'navigator.storage is unavailable in this browsing context',
      );
    }
    return storage.getDirectory().toDart;
  }

  @override
  Future<Uint8List?> read() async {
    final root = await _root();
    final FileSystemFileHandle handle;
    try {
      // create: false (default) — do not fabricate a file just by probing.
      handle = await root.getFileHandle(fileName).toDart;
    } catch (e) {
      if (_isNotFoundError(e)) {
        return null; // nothing persisted yet -- legitimate fresh-install case
      }
      rethrow;
    }

    final file = await handle.getFile().toDart;
    final buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final root = await _root();
    final handle = await root
        .getFileHandle(fileName, FileSystemGetFileOptions(create: true))
        .toDart;
    final writable = await handle.createWritable().toDart;
    await writable.write(bytes.toJS).toDart;
    await writable.close().toDart;
  }

  @override
  Future<void> delete() async {
    final root = await _root();
    try {
      await root.removeEntry(fileName).toDart;
    } catch (e) {
      if (!_isNotFoundError(e)) rethrow;
    }
  }
}

/// Safely checks whether a caught JS-interop error is a DOM `NotFoundError`,
/// without an `on DOMException catch` type clause (whose behavior can differ
/// across the dart2js/dart2wasm compilers for JS interop exception types —
/// `isA<T>()` from `dart:js_interop` is the compiler-consistent check).
bool _isNotFoundError(Object error) {
  try {
    final jsError = error as JSAny;
    if (!jsError.isA<DOMException>()) return false;
    return (jsError as DOMException).name == 'NotFoundError';
  } catch (_) {
    // Not a JS-interop error at all (e.g. a plain Dart exception) -- not a
    // NotFoundError either way.
    return false;
  }
}
