import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../support/item_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('schema version is the canonical destructive reset', () {
    expect(db.schemaVersion, 28);
  });

  test('fresh schema keeps recording drafts separate from Items', () async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(
      names,
      containsAll([
        'items',
        'file_blobs',
        'text_contents',
        'recording_drafts',
        'work_queue',
        'workspaces',
        'matomes',
      ]),
    );
    expect(names, isNot(contains('recordings')));
  });

  test('recording draft save replace and delete round-trips', () async {
    await db.recordingDraftsDao.saveDraft(['/a.m4a'], 1000);
    await db.recordingDraftsDao.saveDraft(['/b.m4a'], 2000);
    final draft = await db.recordingDraftsDao.loadDraft();
    expect(draft?.segments, ['/b.m4a']);
    expect(draft?.durationMs, 2000);

    final rawJson = await db
        .customSelect('SELECT segments_json FROM recording_drafts')
        .map((row) => row.read<String>('segments_json'))
        .getSingle();
    expect(jsonDecode(rawJson), ['/b.m4a']);

    await db.recordingDraftsDao.deleteDraft();
    expect(await db.recordingDraftsDao.loadDraft(), isNull);
  });

  test('workspace delete returns directly filed Items to Inbox', () async {
    final workspace = await db.workspacesDao.createWorkspace('Temporary');
    await insertTestFileItem(db, id: 'direct-file', workspaceId: workspace.id);

    await db.workspacesDao.deleteWorkspace(workspace.id);

    expect(await db.workspacesDao.getWorkspaceById(workspace.id), isNull);
    final item = await db.itemsDao.getById('direct-file', '1');
    expect(item?.workspaceId, isNull);
  });

  test('opening an old database performs a clean canonical reset', () async {
    final dir = await Directory.systemTemp.createTemp('matome_reset_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/matome.sqlite');
    final legacy = raw.sqlite3.open(file.path);
    legacy.execute(
      'CREATE TABLE recordings (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
    );
    legacy.execute("INSERT INTO recordings VALUES ('old', 'Old row')");
    legacy.execute('PRAGMA user_version = 21');
    legacy.dispose();

    final reset = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reset.close);
    final names = await reset
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row.read<String>('name'))
        .get();
    expect(names, containsAll(['items', 'file_blobs', 'text_contents']));
    expect(names, isNot(contains('recordings')));
  });
}
