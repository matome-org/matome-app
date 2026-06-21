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

/// CHARACTERIZATION test (W7, #1413). Pins the detail-screen contract the
/// sibling suites and the app rely on, written BEFORE the letter rewrite so the
/// rewrite is a deliberate migration, not an accidental drift (Feathers,
/// *Working Effectively with Legacy Code* §13).
///
/// Two kinds of assertion live here:
///   * PRESERVED — keys/behaviour that MUST survive the rewrite unchanged
///     (tap targets the contacts/triage/archive/edit/remove suites tap).
///   * REACHABILITY — sections that the letter pushes behind "Show more": the
///     keys still exist, but the test must first reveal them. The
///     `_revealDetails` helper encodes the new affordance so the migration is
///     explicit per key.
///
/// The `matome-on-device` key already changed MEANING in W1 (it is now the
/// rollup-driven [MatomeSyncChip], no inbox gate) — we keep the KEY but assert
/// the new always-visible behaviour, keeping the suite honest.
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

/// Reveal the detailed sections that the letter format gathers behind
/// "Show more". This is the ONE place the rewrite's affordance is encoded; the
/// sibling suites reach detail keys through the same gesture. Idempotent: a no-op
/// if there is no toggle (so the test reads the same pre- and post-rewrite, only
/// the toggle wiring changes).
Future<void> _revealDetails(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('matome-show-more'));
  if (toggle.evaluate().isEmpty) return;
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

  testWidgets('PRESERVED: title, summary hero and sync chip are visible '
      'without revealing details', (tester) async {
    await _seedMatome(
      db,
      id: 'm1',
      title: 'Standup notes',
      aggregatedSummary: 'Discussed the roadmap and blockers.',
      recordingCount: 3,
    );

    await tester.pumpWidget(_app(container(), id: 'm1'));
    await tester.pumpAndSettle();

    // Title (header + AppBar).
    expect(find.text('Standup notes'), findsWidgets);
    // Aggregated summary is the read-first hero — visible up front, no scroll.
    expect(find.byKey(const ValueKey('matome-summary')), findsOneWidget);
    expect(find.text('Discussed the roadmap and blockers.'), findsOneWidget);
    // The sync chip is ALWAYS visible (W1: matome-on-device key, rollup-driven).
    expect(find.byKey(const ValueKey('matome-on-device')), findsOneWidget);
    // Actions overflow lives in the header.
    expect(find.byKey(const ValueKey('matome-actions-trigger')), findsOneWidget);
  });

  testWidgets('PRESERVED: sync chip is always visible for a FILED Matome', (
    tester,
  ) async {
    await _seedMatome(
      db,
      id: 'm_filed',
      spaceId: 'space_1',
      coreId: 7,
      recordingCount: 0,
    );

    await tester.pumpWidget(_app(container(), id: 'm_filed'));
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('matome-on-device'));
    expect(chip, findsOneWidget);
    expect(find.text(t.cardStatus.cloud), findsWidgets);
  });

  testWidgets('PRESERVED: an Inbox Matome surfaces the File-into-space CTA', (
    tester,
  ) async {
    await _seedMatome(db, id: 'm_inbox', spaceId: null, coreId: null);

    await tester.pumpWidget(_app(container(), id: 'm_inbox'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('matome-file-cta')), findsOneWidget);
  });

  testWidgets('REACHABILITY: child Items, contacts and notes are reachable '
      '(behind Show more in the letter format)', (tester) async {
    await _seedMatome(
      db,
      id: 'm2',
      aggregatedSummary: 'Summary',
      recordingCount: 2,
    );

    await tester.pumpWidget(_app(container(), id: 'm2'));
    await tester.pumpAndSettle();

    await _revealDetails(tester);

    // One tile per child Item.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-item-rec_0')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-item-rec_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-item-rec_1')), findsOneWidget);

    // Contacts slot + add-contact action.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-add-contact')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-add-contact')), findsOneWidget);

    // Editable notes.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-edit-notes')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-edit-notes')), findsOneWidget);
  });

  testWidgets('REACHABILITY: deferred Share row stays discoverable', (
    tester,
  ) async {
    await _seedMatome(db, id: 'm3', recordingCount: 1);

    await tester.pumpWidget(_app(container(), id: 'm3'));
    await tester.pumpAndSettle();

    await _revealDetails(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('matome-share')),
      200,
    );
    expect(find.byKey(const ValueKey('matome-share')), findsOneWidget);
  });
}
