import 'dart:convert';
import 'dart:io';

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
  bool summaryStale = false,
  String? itemSummary,
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
      summaryStale: Value(summaryStale),
      coreId: Value(coreId),
    ),
  );

  for (var i = 0; i < recordingCount; i += 1) {
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: Value('rec_$i'),
        matomeId: Value(id),
        title: Value('Item $i'),
        summary: Value(itemSummary),
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

/// W7 letter format gathers the detailed sections (child Items, contacts, notes,
/// Share) behind a "Show more" toggle. Reveal them before reaching those keys.
Future<void> _revealDetails(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('matome-show-more'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
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

    // The aggregated summary is the read-first hero (W7) — visible up front, no
    // reveal, no scroll.
    expect(find.byKey(const ValueKey('matome-summary')), findsOneWidget);
    expect(
      find.text('Discussed the roadmap and blockers.'),
      findsOneWidget,
    );

    // The child-Item tiles live in the "Show more" detail in the letter format.
    await _revealDetails(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-item-rec_0')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-item-rec_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-item-rec_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-item-rec_2')), findsOneWidget);
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

  testWidgets('shows the sync chip for an Inbox (untriaged) Matome', (
    tester,
  ) async {
    await _seedMatome(db, id: 'm3', spaceId: null, coreId: null);

    await tester.pumpWidget(_app(container(), id: 'm3'));
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('matome-on-device'));
    expect(chip, findsOneWidget);
    // Normalized vocab (#1407): pure sync state, no "· not filed" suffix. The
    // same word now also appears on the per-tile badges (one shared vocab), so
    // scope the assertion to the chip.
    expect(
      find.descendant(of: chip, matching: find.text(t.cardStatus.onDevice)),
      findsOneWidget,
    );
    expect(find.textContaining('not filed'), findsNothing);
  });

  testWidgets(
    'shows the sync chip for a FILED Matome too (#1407 dropped isInbox guard)',
    (tester) async {
      // A filed matome (spaceId set) reconciled to Core reads "Synced" — the
      // chip is no longer gated behind the inbox state. Seeded count-only so
      // the rollup falls back to the matome's own coreId.
      await _seedMatome(
        db,
        id: 'm_filed',
        spaceId: 'space_1',
        coreId: 7,
        recordingCount: 0,
      );

      await tester.pumpWidget(_app(container(), id: 'm_filed'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('matome-on-device')), findsOneWidget);
      expect(find.text(t.cardStatus.cloud), findsOneWidget);
    },
  );

  testWidgets('stale summary shows a Regenerate affordance that recomputes '
      'from items and clears stale', (tester) async {
    await _seedMatome(
      db,
      id: 'm_stale',
      // A stored-but-stale summary, with items that DO carry summaries so the
      // local generator has something to roll up.
      aggregatedSummary: 'Old summary',
      summaryStale: true,
      itemSummary: 'Item insight.',
      recordingCount: 2,
    );

    await tester.pumpWidget(_app(container(), id: 'm_stale'));
    await tester.pumpAndSettle();

    // The summary (and its Regenerate affordance) is the hero — visible up
    // front, no reveal needed.
    final regenButton =
        find.byKey(const ValueKey('matome-regenerate-summary'));
    expect(regenButton, findsOneWidget);
    expect(find.text(t.matome.summaryStale), findsOneWidget);

    await tester.tap(regenButton);
    await tester.pumpAndSettle();

    // The stored summary was recomposed from the items and the stale flag (and
    // its affordance) cleared.
    final row = await db.matomesDao.getById('m_stale');
    expect(row!.summaryStale, isFalse);
    expect(row.aggregatedSummary, contains('Item insight.'));
    expect(
      find.byKey(const ValueKey('matome-regenerate-summary')),
      findsNothing,
    );
  });

  testWidgets('no Regenerate affordance when summary is fresh (not stale)', (
    tester,
  ) async {
    await _seedMatome(
      db,
      id: 'm_fresh',
      aggregatedSummary: 'Fresh summary',
      itemSummary: 'insight',
    );

    await tester.pumpWidget(_app(container(), id: 'm_fresh'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('matome-regenerate-summary')),
      findsNothing,
    );
  });

  testWidgets('renders the not-found state for a missing Matome', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container(), id: 'missing'));
    await tester.pumpAndSettle();

    expect(find.text(t.matome.notFound), findsOneWidget);
  });

  testWidgets('image Items render a thumbnail tile with a remove action while '
      'audio Items keep the recording card', (tester) async {
    // One audio Item (rec_0) from the seed, plus one image Item.
    await _seedMatome(db, id: 'm_img', recordingCount: 1);

    // A real 1x1 PNG so Image.file actually decodes and pumpAndSettle settles
    // (a non-existent path would route through errorBuilder, which we also
    // tolerate, but a valid file keeps the test deterministic).
    final tmp = File(
      '${Directory.systemTemp.path}/matome_tile_${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          '+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
      );
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync();
    });

    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_img'),
        matomeId: const Value('m_img'),
        title: const Value('whiteboard'),
        timestamp: const Value('9:05 AM'),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: Value(tmp.path),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch + 99),
        mediaType: const Value('image'),
        processingStatus: const Value('pending_upload'),
      ),
    );

    await tester.pumpWidget(_app(container(), id: 'm_img'));
    await tester.pumpAndSettle();
    await _revealDetails(tester);

    // Image Item → thumbnail tile + a remove action, and a rendered Image.
    expect(find.byKey(const ValueKey('matome-image-rec_img')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('matome-image-remove-rec_img')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsWidgets);

    // The audio Item still renders, and NOT as an image tile.
    expect(find.byKey(const ValueKey('matome-item-rec_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-image-rec_0')), findsNothing);
  });
}
