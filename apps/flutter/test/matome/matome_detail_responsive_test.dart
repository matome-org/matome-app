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

import '../support/item_fixtures.dart';

/// The matome detail is ALWAYS the single-column "letter" presentation (owner
/// decision 2026-06-24): the wide two-pane (letter + persistent side panel)
/// split is retired. These tests pin that the SAME single-column layout — the
/// "Show more" sheet, no side panel — renders at every width.
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
    await insertTestFileItem(
      db,
      id: 'rec_$i',
      matomeId: id,
      position: i,
      title: 'Item $i',
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch + i,
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
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentOwnerIdProvider.overrideWithValue('1'),
      ],
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

  testWidgets('WIDE: still single-column — the wide two-pane split is retired, '
      'so the "Show more" sheet stays and there is NO persistent side panel', (
    tester,
  ) async {
    await sizeTo(tester, const Size(1200, 900));
    await _seedMatome(
      db,
      id: 'm_wide',
      aggregatedSummary: 'Discussed the roadmap.',
      recordingCount: 2,
    );

    await tester.pumpWidget(_app(container(), id: 'm_wide'));
    await tester.pumpAndSettle();

    // Always single-column: the "Show more" trigger is present even wide; the
    // management surface stays hidden until revealed.
    expect(find.byKey(const ValueKey('matome-show-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-details')), findsNothing);
    // The retired wide side panel never appears.
    expect(find.byKey(const ValueKey('matome-detail-panel')), findsNothing);
  });

  testWidgets(
    'the SAME single-column letter renders at every width — no layout '
    'swap with width',
    (tester) async {
      await _seedMatome(db, id: 'm_flip', aggregatedSummary: 'x');

      // Wide → single-column letter with "Show more", no side panel.
      await sizeTo(tester, const Size(1200, 900));
      await tester.pumpWidget(_app(container(), id: 'm_flip'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matome-detail-panel')), findsNothing);
      expect(find.byKey(const ValueKey('matome-show-more')), findsOneWidget);

      // Narrow → identical single-column presentation, same route.
      tester.view.physicalSize = const Size(420, 900);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('matome-detail-panel')), findsNothing);
      expect(find.byKey(const ValueKey('matome-show-more')), findsOneWidget);
    },
  );
}
