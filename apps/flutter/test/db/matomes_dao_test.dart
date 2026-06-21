import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/daos/matomes_dao.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/features/matome/matome_ids.dart';

// ---------------------------------------------------------------------------
// MatomesDao tests (Omakiten #1370). In-memory NativeDatabase, no native file
// or path_provider — mirrors app_database_test.dart's pattern.
// ---------------------------------------------------------------------------

AppDatabase _memDb() => AppDatabase.forTesting(NativeDatabase.memory());

const String _kSpace = 'ws_default_personal'; // seeded on onCreate

MatomesCompanion _matome({
  required String id,
  String title = 'Untitled',
  String? spaceId,
  int happenedAt = 1000,
  int createdAt = 1000,
  String? description,
  String? aggregatedSummary,
  bool summaryStale = false,
  int? coreId,
}) {
  return MatomesCompanion.insert(
    id: id,
    title: title,
    spaceId: Value(spaceId),
    happenedAt: happenedAt,
    createdAt: createdAt,
    description: Value(description),
    aggregatedSummary: Value(aggregatedSummary),
    summaryStale: Value(summaryStale),
    coreId: Value(coreId),
  );
}

RecordingsCompanion _recording({
  required String id,
  String title = 'Rec',
  required int createdAt,
  String? matomeId,
  String? workspaceId,
  String? summary,
  String mediaType = 'audio',
}) {
  return RecordingsCompanion.insert(
    id: id,
    title: title,
    timestamp: '9:00 AM',
    duration: '0:30',
    audioFilePath: '/tmp/$id.m4a',
    createdAt: createdAt,
    matomeId: Value(matomeId),
    workspaceId: Value(workspaceId),
    summary: Value(summary),
    mediaType: Value(mediaType),
  );
}

