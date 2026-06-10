import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Drift table definitions.
//
// These mirror the apps/mobile expo-sqlite schema *byte-for-byte* in column
// name, type and default so the offline cache is portable across the RN and
// Flutter clients (and so the migration history below reproduces the exact
// `user_version` 1..4 sequence the mobile app shipped).
//
// Mobile reference (apps/mobile):
//   utils/database.ts            — base `recordings` table + `recording_drafts`
//   utils/migrations/001..004    — notes / workspaces / drafts / media columns
//
// Notable parity choices:
//   * `id` columns are TEXT (recordings/workspaces). The mobile app stores Core
//     numeric ids as strings and also mints local string ids — so TEXT, not int.
//   * `duration` is TEXT ("m:ss"), not a numeric duration — that is the
//     display-formatted value the mobile DB persists.
//   * `isProcessing` is an INTEGER 0/1 flag (SQLite has no bool).
//   * `workspaceId` is nullable and references workspaces(id); NULL == Inbox.
// ---------------------------------------------------------------------------

/// Mirrors the `recordings` table after migrations 001/002/004 have applied.
///
/// Base columns come from utils/database.ts; `notes` (m001), `workspaceId`
/// (m002), `mediaType` + `processingStatus` (m004) are the migrated additions.
@DataClassName('RecordingRow')
class Recordings extends Table {
  @override
  String get tableName => 'recordings';

  // Column names are pinned with `.named()` to the mobile camelCase SQLite
  // schema (drift would otherwise snake_case them), so the on-disk schema is
  // byte-for-byte portable with the RN client.
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get timestamp => text()();
  TextColumn get duration => text()();
  TextColumn get badge => text().withDefault(const Constant('Inbox'))();
  IntColumn get isProcessing =>
      integer().named('isProcessing').withDefault(const Constant(1))();
  TextColumn get audioFilePath => text().named('audioFilePath')();
  IntColumn get createdAt => integer().named('createdAt')();

  // m001 — defaults to NULL on the mobile side (ALTER ADD COLUMN notes TEXT).
  TextColumn get notes => text().nullable()();

  // m002 — nullable FK back to workspaces(id); NULL means the Inbox.
  TextColumn get workspaceId =>
      text().named('workspaceId').nullable().references(Workspaces, #id)();

  // m004 — NOT NULL with defaults so legacy rows backfill cleanly.
  TextColumn get mediaType =>
      text().named('mediaType').withDefault(const Constant('audio'))();
  TextColumn get processingStatus =>
      text().named('processingStatus').withDefault(const Constant('done'))();

  // m005 — local-first id model (plan #43). `id` stays TEXT and now carries a
  // local UUID (`rec_local_<uuid>`) for rows minted before any Core id exists;
  // `coreId` is the reconciled Core numeric id, NULL until upload succeeds. The
  // m005 migration backfills `coreId = CAST(id AS INTEGER)` for legacy rows
  // whose id is a stringified Core id, so they reconcile without a PK remap.
  IntColumn get coreId => integer().named('coreId').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors the `workspaces` table created by migration 002.
@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  @override
  String get tableName => 'workspaces';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  IntColumn get isDefault =>
      integer().named('isDefault').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('createdAt')();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors the `recording_drafts` table (migration 003 / defensive inline copy).
///
/// `id` is an autoincrementing INTEGER PRIMARY KEY; only one draft row is kept
/// at a time (save replaces the prior row).
@DataClassName('RecordingDraftRow')
class RecordingDrafts extends Table {
  @override
  String get tableName => 'recording_drafts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get segmentsJson => text().named('segments_json')();
  IntColumn get durationMs =>
      integer().named('duration_ms').withDefault(const Constant(0))();
}
