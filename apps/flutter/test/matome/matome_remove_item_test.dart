import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// W7 letter format gathers the detailed sections (Items, contacts, notes,
/// Share) behind a "Show more" toggle. Reveal them before reaching item keys.
Future<void> revealDetails(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('matome-show-more'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

/// Standardized destructive affordance (#1444): the item's '…' overflow opens a
/// sheet whose only entry is Delete, which then raises the confirm dialog. This
/// helper drives both sheet steps so the existing confirm-dialog assertions hold.
Future<void> openItemDelete(WidgetTester tester, String itemId) async {
  await tester.tap(find.byKey(ValueKey('matome-item-overflow-$itemId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('matome-item-delete-$itemId')));
  await tester.pumpAndSettle();
}

/// GUI coverage for removing an image Item through the confirm dialog — the path
/// that froze in the field with no log line, because _confirmRemove was both
/// uninstrumented AND read the controller off the widget `ref` after the dialog
/// await. Drives the real button → dialog → confirm and asserts the row is gone.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> seedMatomeWithImage() async {
    await db.matomesDao.create(
      MatomesCompanion(
        id: const Value('m_rm'),
        title: const Value('Standup'),
        happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      ),
    );
    await db.recordingsDao.insertRecording(
      RecordingsCompanion(
        id: const Value('rec_img'),
        matomeId: const Value('m_rm'),
        title: const Value('screenshot'),
        timestamp: const Value('9:00 AM'),
        duration: const Value(''),
        badge: const Value('Inbox'),
        isProcessing: const Value(0),
        // Empty path → removeItem skips the file delete, so the whole flow stays
        // in the fake-async zone (no real I/O, no runAsync needed).
        audioFilePath: const Value(''),
        createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
        mediaType: const Value('image'),
        processingStatus: const Value('done'),
      ),
    );
    return 'rec_img';
  }

  testWidgets('confirming Remove deletes the image Item and drops its tile',
      (tester) async {
    await seedMatomeWithImage();

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_rm'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await revealDetails(tester);

    // The image tile is present before removal.
    expect(
      find.byKey(const ValueKey('matome-image-rec_img')),
      findsOneWidget,
    );

    // Open the confirm dialog via the standardized '…' overflow → Delete.
    await openItemDelete(tester, 'rec_img');
    expect(find.text('Remove item'), findsOneWidget);

    // Confirm — drives _confirmRemove → container.read → removeItem.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Row is gone from the DB and the tile no longer renders.
    final matome = await db.matomesDao.getMatomeWithRecordings('m_rm');
    expect(matome!.recordings, isEmpty);
    expect(
      find.byKey(const ValueKey('matome-image-rec_img')),
      findsNothing,
    );
  });

  testWidgets('Remove still works when a background reload deactivates the tile '
      'while the dialog is open (was: dialog stuck / app frozen)',
      (tester) async {
    await seedMatomeWithImage();

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_rm'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await revealDetails(tester);

    await openItemDelete(tester, 'rec_img');
    expect(find.text('Remove item'), findsOneWidget);

    // Genuinely UNMOUNT the tile behind the open dialog: drop the row and reload
    // so the items section goes empty. The tile element (whose context the OLD
    // dialog buttons popped through) is now permanently defunct — the same state
    // the upload waiter induces when it republishes the list mid-dialog. The old
    // code called Navigator.of on that dead context inside the button callback,
    // which throws → the pop never runs → the dialog is stuck open → frozen.
    await db.recordingsDao.deleteRecording('rec_img');
    // ignore: unawaited_futures
    c.read(matomeDetailControllerProvider('m_rm').notifier).load();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('matome-image-rec_img')),
      findsNothing,
      reason: 'precondition: the tile must be unmounted behind the dialog',
    );

    // Tapping Remove must still pop the dialog — via the dialog's OWN context.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(
      find.text('Remove item'),
      findsNothing,
      reason: 'the dialog must close (pop) even after the tile was unmounted',
    );
  });

  testWidgets('cancelling keeps the image Item', (tester) async {
    await seedMatomeWithImage();

    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const MatomeDetailScreen(id: 'm_rm'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await revealDetails(tester);

    await openItemDelete(tester, 'rec_img');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final matome = await db.matomesDao.getMatomeWithRecordings('m_rm');
    expect(matome!.recordings, hasLength(1));
    expect(
      find.byKey(const ValueKey('matome-image-rec_img')),
      findsOneWidget,
    );
  });
}
