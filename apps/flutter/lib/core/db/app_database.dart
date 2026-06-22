import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../features/matome/matome_ids.dart';
import '../observability/app_log.dart';
import '../storage/app_storage.dart';
import 'connection.dart';
import 'db_encryption.dart';
import 'daos/contacts_dao.dart';
import 'daos/matomes_dao.dart';
import 'daos/recordings_dao.dart';
import 'daos/recording_drafts_dao.dart';
import 'daos/spaces_dao.dart';
import 'daos/workspaces_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Schema version. Mirrors `migrations.length` in apps/mobile
/// (utils/migrations/index.ts) — i.e. the four shipped expo-sqlite migrations
/// 001..004, which map to SQLite `user_version` 4 on a fully-migrated mobile
/// device. New schema changes are append-only: bump this and add a step in
/// [MigrationStrategy.onUpgrade].
///
/// v6 (m006, matome-centric-pivot Wave 1) adds collaboration *schema* to the
/// Space (the `workspaces` table): `space_type` + `owner_id` columns and the
/// `space_members` / `organizations` tables. Reserved/UNENFORCED — no ACL
/// behaviour ships until the `matome-collaboration` plan (ADR-0004).
///
/// v7 (m007, matome-centric-pivot — the KEYSTONE data slice) makes the
/// **Matome** the central entity (ADR-0003): adds the `matomes` table and the
/// `recordings.matome_id` FK, and BACKFILLS one Matome per existing recording
/// so every recording is an Item of exactly one Matome. (Note: ADR-0003 drafts
/// this as "m006"; m006 was taken by the Space-evolution slice above, so the
/// Matome slice lands as m007 — the version number, not the ADR prose, is
/// authoritative.)
///
/// v8 (m008, Contacts schema — ADR-0004) adds the owner-owned `contacts` table
/// and the three edge tables `matome_contacts` / `space_contacts` /
/// `matome_shares`. SCHEMA-READY, NOT ENFORCED — no sharing/profile/ACL logic
/// and no UI; behaviour is deferred to the `matome-collaboration` plan. (The
/// task prose drafts this as "m007"; m007 was taken by the Matome slice, so the
/// Contacts slice lands as m008 — the version constant is authoritative.)
///
/// v9 (m009, Matome archive / soft-delete — #1409, W3) adds the nullable
/// `matomes.archived_at` column (epoch ms when archived, NULL ⟺ active). Every
/// matome list/watch query filters `archived_at IS NULL`; the row and its child
/// recordings are RETAINED (recoverable via restore — no hard-delete, no
/// orphan-file cleanup). Additive + nullable, so existing rows backfill to NULL
/// (active) and the step needs no data migration.
///
/// v10 (m010, Recording transcript — #1433) adds the nullable
/// `recordings.transcript` TEXT column: machine-generated, type-specific text,
/// DISTINCT from the user-owned `notes` column (which this slice does NOT
/// touch — sync semantics for the two are task #1434's concern). Drift's ALTER
/// ADD COLUMN backfills existing rows to NULL (transcript absent until the
/// pipeline produces one), so no data migration. Additive + nullable +
/// reversible-by-design. (The task prose calls this "m009"; m009/v9 was already
/// taken by the archive slice above, so — per the convention used for
/// m006/m007/m008 — the transcript slice lands as m010. The version constant is
/// authoritative, not the prose.)
///
/// v11 (m011, backfill transcript from legacy notes — #1436) is THE
/// IRREVERSIBLE data slice, made reversible-by-construction. Historical `notes`
/// commingles {old machine transcript copied by the legacy sync} + {user edits}
/// with NO discriminator, so the only safe rule is COPY-FORWARD, never split.
/// Two moves, in order:
///   1. SNAPSHOT FIRST — add the immutable `recordings.notes_legacy_raw` TEXT
///      column and copy the current `notes` into it for EVERY existing row
///      BEFORE any other write. This is the reversibility anchor:
///      restore = `UPDATE recordings SET notes = notes_legacy_raw`.
///   2. COPY-FORWARD — for AUDIO rows where `transcript` IS NULL/empty and
///      `notes` is non-empty, copy `notes` → `transcript`. NEVER blank, delete
///      or modify `notes`; only fill an empty transcript.
/// Both moves are IDEMPOTENT (snapshot guards `notes_legacy_raw IS NULL`;
/// copy-forward guards `transcript IS NULL OR ''`), so a re-run / re-open is a
/// no-op. The column add is additive + nullable; `notes` is byte-conserved.
/// (m010/v10 was the transcript column, so the backfill lands as m011 — the
/// version constant is authoritative, not the prose.)
///
/// PRODUCTION-RUN GATING: landing this migration code does NOT authorize
/// running it against any real/dev/prod DB. The production run remains gated on
/// (a) tasks 1433-1435 (transcript column + inbox_sync/save write-authority)
/// merged AND deploy-baked — backfilling before those leaks are sealed would
/// re-poison the data — and (b) explicit human authorization.
///
/// v12 (m012, document-import original extension — #1449) adds the nullable
/// `recordings.original_extension` TEXT column: the lower-case source extension
/// (no dot) of an imported document Item, captured ONCE at insert so the
/// generic `mediaType = 'document'` path can drive the file-type icon, the
/// open/extract routing and the deferred parse — none recoverable from the
/// renamed durable on-disk path. Additive + nullable: Drift's ALTER ADD COLUMN
/// backfills every existing row to NULL (legacy + audio/image Items carry NULL,
/// their `mediaType` already disambiguates), so there is NO data migration and
/// `notes`/`transcript`/all other columns are byte-conserved. Reversible-by
/// -design (the column is never read by older code paths). (m011/v11 was the
/// notes backfill, so the extension column lands as m012 — the version constant
/// is authoritative, not the prose.)
///
/// v13 (m013, Files owner-scoping column — #1461) adds the nullable
/// `recordings.owner_id` TEXT column, mirroring Core's NOT-NULL
/// `recordings.owner_id`. This is the SECURITY-CRITICAL (A01 — Broken Access
/// Control) scoping column for the Files view: the cross-matome + Unfiled
/// (`matome_id IS NULL`) + Inbox (`workspace_id IS NULL`) file list is scoped by
/// the owner ON THE ROW, never via a NULL-able JOIN to matome/workspace.
/// Additive + nullable: Drift's ALTER ADD COLUMN backfills existing rows to
/// NULL, and the owner-scoped query excludes NULL-owner rows (a legacy
/// un-backfilled row can never surface for a concrete owner), so there is no
/// data migration. The Core reconcile path populates it from the recording
/// JSON's `owner_id`. (The version constant is authoritative, not the prose.)
const int kSchemaVersion = 14;

