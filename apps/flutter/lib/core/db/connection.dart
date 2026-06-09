import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the platform-appropriate lazy connection for the app database.
///
/// `driftDatabase` from drift_flutter is the cross-platform entry point:
///   * native (Android/iOS/macOS/Linux/Windows) — a [NativeDatabase] backed by
///     the bundled sqlite3 lib (sqlite3_flutter_libs), file stored under the
///     app-documents directory (resolved via path_provider internally);
///   * web — a WasmDatabase served from the drift worker + sqlite3.wasm assets
///     under `web/` (see `web/` setup / pubspec). drift_flutter picks the best
///     available storage implementation (OPFS when supported, IndexedDB fall
///     back) automatically.
///
/// Keeping this isolated means the rest of the app never imports a
/// platform-specific connection — the UI/sync layer (Wave 3) just talks to
/// [AppDatabase].
QueryExecutor openConnection() {
  return driftDatabase(
    name: 'matome',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
