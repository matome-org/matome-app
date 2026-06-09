import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'db_encryption.dart';

/// Web connection — drift wasm worker + sqlite3.wasm.
///
/// There is NO SQLCipher equivalent for the wasm build, so the web DB is NOT
/// encrypted at-rest. Mitigation: the browser storage sandbox (OPFS / IndexedDB,
/// same-origin only) plus reliance on the user's OS/disk encryption. The
/// `keyStore` argument is accepted for a uniform signature but unused here.
/// See `.docs/flutter-migration-report.md` (Security) for the rationale.
QueryExecutor openPlatformConnection({SecureKeyStore? keyStore}) {
  return driftDatabase(
    name: 'matome',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
