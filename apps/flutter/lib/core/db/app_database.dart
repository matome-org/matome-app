import 'package:drift/drift.dart';

import 'connection.dart';
import 'db_encryption.dart';
import 'daos/recordings_dao.dart';
import 'daos/recording_drafts_dao.dart';
import 'daos/workspaces_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Schema version. Mirrors `migrations.length` in apps/mobile
/// (utils/migrations/index.ts) — i.e. the four shipped expo-sqlite migrations
/// 001..004, which map to SQLite `user_version` 4 on a fully-migrated mobile
/// device. New schema changes are append-only: bump this and add a step in
/// [MigrationStrategy.onUpgrade].
const int kSchemaVersion = 4;

/// The offline-first local store.
///
/// Cross-platform (native sqlite3 + web wasm) Drift database replicating the
/// apps/mobile schema and migration history. Independent of the HTTP layer —
/// repositories expose plain Dart; the sync layer (Wave 3) decides when to pull
/// from Core and write through these DAOs.
@DriftDatabase(
  tables: [Recordings, Workspaces, RecordingDrafts],
  daos: [RecordingsDao, WorkspacesDao, RecordingDraftsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Production constructor: opens the platform connection, SQLCipher-encrypted
  /// on native (key from [keyStore], defaulting to `flutter_secure_storage`).
  AppDatabase({SecureKeyStore? keyStore})
      : super(openConnection(keyStore: keyStore));

  /// Test constructor — pass a [NativeDatabase.memory] executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Fresh install: build the fully-migrated schema in one shot. Drift's
        // generated `createAll()` produces the same final tables/columns the
        // mobile app reaches after running 001..004.
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultWorkspace();
        },
        // Upgrade path ports the expo-sqlite migrations step by step so a DB
        // opened at an older version reaches the current schema identically to
        // the mobile runner (index == version).
        onUpgrade: (m, from, to) async {
          // m001 — add `notes` to recordings.
          if (from < 1) {
            await m.addColumn(recordings, recordings.notes);
          }
          // m002 — workspaces table + workspaceId FK + default workspace.
          if (from < 2) {
            await m.createTable(workspaces);
            await m.addColumn(recordings, recordings.workspaceId);
            await _seedDefaultWorkspace();
          }
          // m003 — recording_drafts table.
          if (from < 3) {
            await m.createTable(recordingDrafts);
          }
          // m004 — mediaType + processingStatus on recordings.
          if (from < 4) {
            await m.addColumn(recordings, recordings.mediaType);
            await m.addColumn(recordings, recordings.processingStatus);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Inserts the seeded "Pessoal" default workspace, mirroring migration 002's
  /// `INSERT OR IGNORE`. Idempotent.
  Future<void> _seedDefaultWorkspace() async {
    await into(workspaces).insert(
      WorkspacesCompanion.insert(
        id: 'ws_default_personal',
        name: 'Pessoal',
        isDefault: const Value(1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
