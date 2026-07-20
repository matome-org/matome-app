import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/reading_pane.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/contacts/contact_detail_screen.dart';
import 'package:matome_flutter/features/contacts/contacts_controller.dart';
import 'package:matome_flutter/features/contacts/contacts_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// W4 (#1544): the Contacts surface renders through the unified
/// [MasterDetailScaffold] behind `FeatureFlags.masterDetailLayout`. The flag is a
/// COMPILE-TIME const, so this file is run TWICE by the design-system gate:
///   * forced OFF — pins the SHIPPED directory + route-to-`/contacts/:id`-on-tap
///                  reality (the `contact-tile-<id>` keys + long-press delete).
///   * forced ON  — proves the new scaffold-driven reality (reading-pane position
///                  + width class decide the pane; the pane is the selected
///                  contact's real [ContactDetail]; selection clears when the
///                  selected contact leaves the list).
/// Each lane group self-skips under the wrong build.
const _flagOn = bool.fromEnvironment(
  'ff.masterDetailLayout',
  defaultValue: false,
);
const _ownerId = '1';

/// A reading-pane controller pinned to a fixed mode (in-memory store, the mode
/// set synchronously so the pumped tree sees it on the first frame).
class _StubReadingPane extends ReadingPaneModeController {
  _StubReadingPane(ReadingPaneMode mode)
    : super(InMemorySettingsStore(), ReadingPaneSurface.contacts) {
    state = mode;
  }
}

ProviderContainer _container(AppDatabase db, {ReadingPaneMode? mode}) {
  final c = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentOwnerIdProvider.overrideWithValue(_ownerId),
      if (mode != null)
        readingPaneModeProvider(
          ReadingPaneSurface.contacts,
        ).overrideWith((ref) => _StubReadingPane(mode)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Tracks the last route pushed so the OFF / compact lanes can assert
/// route-on-tap without a real detail screen mounting.
class _RouteSpy {
  String? last;
}

Widget _app(ProviderContainer container, _RouteSpy spy) {
  final router = GoRouter(
    initialLocation: '/contacts',
    routes: [
      GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
      GoRoute(
        path: '/contacts/:id',
        builder: (_, state) {
          spy.last = '/contacts/${state.pathParameters['id']}';
          return ContactDetailScreen(id: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/matome/:id',
        builder: (_, _) => const Scaffold(body: Text('matome-stub')),
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

ContactsCompanion _contact({required String id, required String name}) {
  return ContactsCompanion.insert(
    id: id,
    ownerId: _ownerId,
    displayName: name,
    createdAt: DateTime(2026, 6, 24).millisecondsSinceEpoch,
  );
}

/// Force a logical viewport [size] for the pumped tree (devicePixelRatio 1).
void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  // ── OFF lane (characterization): shipped directory + route-on-tap ──────────
  group('lane: ff.masterDetailLayout=false (OFF / shipped directory)', () {
    testWidgets(
      'at width 1280 the directory renders with no MasterDetailScaffold',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(_container(db), spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsNothing);
        expect(find.text('Ada Lovelace'), findsOneWidget);
        expect(find.byKey(const ValueKey('contact-tile-c1')), findsOneWidget);
      },
      skip: _flagOn,
    );

    testWidgets(
      'tapping a contact routes to /contacts/:id (no in-pane selection)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final container = _container(db);
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('contact-tile-c1')));
        await tester.pumpAndSettle();

        expect(spy.last, '/contacts/c1');
        expect(container.read(contactsSelectionProvider), isNull);
      },
      skip: _flagOn,
    );

    testWidgets('long-press + confirm deletes the contact (preserved OFF)', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.contactsDao.create(_contact(id: 'c1', name: 'Doomed'));

      _setSize(tester, const Size(1280, 900));
      final spy = _RouteSpy();
      await tester.pumpWidget(_app(_container(db), spy));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('contact-tile-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-contact-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Doomed'), findsNothing);
      expect(await db.contactsDao.getById('c1'), isNull);
    }, skip: _flagOn);
  });

  // ── ON lane: scaffold-driven reading pane ─────────────────────────────────
  group('lane: ff.masterDetailLayout=true (ON / MasterDetailScaffold)', () {
    testWidgets(
      'Right pane + expanded width (1280) + a selection → ContactDetail pane '
      'present, no route',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(contactsSelectionProvider.notifier).state = 'c1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        // The pane renders the real ContactDetail for the selection.
        expect(
          find.byKey(const ValueKey('contact-detail-name')),
          findsOneWidget,
        );
        expect(find.text('Ada Lovelace'), findsWidgets);
        expect(spy.last, isNull);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'onClick tap-to-select: nothing selected → no pane; tapping a contact at '
      'expanded width opens it in the pane (no navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.onClick);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        // onClick + nothing selected → no pane, so neither the detail nor the
        // teaching hint is rendered.
        expect(find.byKey(const ValueKey('contact-detail-name')), findsNothing);
        expect(find.text(t.contacts.selectHint), findsNothing);

        await tester.tap(find.byKey(const ValueKey('contact-tile-c1')));
        await tester.pumpAndSettle();

        expect(container.read(contactsSelectionProvider), 'c1');
        expect(spy.last, isNull);
        expect(
          find.byKey(const ValueKey('contact-detail-name')),
          findsOneWidget,
        );
      },
      skip: !_flagOn,
    );

    testWidgets(
      'reading pane = off → full-width master, no pane even at expanded width',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.off);
        container.read(contactsSelectionProvider.notifier).state = 'c1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        // No pane → the contact detail is not rendered.
        expect(find.byKey(const ValueKey('contact-detail-name')), findsNothing);
        expect(find.text(t.contacts.selectHint), findsNothing);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'compact width (400) → no pane; tap routes (degrades to navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(400, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('contact-tile-c1')));
        await tester.pumpAndSettle();

        expect(spy.last, '/contacts/c1');
        expect(container.read(contactsSelectionProvider), isNull);
      },
      skip: !_flagOn,
    );

    testWidgets('long-press + confirm deletes the contact (preserved ON)', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.contactsDao.create(_contact(id: 'c1', name: 'Doomed'));

      _setSize(tester, const Size(1280, 900));
      final container = _container(db, mode: ReadingPaneMode.always);
      final spy = _RouteSpy();
      await tester.pumpWidget(_app(container, spy));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('contact-tile-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-contact-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Doomed'), findsNothing);
      expect(await db.contactsDao.getById('c1'), isNull);
    }, skip: !_flagOn);

    testWidgets(
      'selection clears when the selected contact leaves the loaded list',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.contactsDao.create(_contact(id: 'c1', name: 'Ada Lovelace'));

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(contactsSelectionProvider.notifier).state = 'c1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('contact-detail-name')),
          findsOneWidget,
        );

        // The selected contact is deleted and the list re-reads — the pane must
        // NOT keep pointing at the now-absent contact.
        await db.contactsDao.deleteContact('c1');
        await container.read(contactsControllerProvider.notifier).load();
        await tester.pumpAndSettle();

        expect(container.read(contactsSelectionProvider), isNull);
        expect(find.byKey(const ValueKey('contact-detail-name')), findsNothing);
        expect(find.text(t.contacts.selectHint), findsOneWidget);
      },
      skip: !_flagOn,
    );
  });

  test('FeatureFlags.masterDetailLayout matches the lane', () {
    expect(FeatureFlags.masterDetailLayout, _flagOn);
  });
}
