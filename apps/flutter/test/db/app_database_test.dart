import 'dart:convert';
import 'dart:io';

// `isNull`/`isNotNull` collide with matcher's — we only need Value/companions
// from drift here, so hide the column-expression helpers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/features/contacts/contact_ids.dart';
import 'package:matome_flutter/features/matome/matome_ids.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

// ---------------------------------------------------------------------------
// Drift offline-store tests. Mirrors apps/mobile unit coverage:
//   * migrations.unit.test.ts        — schema shape + version
//   * recordingService.ts tests      — CRUD, inbox, date-range, day+workspace
//   * draftRecordingService.ts        — save/load/delete (single-row)
//   * workspaceService.ts             — CRUD + delete returns recordings to inbox
//
// Every test uses an in-memory NativeDatabase so no native sqlite file or
// path_provider is required.
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

const int _kMsPerDay = 24 * 60 * 60 * 1000;

RecordingsCompanion _recording({
  required String id,
  String title = 'Untitled',
  String? summary,
  String timestamp = '9:00 AM',
  String duration = '0:30',
  String badge = 'Inbox',
  int isProcessing = 0,
  String audioFilePath = '/tmp/a.m4a',
  required int createdAt,
  String? notes,
  String? workspaceId,
  String mediaType = 'audio',
  String processingStatus = 'done',
}) {
  return RecordingsCompanion.insert(
    id: id,
    title: title,
    summary: Value(summary),
    timestamp: timestamp,
    duration: duration,
    badge: Value(badge),
    isProcessing: Value(isProcessing),
    audioFilePath: audioFilePath,
    createdAt: createdAt,
    notes: Value(notes),
    workspaceId: Value(workspaceId),
    mediaType: Value(mediaType),
    processingStatus: Value(processingStatus),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = _memDb());
  tearDown(() => db.close());

  // -------------------------------------------------------------------------
  // (a) Schema + migration version (mirrors migrations.unit.test.ts)
  // -------------------------------------------------------------------------
  group('schema & migration version', () {
    test(
      'schemaVersion is 8 (…m006 Space + m007 Matome + m008 Contacts)',
      () {
        expect(db.schemaVersion, 8);
      },
    );

    test(
      'onCreate builds recordings/workspaces/recording_drafts + m006 tables',
      () async {
        final names = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name NOT LIKE 'sqlite_%'",
            )
            .map((r) => r.read<String>('name'))
            .get();
        expect(
          names,
          containsAll(<String>[
            'recordings',
            'workspaces',
            'recording_drafts',
            'space_members', // m006
            'organizations', // m006
            'matomes', // m007
            'contacts', // m008
            'matome_contacts', // m008
            'space_contacts', // m008
            'matome_shares', // m008
          ]),
        );
      },
    );

    test('workspaces has the m006 Space columns', () async {
      final cols = await db
          .customSelect('PRAGMA table_info(workspaces)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        cols,
        containsAll(<String>[
          'id',
          'name',
          'isDefault',
          'createdAt',
          'space_type', // m006
          'owner_id', // m006
        ]),
      );
    });

    test('recordings table has the migrated column contract', () async {
      final cols = await db
          .customSelect('PRAGMA table_info(recordings)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        cols,
        containsAll(<String>[
          'id',
          'title',
          'summary',
          'timestamp',
          'duration',
          'badge',
          'isProcessing',
          'audioFilePath',
          'createdAt',
          'notes', // m001
          'workspaceId', // m002
          'mediaType', // m004
          'processingStatus', // m004
          'coreId', // m005
          'matome_id', // m007
        ]),
      );
    });

    test('matomes has the m007 column contract', () async {
      final cols = await db
          .customSelect('PRAGMA table_info(matomes)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        cols,
        containsAll(<String>[
          'id',
          'space_id',
          'title',
          'happened_at',
          'description',
          'aggregated_summary',
          'summary_stale',
          'created_at',
          'core_id',
        ]),
      );
    });

    test('recording_drafts has the exact m003 column contract', () async {
      final cols = await db
          .customSelect('PRAGMA table_info(recording_drafts)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        cols,
        containsAll(<String>[
          'id',
          'created_at',
          'segments_json',
          'duration_ms',
        ]),
      );
    });

    test(
      'workspaces seeds the default "Pessoal" workspace (m002 INSERT OR IGNORE)',
      () async {
        final all = await db.workspacesDao.getWorkspaces();
        expect(all, hasLength(1));
        expect(all.single.id, 'ws_default_personal');
        expect(all.single.name, 'Pessoal');
        expect(all.single.isDefault, 1);
        // m006 — the default Space is the personal triage destination.
        expect(all.single.spaceType, 'personal');
        expect(all.single.ownerId, isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // (b) recordings CRUD + getInbox + date-range + day-with-workspace
  // -------------------------------------------------------------------------
  group('recordings DAO', () {
    test('insert + getById + getAll (newest first)', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(
        _recording(id: 'r1', title: 'One', createdAt: 100),
      );
      await dao.insertRecording(
        _recording(id: 'r2', title: 'Two', createdAt: 300),
      );
      await dao.insertRecording(
        _recording(id: 'r3', title: 'Three', createdAt: 200),
      );

      final one = await dao.getRecordingById('r1');
      expect(one?.title, 'One');

      final all = await dao.getAllRecordings();
      expect(all.map((r) => r.id), ['r2', 'r3', 'r1']); // createdAt DESC
    });

    test('getInbox returns only workspaceId IS NULL', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(_recording(id: 'inbox1', createdAt: 10));
      await dao.insertRecording(
        _recording(
          id: 'ws1',
          createdAt: 20,
          workspaceId: 'ws_default_personal',
        ),
      );
      await dao.insertRecording(_recording(id: 'inbox2', createdAt: 30));

      final inbox = await dao.getInboxRecordings();
      expect(inbox.map((r) => r.id), ['inbox2', 'inbox1']);
    });

    test('update writes only patched fields; delete removes the row', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(
        _recording(id: 'r1', title: 'Old', summary: 's', createdAt: 1),
      );

      await dao.updateRecording(
        'r1',
        const RecordingsCompanion(title: Value('New'), isProcessing: Value(1)),
      );
      final updated = await dao.getRecordingById('r1');
      expect(updated?.title, 'New');
      expect(updated?.isProcessing, 1);
      expect(updated?.summary, 's'); // untouched

      await dao.deleteRecording('r1');
      expect(await dao.getRecordingById('r1'), isNull);
    });

    test('upsert inserts then updates on conflict', () async {
      final dao = db.recordingsDao;
      await dao.upsertRecording(
        _recording(id: 'r1', title: 'First', createdAt: 1),
      );
      await dao.upsertRecording(
        _recording(id: 'r1', title: 'Second', createdAt: 2),
      );
      final row = await dao.getRecordingById('r1');
      expect(row?.title, 'Second');
      expect(await dao.getAllRecordings(), hasLength(1));
    });

    test('recordingsByDateRange is inclusive of both bounds, DESC', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(_recording(id: 'before', createdAt: 99));
      await dao.insertRecording(_recording(id: 'lo', createdAt: 100));
      await dao.insertRecording(_recording(id: 'mid', createdAt: 150));
      await dao.insertRecording(_recording(id: 'hi', createdAt: 200));
      await dao.insertRecording(_recording(id: 'after', createdAt: 201));

      final rows = await dao.recordingsByDateRange(100, 200);
      expect(rows.map((r) => r.id), ['hi', 'mid', 'lo']);
    });

    test('recordingsByDay covers the full local day window', () async {
      final dao = db.recordingsDao;
      const dayStart = 1_700_000_000_000;
      await dao.insertRecording(_recording(id: 'start', createdAt: dayStart));
      await dao.insertRecording(
        _recording(id: 'endish', createdAt: dayStart + _kMsPerDay - 1),
      );
      await dao.insertRecording(
        _recording(id: 'nextDay', createdAt: dayStart + _kMsPerDay),
      );

      final rows = await dao.recordingsByDay(dayStart);
      expect(rows.map((r) => r.id), containsAll(<String>['start', 'endish']));
      expect(rows.map((r) => r.id), isNot(contains('nextDay')));
    });

    test(
      'recordingsByDayWithWorkspace LEFT JOINs the workspace name',
      () async {
        final dao = db.recordingsDao;
        const dayStart = 1_700_000_000_000;
        await db.workspacesDao.createWorkspace('Work');
        final ws = (await db.workspacesDao.getWorkspaces()).firstWhere(
          (w) => w.name == 'Work',
        );

        await dao.insertRecording(
          _recording(id: 'inbox', createdAt: dayStart, workspaceId: null),
        );
        await dao.insertRecording(
          _recording(
            id: 'assigned',
            createdAt: dayStart + 1,
            workspaceId: ws.id,
          ),
        );

        final rows = await dao.recordingsByDayWithWorkspace(dayStart);
        final byId = {for (final r in rows) r.recording.id: r.workspaceName};
        expect(byId['assigned'], 'Work');
        expect(byId['inbox'], isNull); // no workspace → null name

        // cardsByDay maps rows → UI cards with the joined name.
        final cards = await dao.cardsByDay(dayStart);
        final assignedCard = cards.firstWhere(
          (RecordingItem c) => c.id == 'assigned',
        );
        expect(assignedCard.workspaceName, 'Work');
      },
    );

    test('RecordingItem.fromRow maps isProcessing int → bool', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(
        _recording(
          id: 'p',
          createdAt: 1,
          isProcessing: 1,
          processingStatus: 'processing',
        ),
      );
      final row = await dao.getRecordingById('p');
      final card = RecordingItem.fromRow(row!);
      expect(card.isProcessing, isTrue);
      expect(card.processingStatus, 'processing');
    });
  });

  // -------------------------------------------------------------------------
  // (c) drafts save/load/delete (single-row invariant)
  // -------------------------------------------------------------------------
  group('recording_drafts DAO', () {
    test('loadDraft returns null when empty', () async {
      expect(await db.recordingDraftsDao.loadDraft(), isNull);
    });

    test('save then load round-trips segments + durationMs', () async {
      final dao = db.recordingDraftsDao;
      await dao.saveDraft(['/d/segment_a.m4a', '/d/segment_b.m4a'], 4200);

      final draft = await dao.loadDraft();
      expect(draft, isNotNull);
      expect(draft!.segments, ['/d/segment_a.m4a', '/d/segment_b.m4a']);
      expect(draft.durationMs, 4200);
    });

    test('save replaces the prior draft (only one row kept)', () async {
      final dao = db.recordingDraftsDao;
      await dao.saveDraft(['/d/old.m4a'], 1000);
      await dao.saveDraft(['/d/new.m4a'], 2000);

      final draft = await dao.loadDraft();
      expect(draft!.segments, ['/d/new.m4a']);
      expect(draft.durationMs, 2000);

      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM recording_drafts')
          .map((r) => r.read<int>('c'))
          .getSingle();
      expect(count, 1);
    });

    test('persisted JSON shape matches segments_json', () async {
      final dao = db.recordingDraftsDao;
      await dao.saveDraft(['/d/x.m4a'], 500);
      final raw = await db
          .customSelect('SELECT segments_json FROM recording_drafts LIMIT 1')
          .map((r) => r.read<String>('segments_json'))
          .getSingle();
      expect(jsonDecode(raw), ['/d/x.m4a']);
    });

    test('deleteDraft clears the row', () async {
      final dao = db.recordingDraftsDao;
      await dao.saveDraft(['/d/x.m4a'], 1);
      await dao.deleteDraft();
      expect(await dao.loadDraft(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // (d) workspaces CRUD + delete returns recordings to inbox
  // -------------------------------------------------------------------------
  group('workspaces DAO', () {
    test(
      'create adds a non-default workspace, oldest-first ordering',
      () async {
        final dao = db.workspacesDao;
        final a = await dao.createWorkspace('Alpha');
        expect(a.isDefault, 0);
        expect(a.name, 'Alpha');

        final all = await dao.getWorkspaces();
        // default seed (createdAt ~now) + Alpha; ordered by createdAt ASC.
        expect(
          all.map((w) => w.name),
          containsAll(<String>['Pessoal', 'Alpha']),
        );
      },
    );

    test('createWorkspace trims the name', () async {
      final ws = await db.workspacesDao.createWorkspace('  Spaced  ');
      expect(ws.name, 'Spaced');
    });

    test(
      'deleteWorkspace returns its recordings to the inbox (workspaceId NULL)',
      () async {
        final wsDao = db.workspacesDao;
        final recDao = db.recordingsDao;

        final ws = await wsDao.createWorkspace('Temp');
        await recDao.insertRecording(
          _recording(id: 'r1', createdAt: 1, workspaceId: ws.id),
        );
        await recDao.insertRecording(
          _recording(id: 'r2', createdAt: 2, workspaceId: ws.id),
        );
        // A recording in a different workspace must stay put.
        final other = await wsDao.createWorkspace('Other');
        await recDao.insertRecording(
          _recording(id: 'r3', createdAt: 3, workspaceId: other.id),
        );

        await wsDao.deleteWorkspace(ws.id);

        expect(await wsDao.getWorkspaceById(ws.id), isNull);
        final inbox = await recDao.getInboxRecordings();
        expect(inbox.map((r) => r.id), containsAll(<String>['r1', 'r2']));

        final r3 = await recDao.getRecordingById('r3');
        expect(r3?.workspaceId, other.id); // untouched
      },
    );
  });

  // -------------------------------------------------------------------------
  // (e) m005 — local-first id migration (plan #43, Wave 1)
  //
  // Build a v4-shaped recordings table by hand (no `coreId`, user_version=4),
  // seed both a legacy stringified-Core-id row and a freshly-minted
  // `rec_local_<uuid>` row, then open AppDatabase over the same file so
  // onUpgrade(4→5) runs. Assert: `coreId` column exists, the numeric-id row is
  // backfilled, the local row stays NULL, and every existing row survives.
  // -------------------------------------------------------------------------
  group('m005 v4→v5 migration', () {
    late Directory dir;
    late File file;
    late String localId;

    /// Creates the recordings table as it existed at schema v4 (no coreId),
    /// plus the workspaces/recording_drafts tables, sets user_version=4, and
    /// seeds the rows. Closed before AppDatabase re-opens it.
    void seedV4Database() {
      final sdb = raw.sqlite3.open(file.path);
      sdb.execute('''
        CREATE TABLE recordings (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT,
          timestamp TEXT NOT NULL,
          duration TEXT NOT NULL,
          badge TEXT NOT NULL DEFAULT 'Inbox',
          isProcessing INTEGER NOT NULL DEFAULT 1,
          audioFilePath TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          notes TEXT,
          workspaceId TEXT REFERENCES workspaces(id),
          mediaType TEXT NOT NULL DEFAULT 'audio',
          processingStatus TEXT NOT NULL DEFAULT 'done'
        );
      ''');
      sdb.execute('''
        CREATE TABLE workspaces (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL
        );
      ''');
      sdb.execute('''
        CREATE TABLE recording_drafts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          segments_json TEXT NOT NULL,
          duration_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      // Legacy row: id is a stringified Core id → should backfill coreId=42.
      sdb.execute(
        "INSERT INTO recordings "
        "(id, title, timestamp, duration, audioFilePath, createdAt, processingStatus) "
        "VALUES ('42', 'Legacy Core', '9:00 AM', '0:30', '/tmp/a.m4a', 100, 'done');",
      );
      // Local-first row: rec_local_<uuid> → coreId must stay NULL.
      sdb.execute(
        "INSERT INTO recordings "
        "(id, title, timestamp, duration, audioFilePath, createdAt, processingStatus) "
        "VALUES ('$localId', 'Local Only', '9:05 AM', '1:00', '/tmp/b.m4a', 200, '$kProcessingStatusPendingUpload');",
      );
      sdb.execute('PRAGMA user_version = 4;');
      sdb.dispose();
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('matome_m005');
      file = File('${dir.path}/matome.sqlite');
      localId = mintLocalRecordingId();
      seedV4Database();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('opening a v4 db migrates to v5 and backfills coreId', () async {
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      // A v4-seeded DB now migrates through m005..m008, so the live
      // schemaVersion getter reports the current constant (7).
      expect(upgraded.schemaVersion, 8);

      // coreId column now exists on the migrated table.
      final cols = await upgraded
          .customSelect('PRAGMA table_info(recordings)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(cols, contains('coreId'));

      final dao = upgraded.recordingsDao;

      // Legacy numeric-id row backfilled to coreId = 42.
      final legacy = await dao.getRecordingById('42');
      expect(legacy, isNotNull);
      expect(legacy!.coreId, 42);
      expect(legacy.title, 'Legacy Core'); // existing data intact

      // Local-first row keeps coreId NULL (int.tryParse would fail).
      final local = await dao.getRecordingById(localId);
      expect(local, isNotNull);
      expect(local!.coreId, isNull);
      expect(local.processingStatus, kProcessingStatusPendingUpload);

      // No rows lost in migration.
      expect(await dao.getAllRecordings(), hasLength(2));
    });

    test(
      'recordingByCoreId resolves the backfilled row after migration',
      () async {
        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);

        final byCore = await upgraded.recordingsDao.recordingByCoreId(42);
        expect(byCore, isNotNull);
        expect(byCore!.id, '42');

        // The local-only row is intentionally not matched (coreId NULL).
        expect(await upgraded.recordingsDao.recordingByCoreId(999), isNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // (g) m006 — Space collaboration schema (matome-centric-pivot Wave 1).
  //
  // Build a v5-shaped DB by hand (workspaces WITHOUT space_type/owner_id, no
  // space_members/organizations, user_version=5), seed the default Space plus a
  // second Space, then open AppDatabase over the same file so onUpgrade(5→6)
  // runs. Assert: the two columns exist + backfill 'personal', the two reserved
  // tables exist, the default Space is type=personal, and re-opening is
  // idempotent (no double-add crash, rows intact).
  // -------------------------------------------------------------------------
  group('m006 v5→v6 migration', () {
    late Directory dir;
    late File file;

    /// Creates the v5-shaped tables (recordings with coreId, workspaces WITHOUT
    /// the m006 columns, recording_drafts), seeds two Spaces, sets
    /// user_version=5, then closes the raw handle.
    void seedV5Database() {
      final sdb = raw.sqlite3.open(file.path);
      sdb.execute('''
        CREATE TABLE recordings (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT,
          timestamp TEXT NOT NULL,
          duration TEXT NOT NULL,
          badge TEXT NOT NULL DEFAULT 'Inbox',
          isProcessing INTEGER NOT NULL DEFAULT 1,
          audioFilePath TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          notes TEXT,
          workspaceId TEXT REFERENCES workspaces(id),
          mediaType TEXT NOT NULL DEFAULT 'audio',
          processingStatus TEXT NOT NULL DEFAULT 'done',
          coreId INTEGER
        );
      ''');
      sdb.execute('''
        CREATE TABLE workspaces (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL
        );
      ''');
      sdb.execute('''
        CREATE TABLE recording_drafts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          segments_json TEXT NOT NULL,
          duration_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      // The pre-existing default Space + a user-created Space.
      sdb.execute(
        "INSERT INTO workspaces (id, name, isDefault, createdAt) "
        "VALUES ('ws_default_personal', 'Pessoal', 1, 100);",
      );
      sdb.execute(
        "INSERT INTO workspaces (id, name, isDefault, createdAt) "
        "VALUES ('ws_work', 'Work', 0, 200);",
      );
      sdb.execute('PRAGMA user_version = 5;');
      sdb.dispose();
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('matome_m006');
      file = File('${dir.path}/matome.sqlite');
      seedV5Database();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('opening a v5 db migrates to v6 (columns, tables, backfill)', () async {
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(upgraded.schemaVersion, 8);

      // m006 columns now exist on workspaces.
      final wsCols = await upgraded
          .customSelect('PRAGMA table_info(workspaces)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(wsCols, containsAll(<String>['space_type', 'owner_id']));

      // Both reserved tables exist.
      final tables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(tables, containsAll(<String>['space_members', 'organizations']));

      // Existing rows backfilled to space_type='personal', owner_id NULL.
      final all = await upgraded.workspacesDao.getWorkspaces();
      expect(all.map((w) => w.id), containsAll(<String>['ws_default_personal', 'ws_work']));
      for (final w in all) {
        expect(w.spaceType, 'personal');
        expect(w.ownerId, isNull);
      }

      // The default Space is the personal triage destination.
      final def =
          await upgraded.workspacesDao.getWorkspaceById('ws_default_personal');
      expect(def, isNotNull);
      expect(def!.spaceType, 'personal');
      expect(def.isDefault, 1);
      expect(def.name, 'Pessoal'); // data intact
    });

    test('m006 upgrade is idempotent across re-open', () async {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      await first.workspacesDao.getWorkspaces();
      await first.close();

      // Re-opening at v6 must not re-run m006 (no duplicate-column crash).
      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      final all = await second.workspacesDao.getWorkspaces();
      expect(all, hasLength(2));
      expect(all.every((w) => w.spaceType == 'personal'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // (g2) m007 — Matome central entity (matome-centric-pivot, ADR-0003).
  //
  // The KEYSTONE migration. Build a v6-shaped DB by hand (recordings WITHOUT
  // matome_id, NO matomes table, user_version=6), seed an Inbox recording
  // (workspaceId NULL) and a filed recording (workspaceId = a Space), then open
  // AppDatabase so onUpgrade(6→7) runs. Assert the backfill is correct,
  // FK-resolvable, space-preserving, and idempotent on re-open.
  // -------------------------------------------------------------------------
  group('m007 v6→v7 migration (Matome backfill)', () {
    late Directory dir;
    late File file;

    /// v6-shaped tables: recordings WITH coreId but WITHOUT matome_id,
    /// workspaces WITH the m006 columns, no matomes table. user_version=6.
    void seedV6Database() {
      final sdb = raw.sqlite3.open(file.path);
      sdb.execute('''
        CREATE TABLE workspaces (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          space_type TEXT NOT NULL DEFAULT 'personal',
          owner_id TEXT
        );
      ''');
      sdb.execute('''
        CREATE TABLE recordings (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT,
          timestamp TEXT NOT NULL,
          duration TEXT NOT NULL,
          badge TEXT NOT NULL DEFAULT 'Inbox',
          isProcessing INTEGER NOT NULL DEFAULT 1,
          audioFilePath TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          notes TEXT,
          workspaceId TEXT REFERENCES workspaces(id),
          mediaType TEXT NOT NULL DEFAULT 'audio',
          processingStatus TEXT NOT NULL DEFAULT 'done',
          coreId INTEGER
        );
      ''');
      sdb.execute('''
        CREATE TABLE recording_drafts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          segments_json TEXT NOT NULL,
          duration_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      sdb.execute('''
        CREATE TABLE space_members (
          id TEXT NOT NULL PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES workspaces(id),
          user_id TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'member'
        );
      ''');
      sdb.execute('''
        CREATE TABLE organizations (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      // A Space the filed recording lives in.
      sdb.execute(
        "INSERT INTO workspaces (id, name, isDefault, createdAt, space_type) "
        "VALUES ('ws_work', 'Work', 0, 100, 'personal');",
      );
      // An Inbox recording (workspaceId NULL).
      sdb.execute(
        "INSERT INTO recordings "
        "(id, title, timestamp, duration, audioFilePath, createdAt, processingStatus) "
        "VALUES ('rec_inbox', 'Inbox Note', '9:00 AM', '0:30', '/tmp/a.m4a', 100, 'done');",
      );
      // A filed recording (workspaceId = ws_work).
      sdb.execute(
        "INSERT INTO recordings "
        "(id, title, timestamp, duration, audioFilePath, createdAt, workspaceId, processingStatus) "
        "VALUES ('rec_filed', 'Work Meeting', '9:05 AM', '1:00', '/tmp/b.m4a', 200, 'ws_work', 'done');",
      );
      sdb.execute('PRAGMA user_version = 6;');
      sdb.dispose();
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('matome_m007');
      file = File('${dir.path}/matome.sqlite');
      seedV6Database();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('opening a v6 db migrates to v7: matomes table + matome_id', () async {
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(upgraded.schemaVersion, 8);

      final tables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(tables, contains('matomes'));

      final recCols = await upgraded
          .customSelect('PRAGMA table_info(recordings)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(recCols, contains('matome_id'));
    });

    test(
      'backfill: one Matome per recording, every matome_id FK-resolvable, '
      'space_id == old workspaceId',
      () async {
        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);

        // count(matomes) == count(distinct recordings).
        final recCount = await upgraded
            .customSelect('SELECT COUNT(DISTINCT id) AS c FROM recordings')
            .map((r) => r.read<int>('c'))
            .getSingle();
        final matCount = await upgraded
            .customSelect('SELECT COUNT(*) AS c FROM matomes')
            .map((r) => r.read<int>('c'))
            .getSingle();
        expect(recCount, 2);
        expect(matCount, recCount);

        // EVERY recording.matome_id is non-null AND resolves to a matomes row.
        final orphans = await upgraded
            .customSelect(
              'SELECT r.id AS rid FROM recordings r '
              'LEFT JOIN matomes m ON m.id = r.matome_id '
              'WHERE r.matome_id IS NULL OR m.id IS NULL',
            )
            .get();
        expect(orphans, isEmpty);

        // The backfilled matome.space_id == the recording's old workspace_id.
        Future<String?> spaceOf(String recId) async {
          final row = await upgraded
              .customSelect(
                'SELECT m.space_id AS sid FROM recordings r '
                'JOIN matomes m ON m.id = r.matome_id WHERE r.id = ?',
                variables: [Variable<String>(recId)],
              )
              .getSingle();
          return row.read<String?>('sid');
        }

        expect(await spaceOf('rec_inbox'), isNull); // Inbox → Inbox Matome
        expect(await spaceOf('rec_filed'), 'ws_work'); // filed → filed Matome

        // Backfilled Matome is local-only (mat_local_ prefix, core_id NULL) and
        // carries the recording's title + happened_at.
        final filed = await upgraded
            .customSelect(
              'SELECT m.* FROM recordings r '
              'JOIN matomes m ON m.id = r.matome_id WHERE r.id = ?',
              variables: [Variable<String>('rec_filed')],
            )
            .getSingle();
        expect(isLocalMatomeId(filed.read<String>('id')), isTrue);
        expect(filed.read<int?>('core_id'), isNull);
        expect(filed.read<String>('title'), 'Work Meeting');
        expect(filed.read<int>('happened_at'), 200);
      },
    );

    test('m007 backfill is idempotent across re-open (no duplicate Matomes)',
        () async {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      await first.recordingsDao.getAllRecordings();
      final firstCount = await first
          .customSelect('SELECT COUNT(*) AS c FROM matomes')
          .map((r) => r.read<int>('c'))
          .getSingle();
      await first.close();

      // Re-open: m007 must NOT re-run (already at v7) and the backfill guard
      // (matome_id IS NULL) means even a forced re-run mints no duplicates.
      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      final secondCount = await second
          .customSelect('SELECT COUNT(*) AS c FROM matomes')
          .map((r) => r.read<int>('c'))
          .getSingle();
      expect(secondCount, firstCount);
      expect(secondCount, 2);
    });
  });

  // -------------------------------------------------------------------------
  // (h) SpacesDao — m006 reads + reserved (unenforced) CRUD stubs.
  // -------------------------------------------------------------------------
  group('SpacesDao (m006, schema-ready/unenforced)', () {
    test('getSpaceType / getOwnerId read the new columns', () async {
      final dao = db.spacesDao;
      // Seeded default Space is personal with no owner.
      expect(await dao.getSpaceType('ws_default_personal'), 'personal');
      expect(await dao.getOwnerId('ws_default_personal'), isNull);
      // Unknown Space → null (not a throw).
      expect(await dao.getSpaceType('nope'), isNull);
      expect(await dao.getOwnerId('nope'), isNull);
    });

    test('ensureDefaultPersonalSpace is idempotent + normalises type', () async {
      final dao = db.spacesDao;
      // Force a non-personal type, then ensure it is normalised back.
      await (db.update(db.workspaces)
            ..where((w) => w.id.equals('ws_default_personal')))
          .write(const WorkspacesCompanion(spaceType: Value('shared')));

      final row = await dao.ensureDefaultPersonalSpace();
      expect(row.id, 'ws_default_personal');
      expect(row.spaceType, 'personal');
      expect(row.isDefault, 1);

      // Still exactly one default Space row.
      final all = await db.workspacesDao.getWorkspaces();
      expect(all.where((w) => w.id == 'ws_default_personal'), hasLength(1));
    });

    test('space_members CRUD stub round-trips (no enforcement)', () async {
      final dao = db.spacesDao;
      final owner = await dao.addSpaceMember(
        spaceId: 'ws_default_personal',
        userId: 'u_owner',
        role: 'owner',
      );
      await dao.addSpaceMember(
        spaceId: 'ws_default_personal',
        userId: 'u_view',
        role: 'viewer',
      );

      final members = await dao.membersOfSpace('ws_default_personal');
      expect(members, hasLength(2));
      expect(
        {for (final m in members) m.userId: m.role},
        {'u_owner': 'owner', 'u_view': 'viewer'},
      );

      await dao.removeSpaceMember(owner.id);
      final after = await dao.membersOfSpace('ws_default_personal');
      expect(after.map((m) => m.userId), ['u_view']);
    });

    test('addSpaceMember defaults role to member', () async {
      final dao = db.spacesDao;
      final m = await dao.addSpaceMember(
        spaceId: 'ws_default_personal',
        userId: 'u1',
      );
      expect(m.role, 'member');
      final stored = (await dao.membersOfSpace('ws_default_personal')).single;
      expect(stored.role, 'member');
    });

    test('organizations CRUD stub round-trips (reserved)', () async {
      final dao = db.spacesDao;
      final org = await dao.createOrganization('Acme');
      expect(org.name, 'Acme');

      final fetched = await dao.getOrganizationById(org.id);
      expect(fetched?.name, 'Acme');

      await dao.createOrganization('Globex');
      final all = await dao.getOrganizations();
      expect(all.map((o) => o.name), containsAll(<String>['Acme', 'Globex']));

      await dao.deleteOrganization(org.id);
      expect(await dao.getOrganizationById(org.id), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // (i) local-id minter + status constant (plan #43, Wave 1)
  // -------------------------------------------------------------------------
  group('recording id minter', () {
    test('mints rec_local_<uuid> ids that are recognised as local', () {
      final id = mintLocalRecordingId();
      expect(id, startsWith('rec_local_'));
      expect(isLocalRecordingId(id), isTrue);
      expect(mintLocalRecordingId(), isNot(id)); // unique each call
    });

    test('a stringified Core id is not treated as local', () {
      expect(isLocalRecordingId('42'), isFalse);
    });

    test(
      'coreId column round-trips through insert + recordingByCoreId',
      () async {
        final dao = db.recordingsDao;
        final localId = mintLocalRecordingId();
        await dao.insertRecording(
          _recording(
            id: localId,
            createdAt: 1,
            processingStatus: kProcessingStatusPendingUpload,
          ).copyWith(coreId: const Value(7)),
        );
        final byCore = await dao.recordingByCoreId(7);
        expect(byCore?.id, localId);
        expect(byCore?.coreId, 7);
      },
    );
  });

  // -------------------------------------------------------------------------
  // (j) m008 — Contacts schema (ADR-0004). Real-file v7→v8 migration.
  //
  // Build a v7-shaped DB by hand (matomes + workspaces + recordings, NO
  // contacts/edge tables, user_version=7), then open AppDatabase over the same
  // file so onUpgrade(7→8) runs. Assert the four tables exist, schemaVersion=8,
  // pre-existing rows survive, and re-opening is idempotent.
  // -------------------------------------------------------------------------
  group('m008 v7→v8 migration (Contacts schema)', () {
    late Directory dir;
    late File file;

    /// v7-shaped tables: workspaces (m006 cols) + recordings (matome_id) +
    /// matomes, NO contacts/matome_contacts/space_contacts/matome_shares.
    /// user_version=7.
    void seedV7Database() {
      final sdb = raw.sqlite3.open(file.path);
      sdb.execute('''
        CREATE TABLE workspaces (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          space_type TEXT NOT NULL DEFAULT 'personal',
          owner_id TEXT
        );
      ''');
      sdb.execute('''
        CREATE TABLE matomes (
          id TEXT NOT NULL PRIMARY KEY,
          space_id TEXT REFERENCES workspaces(id),
          title TEXT NOT NULL,
          happened_at INTEGER NOT NULL,
          description TEXT,
          aggregated_summary TEXT,
          summary_stale INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          core_id INTEGER
        );
      ''');
      sdb.execute('''
        CREATE TABLE recordings (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          summary TEXT,
          timestamp TEXT NOT NULL,
          duration TEXT NOT NULL,
          badge TEXT NOT NULL DEFAULT 'Inbox',
          isProcessing INTEGER NOT NULL DEFAULT 1,
          audioFilePath TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          notes TEXT,
          workspaceId TEXT REFERENCES workspaces(id),
          mediaType TEXT NOT NULL DEFAULT 'audio',
          processingStatus TEXT NOT NULL DEFAULT 'done',
          coreId INTEGER,
          matome_id TEXT REFERENCES matomes(id)
        );
      ''');
      sdb.execute('''
        CREATE TABLE recording_drafts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          segments_json TEXT NOT NULL,
          duration_ms INTEGER NOT NULL DEFAULT 0
        );
      ''');
      sdb.execute('''
        CREATE TABLE space_members (
          id TEXT NOT NULL PRIMARY KEY,
          space_id TEXT NOT NULL REFERENCES workspaces(id),
          user_id TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'member'
        );
      ''');
      sdb.execute('''
        CREATE TABLE organizations (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      // A pre-existing Matome so we can prove existing rows survive m008.
      sdb.execute(
        "INSERT INTO matomes (id, title, happened_at, created_at) "
        "VALUES ('mat_local_pre', 'Pre-existing', 100, 100);",
      );
      sdb.execute('PRAGMA user_version = 7;');
      sdb.dispose();
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('matome_m008');
      file = File('${dir.path}/matome.sqlite');
      seedV7Database();
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('opening a v7 db migrates to v8: the four Contacts tables exist',
        () async {
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      expect(upgraded.schemaVersion, 8);

      final tables = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        tables,
        containsAll(<String>[
          'contacts',
          'matome_contacts',
          'space_contacts',
          'matome_shares',
        ]),
      );

      // contacts column contract.
      final cols = await upgraded
          .customSelect('PRAGMA table_info(contacts)')
          .map((r) => r.read<String>('name'))
          .get();
      expect(
        cols,
        containsAll(<String>[
          'id',
          'owner_id',
          'display_name',
          'metadata',
          'linked_user_id',
          'created_at',
          'core_id',
        ]),
      );

      // Pre-existing Matome row survived the migration.
      final pre = await upgraded.matomesDao.getById('mat_local_pre');
      expect(pre, isNotNull);
      expect(pre!.title, 'Pre-existing');
    });

    test('m008 upgrade is idempotent across re-open', () async {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      await first.contactsDao.listContacts();
      await first.close();

      // Re-opening at v8 must not re-run m008 (no duplicate-table crash).
      final second = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(second.close);
      expect(second.schemaVersion, 8);
      final tables = await second
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(tables, contains('contacts'));
    });
  });

  // -------------------------------------------------------------------------
  // (k) ContactsDao — CRUD + edges + set-merge + deletion-cascade (m008).
  // -------------------------------------------------------------------------
  group('ContactsDao (m008, schema-ready/unenforced)', () {
    ContactsCompanion makeContact({
      required String id,
      String ownerId = 'owner1',
      String displayName = 'Alice',
      String metadata = '{}',
      String? linkedUserId,
      int createdAt = 1,
    }) {
      return ContactsCompanion.insert(
        id: id,
        ownerId: ownerId,
        displayName: displayName,
        metadata: Value(metadata),
        linkedUserId: Value(linkedUserId),
        createdAt: createdAt,
      );
    }

    Future<String> seedMatome(AppDatabase d, String id) async {
      await d.matomesDao.create(
        MatomesCompanion.insert(
          id: id,
          title: 'M $id',
          happenedAt: 1,
          createdAt: 1,
        ),
      );
      return id;
    }

    test('contacts CRUD round-trips (defaults metadata + nullable link)',
        () async {
      final dao = db.contactsDao;
      await dao.create(makeContact(id: 'c1', displayName: 'Zoe'));
      await dao.create(
        makeContact(
          id: 'c2',
          displayName: 'Alice',
          metadata: '{"email":"a@x.com"}',
          linkedUserId: 'u_real',
        ),
      );

      final c1 = await dao.getById('c1');
      expect(c1, isNotNull);
      expect(c1!.metadata, '{}'); // default
      expect(c1.linkedUserId, isNull); // reserved, unset

      final c2 = await dao.getById('c2');
      expect(c2!.metadata, '{"email":"a@x.com"}');
      expect(c2.linkedUserId, 'u_real');

      // listContacts is display-name ascending → Alice before Zoe.
      final all = await dao.listContacts();
      expect(all.map((c) => c.id), ['c2', 'c1']);

      // listContactsForOwner filters by owner.
      await dao.create(makeContact(id: 'c3', ownerId: 'other'));
      final mine = await dao.listContactsForOwner('owner1');
      expect(mine.map((c) => c.id), containsAll(<String>['c1', 'c2']));
      expect(mine.map((c) => c.id), isNot(contains('c3')));

      // update writes only patched fields.
      await dao.updateContact(
        'c1',
        const ContactsCompanion(displayName: Value('Zoe Renamed')),
      );
      expect((await dao.getById('c1'))!.displayName, 'Zoe Renamed');

      // coreId reconcile lookup.
      await dao.updateContact('c1', const ContactsCompanion(coreId: Value(99)));
      expect((await dao.contactByCoreId(99))!.id, 'c1');
    });

    test(
      'matome_contacts add/list/remove with role + idempotent re-add',
      () async {
        final dao = db.contactsDao;
        final m = await seedMatome(db, 'mat_local_k1');
        await dao.create(makeContact(id: 'c1', displayName: 'Bob'));

        await dao.addContactToMatome(
          matomeId: m,
          contactId: 'c1',
          role: 'speaker',
        );

        final listed = await dao.listContactsForMatome(m);
        expect(listed, hasLength(1));
        expect(listed.single.contact.id, 'c1');
        expect(listed.single.role, 'speaker');

        // Idempotent re-add (UNIQUE handles dup) — still exactly one edge.
        await dao.addContactToMatome(
          matomeId: m,
          contactId: 'c1',
          role: 'attendee',
        );
        final after = await dao.listContactsForMatome(m);
        expect(after, hasLength(1));
        // Conflict was ignored → role unchanged from first add.
        expect(after.single.role, 'speaker');

        // setMatomeContactRole updates the existing edge.
        await dao.setMatomeContactRole(
          matomeId: m,
          contactId: 'c1',
          role: 'organizer',
        );
        expect(
          (await dao.listContactsForMatome(m)).single.role,
          'organizer',
        );

        // Explicit removal.
        await dao.removeContactFromMatome(matomeId: m, contactId: 'c1');
        expect(await dao.listContactsForMatome(m), isEmpty);
      },
    );

    test('space_contacts add/list/remove + idempotent re-add', () async {
      final dao = db.contactsDao;
      await dao.create(makeContact(id: 'c1', displayName: 'Bob'));

      await dao.addContactToSpace(
        spaceId: 'ws_default_personal',
        contactId: 'c1',
      );
      // Idempotent re-add.
      await dao.addContactToSpace(
        spaceId: 'ws_default_personal',
        contactId: 'c1',
      );
      final members = await dao.listContactsForSpace('ws_default_personal');
      expect(members.map((c) => c.id), ['c1']);

      await dao.removeContactFromSpace(
        spaceId: 'ws_default_personal',
        contactId: 'c1',
      );
      expect(await dao.listContactsForSpace('ws_default_personal'), isEmpty);
    });

    test('matome_shares add/list/remove (reserved)', () async {
      final dao = db.contactsDao;
      final m = await seedMatome(db, 'mat_local_share');
      final share = await dao.addMatomeShare(
        matomeId: m,
        sharedWithUserId: 'u_friend',
      );
      expect(share.permission, 'read'); // default

      await dao.addMatomeShare(
        matomeId: m,
        sharedWithUserId: 'u_editor',
        permission: 'write',
      );
      final shares = await dao.listSharesForMatome(m);
      expect(shares, hasLength(2));

      await dao.removeMatomeShare(share.id);
      final after = await dao.listSharesForMatome(m);
      expect(after.map((s) => s.sharedWithUserId), ['u_editor']);
    });

    // The join-table MERGE-SURVIVAL test (set-merge rule): adding contact A then
    // a stale "re-sync" that re-adds the PRE-EXISTING set (B, C) WITHOUT A must
    // NOT drop A — removal is explicit-only, never implied by a partial set.
    test('partial re-sync of an edge set never drops an absent member',
        () async {
      final dao = db.contactsDao;
      final m = await seedMatome(db, 'mat_local_merge');
      for (final id in ['A', 'B', 'C']) {
        await dao.create(makeContact(id: id, displayName: id));
      }

      // Initial set: B, C are tagged.
      await dao.addContactToMatome(matomeId: m, contactId: 'B');
      await dao.addContactToMatome(matomeId: m, contactId: 'C');
      // Then A is added.
      await dao.addContactToMatome(matomeId: m, contactId: 'A');

      // A stale re-sync re-adds the OLD set (B, C) — A is absent from it.
      // Because add is a union (idempotent) and removal is explicit-only, A's
      // edge MUST survive.
      await dao.addContactToMatome(matomeId: m, contactId: 'B');
      await dao.addContactToMatome(matomeId: m, contactId: 'C');

      final ids =
          (await dao.listContactsForMatome(m)).map((e) => e.contact.id).toSet();
      expect(ids, {'A', 'B', 'C'}); // A survived the partial re-sync.
    });

    test(
      'deletion-cascade: delete contact removes its edges, Matome survives',
      () async {
        final dao = db.contactsDao;
        final m = await seedMatome(db, 'mat_local_del_c');
        await dao.create(makeContact(id: 'c1', displayName: 'Bob'));
        await dao.create(makeContact(id: 'c2', displayName: 'Eve'));

        await dao.addContactToMatome(matomeId: m, contactId: 'c1');
        await dao.addContactToMatome(matomeId: m, contactId: 'c2');
        await dao.addContactToSpace(
          spaceId: 'ws_default_personal',
          contactId: 'c1',
        );

        await dao.deleteContact('c1');

        // c1 gone, its edges gone; c2's edge survives; Matome + Space survive.
        expect(await dao.getById('c1'), isNull);
        final tagged =
            (await dao.listContactsForMatome(m)).map((e) => e.contact.id);
        expect(tagged, ['c2']);
        expect(
          await dao.listContactsForSpace('ws_default_personal'),
          isEmpty,
        );
        expect(await db.matomesDao.getById(m), isNotNull);
        expect(await dao.getById('c2'), isNotNull);
      },
    );

    test(
      'deletion-cascade: delete matome removes its edges, contact survives',
      () async {
        final dao = db.contactsDao;
        final m = await seedMatome(db, 'mat_local_del_m');
        await dao.create(makeContact(id: 'c1', displayName: 'Bob'));

        await dao.addContactToMatome(matomeId: m, contactId: 'c1');
        await dao.addMatomeShare(matomeId: m, sharedWithUserId: 'u_x');

        await db.matomesDao.deleteMatome(m);

        // Matome gone, its matome_contacts + matome_shares gone; contact stays.
        expect(await db.matomesDao.getById(m), isNull);
        expect(await dao.listContactsForMatome(m), isEmpty);
        expect(await dao.listSharesForMatome(m), isEmpty);
        expect(await dao.getById('c1'), isNotNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // (l) contact id minter (m008).
  // -------------------------------------------------------------------------
  group('contact id minter', () {
    test('mints contact_local_<uuid> ids recognised as local', () {
      final id = mintLocalContactId();
      expect(id, startsWith('contact_local_'));
      expect(isLocalContactId(id), isTrue);
      expect(mintLocalContactId(), isNot(id)); // unique each call
    });

    test('a stringified Core id is not treated as local', () {
      expect(isLocalContactId('42'), isFalse);
    });
  });
}
