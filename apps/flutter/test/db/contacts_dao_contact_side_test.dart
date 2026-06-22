import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/contacts_dao.dart';

// ---------------------------------------------------------------------------
// ContactsDao contact-side relationship reads (DR-004 / #1464). In-memory
// NativeDatabase, mirroring matomes_dao_test.dart. Exercises the inverse
// (contact-end) queries: listMatomesForContact / listSpacesForContact /
// listFilesForContactViaMatomes (MATOME-MEDIATED — no direct contact↔file edge).
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

const String _kSpace = 'ws_default_personal'; // seeded on onCreate

Future<void> _seedContact(AppDatabase db, String id) {
  return db.contactsDao.create(
    ContactsCompanion.insert(
      id: id,
      ownerId: 'user_local',
      displayName: 'Ana',
      createdAt: 1000,
    ),
  );
}

Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'M',
  int happenedAt = 1000,
  int? archivedAt,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      happenedAt: happenedAt,
      createdAt: 1000,
      archivedAt: Value(archivedAt),
    ),
  );
}

Future<void> _seedRecording(
  AppDatabase db, {
  required String id,
  required String matomeId,
  int createdAt = 1000,
  String mediaType = 'audio',
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion.insert(
      id: id,
      title: 'Rec $id',
      timestamp: '9:00 AM',
      duration: '0:30',
      audioFilePath: '/tmp/$id.m4a',
      createdAt: createdAt,
      matomeId: Value(matomeId),
      mediaType: Value(mediaType),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ContactsDao dao;

  setUp(() {
    db = _memDb();
    dao = db.contactsDao;
  });

  tearDown(() => db.close());

  group('listMatomesForContact', () {
    test('returns the contact\'s matomes with roles, newest happening first',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1', title: 'Older', happenedAt: 100);
      await _seedMatome(db, id: 'm2', title: 'Newer', happenedAt: 900);
      await dao.addContactToMatome(
          matomeId: 'm1', contactId: 'c1', role: 'attendee');
      await dao.addContactToMatome(
          matomeId: 'm2', contactId: 'c1', role: 'organizer');

      final result = await dao.listMatomesForContact('c1');
      expect(result.map((e) => e.matome.id).toList(), ['m2', 'm1']);
      expect(result.first.role, 'organizer');
    });

    test('excludes archived matomes', () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await _seedMatome(db, id: 'm2', archivedAt: 5000);
      await dao.addContactToMatome(matomeId: 'm1', contactId: 'c1');
      await dao.addContactToMatome(matomeId: 'm2', contactId: 'c1');

      final result = await dao.listMatomesForContact('c1');
      expect(result.map((e) => e.matome.id).toList(), ['m1']);
    });

    test('empty when the contact has no matomes', () async {
      await _seedContact(db, 'c1');
      expect(await dao.listMatomesForContact('c1'), isEmpty);
    });
  });

  group('listSpacesForContact', () {
    test('returns the spaces the contact is a member of', () async {
      await _seedContact(db, 'c1');
      await dao.addContactToSpace(spaceId: _kSpace, contactId: 'c1');

      final result = await dao.listSpacesForContact('c1');
      expect(result.map((w) => w.id).toList(), [_kSpace]);
    });

    test('empty when the contact is in no space', () async {
      await _seedContact(db, 'c1');
      expect(await dao.listSpacesForContact('c1'), isEmpty);
    });
  });

  group('listFilesForContactViaMatomes', () {
    test('returns recordings of the contact\'s matomes, newest first',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await dao.addContactToMatome(matomeId: 'm1', contactId: 'c1');
      await _seedRecording(db, id: 'r1', matomeId: 'm1', createdAt: 100);
      await _seedRecording(db, id: 'r2', matomeId: 'm1', createdAt: 900);

      final result = await dao.listFilesForContactViaMatomes('c1');
      expect(result.map((r) => r.id).toList(), ['r2', 'r1']);
    });

    test('does NOT return files from matomes the contact is not tagged in',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await _seedMatome(db, id: 'm2');
      await dao.addContactToMatome(matomeId: 'm1', contactId: 'c1');
      await _seedRecording(db, id: 'r1', matomeId: 'm1');
      await _seedRecording(db, id: 'rOther', matomeId: 'm2');

      final result = await dao.listFilesForContactViaMatomes('c1');
      expect(result.map((r) => r.id).toList(), ['r1']);
    });

    test('empty when the contact has no matomes (matome-mediated only)',
        () async {
      await _seedContact(db, 'c1');
      expect(await dao.listFilesForContactViaMatomes('c1'), isEmpty);
    });
  });

  group('recording_contacts — the DIRECT file↔contact edge (#1472)', () {
    test('link/unlink/list both ways, idempotent add', () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await _seedRecording(db, id: 'r1', matomeId: 'm1');

      await dao.linkContactToRecording(recordingId: 'r1', contactId: 'c1');
      // idempotent: re-link is a no-op (UNIQUE(recording_id, contact_id))
      await dao.linkContactToRecording(recordingId: 'r1', contactId: 'c1');

      expect((await dao.listContactsForFile('r1')).map((c) => c.id), ['c1']);
      expect((await dao.listFilesForContact('c1')).map((r) => r.id), ['r1']);

      final removed = await dao.unlinkContactFromRecording(
          recordingId: 'r1', contactId: 'c1');
      expect(removed, 1);
      expect(await dao.listContactsForFile('r1'), isEmpty);
      expect(await dao.listFilesForContact('c1'), isEmpty);
    });

    test('listFilesForContact returns only directly-linked files, newest first',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await _seedRecording(db, id: 'r1', matomeId: 'm1', createdAt: 100);
      await _seedRecording(db, id: 'r2', matomeId: 'm1', createdAt: 900);
      await _seedRecording(db, id: 'rOther', matomeId: 'm1');

      await dao.linkContactToRecording(recordingId: 'r1', contactId: 'c1');
      await dao.linkContactToRecording(recordingId: 'r2', contactId: 'c1');

      final result = await dao.listFilesForContact('c1');
      expect(result.map((r) => r.id).toList(), ['r2', 'r1']);
    });

    test('deleteContact cascades the direct recording_contacts edges',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await _seedRecording(db, id: 'r1', matomeId: 'm1');
      await dao.linkContactToRecording(recordingId: 'r1', contactId: 'c1');

      await dao.deleteContact('c1');
      expect(await dao.listContactsForFile('r1'), isEmpty);
    });
  });

  group('listFilesForContactUnion (direct ∪ matome-mediated, #1472)', () {
    test('unions direct and matome-mediated files, de-duped by id, newest first',
        () async {
      await _seedContact(db, 'c1');
      await _seedMatome(db, id: 'm1');
      await dao.addContactToMatome(matomeId: 'm1', contactId: 'c1');
      // via matome
      await _seedRecording(db, id: 'rViaMatome', matomeId: 'm1', createdAt: 100);
      // both direct AND via matome — must appear exactly once
      await _seedRecording(db, id: 'rBoth', matomeId: 'm1', createdAt: 500);
      await dao.linkContactToRecording(recordingId: 'rBoth', contactId: 'c1');
      // direct only, on an Unfiled file (no matome) — proves direct surfaces it
      await db.recordingsDao.insertRecording(
        RecordingsCompanion.insert(
          id: 'rDirectOnly',
          title: 'Unfiled direct',
          timestamp: '9:00 AM',
          duration: '0:30',
          audioFilePath: '/tmp/rDirectOnly.m4a',
          createdAt: 900,
        ),
      );
      await dao.linkContactToRecording(
          recordingId: 'rDirectOnly', contactId: 'c1');

      final ids = (await dao.listFilesForContactUnion('c1'))
          .map((r) => r.id)
          .toList();
      // newest first; rBoth de-duplicated to a single entry
      expect(ids, ['rDirectOnly', 'rBoth', 'rViaMatome']);
      expect(ids.where((id) => id == 'rBoth').length, 1);
    });
  });
}
