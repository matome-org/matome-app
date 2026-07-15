import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/calendar/calendar_data.dart';

import '../support/item_fixtures.dart';

/// Unit tests for features/calendar/calendar_data.dart under the matome-centric
/// model (#1378): the Calendar groups **matomes** by `happened_at`, against a
/// real in-memory Drift DB.

int _epoch(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;

Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  required int happenedAt,
  String title = 'Stand-up call',
  String? spaceId,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      spaceId: Value(spaceId),
      happenedAt: happenedAt,
      createdAt: happenedAt,
    ),
  );
}

Future<void> _seedItem(
  AppDatabase db, {
  required String id,
  required String matomeId,
  required int createdAt,
}) {
  return insertTestFileItem(
    db,
    id: id,
    title: 'Rec',
    localPath: '/tmp/$id.m4a',
    createdAt: createdAt,
    matomeId: matomeId,
  );
}

void main() {
  group('CalendarData over Drift (matomes)', () {
    late AppDatabase db;
    late CalendarData data;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      data = CalendarData(db.matomesDao, '1');
    });
    tearDown(() => db.close());

    // --- fetchDaysWithMatomes ------------------------------------------------
    test('returns an empty Set when the month has no matomes', () async {
      final result = await data.fetchDaysWithMatomes(2026, 3); // April
      expect(result, isA<Set<int>>());
      expect(result, isEmpty);
    });

    test('returns day numbers for all days that have matomes', () async {
      await _seedMatome(db, id: 'm1', happenedAt: _epoch(2026, 4, 1, 8));
      await _seedMatome(db, id: 'm2', happenedAt: _epoch(2026, 4, 15, 12));
      await _seedMatome(db, id: 'm3', happenedAt: _epoch(2026, 4, 28, 20));
      // A matome in another month must be excluded.
      await _seedMatome(db, id: 'mX', happenedAt: _epoch(2026, 5, 3, 9));

      final result = await data.fetchDaysWithMatomes(2026, 3); // April
      expect(result, {1, 15, 28});
    });

    test('deduplicates days when several matomes share a day', () async {
      await _seedMatome(db, id: 'm1', happenedAt: _epoch(2026, 4, 10, 8));
      await _seedMatome(db, id: 'm2', happenedAt: _epoch(2026, 4, 10, 12));
      await _seedMatome(db, id: 'm3', happenedAt: _epoch(2026, 4, 10, 18));

      final result = await data.fetchDaysWithMatomes(2026, 3);
      expect(result.length, 1);
      expect(result.contains(10), isTrue);
    });

    test('February has 29 days in a leap year (2028)', () async {
      await _seedMatome(db, id: 'm29', happenedAt: _epoch(2028, 2, 29, 10));
      final result = await data.fetchDaysWithMatomes(2028, 1); // Feb
      expect(result.contains(29), isTrue);
    });

    test('February has 28 days in a non-leap year (2026)', () async {
      await _seedMatome(db, id: 'm28', happenedAt: _epoch(2026, 2, 28, 23));
      await _seedMatome(db, id: 'mar', happenedAt: _epoch(2026, 3, 1, 0));
      final result = await data.fetchDaysWithMatomes(2026, 1); // Feb
      expect(result, {28});
    });

    // --- fetchDayMatomes -----------------------------------------------------
    test('returns an empty list when the day has no matomes', () async {
      final result = await data.fetchDayMatomes(
        DateTime(2026, 4, 10),
        spaceNames: const {},
      );
      expect(result, isEmpty);
    });

    test('hydrates the item count for the day list', () async {
      await _seedMatome(
        db,
        id: 'm-1',
        title: 'Meeting',
        happenedAt: _epoch(2026, 4, 10, 9),
      );
      await _seedItem(
        db,
        id: 'r1',
        matomeId: 'm-1',
        createdAt: _epoch(2026, 4, 10, 9),
      );
      await _seedItem(
        db,
        id: 'r2',
        matomeId: 'm-1',
        createdAt: _epoch(2026, 4, 10, 10),
      );
      final result = await data.fetchDayMatomes(
        DateTime(2026, 4, 10),
        spaceNames: const {},
      );
      expect(result.single.title, 'Meeting');
      expect(result.single.itemCount, 2);
    });

    test('spaceName is null for inbox matomes', () async {
      await _seedMatome(db, id: 'm-inbox', happenedAt: _epoch(2026, 4, 10, 9));
      final result = await data.fetchDayMatomes(
        DateTime(2026, 4, 10),
        spaceNames: const {},
      );
      expect(result.single.spaceName, isNull);
      expect(result.single.spaceId, isNull);
    });

    test('resolves the space name + id for filed matomes', () async {
      final ws = await db.workspacesDao.createWorkspace('Engineering');
      await _seedMatome(
        db,
        id: 'm-eng',
        spaceId: ws.id,
        happenedAt: _epoch(2026, 4, 10, 9),
      );
      final result = await data.fetchDayMatomes(
        DateTime(2026, 4, 10),
        spaceNames: {ws.id: 'Engineering'},
      );
      expect(result.single.spaceName, 'Engineering');
      expect(result.single.spaceId, ws.id);
    });

    test(
      'preserves the DB ordering (newest first) without re-sorting',
      () async {
        await _seedMatome(
          db,
          id: 'm-early',
          happenedAt: _epoch(2026, 4, 10, 9),
        );
        await _seedMatome(
          db,
          id: 'm-late',
          happenedAt: _epoch(2026, 4, 10, 18),
        );
        final result = await data.fetchDayMatomes(
          DateTime(2026, 4, 10),
          spaceNames: const {},
        );
        expect(result.map((m) => m.id).toList(), ['m-late', 'm-early']);
      },
    );

    test('only returns matomes within the target day window', () async {
      await _seedMatome(db, id: 'prev', happenedAt: _epoch(2026, 4, 9, 23, 59));
      await _seedMatome(db, id: 'in', happenedAt: _epoch(2026, 4, 10, 0, 1));
      await _seedMatome(db, id: 'next', happenedAt: _epoch(2026, 4, 11, 0, 1));
      final result = await data.fetchDayMatomes(
        DateTime(2026, 4, 10),
        spaceNames: const {},
      );
      expect(result.map((m) => m.id).toList(), ['in']);
    });
  });
}
