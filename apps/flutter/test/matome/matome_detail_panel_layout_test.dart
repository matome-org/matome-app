import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_card.dart';
import 'package:matome_flutter/ui/matome_detail_panel.dart';

/// #1458 — the live Details panel (`_MatomeDetails`, the SINGLE composition
/// point for BOTH the desktop side panel AND the mobile sheet) must render the
/// owner-APPROVED sectioned layout: labeled, divider-framed
/// [MatomePanelSection]s in the order Items · N → People · N → Space → Notes →
/// Share, with compact item rows carrying a REAL per-item sync chip, both Add
/// affordances, and document rows that show the doc icon + route to the doc
/// host — all WITHOUT regressing any shipped feature.
///
/// These tests pin the new structure (written before/with the restructure so it
/// is a deliberate migration). They drive a WIDE viewport so the management
/// surface is the persistent side panel, visible without a "Show more" reveal.
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  String title = 'Standup notes',
  String? aggregatedSummary,
  String? spaceId,
}) async {
  await db.matomesDao.create(
    MatomesCompanion(
      id: Value(id),
      spaceId: Value(spaceId),
      title: Value(title),
      happenedAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch),
      aggregatedSummary: Value(aggregatedSummary),
    ),
  );
}

Future<void> _seedItem(
  AppDatabase db, {
  required String id,
  required String matomeId,
  required String mediaType,
  required String title,
  String? originalExtension,
  int order = 0,
}) async {
  await db.recordingsDao.insertRecording(
    RecordingsCompanion(
      id: Value(id),
      matomeId: Value(matomeId),
      title: Value(title),
      timestamp: const Value('2026-06-08T09:00:00Z'),
      duration: const Value('0:30'),
      badge: const Value('Inbox'),
      isProcessing: const Value(0),
      audioFilePath: const Value('/tmp/does-not-exist.bin'),
      createdAt: Value(DateTime(2026, 6, 8).millisecondsSinceEpoch + order),
      mediaType: Value(mediaType),
      originalExtension: Value(originalExtension),
      processingStatus: const Value('done'),
    ),
  );
}

