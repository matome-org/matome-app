import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Drift table definitions.
//
// These mirror the apps/mobile expo-sqlite schema *byte-for-byte* in column
// name, type and default so the offline cache is portable across the RN and
// Flutter clients (and so the migration history below reproduces the exact
// `user_version` 1..4 sequence the mobile app shipped).
//
// NOTE (#1433): the legacy RN/expo-sqlite (apps/mobile) client has been DELETED
// — every reference below to "mobile parity", RN portability, or the expo
// migration runner is now a HISTORICAL GHOST. The byte-for-byte column names
// (camelCase `.named()`, `user_version` lineage) are RETAINED on purpose: they
// are the on-disk contract that existing installs replay (m001..m008), so they
// must not be rewritten. New schema slices (m009 archive, m010 transcript) are
// Flutter-only additions with no RN counterpart.
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

  // m007 — matome-centric-pivot (ADR-0003). Every recording is an *Item* of
  // exactly ONE Matome (`recording.matomeId` FK → matomes(id); 1 recording → 1
  // Matome, move never copy). The column is declared NULLABLE here so Drift's
  // ALTER ADD COLUMN can land on legacy rows; the m007 migration then BACKFILLS
  // one Matome per recording and points every row at it, after which the column
  // is non-null for every persisted row. New write paths must create the Matome
  // in the SAME transaction as the recording so the FK never sees an orphan
  // (ADR-0003 invariant 4). The DB keeps it nullable only to allow the additive
  // ALTER without a table rebuild — the contract is "non-null after backfill".
  TextColumn get matomeId =>
      text().named('matome_id').nullable().references(Matomes, #id)();

  // m010 (#1433) — machine-generated, type-specific transcript text. NULLABLE
  // (absent until the transcription pipeline fills it). This is DISTINCT from
  // the user-owned [notes] column above: `notes` is hand-authored and
  // user-mutable; `transcript` is derived/machine-produced and replaced
  // wholesale on regeneration. Sync semantics for the two columns are NOT
  // decided here (task #1434 owns that) — m010 is purely the additive column.
  TextColumn get transcript => text().nullable()();

  // m011 (#1436) — IMMUTABLE snapshot of the legacy `notes` value, captured by
  // the m011 backfill BEFORE any other write so the irreversible
  // notes→transcript copy-forward is reversible-by-construction. This is the
  // RESTORE ANCHOR: to undo the backfill, `UPDATE recordings SET notes =
  // notes_legacy_raw`. It is written exactly once (the m011 step guards on
  // `notes_legacy_raw IS NULL`) and is NEVER read/written by app code — it
  // exists purely as the pre-migration copy of `notes`. NULLABLE: rows whose
  // pre-migration `notes` was NULL snapshot to NULL. Distinct from `notes`
  // (user-owned, mutable) and `transcript` (machine-owned).
  TextColumn get notesLegacyRaw => text().named('notes_legacy_raw').nullable()();

  // m012 (#1449) — the ORIGINAL file extension of an imported document Item
  // (lower-case, no leading dot — e.g. `pdf`, `docx`, `md`). This is a SCHEMA
  // DECISION made up front, NOT retrofitted: the generic document-import path
  // (`mediaType = 'document'`) needs the source extension preserved on the row
  // to drive the file-type icon, the open/extract routing, and the deferred
  // parse/preview — none of which can be recovered from the durable on-disk
  // path (which is renamed to an opaque `import_<uuid>` filename). NULLABLE:
  // legacy rows and audio/image Items (whose `mediaType` already disambiguates)
  // carry NULL. Written once at insert from the picked file's name; never
  // mutated afterwards.
  TextColumn get originalExtension =>
      text().named('original_extension').nullable()();

  // m013 (#1461) — the OWNING USER's Core id, mirrored onto the row from Core's
  // NOT-NULL `recordings.owner_id` (server-enforced — see
  // `MatomeApi.Content.list_recordings`, which filters `owner_id == ^owner_id`).
  // This is the SECURITY-CRITICAL scoping column for the Files view (A01 — Broken
  // Access Control): the cross-matome + Unfiled (`matome_id IS NULL`) + Inbox
  // (`workspace_id IS NULL`) file list MUST be scoped by the owner ON THE ROW
  // ITSELF, never via a JOIN to matome/workspace that is NULL for an orphan row
  // (which would either drop or LEAK an unfiled/inbox file). NULLABLE so Drift's
  // additive ALTER ADD COLUMN lands on legacy rows without a table rebuild; the
  // owner-scoped query treats a NULL owner as "not the current owner" (excluded),
  // so a legacy un-backfilled row can never surface for a concrete owner. New
  // write paths (Core reconcile) populate it from the recording JSON's
  // `owner_id`. Stored as TEXT (matching the other id columns / the stringified
  // Core id convention).
  TextColumn get ownerId => text().named('owner_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The **Matome** — the central entity of the matome-centric pivot (ADR-0003).
///
/// A Matome (まとめ — "a compiled whole") aggregates Items (recordings of
/// `mediaType` audio|image), contacts, notes and summaries about one happening.
/// Every recording belongs to exactly one Matome; a quick voice note is a
/// Matome with a single item.
///
/// Local-first lifecycle (ADR-0004): a Matome is minted `mat_local_<uuid>` and
/// stays Core-less (`coreId` NULL) while in the Inbox (`spaceId == null` —
/// untriaged, local-only, NOT synced). `coreId` is assigned on first sync,
/// which only happens once the Matome is filed into a (synced) Space. This
/// mirrors the proven `recording_ids.dart` / m005 reconciliation pattern.
///
/// `space_id` reuses the existing `workspaces` table (the Space rename is
/// logical — ADR-0003). NULL ⟺ Inbox.
@DataClassName('MatomeRow')
class Matomes extends Table {
  @override
  String get tableName => 'matomes';

  TextColumn get id => text()();

  // FK → workspaces(id) (the Space). NULL ⟺ Inbox ⟺ local-only/untriaged/
  // unsynced (ADR-0004). A Matome enters the sync domain only when filed into a
  // Space.
  TextColumn get spaceId =>
      text().named('space_id').nullable().references(Workspaces, #id)();

  TextColumn get title => text()();

  // Epoch ms of the happening this Matome gathers. Backfilled from the seed
  // recording's `createdAt` (m007).
  IntColumn get happenedAt => integer().named('happened_at')();

  TextColumn get description => text().nullable()();

  // ADR-0003 "open decisions resolved": the aggregated (Matome-level) summary is
  // STORED (denormalized), regenerated when the item set changes. `summaryStale`
  // flags pending regeneration. This task only adds the columns; regeneration is
  // a later wave. The aggregated summary syncs as its own field with a
  // `mergeText`-style null-wipe guard (a sparse Core payload must not erase it).
  TextColumn get aggregatedSummary =>
      text().named('aggregated_summary').nullable()();
  BoolColumn get summaryStale =>
      boolean().named('summary_stale').withDefault(const Constant(false))();

  IntColumn get createdAt => integer().named('created_at')();

  // Reconciled Core numeric id, NULL until the Matome is triaged into a Space
  // and the first sync succeeds (mirrors recordings.coreId / m005).
  IntColumn get coreId => integer().named('core_id').nullable()();

  // Soft-delete (archive) marker (W3, #1409). Epoch ms when archived, NULL ⟺
  // active. Every list/watch query filters `archived_at IS NULL`; the row and
  // its child recordings are retained (recoverable via restore). Mirrors Core's
  // nullable `matomes.archived_at`.
  IntColumn get archivedAt => integer().named('archived_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mirrors the `workspaces` table created by migration 002.
///
/// The physical table is kept named `workspaces` (preserving m002 history and
/// the `recordings.workspaceId` FK lineage). The code/UI concept is **Space**
/// (ADR-0003 — the rename is logical, not physical). m006 extends it with two
/// collaboration-schema columns that are reserved/unenforced (ADR-0004):
///   * `space_type` ∈ { personal | shared | org } (NOT NULL default 'personal')
///   * `owner_id`   — reserved Space owner user id (nullable, unenforced)
@DataClassName('WorkspaceRow')
class Workspaces extends Table {
  @override
  String get tableName => 'workspaces';

  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  IntColumn get isDefault =>
      integer().named('isDefault').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('createdAt')();

  // m006 — Space type discriminator. NOT NULL with a 'personal' default so
  // legacy rows backfill cleanly and the seeded default Space stays personal.
  TextColumn get spaceType =>
      text().named('space_type').withDefault(const Constant('personal'))();

  // m006 — reserved Space owner (user id). Nullable + UNENFORCED until the
  // `matome-collaboration` plan builds ACLs (ADR-0004 "schema-ready").
  TextColumn get ownerId => text().named('owner_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Membership edge of a Space (the RBAC join — ADR-0004).
///
/// m006, reserved/UNENFORCED: the columns and table exist so the collaboration
/// plan can land behaviour later, but no ACL logic reads them today.
/// `role` ∈ { owner | admin | member | viewer }.
@DataClassName('SpaceMemberRow')
class SpaceMembers extends Table {
  @override
  String get tableName => 'space_members';

  TextColumn get id => text()();
  // FK → workspaces(id) (the Space). Reserved; not enforced behaviourally.
  TextColumn get spaceId =>
      text().named('space_id').references(Workspaces, #id)();
  TextColumn get userId => text().named('user_id')();
  TextColumn get role => text().withDefault(const Constant('member'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// An organization that may own Spaces (multi-tenant — ADR-0004).
///
/// m006, reserved/UNENFORCED: present so org-owned Spaces can be modelled by
/// the collaboration plan; no org management exists yet.
@DataClassName('OrganizationRow')
class Organizations extends Table {
  @override
  String get tableName => 'organizations';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer().named('created_at')();

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

/// A **Contact** — an owner-owned person record (ADR-0004 — identity & contacts).
///
/// m008, SCHEMA-READY / NOT ENFORCED: a Contact is owned by a user
/// (`owner_id`), carries a `display_name` and arbitrary JSON `metadata`, and may
/// optionally LINK to a real platform user (`linked_user_id`, reserved). The
/// linked-user *profile-without-consent* BEHAVIOUR is deferred to the
/// `matome-collaboration` plan — this table only adds the columns.
///
/// Minted local-first (`contact_local_<uuid>`, `core_id` NULL until synced),
/// mirroring the Matome id model (see `contact_ids.dart`).
@DataClassName('ContactRow')
class Contacts extends Table {
  @override
  String get tableName => 'contacts';

  TextColumn get id => text()();

  // The owning user's id. Reserved/unenforced — no ACL reads it today.
  TextColumn get ownerId => text().named('owner_id')();

  TextColumn get displayName => text().named('display_name')();

  // Structured contact fields (#1462), mirroring Core's typed columns. All
  // nullable — validation/normalization is enforced Core-side on write.
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get company => text().nullable()();
  TextColumn get title => text().nullable()();

  // Arbitrary JSON map of contact fields (notes, etc). Stored as a TEXT
  // blob; defaults to an empty JSON object so a bare insert is valid.
  TextColumn get metadata =>
      text().withDefault(const Constant('{}'))();

  // Reserved FK → a real platform user. NULLABLE/unenforced: when set, the
  // owner may (eventually) view that user's Matome profile — BEHAVIOUR deferred.
  TextColumn get linkedUserId =>
      text().named('linked_user_id').nullable()();

  IntColumn get createdAt => integer().named('created_at')();

  // Reconciled Core numeric id, NULL until synced (mirrors matomes.coreId).
  IntColumn get coreId => integer().named('core_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Edge: a Contact tagged in a Matome (ADR-0004 — `matome_contacts`).
///
/// m008, SCHEMA-READY. `role` ∈ { organizer | attendee | speaker } (default
/// 'attendee'). UNIQUE(matome_id, contact_id) makes the add idempotent (a
/// re-sync re-adding an existing edge is a no-op — the set-merge rule).
///
/// Deletion-cascade is done by EXPLICIT DAO deletes (ContactsDao), NOT by an
/// on-disk FK `onDelete` clause: this project's drift build does not emit
/// REFERENCES DDL (the existing `matomes.space_id` / `recordings.matome_id`
/// references are relation hints only — see app_database.g.dart), so a runtime
/// FK cascade would silently not fire. `references(...)` is kept as a drift
/// relation hint for query joins.
@DataClassName('MatomeContactRow')
class MatomeContacts extends Table {
  @override
  String get tableName => 'matome_contacts';

  TextColumn get id => text()();
  TextColumn get matomeId => text().named('matome_id').references(Matomes, #id)();
  TextColumn get contactId =>
      text().named('contact_id').references(Contacts, #id)();
  TextColumn get role => text().withDefault(const Constant('attendee'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {matomeId, contactId},
      ];
}

/// Edge: a Contact as a member of a Space (ADR-0004 — `space_contacts`).
///
/// m008, SCHEMA-READY. UNIQUE(space_id, contact_id) → idempotent add. The
/// space FK references `workspaces` (the Space — the rename is logical).
/// Deletion-cascade on Contact delete is done by EXPLICIT DAO deletes (see
/// [MatomeContacts] doc) — no on-disk FK cascade.
@DataClassName('SpaceContactRow')
class SpaceContacts extends Table {
  @override
  String get tableName => 'space_contacts';

  TextColumn get id => text()();
  TextColumn get spaceId =>
      text().named('space_id').references(Workspaces, #id)();
  TextColumn get contactId =>
      text().named('contact_id').references(Contacts, #id)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {spaceId, contactId},
      ];
}

/// Edge: a Matome shared with a user (ADR-0004 — `matome_shares`).
///
/// m008, RESERVED — sharing BEHAVIOUR is deferred to the `matome-collaboration`
/// plan; this table only persists the intent. `permission` defaults to 'read'.
/// Deletion-cascade on Matome delete is done by EXPLICIT DAO deletes (see
/// [MatomeContacts] doc) — no on-disk FK cascade.
@DataClassName('MatomeShareRow')
class MatomeShares extends Table {
  @override
  String get tableName => 'matome_shares';

  TextColumn get id => text()();
  TextColumn get matomeId =>
      text().named('matome_id').references(Matomes, #id)();
  TextColumn get sharedWithUserId => text().named('shared_with_user_id')();
  TextColumn get permission => text().withDefault(const Constant('read'))();

  @override
  Set<Column> get primaryKey => {id};
}
