import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// W8 (#1414) — the detail panel presentation is RESPONSIVE on the SAME
/// `/matome/:id` route (ADR-0005): a breakpoint-driven layout swap, not a route
/// change. Below the breakpoint the letter keeps its mobile "Show more" reveal
/// (the sheet presentation); above it the management surface is a PERSISTENT
/// side panel beside the letter, visible without tapping anything.
///
/// "Responsive" must be a VERIFIED behaviour: we pump the SAME screen at a
/// narrow and a wide viewport and assert the two presentations differ.
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'Standup notes',
  String? aggregatedSummary,
  int recordingCount = 2,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      title: Value(title),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      aggregatedSummary: Value(aggregatedSummary),
    ),
  );

  for (var i = 0; i < recordingCount; i += 1) {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: Value('rec_$i'),
        matomeId: Value(id),
        title: Value('Item $i'),
        timestamp: const Value('9:00 AM'),
        duration: const Value('0:30'),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch + i),
        mediaType: const Value('audio'),
        processingStatus: const Value('done'),
      ),
    );
  }
}

Widget _app(ProviderContainer container, {required String id}) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: MatomeDetailScreen(id: id),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> sizeTo(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('NARROW (below breakpoint): the letter shows the "Show more" '
      'affordance and the detail surface is NOT persistently beside it', (
    tester,
  ) async {
    await sizeTo(tester, const Size(420, 900));
    await _seedMatome(
      db,
      id: 'm_narrow',
      aggregatedSummary: 'Discussed the roadmap.',
      recordingCount: 2,
    );

    await tester.pumpWidget(_app(container(), id: 'm_narrow'));
    await tester.pumpAndSettle();

    // Sheet presentation: the "Show more" trigger is present below the
    // breakpoint.
    expect(find.byKey(const ValueKey('matome-show-more')), findsOneWidget);
    // The management surface is hidden until revealed — NOT persistently beside
    // the letter.
    expect(find.byKey(const ValueKey('matome-details')), findsNothing);
    // The persistent side panel host is absent at this width.
    expect(find.byKey(const ValueKey('matome-detail-panel')), findsNothing);
  });

  testWidgets('WIDE (above breakpoint): the detail surface is a PERSISTENT '
      'panel beside the letter, with no "Show more" needed', (tester) async {
    await sizeTo(tester, const Size(1200, 900));
    await _seedMatome(
      db,
      id: 'm_wide',
      aggregatedSummary: 'Discussed the roadmap.',
      recordingCount: 2,
    );

    await tester.pumpWidget(_app(container(), id: 'm_wide'));
    await tester.pumpAndSettle();

    // Drawer presentation: the management surface is visible beside the letter
    // WITHOUT tapping anything.
    expect(find.byKey(const ValueKey('matome-detail-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-details')), findsOneWidget);
    // Detail keys are reachable up front (no reveal).
    expect(find.byKey(const ValueKey('matome-add-contact')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-share')), findsOneWidget);
    // "Show more" is not needed (and not built) above the breakpoint.
    expect(find.byKey(const ValueKey('matome-show-more')), findsNothing);
  });

  testWidgets('the SAME route renders both presentations — flips with width '
      'alone (no navigation)', (tester) async {
    await _seedMatome(db, id: 'm_flip', aggregatedSummary: 'x');

    // Start wide → persistent panel.
    await sizeTo(tester, const Size(1200, 900));
    await tester.pumpWidget(_app(container(), id: 'm_flip'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matome-detail-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-show-more')), findsNothing);

    // Shrink below the breakpoint → back to the sheet presentation, same route.
    tester.view.physicalSize = const Size(420, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matome-detail-panel')), findsNothing);
    expect(find.byKey(const ValueKey('matome-show-more')), findsOneWidget);
  });
}
