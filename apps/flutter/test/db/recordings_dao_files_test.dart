import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/file_row.dart';
import 'package:matome_flutter/core/db/matome_card.dart';

// ---------------------------------------------------------------------------
// RecordingsDao.filesForOwner — owner-scoped cross-matome + Unfiled file query
// (Omakiten #1461). SECURITY (A01 — Broken Access Control): the hard AC is that
// a file owned by owner B is NEVER returned for owner A, INCLUDING the Unfiled
// (no matome) and Inbox (no space) paths. These tests seed two owners and prove
// the scope holds on every path. In-memory NativeDatabase, no native file —
// mirrors matomes_dao_test.dart's pattern.
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

const String _ownerA = '1';
const String _ownerB = '2';

MatomesCompanion _matome({
  required String id,
  String title = 'Matome',
  String? spaceId,
  int? coreId,
}) {
  return MatomesCompanion.insert(
    id: id,
    title: title,
    spaceId: Value(spaceId),
    happenedAt: 1000,
    createdAt: 1000,
    coreId: Value(coreId),
  );
}

RecordingsCompanion _recording({
  required String id,
  required String ownerId,
  String title = 'File',
  int createdAt = 1000,
  String? matomeId,
  String? workspaceId,
  String mediaType = 'audio',
  String duration = '0:30',
  String? originalExtension,
  int? coreId,
  String processingStatus = 'done',
}) {
  return RecordingsCompanion.insert(
    id: id,
    title: title,
    timestamp: '9:00 AM',
    duration: duration,
    audioFilePath: '/tmp/$id.m4a',
    createdAt: createdAt,
    ownerId: Value(ownerId),
    matomeId: Value(matomeId),
    workspaceId: Value(workspaceId),
    mediaType: Value(mediaType),
    originalExtension: Value(originalExtension),
    coreId: Value(coreId),
    processingStatus: Value(processingStatus),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = _memDb());
  tearDown(() => db.close());

  group('filesForOwner — owner-scoping (A01, the hard AC)', () {
    test('a file owned by owner B is NEVER returned for owner A (filed)',
        () async {
      await db.matomesDao.create(_matome(id: 'm_a', title: 'A matome'));
      await db.matomesDao.create(_matome(id: 'm_b', title: 'B matome'));
      await db.recordingsDao
          .insertRecording(_recording(id: 'r_a', ownerId: _ownerA, matomeId: 'm_a'));
      await db.recordingsDao
          .insertRecording(_recording(id: 'r_b', ownerId: _ownerB, matomeId: 'm_b'));

      final filesA = await db.recordingsDao.filesForOwner(_ownerA);
      final filesB = await db.recordingsDao.filesForOwner(_ownerB);

      expect(filesA.map((f) => f.id), ['r_a']);
      expect(filesB.map((f) => f.id), ['r_b']);
    });

    test('UNFILED (matome_id NULL) rows are owner-scoped — B never leaks to A',
        () async {
      // Loose files, no matome at all. The owner predicate must be on the row,
      // not via a matome JOIN (which is NULL here and would otherwise leak).
      await db.recordingsDao.insertRecording(
        _recording(id: 'loose_a', ownerId: _ownerA, matomeId: null),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'loose_b', ownerId: _ownerB, matomeId: null),
      );

      final filesA = await db.recordingsDao.filesForOwner(_ownerA);

      expect(filesA.map((f) => f.id), ['loose_a']);
      expect(filesA.single.unfiled, isTrue);
      // B's loose file must be absent from A's view.
      expect(filesA.any((f) => f.id == 'loose_b'), isFalse);
    });

    test('INBOX (workspace_id NULL) rows are owner-scoped — B never leaks to A',
        () async {
      // Files with no space (Inbox), each filed in a matome that itself has no
      // space. The scope must hold even though the workspace JOIN is NULL.
      await db.matomesDao.create(_matome(id: 'm_a', spaceId: null));
      await db.matomesDao.create(_matome(id: 'm_b', spaceId: null));
      await db.recordingsDao.insertRecording(_recording(
        id: 'inbox_a',
        ownerId: _ownerA,
        matomeId: 'm_a',
        workspaceId: null,
      ));
      await db.recordingsDao.insertRecording(_recording(
        id: 'inbox_b',
        ownerId: _ownerB,
        matomeId: 'm_b',
        workspaceId: null,
      ));

      final filesA = await db.recordingsDao.filesForOwner(_ownerA);

      expect(filesA.map((f) => f.id), ['inbox_a']);
      expect(filesA.single.inInbox, isTrue);
      expect(filesA.any((f) => f.id == 'inbox_b'), isFalse);
    });

    test('a NULL-owner (legacy un-backfilled) row never surfaces for any owner',
        () async {
      await db.recordingsDao.insertRecording(
        // ownerId omitted → NULL (legacy / pre-m013 row).
        RecordingsCompanion.insert(
          id: 'legacy',
          title: 'Legacy',
          timestamp: '9:00 AM',
          duration: '0:30',
          audioFilePath: '/tmp/legacy.m4a',
          createdAt: 1000,
        ),
      );

      expect(await db.recordingsDao.filesForOwner(_ownerA), isEmpty);
      expect(await db.recordingsDao.filesForOwner(_ownerB), isEmpty);
    });
  });

  group('filesForOwner — cross-matome + unfiled aggregation for one owner', () {
    test('returns the owner files across matomes AND unfiled, newest first',
        () async {
      await db.matomesDao.create(_matome(id: 'm1', title: 'Trip'));
      await db.matomesDao.create(_matome(id: 'm2', title: 'Sprint'));
      await db.recordingsDao.insertRecording(_recording(
        id: 'r1',
        ownerId: _ownerA,
        matomeId: 'm1',
        createdAt: 100,
      ));
      await db.recordingsDao.insertRecording(_recording(
        id: 'r2',
        ownerId: _ownerA,
        matomeId: 'm2',
        createdAt: 300,
      ));
      await db.recordingsDao.insertRecording(_recording(
        id: 'r3',
        ownerId: _ownerA,
        matomeId: null, // unfiled
        createdAt: 200,
      ));

      final files = await db.recordingsDao.filesForOwner(_ownerA);

      // All three (across two matomes + unfiled), newest createdAt first.
      expect(files.map((f) => f.id), ['r2', 'r3', 'r1']);
      expect(files.firstWhere((f) => f.id == 'r2').matome, 'Sprint');
      expect(files.firstWhere((f) => f.id == 'r3').unfiled, isTrue);
    });
  });

  group('filesForOwner — view-model mapping', () {
    test('maps kind, ext, duration, space and contacts from the schema',
        () async {
      // Seed a space and a contact tagged on the matome.
      final spaceId = (await db.workspacesDao.getWorkspaces()).first.id;
      await db.matomesDao
          .create(_matome(id: 'm1', title: 'Q3', spaceId: spaceId, coreId: 9));
      await db.contactsDao.create(ContactsCompanion.insert(
        id: 'c1',
        ownerId: _ownerA,
        displayName: 'Alice',
        createdAt: 1000,
      ));
      await db.contactsDao
          .addContactToMatome(matomeId: 'm1', contactId: 'c1');

      // A document file (with original extension) filed in the matome + space.
      await db.recordingsDao.insertRecording(_recording(
        id: 'doc1',
        ownerId: _ownerA,
        title: 'budget',
        matomeId: 'm1',
        workspaceId: spaceId,
        mediaType: 'document',
        originalExtension: 'xlsx',
        coreId: 9,
      ));
      // An audio file, unfiled.
      await db.recordingsDao.insertRecording(_recording(
        id: 'aud1',
        ownerId: _ownerA,
        title: 'memo',
        mediaType: 'audio',
        duration: '1:23',
        createdAt: 2000,
      ));

      final files = await db.recordingsDao.filesForOwner(_ownerA);
      final doc = files.firstWhere((f) => f.id == 'doc1');
      final aud = files.firstWhere((f) => f.id == 'aud1');

      expect(doc.kind, FileKind.document);
      expect(doc.ext, 'xlsx');
      expect(doc.duration, isNull); // documents have no duration
      expect(doc.space, isNotNull); // filed in a space → not Inbox
      expect(doc.inInbox, isFalse);
      expect(doc.matome, 'Q3');
      expect(doc.contacts, ['Alice']); // matome-mediated
      expect(doc.rollup, MatomeSyncRollup.cloud); // coreId set, done

      expect(aud.kind, FileKind.audio);
      expect(aud.duration, '1:23');
      expect(aud.unfiled, isTrue);
      expect(aud.contacts, isEmpty); // unfiled, no direct link → no contacts
      expect(aud.rollup, MatomeSyncRollup.onDevice); // no coreId
    });
  });

  group('filesForOwner — direct file↔contact edge in the people cluster (#1472)',
      () {
    test('people union direct + matome-mediated, de-duped; direct surfaces on '
        'an Unfiled file', () async {
      await db.matomesDao.create(_matome(id: 'm1', title: 'Q3'));
      // Bob is tagged on the matome; Alice is linked DIRECTLY to the file; Carol
      // is linked BOTH ways and must appear exactly once.
      for (final c in ['alice', 'bob', 'carol']) {
        await db.contactsDao.create(ContactsCompanion.insert(
          id: c,
          ownerId: _ownerA,
          displayName: c[0].toUpperCase() + c.substring(1),
          createdAt: 1000,
        ));
      }
      await db.contactsDao.addContactToMatome(matomeId: 'm1', contactId: 'bob');
      await db.contactsDao
          .addContactToMatome(matomeId: 'm1', contactId: 'carol');

      await db.recordingsDao.insertRecording(
        _recording(id: 'filed', ownerId: _ownerA, matomeId: 'm1'),
      );
      await db.contactsDao
          .linkContactToRecording(recordingId: 'filed', contactId: 'alice');
      await db.contactsDao
          .linkContactToRecording(recordingId: 'filed', contactId: 'carol');

      // an UNFILED file with a direct contact link — previously impossible.
      await db.recordingsDao.insertRecording(
        _recording(id: 'loose', ownerId: _ownerA, matomeId: null),
      );
      await db.contactsDao
          .linkContactToRecording(recordingId: 'loose', contactId: 'alice');

      final files = await db.recordingsDao.filesForOwner(_ownerA);
      final filed = files.firstWhere((f) => f.id == 'filed');
      final loose = files.firstWhere((f) => f.id == 'loose');

      // direct (Alice, Carol) ∪ matome (Bob, Carol), Carol de-duplicated.
      expect(filed.contacts.toSet(), {'Alice', 'Bob', 'Carol'});
      expect(filed.contacts.where((n) => n == 'Carol').length, 1);
      // the Unfiled file now shows its direct person.
      expect(loose.contacts, ['Alice']);
      expect(loose.unfiled, isTrue);
    });

    test('a cross-owner contact linked to an owned file does NOT leak into the '
        "people cluster (defense-in-depth)", () async {
      // Forge a direct link from owner A's file to a contact owned by B. The
      // file is A's, but the people cluster must filter the joined contact on
      // owner, so B's contact never surfaces in A's view.
      await db.contactsDao.create(ContactsCompanion.insert(
        id: 'b_contact',
        ownerId: _ownerB,
        displayName: 'Mallory',
        createdAt: 1000,
      ));
      await db.recordingsDao.insertRecording(
        _recording(id: 'a_file', ownerId: _ownerA, matomeId: null),
      );
      await db.contactsDao
          .linkContactToRecording(recordingId: 'a_file', contactId: 'b_contact');

      final files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.firstWhere((f) => f.id == 'a_file').contacts, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // move-to-matome (#1473) — owner-scoped reassignment + targets + undo
  // -------------------------------------------------------------------------

  group('matomeTargetsForOwner — owner-scoped picker targets (A01)', () {
    test('lists only matomes the owner has recordings in, newest happening first',
        () async {
      await db.matomesDao.create(_matome(id: 'm_a1', title: 'Trip'));
      await db.matomesDao.create(_matome(id: 'm_a2', title: 'Sprint'));
      await db.matomesDao.create(_matome(id: 'm_b', title: 'B matome'));
      // Owner A owns files in m_a1 + m_a2; owner B owns a file in m_b.
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm_a1'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r2', ownerId: _ownerA, matomeId: 'm_a2'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r3', ownerId: _ownerB, matomeId: 'm_b'));

      final targets = await db.recordingsDao.matomeTargetsForOwner(_ownerA);
      // Only A's two matomes — B's matome is NOT a target for A.
      expect(targets.map((m) => m.id).toSet(), {'m_a1', 'm_a2'});
      expect(targets.any((m) => m.id == 'm_b'), isFalse);
    });

    test('excludes archived matomes', () async {
      await db.matomesDao.create(_matome(id: 'm_live', title: 'Live'));
      await db.matomesDao.create(_matome(id: 'm_arch', title: 'Archived'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm_live'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r2', ownerId: _ownerA, matomeId: 'm_arch'));
      await db.matomesDao.archive('m_arch');

      final targets = await db.recordingsDao.matomeTargetsForOwner(_ownerA);
      expect(targets.map((m) => m.id), ['m_live']);
    });
  });

  group('moveRecordingsToMatome — owner-scoped reassignment (A01)', () {
    test('reassigns the owner files; the provider query reflects the new matome',
        () async {
      await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
      await db.matomesDao.create(_matome(id: 'm_dst', title: 'Dest'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm_src'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r2', ownerId: _ownerA, matomeId: 'm_src'));

      final moved = await db.recordingsDao
          .moveRecordingsToMatome({'r1', 'r2'}, 'm_dst', _ownerA);
      expect(moved, 2);

      final files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.firstWhere((f) => f.id == 'r1').matome, 'Dest');
      expect(files.firstWhere((f) => f.id == 'r2').matome, 'Dest');
    });

    test('moving to null (Unfiled) clears the matome relation', () async {
      await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm_src'));

      final moved =
          await db.recordingsDao.moveRecordingsToMatome({'r1'}, null, _ownerA);
      expect(moved, 1);
      final files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.single.unfiled, isTrue);
    });

    test('CROSS-OWNER target is rejected — a no-op, the file is unchanged',
        () async {
      // m_b holds only owner B's file → not a target for A. A forged move of A's
      // file into m_b must move zero rows and leave A's file where it was.
      await db.matomesDao.create(_matome(id: 'm_a', title: 'A'));
      await db.matomesDao.create(_matome(id: 'm_b', title: 'B'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r_a', ownerId: _ownerA, matomeId: 'm_a'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r_b', ownerId: _ownerB, matomeId: 'm_b'));

      final moved =
          await db.recordingsDao.moveRecordingsToMatome({'r_a'}, 'm_b', _ownerA);
      expect(moved, 0);
      final files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.single.matome, 'A'); // unchanged
    });

    test("CROSS-OWNER row id cannot be moved by another owner (owner-scoped WHERE)",
        () async {
      // Owner A tries to move owner B's file into A's own matome. The owner
      // predicate on the UPDATE matches zero rows → no-op, B's file untouched.
      await db.matomesDao.create(_matome(id: 'm_a', title: 'A'));
      await db.matomesDao.create(_matome(id: 'm_b', title: 'B'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r_a', ownerId: _ownerA, matomeId: 'm_a'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r_b', ownerId: _ownerB, matomeId: 'm_b'));

      final moved =
          await db.recordingsDao.moveRecordingsToMatome({'r_b'}, 'm_a', _ownerA);
      expect(moved, 0);
      final filesB = await db.recordingsDao.filesForOwner(_ownerB);
      expect(filesB.single.matome, 'B'); // B's file untouched
    });
  });

  group('move undo — stash prior + restore (A01)', () {
    test('matomeIdsForOwnedRecordings returns prior filing, owner-scoped',
        () async {
      await db.matomesDao.create(_matome(id: 'm1', title: 'M1'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm1'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'loose', ownerId: _ownerA, matomeId: null));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r_b', ownerId: _ownerB, matomeId: 'm1'));

      final prior = await db.recordingsDao
          .matomeIdsForOwnedRecordings({'r1', 'loose', 'r_b'}, _ownerA);
      // r_b is owner B's → absent. r1 → m1; loose → null.
      expect(prior, {'r1': 'm1', 'loose': null});
    });

    test('restoreRecordingMatomes restores the prior matome (including Unfiled)',
        () async {
      await db.matomesDao.create(_matome(id: 'm_src', title: 'Source'));
      await db.matomesDao.create(_matome(id: 'm_dst', title: 'Dest'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r1', ownerId: _ownerA, matomeId: 'm_src'));
      await db.recordingsDao.insertRecording(
          _recording(id: 'r2', ownerId: _ownerA, matomeId: null)); // Unfiled

      final prior = await db.recordingsDao
          .matomeIdsForOwnedRecordings({'r1', 'r2'}, _ownerA);
      await db.recordingsDao
          .moveRecordingsToMatome({'r1', 'r2'}, 'm_dst', _ownerA);
      // Both now in Dest.
      var files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.every((f) => f.matome == 'Dest'), isTrue);

      // Undo.
      await db.recordingsDao.restoreRecordingMatomes(prior, _ownerA);
      files = await db.recordingsDao.filesForOwner(_ownerA);
      expect(files.firstWhere((f) => f.id == 'r1').matome, 'Source');
      expect(files.firstWhere((f) => f.id == 'r2').unfiled, isTrue);
    });
  });
}
