import 'package:drift/drift.dart' show Value;
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
import 'package:matome_flutter/features/spaces/spaces_controller.dart';
import 'package:matome_flutter/features/spaces/spaces_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// W4 (#1543): the Spaces surface renders through the unified
/// [MasterDetailScaffold] behind `FeatureFlags.masterDetailLayout`. The flag is
/// a COMPILE-TIME const, so this file is run TWICE by the design-system gate:
///   * forced OFF — pins the SHIPPED list + route-to-`/spaces/:id`-on-tap reality.
///   * forced ON  — proves the new scaffold-driven reality (reading-pane
///                  position + width class decide the pane; the pane is the
///                  selected space's matomes; selection clears when the selected
///                  space leaves the list).
/// Each lane group self-skips under the wrong build.
const _flagOn = bool.fromEnvironment(
  'ff.masterDetailLayout',
  defaultValue: false,
);

/// A reading-pane controller pinned to a fixed mode (in-memory store, the mode
/// set synchronously so the pumped tree sees it on the first frame).
class _StubReadingPane extends ReadingPaneModeController {
  _StubReadingPane(ReadingPaneMode mode)
      : super(InMemorySettingsStore(), ReadingPaneSurface.spaces) {
    state = mode;
  }
}

ProviderContainer _container(
  AppDatabase db, {
  ReadingPaneMode? mode,
}) {
  final c = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    currentOwnerIdProvider.overrideWithValue('1'),
    if (mode != null)
      readingPaneModeProvider(ReadingPaneSurface.spaces)
          .overrideWith((ref) => _StubReadingPane(mode)),
  ]);
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
    initialLocation: '/spaces',
    routes: [
      GoRoute(path: '/spaces', builder: (_, _) => const SpacesScreen()),
      GoRoute(
        path: '/spaces/:spaceId',
        builder: (_, state) {
          spy.last = '/spaces/${state.pathParameters['spaceId']}';
          return const Scaffold(body: Text('space-detail-route'));
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
      child: MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
      ),
    ),
  );
}

/// Seeds a Matome filed into [spaceId] (#1378) — the unit the Space pane lists.
Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  required String title,
  String? spaceId,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      spaceId: Value(spaceId),
      happenedAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 6, 8).millisecondsSinceEpoch,
    ),
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

  // ── OFF lane (characterization): shipped list + route-on-tap ───────────────
  group('lane: ff.masterDetailLayout=false (OFF / shipped list)', () {
    testWidgets(
      'at width 1280 the list renders with no MasterDetailScaffold',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');
        await _seedMatome(db, id: 'm1', title: 'Alpha', spaceId: work.id);

        _setSize(tester, const Size(1280, 900));
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(_container(db), spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsNothing);
        expect(find.text('Work'), findsOneWidget);
      },
      skip: _flagOn,
    );

    testWidgets(
      'tapping a space routes to /spaces/:id (no in-pane selection)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db);
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
        await tester.pumpAndSettle();

        expect(spy.last, '/spaces/${work.id}');
        expect(container.read(spacesSelectionProvider), isNull);
      },
      skip: _flagOn,
    );
  });

  // ── ON lane: scaffold-driven reading pane ─────────────────────────────────
  group('lane: ff.masterDetailLayout=true (ON / MasterDetailScaffold)', () {
    testWidgets(
      'Right pane + expanded width (1280) + a selection → space-detail pane '
      'present (its matomes), no route',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');
        await _seedMatome(db, id: 'm1', title: 'InSpace', spaceId: work.id);

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(spacesSelectionProvider.notifier).state = work.id;
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        // The pane lists the selected space's matomes.
        expect(find.text('InSpace'), findsOneWidget);
        expect(spy.last, isNull);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'onClick tap-to-select: nothing selected → no pane; tapping a space at '
      'expanded width opens it in the pane (no navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');
        await _seedMatome(db, id: 'm1', title: 'InSpace', spaceId: work.id);

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.onClick);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        // onClick + nothing selected → no pane, so neither the matome nor the
        // teaching hint is rendered.
        expect(find.text('InSpace'), findsNothing);
        expect(find.text(t.spaces.selectHint), findsNothing);

        await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
        await tester.pumpAndSettle();

        expect(container.read(spacesSelectionProvider), work.id);
        expect(spy.last, isNull);
        expect(find.text('InSpace'), findsOneWidget);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'reading pane = off → full-width master, no pane even at expanded width',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');
        await _seedMatome(db, id: 'm1', title: 'InSpace', spaceId: work.id);

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.off);
        container.read(spacesSelectionProvider.notifier).state = work.id;
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        // No pane → the space's matomes are not rendered.
        expect(find.text('InSpace'), findsNothing);
        expect(find.text(t.spaces.selectHint), findsNothing);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'compact width (400) → no pane; tap routes (degrades to navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');

        _setSize(tester, const Size(400, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(ValueKey('space-tile-${work.id}')));
        await tester.pumpAndSettle();

        expect(spy.last, '/spaces/${work.id}');
        expect(container.read(spacesSelectionProvider), isNull);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'selection clears when the selected space leaves the loaded list',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final work = await db.workspacesDao.createWorkspace('Work');
        await _seedMatome(db, id: 'm1', title: 'InSpace', spaceId: work.id);

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(spacesSelectionProvider.notifier).state = work.id;
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();
        expect(find.text('InSpace'), findsOneWidget);

        // The selected space is deleted and the list re-reads — the pane must
        // NOT keep pointing at the now-absent space.
        await db.workspacesDao.deleteWorkspace(work.id);
        await container.read(spacesControllerProvider.notifier).load();
        await tester.pumpAndSettle();

        expect(container.read(spacesSelectionProvider), isNull);
        expect(find.text('InSpace'), findsNothing);
        expect(find.text(t.spaces.selectHint), findsOneWidget);
      },
      skip: !_flagOn,
    );
  });

  test('FeatureFlags.masterDetailLayout matches the lane', () {
    expect(FeatureFlags.masterDetailLayout, _flagOn);
  });
}