void main() {
  late AppDatabase db;
  late MatomesDao dao;

  setUp(() {
    db = _memDb();
    dao = db.matomesDao;
  });
  tearDown(() => db.close());

  group('CRUD', () {
    test('create + getById round-trips a row faithfully', () async {
      final id = mintLocalMatomeId();
      await dao.create(
        _matome(
          id: id,
          title: 'Lunch with Aki',
          spaceId: _kSpace,
          happenedAt: 5000,
          createdAt: 4000,
          description: 'desc',
          aggregatedSummary: 'sum',
          summaryStale: true,
          coreId: 42,
        ),
      );

      final row = await dao.getById(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.title, 'Lunch with Aki');
      expect(row.spaceId, _kSpace);
      expect(row.happenedAt, 5000);
      expect(row.createdAt, 4000);
      expect(row.description, 'desc');
      expect(row.aggregatedSummary, 'sum');
      expect(row.summaryStale, isTrue);
      expect(row.coreId, 42);
    });

    test('getById returns null for an unknown id', () async {
      expect(await dao.getById('nope'), isNull);
    });

    test('updateMatome writes only the patched fields', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, title: 'Before'));

      final n = await dao.updateMatome(
        id,
        const MatomesCompanion(title: Value('After')),
      );
      expect(n, 1);

      final row = await dao.getById(id);
      expect(row!.title, 'After');
      expect(row.summaryStale, isFalse); // untouched
    });

    test('deleteMatome removes the row', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id));
      expect(await dao.deleteMatome(id), 1);
      expect(await dao.getById(id), isNull);
    });

    test('matomeByCoreId resolves the reconciled row', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, coreId: 99));
      final row = await dao.matomeByCoreId(99);
      expect(row?.id, id);
      expect(await dao.matomeByCoreId(7), isNull);
    });
  });

  group('archive / restore (soft-delete #1409)', () {
    test('archive stamps archivedAt; restore clears it', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, title: 'Soft'));
      expect((await dao.getById(id))!.archivedAt, isNull);

      expect(await dao.archive(id), 1);
      final archived = await dao.getById(id);
      expect(archived!.archivedAt, isNotNull);

      expect(await dao.restore(id), 1);
      expect((await dao.getById(id))!.archivedAt, isNull);
    });

    test('an archived matome drops out of EVERY list query', () async {
      final inbox = mintLocalMatomeId();
      final filed = mintLocalMatomeId();
      await dao.create(_matome(id: inbox, spaceId: null, happenedAt: 100));
      await dao.create(_matome(id: filed, spaceId: _kSpace, happenedAt: 200));

      await dao.archive(inbox);
      await dao.archive(filed);

      expect(await dao.listMatomes(), isEmpty);
      expect(await dao.listInboxMatomes(), isEmpty);
      expect(await dao.listFiledMatomes(), isEmpty);
      expect(await dao.listMatomesInSpace(_kSpace), isEmpty);
      expect(await dao.listMatomesByDate(), isEmpty);
      expect(await dao.matomesByDateRange(0, 1000), isEmpty);
      expect(await dao.listInboxMatomeItems(), isEmpty);
      expect(await dao.listMatomeItemsInSpace(_kSpace), isEmpty);
      expect(await dao.matomeItemsByDateRange(0, 1000), isEmpty);
    });

    test('restore brings the matome back into the lists', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, spaceId: _kSpace, happenedAt: 100));
      await dao.archive(id);
      expect(await dao.listMatomesInSpace(_kSpace), isEmpty);

      await dao.restore(id);
      final back = await dao.listMatomesInSpace(_kSpace);
      expect(back.map((m) => m.id), [id]);
    });

    test('archive retains the row and its child recordings (soft, not hard)',
        () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, spaceId: _kSpace));
      await db.recordingsDao.insertRecording(
        _recording(id: 'child', createdAt: 1, matomeId: id),
      );

      await dao.archive(id);

      // The row is still there (getById ignores the archive filter) and so are
      // its children — archiving never deletes data.
      expect(await dao.getById(id), isNotNull);
      final hub = await dao.getMatomeWithRecordings(id);
      expect(hub!.recordings.map((r) => r.id), ['child']);
    });
  });

  group('getMatomeWithRecordings', () {
    test('returns the Matome + exactly its recordings (not others)', () async {
      final mA = mintLocalMatomeId();
      final mB = mintLocalMatomeId();
      await dao.create(_matome(id: mA, title: 'A'));
      await dao.create(_matome(id: mB, title: 'B'));

      await db.recordingsDao.insertRecording(
        _recording(id: 'a1', createdAt: 100, matomeId: mA),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'a2', createdAt: 200, matomeId: mA),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'b1', createdAt: 300, matomeId: mB),
      );

      final item = await dao.getMatomeWithRecordings(mA);
      expect(item, isNotNull);
      expect(item!.id, mA);
      expect(item.recordingCount, 2);
      expect(
        item.recordings.map((r) => r.id),
        // newest createdAt first
        equals(<String>['a2', 'a1']),
      );
    });

    test('returns null for an unknown id', () async {
      expect(await dao.getMatomeWithRecordings('nope'), isNull);
    });

    test('hydrates a MatomeItem from the row', () async {
      final id = mintLocalMatomeId();
      await dao.create(
        _matome(id: id, title: 'T', aggregatedSummary: 'agg'),
      );
      final item = await dao.getMatomeWithRecordings(id);
      expect(item, isA<MatomeItem>());
      expect(item!.title, 'T');
      expect(item.aggregatedSummary, 'agg');
      expect(item.isInbox, isTrue); // spaceId null
      expect(item.isLocalOnly, isTrue); // coreId null
      expect(item.recordings, isEmpty);
      expect(item.recordingCount, 0);
    });
  });

  group('listMatomes filtering', () {
    setUp(() async {
      await dao.create(
        _matome(id: 'm_inbox', spaceId: null, happenedAt: 100),
      );
      await dao.create(
        _matome(id: 'm_space', spaceId: _kSpace, happenedAt: 300),
      );
      await dao.create(
        _matome(id: 'm_inbox2', spaceId: null, happenedAt: 200),
      );
    });

    test('listMatomes returns all, newest happened_at first', () async {
      final all = await dao.listMatomes();
      expect(all.map((m) => m.id), equals(['m_space', 'm_inbox2', 'm_inbox']));
    });

    test('listInboxMatomes returns only space_id IS NULL', () async {
      final inbox = await dao.listInboxMatomes();
      expect(inbox.map((m) => m.id), equals(['m_inbox2', 'm_inbox']));
    });

    test('listMatomesInSpace returns only that space', () async {
      final inSpace = await dao.listMatomesInSpace(_kSpace);
      expect(inSpace.map((m) => m.id), equals(['m_space']));
    });

    test('listMatomesByDate orders by happened_at desc', () async {
      final byDate = await dao.listMatomesByDate();
      expect(
        byDate.map((m) => m.happenedAt),
        equals(<int>[300, 200, 100]),
      );
    });
  });

  group('moveRecordingToMatome', () {
    test('reassigns a recording to a different Matome (move)', () async {
      final mA = mintLocalMatomeId();
      final mB = mintLocalMatomeId();
      await dao.create(_matome(id: mA));
      await dao.create(_matome(id: mB));
      await db.recordingsDao.insertRecording(
        _recording(id: 'r1', createdAt: 1, matomeId: mA),
      );

      final n = await dao.moveRecordingToMatome('r1', mB);
      expect(n, 1);

      final fromA = await dao.getMatomeWithRecordings(mA);
      final fromB = await dao.getMatomeWithRecordings(mB);
      expect(fromA!.recordings, isEmpty);
      expect(fromB!.recordings.map((r) => r.id), equals(['r1']));
    });

    test('marks BOTH the source and destination summaries stale', () async {
      final mA = mintLocalMatomeId();
      final mB = mintLocalMatomeId();
      // Both start with a fresh (non-stale) stored summary.
      await dao.create(_matome(id: mA, summaryStale: false));
      await dao.create(_matome(id: mB, summaryStale: false));
      await db.recordingsDao.insertRecording(
        _recording(id: 'r1', createdAt: 1, matomeId: mA),
      );
      // Clear the stale flag set by the insert itself so we observe the MOVE.
      await dao.markSummaryStale(mA, false);
      await dao.markSummaryStale(mB, false);

      await dao.moveRecordingToMatome('r1', mB);

      expect((await dao.getById(mA))!.summaryStale, isTrue);
      expect((await dao.getById(mB))!.summaryStale, isTrue);
    });
  });

  group('regenerateSummary', () {
    test('composes from current items, stores it, and clears stale', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, summaryStale: true));
      await db.recordingsDao.insertRecording(
        _recording(
          id: 'r1',
          title: 'Kickoff',
          createdAt: 100,
          matomeId: id,
          summary: 'Agreed scope.',
        ),
      );
      await db.recordingsDao.insertRecording(
        _recording(
          id: 'r2',
          title: 'Recap',
          createdAt: 50,
          matomeId: id,
          summary: 'Next steps.',
        ),
      );

      final out = await dao.regenerateSummary(id);
      expect(out, isNotNull);
      expect(out, contains('2 recordings'));

      final row = await dao.getById(id);
      expect(row!.aggregatedSummary, out);
      expect(row.summaryStale, isFalse);
      expect(row.aggregatedSummary, contains('• Kickoff: Agreed scope.'));
    });

    test('NULLs the summary (still clearing stale) when no item has one',
        () async {
      final id = mintLocalMatomeId();
      await dao.create(
        _matome(id: id, aggregatedSummary: 'stale text', summaryStale: true),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'r1', createdAt: 1, matomeId: id, summary: null),
      );

      final out = await dao.regenerateSummary(id);
      expect(out, isNull);

      final row = await dao.getById(id);
      expect(row!.aggregatedSummary, isNull);
      expect(row.summaryStale, isFalse);
    });

    test('returns null for an unknown Matome', () async {
      expect(await dao.regenerateSummary('nope'), isNull);
    });
  });

  group('item-change invalidation', () {
    test('adding an Item via upsertRecordingWithMatome marks summary stale',
        () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, summaryStale: false));

      await db.recordingsDao.upsertRecordingWithMatome(
        _recording(id: 'r1', createdAt: 1, matomeId: id, summary: 'x'),
      );

      expect((await dao.getById(id))!.summaryStale, isTrue);
    });
  });

  group('summary mutations', () {
    test('setAggregatedSummary stores text and clears stale flag', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id, summaryStale: true));

      final n = await dao.setAggregatedSummary(id, 'the summary');
      expect(n, 1);

      final row = await dao.getById(id);
      expect(row!.aggregatedSummary, 'the summary');
      expect(row.summaryStale, isFalse);
    });

    test('markSummaryStale toggles the flag', () async {
      final id = mintLocalMatomeId();
      await dao.create(_matome(id: id));

      expect(await dao.markSummaryStale(id, true), 1);
      expect((await dao.getById(id))!.summaryStale, isTrue);

      expect(await dao.markSummaryStale(id, false), 1);
      expect((await dao.getById(id))!.summaryStale, isFalse);
    });
  });

  // Hydrated list cards + the deep-link resolver (#1378).
  group('list cards (#1378)', () {
    test('listInboxMatomeItems returns inbox matomes with item counts',
        () async {
      await dao.create(_matome(id: 'inbox-a', happenedAt: 2000));
      await dao.create(_matome(id: 'inbox-b', happenedAt: 1000));
      await dao.create(_matome(id: 'filed', spaceId: _kSpace, happenedAt: 3000));
      // Two recordings under inbox-a, none under inbox-b.
      await db.recordingsDao
          .insertRecording(_recording(id: 'r1', createdAt: 1, matomeId: 'inbox-a'));
      await db.recordingsDao
          .insertRecording(_recording(id: 'r2', createdAt: 2, matomeId: 'inbox-a'));

      final items = await dao.listInboxMatomeItems();
      expect(items.map((m) => m.id), ['inbox-a', 'inbox-b']); // newest first
      expect(items.first.recordingCount, 2);
      expect(items[1].recordingCount, 0);
    });

    test('listMatomeItemsInSpace returns only that space\'s matomes', () async {
      await dao.create(_matome(id: 'in', spaceId: _kSpace, happenedAt: 1000));
      await dao.create(_matome(id: 'out', happenedAt: 2000)); // inbox

      final items = await dao.listMatomeItemsInSpace(_kSpace);
      expect(items.map((m) => m.id), ['in']);
    });

    test('matomeItemsByDateRange windows by happened_at', () async {
      await dao.create(_matome(id: 'before', happenedAt: 100));
      await dao.create(_matome(id: 'inside', happenedAt: 500));
      await dao.create(_matome(id: 'after', happenedAt: 900));

      final items = await dao.matomeItemsByDateRange(400, 600);
      expect(items.map((m) => m.id), ['inside']);
    });

    test('matomeIdForRecording resolves a recording to its parent matome',
        () async {
      await dao.create(_matome(id: 'parent', happenedAt: 1000));
      await db.recordingsDao.insertRecording(
        _recording(id: 'child', createdAt: 1, matomeId: 'parent'),
      );

      expect(await dao.matomeIdForRecording('child'), 'parent');
      expect(await dao.matomeIdForRecording('nope'), isNull);
    });
  });

  // The list-row rework (#1412) derives the dense meta strip's counts inside
  // `_hydrateCounts`: audio/image split by mediaType, people from
  // `matome_contacts`, and the filed Space name from `workspaces`.
  group('list-card derived fields (#1412)', () {
    Future<void> addContact(String contactId, String matomeId) async {
      await db.contactsDao.create(
        ContactsCompanion.insert(
          id: contactId,
          ownerId: 'owner',
          displayName: contactId,
          createdAt: 1,
        ),
      );
      await db.contactsDao.addContactToMatome(
        matomeId: matomeId,
        contactId: contactId,
      );
    }

    test('splits the item mix into audio / image counts by mediaType',
        () async {
      await dao.create(_matome(id: 'm', spaceId: null, happenedAt: 100));
      await db.recordingsDao.insertRecording(
        _recording(id: 'a1', createdAt: 1, matomeId: 'm', mediaType: 'audio'),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'a2', createdAt: 2, matomeId: 'm', mediaType: 'audio'),
      );
      await db.recordingsDao.insertRecording(
        _recording(id: 'i1', createdAt: 3, matomeId: 'm', mediaType: 'image'),
      );

      final item = (await dao.listInboxMatomeItems()).single;
      expect(item.recordingCount, 3);
      expect(item.audioCount, 2);
      expect(item.imageCount, 1);
    });

    test('counts tagged people from matome_contacts', () async {
      await dao.create(_matome(id: 'm', spaceId: null, happenedAt: 100));
      await addContact('c1', 'm');
      await addContact('c2', 'm');

      final item = (await dao.listInboxMatomeItems()).single;
      expect(item.peopleCount, 2);
    });

    test('Inbox cards carry no spaceName; filed cards resolve the Space name',
        () async {
      await dao.create(_matome(id: 'inbox', spaceId: null, happenedAt: 200));
      await dao.create(_matome(id: 'filed', spaceId: _kSpace, happenedAt: 100));

      final inbox = (await dao.listInboxMatomeItems()).single;
      expect(inbox.spaceName, isNull);

      final filed = (await dao.listMatomeItemsInSpace(_kSpace)).single;
      expect(filed.spaceName, isNotNull);
      expect(filed.spaceName, isNotEmpty);
    });

    test('a matome with no items / people reports zero counts', () async {
      await dao.create(_matome(id: 'empty', spaceId: null, happenedAt: 100));

      final item = (await dao.listInboxMatomeItems()).single;
      expect(item.recordingCount, 0);
      expect(item.audioCount, 0);
      expect(item.imageCount, 0);
      expect(item.peopleCount, 0);
    });
  });
}
