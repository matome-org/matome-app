import 'package:drift/wasm.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:sqlite3/wasm.dart';

Future<AppDatabase> createE2EDatabase() async {
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return AppDatabase.forTesting(WasmDatabase.inMemory(sqlite));
}