/// A wide router app: above the panel breakpoint the management surface is the
/// persistent side panel, so `_MatomeDetails` is visible up front. Real
/// `/items/document/:id` route wired so the doc-host routing can be pinned.
Widget _wideRouterApp(ProviderContainer container, {required String id}) {
  final router = GoRouter(
    initialLocation: '/matome/$id',
    routes: [
      GoRoute(
        path: '/matome/:id',
        builder: (context, state) =>
            MatomeDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/items/document/:id',
        builder: (context, state) =>
            FileDetailScreen.documentById(id: state.pathParameters['id']!),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp.router(theme: buildLightTheme(), routerConfig: router),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> sizeWide(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The matome detail is now ALWAYS single-column: the management sections live
  // behind the letter's "Show more" reveal (the wide two-pane side panel is
  // retired). Pump the screen and reveal the detail so the panel-composition
  // assertions below see the sections.
  Future<void> pumpRevealed(WidgetTester tester, String id) async {
    await tester.pumpWidget(_wideRouterApp(container(), id: id));
    await tester.pumpAndSettle();
    final showMore = find.byKey(const ValueKey('matome-show-more'));
    if (showMore.evaluate().isNotEmpty) {
      await tester.tap(showMore);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'the panel renders the approved sections (framed [MatomePanelSection]s) '
    'with divider framing',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm1', aggregatedSummary: 'x');
      await _seedItem(
        db,
        id: 'rec_0',
        matomeId: 'm1',
        mediaType: 'audio',
        title: 'Meeting audio',
      );

      await pumpRevealed(tester, 'm1');

      // The shared composition point + the persistent panel host are present.
      expect(find.byKey(const ValueKey('matome-details')), findsOneWidget);
      // The approved layout is built from framed sections (not the old big
      // thumbnail cards / split add header). Items + People + Space + Notes.
      expect(find.byType(MatomePanelSection), findsAtLeastNWidgets(4));
      // Dividers frame the sections.
      expect(find.byType(Divider), findsAtLeastNWidgets(3));
      // Section headings carry the live counts.
      expect(find.text('${t.matome.recordings} · 1'), findsOneWidget);
    },
  );

  testWidgets(
    'a SINGLE "Add item" accent row fronts the photo/file menu (not a split '
    'header) — #1475',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm_add', aggregatedSummary: 'x');

      await pumpRevealed(tester, 'm_add');

      // Exactly ONE "Add item" affordance, styled as the approved accent
      // MatomePanelAddRow — matching the proposal, not the old split
      // "Add photo / Add file" header.
      final addItem = find.byKey(const ValueKey('matome-add-item'));
      expect(addItem, findsOneWidget);
      expect(tester.widget(addItem), isA<MatomePanelAddRow>());
      expect(find.text(t.matome.addItem), findsOneWidget);

      // The create actions are NOT rendered up front — they live behind the
      // unified picker's header "+", which only exists once the picker is open.
      expect(
        find.byKey(const ValueKey('relationship-action-photo')),
        findsNothing,
      );

      // Tapping "Add item" opens the unified "Add anything" picker → the
      // cross-entity type filter (Contacts/Files/Spaces) + the "+" create
      // affordance show up front; the body stays a clean link-existing list.
      await tester.tap(addItem);
      await tester.pumpAndSettle();
      expect(find.text(t.matome.relationPicker.typeContacts), findsOneWidget);
      expect(find.text(t.matome.relationPicker.typeFiles), findsOneWidget);
      expect(find.text(t.matome.relationPicker.typeSpaces), findsOneWidget);
      expect(
        find.byKey(const ValueKey('relationship-create-menu')),
        findsOneWidget,
      );

      // Opening the "+" surfaces the create actions (Add photo, create-contact,
      // new-space). "Add file" is flag-gated — pinned by the add-file suite.
      await tester.tap(find.byKey(const ValueKey('relationship-create-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('relationship-action-photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('relationship-action-create-contact')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('relationship-action-new-space')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a document item shows the doc icon, routes to the document host, and '
    'carries a per-item sync chip',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm_doc');
      await _seedItem(
        db,
        id: 'rec_doc',
        matomeId: 'm_doc',
        mediaType: 'document',
        title: 'Quarterly report',
        originalExtension: 'pdf',
      );

      await pumpRevealed(tester, 'm_doc');

      final tile = find.byKey(const ValueKey('matome-item-rec_doc'));
      expect(tile, findsOneWidget);

      // The document type icon (description glyph) is the leading icon.
      expect(
        find.descendant(
          of: tile,
          matching: find.byIcon(Icons.description_outlined),
        ),
        findsOneWidget,
      );

      // A REAL per-item sync chip rides in the row (on-device — no Core id).
      expect(
        find.byKey(const ValueKey('matome-item-sync-rec_doc')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(MatomeSyncChip)),
        findsOneWidget,
      );

      // Tapping the document row drills into the DOCUMENT host, not the audio
      // host (no player bar) — #1450 doc routing preserved.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(FileDetailScreen), findsOneWidget);
      expect(find.text('Document', skipOffstage: false), findsOneWidget);
      expect(find.text('Transcript', skipOffstage: false), findsNothing);
    },
  );

  testWidgets(
    'every child item carries its own sync chip (rollup-correct per item)',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm_many');
      await _seedItem(
        db,
        id: 'a',
        matomeId: 'm_many',
        mediaType: 'audio',
        title: 'Audio',
        order: 0,
      );
      await _seedItem(
        db,
        id: 'b',
        matomeId: 'm_many',
        mediaType: 'document',
        title: 'Doc',
        order: 1,
      );

      await pumpRevealed(tester, 'm_many');

      expect(find.byKey(const ValueKey('matome-item-sync-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('matome-item-sync-b')), findsOneWidget);
      // On-device items show the on-device chip.
      expect(find.text(t.cardStatus.onDevice), findsWidgets);
    },
  );

  testWidgets(
    'the Space section hosts the filing flow (Refile for a filed matome / '
    'the File-into-space CTA for an inbox)',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm_inbox');

      await pumpRevealed(tester, 'm_inbox');

      // Space section present; an inbox matome surfaces the File CTA inside it.
      expect(find.text(t.matome.spaceLabel), findsOneWidget);
      expect(find.byKey(const ValueKey('matome-file-cta')), findsOneWidget);
    },
  );

  testWidgets(
    'Notes renders with the slang "Edit" trailing; People uses "Add person"; '
    'Share matches the proposal Share row — #1475',
    (tester) async {
      await sizeWide(tester);
      await _seedMatome(db, id: 'm_notes');

      await pumpRevealed(tester, 'm_notes');

      // Notes trailing is the slang "Edit" (not "Edit notes"). The key rides on
      // the Text itself, so assert the keyed widget's data is "Edit".
      final editNotes = find.byKey(const ValueKey('matome-edit-notes'));
      expect(editNotes, findsOneWidget);
      expect((tester.widget<Text>(editNotes)).data, t.matome.edit);
      expect(t.matome.edit, 'Edit');

      // People "Add person" affordance (slang label).
      final addPerson = find.byKey(const ValueKey('matome-add-contact'));
      expect(addPerson, findsOneWidget);
      expect(find.text(t.matome.addContact), findsOneWidget);

      // Share row matches the proposal: a plain ios_share glyph + "Share", no
      // dimmed inline "Coming soon" text (the deferred state rides on a tooltip
      // / a11y hint instead).
      final share = find.byKey(const ValueKey('matome-share'));
      expect(share, findsOneWidget);
      expect(
        find.descendant(of: share, matching: find.byIcon(Icons.ios_share)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: share, matching: find.text(t.matome.share)),
        findsOneWidget,
      );
    },
  );
}
