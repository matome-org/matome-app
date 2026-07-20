// Web worker entrypoint for the drift WASM database.
//
// Compiled to `web/drift_worker.js` (committed alongside this source) and loaded
// by `openConnection()` (lib/core/db/connection.dart) on the web target. The
// companion `web/sqlite3.wasm` is the matching prebuilt sqlite3 binary.
//
// To regenerate after a drift/sqlite3 upgrade:
//   dart run drift_dev make-default-driftworker   # or:
//   dart compile js web/drift_worker.dart -o web/drift_worker.js -O4
// and refresh web/sqlite3.wasm to the version pinned in pubspec.lock.
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
