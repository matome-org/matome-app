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

/// #1444 — the destructive affordance is STANDARDIZED across both Item kinds:
/// audio AND image tiles expose Delete through the SAME '…' overflow menu
/// (`matome-item-overflow-<id>` → `matome-item-delete-<id>`), never a bare trash
/// icon on one and a menu on the other. These tests pin that consistency and the
/// delete path each affordance drives.
Future<void> _revealDetails(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('matome-show-more'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_ov'),
        title: const Value('Standup'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
    // One audio Item.
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_audio'),
        matomeId: const Value('m_ov'),
        title: const Value('Audio note'),
        timestamp: const Value('9:00 AM'),
        duration: const Value('0:30'),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('audio'),
        processingStatus: const Value('done'),
      ),
    );
    // One image Item (empty path → removeItem skips file I/O, stays fake-async).
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_image'),
        matomeId: const Value('m_ov'),
        title: const Value('whiteboard'),
        timestamp: const Value('9:05 AM'),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch + 1),
        mediaType: const Value('image'),
        processingStatus: const Value('done'),
      ),
    );
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_ov'),
          ),
        ),
      );

  testWidgets(
    'both audio and image tiles expose the SAME overflow menu (no bare trash)',
    (tester) async {
      await seed();
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();
      await _revealDetails(tester);

      // The standardized overflow is present on BOTH kinds.
      expect(
        find.byKey(const ValueKey('matome-item-overflow-rec_audio')),
        findsOneWidget,
        reason: 'audio tile must carry the standardized overflow',
      );
      expect(
        find.byKey(const ValueKey('matome-item-overflow-rec_image')),
        findsOneWidget,
        reason: 'image tile must carry the standardized overflow',
      );

      // The retired bare trash icon key must be gone (no inconsistent affordance).
      expect(
        find.byKey(const ValueKey('matome-image-remove-rec_image')),
        findsNothing,
      );
    },
  );

  testWidgets('image tile: overflow → Delete → confirm removes the Item',
      (tester) async {
    await seed();
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await _revealDetails(tester);

    final overflow = find.byKey(const ValueKey('matome-item-overflow-rec_image'));
    await tester.ensureVisible(overflow);
    await tester.pumpAndSettle();
    await tester.tap(overflow);
    await tester.pumpAndSettle();
    // The destructive entry lives inside the overflow sheet.
    await tester.tap(find.byKey(const ValueKey('matome-item-delete-rec_image')));
    await tester.pumpAndSettle();
    // It raises the confirm dialog; confirm to delete.
    expect(find.text(t.matome.removeItemTitle), findsOneWidget);
    await tester.tap(find.text(t.matome.remove));
    await tester.pumpAndSettle();

    final matome = await db.matomesDao.getMatomeWithRecordings('m_ov');
    final ids = matome!.recordings.map((r) => r.id).toList();
    expect(ids, isNot(contains('rec_image')));
    expect(ids, contains('rec_audio'));
  });

  testWidgets('audio tile: overflow → Delete → confirm removes the Item',
      (tester) async {
    await seed();
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await _revealDetails(tester);

    final overflow = find.byKey(const ValueKey('matome-item-overflow-rec_audio'));
    await tester.ensureVisible(overflow);
    await tester.pumpAndSettle();
    await tester.tap(overflow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matome-item-delete-rec_audio')));
    await tester.pumpAndSettle();
    expect(find.text(t.matome.removeItemTitle), findsOneWidget);
    await tester.tap(find.text(t.matome.remove));
    await tester.pumpAndSettle();

    final matome = await db.matomesDao.getMatomeWithRecordings('m_ov');
    final ids = matome!.recordings.map((r) => r.id).toList();
    expect(ids, isNot(contains('rec_audio')));
    expect(ids, contains('rec_image'));
  });
}
