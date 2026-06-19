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

/// Seeds a Matome plus [recordingCount] child Items (recordings).
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'Standup notes',
  String? aggregatedSummary,
  String? description,
  String? spaceId,
  int? coreId,
  int recordingCount = 2,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      title: Value(title),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      description: Value(description),
      aggregatedSummary: Value(aggregatedSummary),
      coreId: Value(coreId),
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

  testWidgets('renders header title and one card per child Item', (
    tester,
  ) async {
    await _seedMatome(
      db,
      id: 'm1',
      title: 'Standup notes',
      aggregatedSummary: 'Discussed the roadmap and blockers.',
      recordingCount: 3,
    );

    await tester.pumpWidget(_app(container(), id: 'm1'));
    await tester.pumpAndSettle();

    // Header title (also the AppBar title — appears at least once).
    expect(find.text('Standup notes'), findsWidgets);

    // One tile per child Item.
    expect(find.byKey(const ValueKey('matome-item-rec_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-item-rec_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-item-rec_2')), findsOneWidget);

    // Aggregated-summary slot shows the stored summary. Triage actions (#1372)
    // grew the page, so scroll the summary into view before asserting.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-summary')),
      200,
    );
    expect(
      find.text('Discussed the roadmap and blockers.'),
      findsOneWidget,
    );
  });

  testWidgets('aggregated-summary slot shows the empty state when null', (
    tester,
  ) async {
    await _seedMatome(db, id: 'm2', aggregatedSummary: null);

    await tester.pumpWidget(_app(container(), id: 'm2'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matome-summary')), findsOneWidget);
    expect(find.text(t.matome.noSummary), findsOneWidget);
  });

  testWidgets('shows the on-device hint for an Inbox (untriaged) Matome', (
    tester,
  ) async {
    await _seedMatome(db, id: 'm3', spaceId: null, coreId: null);

    await tester.pumpWidget(_app(container(), id: 'm3'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matome-on-device')), findsOneWidget);
    expect(find.text(t.matome.onDevice), findsOneWidget);
  });

  testWidgets('renders the not-found state for a missing Matome', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container(), id: 'missing'));
    await tester.pumpAndSettle();

    expect(find.text(t.matome.notFound), findsOneWidget);
  });
}
