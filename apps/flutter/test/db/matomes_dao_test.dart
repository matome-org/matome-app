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
}
