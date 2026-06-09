import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/calendar/calendar_data.dart';

/// Unit tests for features/calendar/calendar_data.dart, mirroring the RN
/// apps/mobile/__tests__/unit/calendarData.test.ts cases against a real
/// in-memory Drift DB (the Flutter readers query Drift directly).

int _epoch(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;

Future<void> _seed(
  AppDatabase db, {
  required String id,
  required int createdAt,
  String title = 'Stand-up call',
  String duration = '1m 23s',
  String badge = 'Work',
  String? workspaceId,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: Value(id),
      title: Value(title),
      timestamp: const Value(''),
      duration: Value(duration),
      badge: Value(badge),
      isProcessing: const Value(0),
      audioFilePath: const Value(''),
      createdAt: Value(createdAt),
      mediaType: const Value('audio'),
      processingStatus: const Value('done'),
      workspaceId: Value(workspaceId),
    ),
  );
}

void main() {
  // --- parseDurationSeconds (pure) --------------------------------------
  group('parseDurationSeconds', () {
    test("maps '2m 45s' to 165 seconds", () {
      expect(parseDurationSeconds('2m 45s'), 165);
    });
    test("maps '5s' to 5 seconds", () {
      expect(parseDurationSeconds('5s'), 5);
    });
    test('returns 0 for unrecognised strings', () {
      expect(parseDurationSeconds('invalid'), 0);
    });
    test('returns 0 for the empty string', () {
      expect(parseDurationSeconds(''), 0);
    });
    test('returns 0 for null', () {
      expect(parseDurationSeconds(null), 0);
    });
    test("maps '0m 30s' to 30 seconds", () {
      expect(parseDurationSeconds('0m 30s'), 30);
    });
  });

  // --- coerceBadge (pure) -----------------------------------------------
  group('coerceBadge', () {
    test('keeps the valid values Work/Personal/Inbox', () {
      expect(coerceBadge('Work'), 'Work');
      expect(coerceBadge('Personal'), 'Personal');
      expect(coerceBadge('Inbox'), 'Inbox');
    });
    test('coerces an unknown badge to Inbox', () {
      expect(coerceBadge('WeirdValue'), 'Inbox');
    });
    test('coerces null to Inbox', () {
      expect(coerceBadge(null), 'Inbox');
    });
  });

  group('CalendarData over Drift', () {
    late AppDatabase db;
    late CalendarData data;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      data = CalendarData(db.recordingsDao);
    });
    tearDown(() => db.close());

    // --- fetchDaysWithRecordings ----------------------------------------
    test('returns an empty Set when the month has no recordings', () async {
      final result = await data.fetchDaysWithRecordings(2026, 3); // April
      expect(result, isA<Set<int>>());
      expect(result, isEmpty);
    });

    test('returns day numbers for all days that have recordings', () async {
      await _seed(db, id: 'r1', createdAt: _epoch(2026, 4, 1, 8));
      await _seed(db, id: 'r2', createdAt: _epoch(2026, 4, 15, 12));
      await _seed(db, id: 'r3', createdAt: _epoch(2026, 4, 28, 20));
      // A recording in another month must be excluded.
      await _seed(db, id: 'rX', createdAt: _epoch(2026, 5, 3, 9));

      final result = await data.fetchDaysWithRecordings(2026, 3); // April
      expect(result, {1, 15, 28});
    });

    test('deduplicates days when several recordings share a day', () async {
      await _seed(db, id: 'r1', createdAt: _epoch(2026, 4, 10, 8));
      await _seed(db, id: 'r2', createdAt: _epoch(2026, 4, 10, 12));
      await _seed(db, id: 'r3', createdAt: _epoch(2026, 4, 10, 18));

      final result = await data.fetchDaysWithRecordings(2026, 3);
      expect(result.length, 1);
      expect(result.contains(10), isTrue);
    });

    test('February has 29 days in a leap year (2028)', () async {
      await _seed(db, id: 'r29', createdAt: _epoch(2028, 2, 29, 10));
      final result = await data.fetchDaysWithRecordings(2028, 1); // Feb
      expect(result.contains(29), isTrue);
    });

    test('February has 28 days in a non-leap year (2026)', () async {
      // Feb 28 is the last day; nothing on Mar 1 should leak in.
      await _seed(db, id: 'r28', createdAt: _epoch(2026, 2, 28, 23));
      await _seed(db, id: 'mar', createdAt: _epoch(2026, 3, 1, 0));
      final result = await data.fetchDaysWithRecordings(2026, 1); // Feb
      expect(result, {28});
    });

    // --- fetchDayRecordings ---------------------------------------------
    test('returns an empty list when the day has no recordings', () async {
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result, isEmpty);
    });

    test('parses durations and coerces badges for the day list', () async {
      await _seed(
        db,
        id: 'rec-1',
        title: 'Meeting',
        duration: '2m 45s',
        badge: 'Work',
        createdAt: _epoch(2026, 4, 10, 9),
      );
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.single.duration, 165);
      expect(result.single.badge, 'Work');
    });

    test('coerces an unknown badge to Inbox in the day list', () async {
      await _seed(
        db,
        id: 'rec-bad',
        badge: 'WeirdValue',
        duration: '1m 0s',
        createdAt: _epoch(2026, 4, 10, 9),
      );
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.single.badge, 'Inbox');
    });

    test('workspaceName is null for inbox recordings (LEFT JOIN)', () async {
      await _seed(
        db,
        id: 'rec-7',
        badge: 'Inbox',
        createdAt: _epoch(2026, 4, 10, 9),
      );
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.single.workspaceName, isNull);
      expect(result.single.workspaceId, isNull);
    });

    test('joins the workspace name + id for spaced recordings', () async {
      final ws = await db.workspacesDao.createWorkspace('Engineering');
      await _seed(
        db,
        id: 'rec-eng',
        workspaceId: ws.id,
        createdAt: _epoch(2026, 4, 10, 9),
      );
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.single.workspaceName, 'Engineering');
      expect(result.single.workspaceId, ws.id);
    });

    test('preserves the DB ordering (newest first) without re-sorting',
        () async {
      await _seed(db, id: 'r-early', createdAt: _epoch(2026, 4, 10, 9));
      await _seed(db, id: 'r-late', createdAt: _epoch(2026, 4, 10, 18));
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.map((r) => r.id).toList(), ['r-late', 'r-early']);
    });

    test('only returns recordings within the target day window', () async {
      await _seed(db, id: 'prev', createdAt: _epoch(2026, 4, 9, 23, 59));
      await _seed(db, id: 'in', createdAt: _epoch(2026, 4, 10, 0, 1));
      await _seed(db, id: 'next', createdAt: _epoch(2026, 4, 11, 0, 1));
      final result = await data.fetchDayRecordings(DateTime(2026, 4, 10));
      expect(result.map((r) => r.id).toList(), ['in']);
    });
  });
}
