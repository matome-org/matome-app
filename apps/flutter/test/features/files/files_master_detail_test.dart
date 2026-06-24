import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/settings/reading_pane.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// W3 (#1542): the Files surface renders through the unified
/// [MasterDetailScaffold] behind `FeatureFlags.masterDetailLayout`. The flag is
/// a COMPILE-TIME const, so this file is run TWICE by the design-system gate:
///   * forced OFF — pins the SHIPPED centred-1080 + route-on-tap reality.
///   * forced ON  — proves the new scaffold-driven reality (reading-pane
///                  position + width class decide the pane; selection clears
///                  when the selected file leaves the list).
/// Each lane group self-skips under the wrong build.
const _flagOn = bool.fromEnvironment(
  'ff.masterDetailLayout',
  defaultValue: false,
);

const String _owner = '1';

/// A reading-pane controller pinned to a fixed mode (in-memory store, the mode
/// set synchronously so the pumped tree sees it on the first frame).
class _StubReadingPane extends ReadingPaneModeController {
  _StubReadingPane(ReadingPaneMode mode)
      : super(InMemorySettingsStore(), ReadingPaneSurface.files) {
    state = mode;
  }
}

ProviderContainer _container(
  AppDatabase db, {
  ReadingPaneMode? mode,
  String view = 'table',
}) {
  final c = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    currentOwnerIdProvider.overrideWithValue(_owner),
    settingsStoreProvider
        .overrideWithValue(InMemorySettingsStore({'matome.files_view': view})),
    if (mode != null)
      readingPaneModeProvider(ReadingPaneSurface.files)
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
    initialLocation: '/files',
    routes: [
      GoRoute(path: '/files', builder: (_, _) => const FilesScreen()),
      GoRoute(
        path: '/recording/:kind/:id',
        builder: (_, state) {
          spy.last =
              '/recording/${state.pathParameters['kind']}/${state.pathParameters['id']}';
          return const Scaffold(body: Text('detail'));
        },
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

Future<void> _seedFile(
  AppDatabase db, {
  required String id,
  required String title,
  String mediaType = 'audio',
  int createdAt = 1000,
}) {
  return db.recordingsDao.insertRecording(
    RecordingsCompanion.insert(
      id: id,
      title: title,
      timestamp: '9:00 AM',
      duration: '0:30',
      audioFilePath: '/tmp/$id.m4a',
      createdAt: createdAt,
      ownerId: const Value(_owner),
      mediaType: Value(mediaType),
      processingStatus: const Value('done'),
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

  // ── OFF lane (characterization): shipped centred-1080 + route-on-tap ──────
  group('lane: ff.masterDetailLayout=false (OFF / shipped centred)', () {
    testWidgets(
      'at width 1280 the master is centred (1080 ConstrainedBox), no scaffold',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(_container(db), spy));
        await tester.pumpAndSettle();

        // Shipped reality: the 1080-cap ConstrainedBox is present and the
        // unified scaffold is NOT in the tree.
        expect(find.byType(MasterDetailScaffold), findsNothing);
        final cap = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox)).where(
              (b) => b.constraints.maxWidth == 1080,
            );
        expect(cap, isNotEmpty);
      },
      skip: _flagOn,
    );

    testWidgets(
      'tapping a file routes to its detail (no in-pane selection)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db);
        final spy = _RouteSpy();
        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(spy.last, '/recording/detail/r1');
        expect(container.read(filesSelectionProvider), isNull);
      },
      skip: _flagOn,
    );
  });

  // ── ON lane: scaffold-driven reading pane ─────────────────────────────────
  group('lane: ff.masterDetailLayout=true (ON / MasterDetailScaffold)', () {
    testWidgets(
      'Right pane + expanded width (1280) + a selection → FileView pane present,'
      ' no 1080 ConstrainedBox',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(filesSelectionProvider.notifier).state = 'r1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        expect(find.byType(FileView), findsOneWidget);
        // Full-width master: the shipped 1080 cap is gone.
        final cap = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox)).where(
              (b) => b.constraints.maxWidth == 1080,
            );
        expect(cap, isEmpty);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'onClick tap-to-select: nothing selected → no pane (no empty hint); '
      'tapping a file at expanded width opens it in the pane (no navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.onClick);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        // onClick + nothing selected → full-width master: no pane, no hint.
        expect(find.byType(FileView), findsNothing);
        expect(find.text(t.files.selectHint), findsNothing);

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(container.read(filesSelectionProvider), 'r1');
        expect(spy.last, isNull);
        expect(find.byType(FileView), findsOneWidget);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'reading pane = off → full-width master, no pane even at expanded width',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.off);
        container.read(filesSelectionProvider.notifier).state = 'r1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        expect(find.byType(FileView), findsNothing);
        expect(find.text(t.files.selectHint), findsNothing);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'compact width (400) → no pane; tap routes (degrades to navigation)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(400, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(spy.last, '/recording/detail/r1');
        expect(container.read(filesSelectionProvider), isNull);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'selection clears when the selected file leaves the loaded list',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedFile(db, id: 'r1', title: 'Alpha');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(filesSelectionProvider.notifier).state = 'r1';
        final spy = _RouteSpy();

        await tester.pumpWidget(_app(container, spy));
        await tester.pumpAndSettle();
        expect(find.byType(FileView), findsOneWidget);

        // The selected file is removed and the owner-scoped provider re-reads —
        // the pane must NOT keep pointing at the now-absent file.
        await db.recordingsDao.deleteRecording('r1');
        container.invalidate(filesForCurrentOwnerProvider);
        await tester.pumpAndSettle();

        expect(container.read(filesSelectionProvider), isNull);
        expect(find.byType(FileView), findsNothing);
        expect(find.text(t.files.selectHint), findsOneWidget);
      },
      skip: !_flagOn,
    );
  });

  test('FeatureFlags.masterDetailLayout matches the lane', () {
    expect(FeatureFlags.masterDetailLayout, _flagOn);
  });
}
