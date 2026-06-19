import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/calendar/calendar_controller.dart';
// ignore_for_file: avoid_redundant_argument_values

/// Drives the matome-centric [CalendarController] (#1378) against a real
/// in-memory Drift DB: the unit is the **Matome**, grouped by `happened_at`.

int _epoch(int year, int month, int day, [int hour = 0]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch;

Future<void> _seed(
  AppDatabase db, {
  required String id,
  required int createdAt,
  String title = 'Team meeting',
  String? workspaceId,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      spaceId: Value(workspaceId),
      happenedAt: createdAt,
      createdAt: createdAt,
    ),
  );
}

/// Builds a container wired to [db] with a pinned clock, and returns the
/// Calendar controller built by Riverpod (so it gets a real Ref).
({ProviderContainer container, CalendarController controller}) _build(
  AppDatabase db, {
  DateTime? now,
}) {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (now != null)
        calendarNowProvider.overrideWithValue(() => now),
    ],
  );
  return (
    container: container,
    controller: container.read(calendarControllerProvider.notifier),
  );
}

/// Pump until [predicate] holds (the controller's loads are async).
Future<void> _pumpUntil(bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('bootstraps to today\'s year/month/day (0-indexed month)', () async {
    final now = DateTime(2026, 4, 10, 9);
    final b = _build(db, now: now);
    addTearDown(b.container.dispose);
    final controller = b.controller;

    expect(controller.state.year, now.year);
    expect(controller.state.month, now.month - 1);
    expect(controller.state.selectedDay, now.day);
    // Let the in-flight bootstrap loads settle before the container disposes.
    await _pumpUntil(() => !controller.state.isMonthLoading);
  });

  test('loads spaces from Drift workspaces on bootstrap', () async {
    await db.workspacesDao.createWorkspace('Design');
    await db.workspacesDao.createWorkspace('Marketing');
    final b = _build(db);
    addTearDown(b.container.dispose);
    final controller = b.controller;

    await _pumpUntil(() => controller.state.spaces.length == 2);
    expect(
      controller.state.spaces.map((s) => s.name),
      containsAll(['Design', 'Marketing']),
    );
  });

  test('loads the dots and the day list for the bootstrap month', () async {
    final fixed = DateTime(2026, 4, 10, 9);
    await _seed(db, id: 'r-today', createdAt: fixed.millisecondsSinceEpoch);
    await _seed(db, id: 'r-5th', createdAt: _epoch(2026, 4, 5, 9));

    final b = _build(db, now: fixed);
    addTearDown(b.container.dispose);
    final controller = b.controller;

    await _pumpUntil(() => controller.state.daysWithMatomes.isNotEmpty);
    expect(controller.state.daysWithMatomes, containsAll(<int>{5, 10}));
    // Day list is the selected (today=10th) day's recordings.
    expect(controller.state.dayMatomes.map((r) => r.id), ['r-today']);
  });

  group('space filter', () {
    late CalendarController controller;
    late ProviderContainer container;

    setUp(() async {
      final eng = await db.workspacesDao.createWorkspace('Engineering');
      final design = await db.workspacesDao.createWorkspace('Design');
      final day = _epoch(2026, 4, 10, 9);
      await _seed(db, id: 'r1', createdAt: day, workspaceId: eng.id);
      await _seed(db, id: 'r2', createdAt: day, workspaceId: design.id);
      await _seed(db, id: 'r3', createdAt: day, workspaceId: eng.id);
      await _seed(db, id: 'r4', createdAt: day); // inbox matome (no space)

      final b = _build(db, now: DateTime(2026, 4, 10, 9));
      container = b.container;
      controller = b.controller;
      addTearDown(container.dispose);
      await _pumpUntil(() => controller.state.rawDayMatomes.length == 4);
    });

    test('shows all recordings when no space filter is active', () {
      expect(controller.state.dayMatomes.length, 4);
    });

    test('filters to one space when its chip is active', () async {
      final eng =
          controller.state.spaces.firstWhere((s) => s.name == 'Engineering');
      controller.setSpaceFilter(eng.id);
      expect(controller.state.dayMatomes.map((r) => r.id), ['r1', 'r3']);
    });

    test('clears the filter (toggle off) restores all recordings', () {
      final eng =
          controller.state.spaces.firstWhere((s) => s.name == 'Engineering');
      controller.setSpaceFilter(eng.id);
      controller.setSpaceFilter(null);
      expect(controller.state.dayMatomes.length, 4);
    });
  });

  // CRITICAL-2 regression guard: month navigation always reloads the day list.
  test('changeMonth reloads the day list for the new month', () async {
    await _seed(db, id: 'apr', createdAt: _epoch(2026, 4, 10, 9));
    await _seed(db, id: 'mar', createdAt: _epoch(2026, 3, 10, 9));

    final b = _build(db, now: DateTime(2026, 4, 10, 9));
    addTearDown(b.container.dispose);
    final controller = b.controller;

    await _pumpUntil(() => controller.state.dayMatomes.isNotEmpty);
    expect(controller.state.dayMatomes.single.id, 'apr');

    // Navigate April -> March on day 10 (valid in both months). The day panel
    // must refresh to March's recordings, not keep stale April data.
    await controller.prevMonth();
    expect(controller.state.month, 2); // 0-indexed March
    expect(controller.state.dayMatomes.single.id, 'mar');
  });

  test('prevMonth wraps the year at January', () async {
    final b = _build(db, now: DateTime(2026, 1, 15));
    addTearDown(b.container.dispose);
    final controller = b.controller;
    await _pumpUntil(() => !controller.state.isMonthLoading);

    await controller.prevMonth();
    expect(controller.state.year, 2025);
    expect(controller.state.month, 11); // December
  });

  test('nextMonth wraps the year at December', () async {
    final b = _build(db, now: DateTime(2026, 12, 15));
    addTearDown(b.container.dispose);
    final controller = b.controller;
    await _pumpUntil(() => !controller.state.isMonthLoading);

    await controller.nextMonth();
    expect(controller.state.year, 2027);
    expect(controller.state.month, 0); // January
  });

  test('changeMonth clamps the selected day to the new month length',
      () async {
    // Mar 31 -> Feb (2026, 28 days): selectedDay should clamp to 1.
    final b = _build(db, now: DateTime(2026, 3, 31));
    addTearDown(b.container.dispose);
    final controller = b.controller;
    await _pumpUntil(() => !controller.state.isMonthLoading);

    await controller.prevMonth(); // -> February
    expect(controller.state.month, 1);
    expect(controller.state.selectedDay, 1);
  });

  test('selectDay loads that day\'s recordings', () async {
    await _seed(db, id: 'd5', createdAt: _epoch(2026, 4, 5, 9));
    final b = _build(db, now: DateTime(2026, 4, 10, 9));
    addTearDown(b.container.dispose);
    final controller = b.controller;
    await _pumpUntil(() => !controller.state.isDayLoading);

    await controller.selectDay(5);
    expect(controller.state.selectedDay, 5);
    expect(controller.state.dayMatomes.single.id, 'd5');
  });
}
