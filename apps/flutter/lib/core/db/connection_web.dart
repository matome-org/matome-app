import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import 'db_encryption.dart';

/// Web connection — **online-only, in-memory** (ADR-0001 #2).
///
/// matome web is an authenticated, online-only client: it reads from the Core
/// API and does NOT persist a local mirror at-rest. There is no SQLCipher
/// equivalent for the drift wasm worker, so a persistent OPFS/IndexedDB store
/// would be an UNENCRYPTED at-rest copy of recordings/transcripts — a security
/// regression. We avoid it entirely by backing the web database with an
/// **in-memory** sqlite3 VFS: the schema + repositories work unchanged, but the
/// store lives only in page memory and is re-hydrated from the Core API on each
/// load. Nothing touches OPFS/IndexedDB or disk.
///
/// (Auth tokens are not in this store — they live in `flutter_secure_storage`'s
/// web backend; session survival across reload is the token-in-storage path,
/// not Drift persistence.)
///
/// The [keyStore] argument is accepted for a uniform signature but unused here
/// (no at-rest key to manage when nothing is persisted).
QueryExecutor openPlatformConnection({SecureKeyStore? keyStore}) {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
    return WasmDatabase.inMemory(sqlite3);
  });
}
