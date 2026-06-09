import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/features/calendar/calendar_controller.dart';
import 'package:matome_flutter/features/calendar/calendar_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Widget tests for the Calendar tab (S4): dots render on days with
/// recordings, tapping a day lists its recordings, the space filter narrows the
/// list, month nav reloads, and tapping a recording routes to `/calendar/:id`.

int _epoch(int year, int month, int day, [int hour = 9]) =>
    DateTime(year, month, day, hour).millisecondsSinceEpoch;

Future<void> _seed(
  AppDatabase db, {
  required String id,
  required int createdAt,
  String title = 'Team meeting',
  String duration = '5m 0s',
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

/// Tracks the last route the embedded router navigated to.
String? _lastRoute;

Widget _app(AppDatabase db, {required DateTime now}) {
  _lastRoute = null;
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (_, _) => const CalendarScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) {
              _lastRoute = '/calendar/${state.pathParameters['id']}';
              return const Scaffold(body: Text('details-stub'));
            },
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      calendarNowProvider.overrideWithValue(() => now),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('renders the month grid with the selected (today) heading',
      (tester) async {
    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();

    // April title + a few day cells exist.
    expect(find.text('April'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-day-15')), findsOneWidget);
  });

  testWidgets('renders dots on days with recordings', (tester) async {
    await _seed(db, id: 'r5', createdAt: _epoch(2026, 4, 5));
    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(CalendarScreen));
    final container = ProviderScope.containerOf(element);
    final state = container.read(calendarControllerProvider);
    expect(state.daysWithRecordings.contains(5), isTrue);
  });

  testWidgets('tapping a day lists that day\'s recordings', (tester) async {
    await _seed(db, id: 'r5', title: 'Morning sync', createdAt: _epoch(2026, 4, 5));
    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();

    // Today (10th) has nothing -> empty state.
    expect(find.text(t.calendar.noRecordings), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-day-5')));
    await tester.pumpAndSettle();

    expect(find.text('Morning sync'), findsOneWidget);
    expect(find.text(t.calendar.noRecordings), findsNothing);
  });

  testWidgets('space filter narrows the day list', (tester) async {
    final eng = await db.workspacesDao.createWorkspace('Engineering');
    final day = _epoch(2026, 4, 10);
    await _seed(db, id: 'r-eng', title: 'Eng standup', createdAt: day, workspaceId: eng.id);
    await _seed(db, id: 'r-inbox', title: 'Inbox note', createdAt: day, badge: 'Inbox');

    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();

    // Both visible under "All".
    expect(find.text('Eng standup'), findsOneWidget);
    expect(find.text('Inbox note'), findsOneWidget);

    // Activate the Engineering chip.
    await tester.tap(find.byKey(ValueKey('calendar-filter-${eng.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Eng standup'), findsOneWidget);
    expect(find.text('Inbox note'), findsNothing);

    // Toggle off -> both back.
    await tester.tap(find.byKey(ValueKey('calendar-filter-${eng.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Inbox note'), findsOneWidget);
  });

  testWidgets('month nav reloads the day list', (tester) async {
    await _seed(db, id: 'apr', title: 'April rec', createdAt: _epoch(2026, 4, 10));
    await _seed(db, id: 'mar', title: 'March rec', createdAt: _epoch(2026, 3, 10));

    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();
    expect(find.text('April rec'), findsOneWidget);

    // Previous month -> March, day 10 still selected, list refreshes.
    await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
    await tester.pumpAndSettle();

    expect(find.text('March'), findsOneWidget);
    expect(find.text('March rec'), findsOneWidget);
    expect(find.text('April rec'), findsNothing);
  });

  testWidgets('tapping a recording navigates to /calendar/:id', (tester) async {
    await _seed(db, id: 'rec-42', title: 'Routed rec', createdAt: _epoch(2026, 4, 10));
    await tester.pumpWidget(_app(db, now: DateTime(2026, 4, 10, 9)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('calendar-recording-rec-42')));
    await tester.pumpAndSettle();

    expect(_lastRoute, '/calendar/rec-42');
    expect(find.text('details-stub'), findsOneWidget);
  });
}