/// The offline-first local store.
///
/// Cross-platform (native sqlite3 + web wasm) Drift database replicating the
/// apps/mobile schema and migration history. Independent of the HTTP layer —
/// repositories expose plain Dart; the sync layer (Wave 3) decides when to pull
/// from Core and write through these DAOs.
@DriftDatabase(
  tables: [
    Recordings,
    Workspaces,
    RecordingDrafts,
    SpaceMembers,
    Organizations,
    Matomes,
    Contacts,
    MatomeContacts,
    SpaceContacts,
    MatomeShares,
  ],
  daos: [
    RecordingsDao,
    WorkspacesDao,
    RecordingDraftsDao,
    SpacesDao,
    MatomesDao,
    ContactsDao,
  ],
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
          AppLog.event(LogCat.db, 'db onCreate version=$kSchemaVersion');
          await m.createAll();
          await _seedDefaultWorkspace();
        },
        // Upgrade path ports the expo-sqlite migrations step by step so a DB
        // opened at an older version reaches the current schema identically to
        // the mobile runner (index == version).
        onUpgrade: (m, from, to) async {
          AppLog.event(LogCat.db, 'db onUpgrade $from->$to');
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
          // m005 — local-first id model (plan #43): add nullable `coreId` and
          // backfill it from legacy rows whose stringified `id` is a Core int.
          // The GLOB guard APPROXIMATES Dart's `int.tryParse(id)` for canonical
          // Core ids (a leading-sign-optional run of digits → UUID-style
          // `rec_local_…` ids stay NULL). It is NOT exact: it accepts embedded
          // `-` (e.g. `12-34`) that `int.tryParse` rejects, and does not bound
          // length, so an overflowing all-digit string would diverge too. That
          // is acceptable here because real Core ids are small positive ints —
          // no actual row matches the divergent cases. The GLOB still prevents
          // SQLite's bare CAST from silently coercing non-numeric text to 0.
          // (This is an applied, irreversible migration — do NOT change the SQL.)
          if (from < 5) {
            await m.addColumn(recordings, recordings.coreId);
            await customStatement(
              "UPDATE recordings SET coreId = CAST(id AS INTEGER) "
              "WHERE coreId IS NULL "
              "AND (id GLOB '[0-9]*' OR id GLOB '-[0-9]*') "
              "AND id NOT GLOB '*[^0-9-]*' "
              "AND id GLOB '*[0-9]*'",
            );
          }
          // m006 — Space collaboration schema (matome-centric-pivot Wave 1,
          // ADR-0003/0004). The Space rename is LOGICAL: the table stays named
          // `workspaces`. Two columns are added to it and two reserved tables
          // are created. All collaboration columns are UNENFORCED — no ACL
          // logic reads them until the `matome-collaboration` plan.
          //
          // Both columns are NULLABLE/defaulted, so Drift's ALTER ADD COLUMN
          // backfills existing rows: `space_type` → 'personal' (its column
          // default), `owner_id` → NULL. The seeded default Space ('Pessoal',
          // isDefault=1) therefore becomes type 'personal' — it is the default
          // triage destination (ADR-0004). The explicit UPDATE below is a
          // belt-and-braces backfill in case a prior build had already created
          // the column without the default.
          //
          // DOWN-migration / reversal (no automatic downgrade path in Drift;
          // documented for discipline — additive, low-risk, no prod users):
          //   DROP TABLE IF EXISTS organizations;
          //   DROP TABLE IF EXISTS space_members;
          //   -- SQLite < 3.35 cannot DROP COLUMN; rebuild `workspaces` without
          //   -- space_type/owner_id via a copy table if a true v5 shape is
          //   -- required. Leaving the columns in place is otherwise harmless.
          //   PRAGMA user_version = 5;
          if (from < 6) {
            await m.addColumn(workspaces, workspaces.spaceType);
            await m.addColumn(workspaces, workspaces.ownerId);
            await customStatement(
              "UPDATE workspaces SET space_type = 'personal' "
              "WHERE space_type IS NULL",
            );
            await m.createTable(spaceMembers);
            await m.createTable(organizations);
          }
          // m007 — Matome becomes the central entity (matome-centric-pivot,
          // ADR-0003 — the KEYSTONE data slice). Adds the `matomes` table and
          // the `recordings.matome_id` FK, then BACKFILLS one Matome per
          // existing recording so every recording is an Item of exactly one
          // Matome (ADR-0003 invariant 1/2). The Matome is minted local-only
          // (`mat_local_<uuid>`, `core_id` NULL — Inbox/untriaged until
          // triaged into a Space; ADR-0004) and takes its `space_id` from the
          // recording's existing `workspaceId` so a recording already filed in a
          // Space yields a Space-filed Matome, and an Inbox recording
          // (workspaceId NULL) yields an Inbox Matome.
          //
          // ORDERING: the Matome row is INSERTed BEFORE the recording is
          // pointed at it, so the (eventually-non-null) FK never sees an orphan
          // window (ADR-0003 invariant 4). `recordings.matomeId` is added as a
          // nullable column (Drift ALTER ADD can't add a NOT NULL column to a
          // populated table), then the backfill makes it non-null for every
          // row; the WHERE matome_id IS NULL guard makes the whole step
          // IDEMPOTENT (a re-run finds no un-backfilled rows and creates no
          // duplicate Matomes).
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, low-risk, no prod users):
          //   -- SQLite < 3.35 cannot DROP COLUMN; to reach a true v6 shape,
          //   -- rebuild `recordings` without `matome_id` via a copy table.
          //   -- Leaving the column in place is otherwise harmless.
          //   DROP TABLE IF EXISTS matomes;
          //   PRAGMA user_version = 6;
          if (from < 7) {
            await m.createTable(matomes);
            await m.addColumn(recordings, recordings.matomeId);
            await _backfillMatomesPerRecording();
          }
          // m008 — Contacts schema (ADR-0004). Creates the owner-owned
          // `contacts` table and the three edge tables `matome_contacts`,
          // `space_contacts` and `matome_shares`. New domain — NO backfill.
          // SCHEMA-READY / NOT ENFORCED: no sharing / profile / ACL logic and
          // no UI ships here (deferred to the `matome-collaboration` plan).
          //
          // Deletion-cascade is EXPLICIT (ContactsDao/MatomesDao transactions),
          // NOT an on-disk FK clause: this drift build emits no REFERENCES DDL,
          // so a runtime PRAGMA cascade would not fire. Deleting a Contact drops
          // its matome_contacts/space_contacts edges; deleting a Matome drops
          // its matome_contacts/matome_shares edges — never the counterpart row.
          // The M:N add is idempotent (UNIQUE(matome_id, contact_id) /
          // UNIQUE(space_id, contact_id)): a re-sync re-adding an existing edge
          // is a no-op and never drops other members (set-merge).
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, new domain, no prod users):
          //   DROP TABLE IF EXISTS matome_shares;
          //   DROP TABLE IF EXISTS space_contacts;
          //   DROP TABLE IF EXISTS matome_contacts;
          //   DROP TABLE IF EXISTS contacts;
          //   PRAGMA user_version = 7;
          if (from < 8) {
            await m.createTable(contacts);
            await m.createTable(matomeContacts);
            await m.createTable(spaceContacts);
            await m.createTable(matomeShares);
          }
          // m009 — Matome archive / soft-delete (#1409, W3). Adds the nullable
          // `matomes.archived_at` column (epoch ms when archived, NULL ⟺
          // active). Drift's ALTER ADD COLUMN backfills existing rows to NULL,
          // so every pre-existing Matome stays active — no data migration. The
          // row + its child recordings are RETAINED on archive (recoverable via
          // restore); only the list/watch queries hide it.
          //
          // GUARD `from >= 7`: the `matomes` table is created by m007 via
          // `m.createTable(matomes)`, which always emits the CURRENT table
          // definition — already including `archived_at`. So a DB upgrading from
          // before v7 reaches v7 with the column already present; re-adding it
          // here would throw "duplicate column". Only a DB that already had the
          // m007/m008-era `matomes` (no archived_at) needs the ALTER.
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, nullable, no prod users):
          //   -- SQLite < 3.35 cannot DROP COLUMN; to reach a true v8 shape,
          //   -- rebuild `matomes` without `archived_at` via a copy table.
          //   -- Leaving the column in place is otherwise harmless.
          //   PRAGMA user_version = 8;
          if (from >= 7 && from < 9) {
            await m.addColumn(matomes, matomes.archivedAt);
          }
          // m010 — Recording transcript (#1433). Adds the nullable
          // `recordings.transcript` TEXT column (machine-generated,
          // type-specific text — DISTINCT from the user-owned `notes` column,
          // which is untouched here; sync semantics for the pair are task
          // #1434). Drift's ALTER ADD COLUMN backfills existing rows to NULL
          // (no transcript until the pipeline produces one), so no data
          // migration. The `recordings` table predates every migration in this
          // strategy, so — unlike m009's `matomes` guard — no `from >=` floor
          // is needed: any DB reaching here from < 10 already has `recordings`
          // WITHOUT `transcript`, and the column is added exactly once.
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, nullable, no prod users):
          //   -- SQLite < 3.35 cannot DROP COLUMN; to reach a true v9 shape,
          //   -- rebuild `recordings` without `transcript` via a copy table.
          //   -- Leaving the column in place is otherwise harmless.
          //   PRAGMA user_version = 9;
          if (from < 10) {
            await m.addColumn(recordings, recordings.transcript);
          }
          // m011 — backfill transcript from legacy notes (#1436). THE
          // IRREVERSIBLE data slice, made reversible-by-construction. Historical
          // `notes` commingles {old machine transcript copied by the legacy
          // sync} + {user edits} with NO discriminator, so the only safe rule is
          // COPY-FORWARD, never split. Done in [_snapshotAndCopyForwardNotes].
          //
          // ORDERING IS LOAD-BEARING: the snapshot (notes → notes_legacy_raw) is
          // written for every row BEFORE the copy-forward, so even a crash
          // between the two leaves the restore anchor intact.
          //
          // IDEMPOTENT: the ALTER ADD COLUMN runs once (from < 11); the snapshot
          // UPDATE guards `notes_legacy_raw IS NULL`; the copy-forward UPDATE
          // guards `transcript IS NULL OR transcript = ''` AND `mediaType =
          // 'audio'`. A re-run / re-open finds nothing to do.
          //
          // NON-LOSSY BY CONSTRUCTION: `notes` is NEVER written — only read.
          // `notes_legacy_raw` is the immutable pre-migration copy of `notes`.
          // `transcript` is only ever FILLED when empty, never overwritten.
          //
          // RESTORE PROCEDURE (no automatic Drift downgrade; documented for
          // discipline). The backfill is reversed WITHOUT data loss because the
          // pre-migration `notes` was snapshotted first:
          //   -- 1. Restore notes to their exact pre-migration bytes:
          //   UPDATE recordings SET notes = notes_legacy_raw;
          //   -- 2. (optional) undo the copy-forward — clear transcripts that
          //   --    this backfill filled from notes. Only safe if the fixed sync
          //   --    has not since written a real transcript; prefer (1) alone.
          //   --    UPDATE recordings SET transcript = NULL
          //   --      WHERE mediaType = 'audio' AND transcript = notes_legacy_raw;
          //   -- 3. SQLite < 3.35 cannot DROP COLUMN; leaving notes_legacy_raw in
          //   --    place is harmless. To reach a true v10 shape, rebuild
          //   --    `recordings` without it via a copy table.
          //   PRAGMA user_version = 10;
          if (from < 11) {
            await m.addColumn(recordings, recordings.notesLegacyRaw);
            await _snapshotAndCopyForwardNotes();
          }
          // m012 — document-import original extension (#1449). Adds the nullable
          // `recordings.original_extension` TEXT column (lower-case source
          // extension, no dot — e.g. 'pdf'). Drift's ALTER ADD COLUMN backfills
          // existing rows to NULL (no extension recorded until the generic
          // document-import path writes one at insert), so no data migration.
          // The `recordings` table predates every migration in this strategy, so
          // — like m010/m011 and unlike m009's `matomes` guard — no `from >=`
          // floor is needed: any DB reaching here from < 12 already has
          // `recordings` WITHOUT `original_extension`, and the column is added
          // exactly once. NON-LOSSY: this step ONLY adds a column; no existing
          // column is read or written.
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, nullable, no prod users):
          //   -- SQLite < 3.35 cannot DROP COLUMN; to reach a true v11 shape,
          //   -- rebuild `recordings` without `original_extension` via a copy
          //   -- table. Leaving the column in place is otherwise harmless.
          //   PRAGMA user_version = 11;
          if (from < 12) {
            await m.addColumn(recordings, recordings.originalExtension);
          }
          // m013 — owner-scoping column on recordings (#1461). Mirrors Core's
          // NOT-NULL `recordings.owner_id`; the SECURITY-CRITICAL scope for the
          // Files view's cross-matome + Unfiled + Inbox list. Additive +
          // nullable: Drift's ALTER ADD COLUMN backfills every existing row to
          // NULL. No data backfill — a legacy NULL owner is treated as "not the
          // current owner" by the owner-scoped query (excluded, never leaked);
          // the Core reconcile path populates it on next sync from the
          // recording JSON's `owner_id`.
          if (from < 13) {
            await m.addColumn(recordings, recordings.ownerId);
          }
          // m014 — structured contact fields (#1462). Adds the nullable
          // `contacts.email/phone/company/title` TEXT columns, mirroring Core's
          // typed columns. Validation/normalization is enforced Core-side on
          // write; the local store just persists what Core returns. Drift's
          // ALTER ADD COLUMN backfills existing rows to NULL — no data
          // migration.
          //
          // GUARD `from >= 8`: the `contacts` table is created by m008 via
          // `m.createTable(contacts)`, which always emits the CURRENT table
          // definition — already including these four columns. A DB upgrading
          // from before v8 reaches v8 with the columns already present, so
          // re-adding them here would throw "duplicate column". Only a DB that
          // already had the m008-era `contacts` (no structured fields) needs
          // the ALTER.
          //
          // DOWN-migration / reversal (no automatic Drift downgrade; documented
          // for discipline — additive, nullable, no prod users):
          //   -- SQLite < 3.35 cannot DROP COLUMN; to reach a true v13 shape,
          //   -- rebuild `contacts` without these columns via a copy table.
          //   -- Leaving the columns in place is otherwise harmless.
          //   PRAGMA user_version = 13;
          if (from >= 8 && from < 14) {
            await m.addColumn(contacts, contacts.email);
            await m.addColumn(contacts, contacts.phone);
            await m.addColumn(contacts, contacts.company);
            await m.addColumn(contacts, contacts.title);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await _relocateLegacyMedia();
        },
      );

  /// One-time, best-effort: move pre-existing `import_*` / `segment_*` media out
  /// of the Documents root into the dedicated Matome folder, then rewrite the
  /// absolute paths stored on `recordings.audio_file_path` so the moved files
  /// stay playable. Idempotent (only rows still pointing at the old root match)
  /// and guarded — a fresh install, web, or a test in-memory DB (no documents
  /// dir plugin) simply skips it.
  Future<void> _relocateLegacyMedia() async {
    // Under `flutter test` the path_provider channel has no handler and
    // `getApplicationDocumentsDirectory()` HANGS (never throws), so the
    // try/catch below cannot rescue it — every DB-opening test would stall.
    // Production runs always pass this guard.
    if (isRunningFlutterTest) return;
    try {
      final dir = await matomeStorageDir();
      final moved = await moveLegacyMediaInto(dir);
      if (moved == null || moved.oldDir == moved.newDir) return;
      await rewriteLegacyMediaPaths(moved.oldDir, moved.newDir);
      AppLog.event(
        LogCat.db,
        'legacy media relocated ${moved.oldDir} -> ${moved.newDir}',
      );
    } catch (e, st) {
      // Best-effort relocation — never block app start on it.
      AppLog.error(LogCat.db, 'legacy media relocation failed', e, st);
    }
  }

  /// Rewrites the stored absolute media paths of legacy `import_*` / `segment_*`
  /// rows from under [oldDir] to [newDir] (the new Matome folder), preserving the
  /// filename. Split out from [_relocateLegacyMedia] (which is gated off under
  /// `flutter test`) so the raw SQL — and the column name — can be unit-tested.
  ///
  /// NB: the SQL column is camelCase `audioFilePath` (a legacy name carried over
  /// from the original schema), NOT snake_case — only `matome_id` and the
  /// contacts tables use snake_case. Referencing `audio_file_path` here threw
  /// "no such column" and silently skipped every relocation.
  @visibleForTesting
  Future<void> rewriteLegacyMediaPaths(String oldDir, String newDir) {
    return customStatement(
      'UPDATE recordings SET audioFilePath = '
      '? || substr(audioFilePath, ?) '
      'WHERE audioFilePath LIKE ? OR audioFilePath LIKE ?',
      [
        '$newDir/',
        oldDir.length + 2, // skip the "<oldDir>/" prefix (1-indexed)
        '$oldDir/import_%',
        '$oldDir/segment_%',
      ],
    );
  }

  /// Inserts the seeded "Pessoal" default workspace (the default personal
  /// Space), mirroring migration 002's `INSERT OR IGNORE`. Idempotent.
  ///
  /// `spaceType` is pinned to 'personal' — this is the default triage
  /// destination (ADR-0004). On a fresh install (onCreate) the column exists
  /// from `createAll()`; on the m002 upgrade path the column is absent until
  /// m006 runs, so the companion only sets it when meaningful (the column
  /// default 'personal' covers the pre-m006 insert).
  Future<void> _seedDefaultWorkspace() async {
    await into(workspaces).insert(
      WorkspacesCompanion.insert(
        id: 'ws_default_personal',
        name: 'Pessoal',
        isDefault: const Value(1),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        spaceType: const Value('personal'),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// m007 backfill: create exactly one Matome per existing recording and point
  /// the recording at it (ADR-0003 invariant 1/2 — every recording ∈ exactly
  /// one Matome). Each Matome is minted local-only (`mat_local_<uuid>`,
  /// `core_id` NULL); its `space_id` is the recording's existing `workspaceId`
  /// (so an Inbox recording → an Inbox Matome, a filed recording → a filed
  /// Matome) and `happened_at` is the recording's `createdAt`.
  ///
  /// Per row the Matome is INSERTED FIRST, then the recording's `matome_id` is
  /// set — the FK never sees an orphan window. The `matome_id IS NULL` filter
  /// makes the whole backfill IDEMPOTENT: a re-run (or a partial prior run)
  /// only touches recordings that still lack a Matome, so no duplicate Matomes
  /// are ever created. Runs inside the surrounding migration so a failure rolls
  /// the whole step back.
  Future<void> _backfillMatomesPerRecording() async {
    // Read raw so this does not depend on the generated row mapper being in
    // sync with intermediate migration shapes.
    final rows = await customSelect(
      'SELECT id, title, createdAt, workspaceId FROM recordings '
      'WHERE matome_id IS NULL',
    ).get();

    for (final row in rows) {
      final recordingId = row.read<String>('id');
      final title = row.read<String>('title');
      final createdAt = row.read<int>('createdAt');
      final workspaceId = row.read<String?>('workspaceId');
      final matomeId = mintLocalMatomeId();

      // 1. Insert the Matome FIRST so the FK target exists before any recording
      //    references it (no orphan / NOT-NULL-after-backfill violation).
      await into(matomes).insert(
        MatomesCompanion.insert(
          id: matomeId,
          spaceId: Value(workspaceId),
          title: title,
          happenedAt: createdAt,
          createdAt: createdAt,
        ),
      );

      // 2. Point the recording at its freshly-created Matome.
      await customStatement(
        'UPDATE recordings SET matome_id = ? WHERE id = ?',
        [matomeId, recordingId],
      );
    }
  }

  /// m011 backfill (#1436): snapshot legacy `notes` then copy-forward into an
  /// empty `transcript` for audio rows — THE IRREVERSIBLE step, made
  /// reversible-by-construction. Runs inside the surrounding migration so a
  /// failure rolls the whole step back.
  ///
  /// NON-LOSSY BY CONSTRUCTION — the two statements below NEVER write `notes`:
  ///
  ///   1. SNAPSHOT FIRST: copy the current `notes` into the immutable
  ///      `notes_legacy_raw` column for every row whose snapshot is still empty.
  ///      This is the restore anchor (`UPDATE recordings SET notes =
  ///      notes_legacy_raw`). It MUST precede the copy-forward so the
  ///      pre-migration bytes are captured before anything else touches the row.
  ///      Guard `notes_legacy_raw IS NULL` makes it idempotent and prevents a
  ///      re-run from re-snapshotting a (possibly later-edited) `notes`.
  ///
  ///   2. COPY-FORWARD: for AUDIO rows (`mediaType = 'audio'`) whose
  ///      `transcript` is NULL/empty and whose `notes` is non-empty, set
  ///      `transcript = notes`. `notes` is only READ here — never blanked,
  ///      deleted or modified. The `transcript IS NULL OR transcript = ''` guard
  ///      makes it idempotent and ensures a real transcript (e.g. one the fixed
  ///      sync already wrote) is NEVER overwritten.
  ///
  /// Idempotent end-to-end: re-running both UPDATEs after the first pass matches
  /// no rows (snapshots already set, target transcripts already filled).
  Future<void> _snapshotAndCopyForwardNotes() async {
    // 1. SNAPSHOT FIRST — immutable copy of pre-migration `notes`.
    await customStatement(
      'UPDATE recordings SET notes_legacy_raw = notes '
      'WHERE notes_legacy_raw IS NULL',
    );
    // 2. COPY-FORWARD — fill empty transcripts of audio rows from notes.
    //    `notes` is read-only here; only `transcript` is written.
    await customStatement(
      "UPDATE recordings SET transcript = notes "
      "WHERE mediaType = 'audio' "
      "AND (transcript IS NULL OR transcript = '') "
      "AND notes IS NOT NULL AND notes != ''",
    );
  }
}
