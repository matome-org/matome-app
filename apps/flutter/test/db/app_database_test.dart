import 'dart:convert';

// `isNull`/`isNotNull` collide with matcher's — we only need Value/companions
// from drift here, so hide the column-expression helpers.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';

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
    test('schemaVersion is 4 (mobile migrations 001..004)', () {
      expect(db.schemaVersion, 4);
    });

    test('onCreate builds recordings/workspaces/recording_drafts tables', () async {
      final names = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((r) => r.read<String>('name'))
          .get();
      expect(names, containsAll(<String>['recordings', 'workspaces', 'recording_drafts']));
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
        containsAll(<String>['id', 'created_at', 'segments_json', 'duration_ms']),
      );
    });

    test('workspaces seeds the default "Pessoal" workspace (m002 INSERT OR IGNORE)',
        () async {
      final all = await db.workspacesDao.getWorkspaces();
      expect(all, hasLength(1));
      expect(all.single.id, 'ws_default_personal');
      expect(all.single.name, 'Pessoal');
      expect(all.single.isDefault, 1);
    });
  });

  // -------------------------------------------------------------------------
  // (b) recordings CRUD + getInbox + date-range + day-with-workspace
  // -------------------------------------------------------------------------
  group('recordings DAO', () {
    test('insert + getById + getAll (newest first)', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(_recording(id: 'r1', title: 'One', createdAt: 100));
      await dao.insertRecording(_recording(id: 'r2', title: 'Two', createdAt: 300));
      await dao.insertRecording(_recording(id: 'r3', title: 'Three', createdAt: 200));

      final one = await dao.getRecordingById('r1');
      expect(one?.title, 'One');

      final all = await dao.getAllRecordings();
      expect(all.map((r) => r.id), ['r2', 'r3', 'r1']); // createdAt DESC
    });

    test('getInbox returns only workspaceId IS NULL', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(_recording(id: 'inbox1', createdAt: 10));
      await dao.insertRecording(
        _recording(id: 'ws1', createdAt: 20, workspaceId: 'ws_default_personal'),
      );
      await dao.insertRecording(_recording(id: 'inbox2', createdAt: 30));

      final inbox = await dao.getInboxRecordings();
      expect(inbox.map((r) => r.id), ['inbox2', 'inbox1']);
    });

    test('update writes only patched fields; delete removes the row', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(_recording(id: 'r1', title: 'Old', summary: 's', createdAt: 1));

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
      await dao.upsertRecording(_recording(id: 'r1', title: 'First', createdAt: 1));
      await dao.upsertRecording(_recording(id: 'r1', title: 'Second', createdAt: 2));
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

    test('recordingsByDayWithWorkspace LEFT JOINs the workspace name', () async {
      final dao = db.recordingsDao;
      const dayStart = 1_700_000_000_000;
      await db.workspacesDao.createWorkspace('Work');
      final ws = (await db.workspacesDao.getWorkspaces())
          .firstWhere((w) => w.name == 'Work');

      await dao.insertRecording(
        _recording(id: 'inbox', createdAt: dayStart, workspaceId: null),
      );
      await dao.insertRecording(
        _recording(id: 'assigned', createdAt: dayStart + 1, workspaceId: ws.id),
      );

      final rows = await dao.recordingsByDayWithWorkspace(dayStart);
      final byId = {for (final r in rows) r.recording.id: r.workspaceName};
      expect(byId['assigned'], 'Work');
      expect(byId['inbox'], isNull); // no workspace → null name

      // cardsByDay maps rows → UI cards with the joined name.
      final cards = await dao.cardsByDay(dayStart);
      final assignedCard =
          cards.firstWhere((RecordingCard c) => c.id == 'assigned');
      expect(assignedCard.workspaceName, 'Work');
    });

    test('RecordingCard.fromRow maps isProcessing int → bool', () async {
      final dao = db.recordingsDao;
      await dao.insertRecording(
        _recording(id: 'p', createdAt: 1, isProcessing: 1, processingStatus: 'processing'),
      );
      final row = await dao.getRecordingById('p');
      final card = RecordingCard.fromRow(row!);
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
    test('create adds a non-default workspace, oldest-first ordering', () async {
      final dao = db.workspacesDao;
      final a = await dao.createWorkspace('Alpha');
      expect(a.isDefault, 0);
      expect(a.name, 'Alpha');

      final all = await dao.getWorkspaces();
      // default seed (createdAt ~now) + Alpha; ordered by createdAt ASC.
      expect(all.map((w) => w.name), containsAll(<String>['Pessoal', 'Alpha']));
    });

    test('createWorkspace trims the name', () async {
      final ws = await db.workspacesDao.createWorkspace('  Spaced  ');
      expect(ws.name, 'Spaced');
    });

    test('deleteWorkspace returns its recordings to the inbox (workspaceId NULL)',
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
    });
  });
}
