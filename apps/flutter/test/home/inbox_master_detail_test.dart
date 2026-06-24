import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/reading_pane.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/files/files_providers.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';
import 'package:matome_flutter/features/matome/matome_detail_screen.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_repository.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

/// W2 (#1541): the Inbox renders through the unified [MasterDetailScaffold]
/// behind `FeatureFlags.masterDetailLayout`. The flag is a COMPILE-TIME const,
/// so this file is run TWICE by the design-system gate:
///   * forced OFF — pins the SHIPPED `_wideBreakpoint`=1000 two-pane reality.
///   * forced ON  — proves the new scaffold-driven reality (reading-pane
///                  position + width class decide the pane; selection clears
///                  when the selected matome leaves the list).
/// Each lane group self-skips under the wrong build.
const _flagOn = bool.fromEnvironment(
  'ff.masterDetailLayout',
  defaultValue: false,
);

/// A repo whose Core fetch returns nothing — the inbox controller runs a Core
/// `refresh()` on construction, so the repo is stubbed to keep the test
/// offline / DB-only.
class _EmptyRepo extends RecordingsRepository {
  _EmptyRepo({required super.apiClient});

  @override
  Future<List<Recording>> fetchRecordings() async => const [];
}

/// Inert retry service — HomeScreen's `initState` post-frame callback calls
/// `start()`, which would otherwise leave a periodic [Timer] pending and trip
/// the test binding's timer-leak guard. A no-op `start()` keeps the pump clean.
class _InertRetryService extends UploadRetryService {
  _InertRetryService(super.ref);

  @override
  Future<void> start() async {}
}

Future<void> _seedMatome(
  AppDatabase db, {
  required String id,
  required String title,
  int happenedAt = 1000,
}) {
  return db.matomesDao.create(
    MatomesCompanion.insert(
      id: id,
      title: title,
      happenedAt: happenedAt,
      createdAt: happenedAt,
    ),
  );
}

ProviderContainer _container(
  AppDatabase db, {
  ReadingPaneMode? mode,
}) {
  final c = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    recordingsRepositoryProvider.overrideWithValue(
      _EmptyRepo(
        apiClient: ApiClient(
          tokenStore: InMemoryTokenStore(),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:4000')),
        ),
      ),
    ),
    currentOwnerIdProvider.overrideWithValue('1'),
    uploadRetryServiceProvider.overrideWith(
      (ref) => _InertRetryService(ref),
    ),
    if (mode != null)
      readingPaneModeProvider(ReadingPaneSurface.inbox).overrideWith(
        (ref) => _StubReadingPane(ReadingPaneSurface.inbox, mode),
      ),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// A reading-pane controller pinned to a fixed mode (in-memory store, the mode
/// set synchronously so the pumped tree sees it on the first frame).
class _StubReadingPane extends ReadingPaneModeController {
  _StubReadingPane(ReadingPaneSurface surface, ReadingPaneMode mode)
      : super(InMemorySettingsStore(), surface) {
    state = mode;
  }
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const HomeScreen(),
      ),
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

  // ── OFF lane (characterization): shipped two-pane unchanged ───────────────
  group('lane: ff.masterDetailLayout=false (OFF / shipped two-pane)', () {
    testWidgets(
      'at width 1000 the legacy two-pane renders the _InboxDetailPane '
      'placeholder (no MasterDetailScaffold)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(1000, 900));
        await tester.pumpWidget(_app(_container(db)));
        await tester.pumpAndSettle();

        // The shipped wide path: the teaching placeholder is visible beside the
        // list, and the unified scaffold is NOT in the tree.
        expect(find.text(t.inbox.selectHint), findsOneWidget);
        expect(find.byType(MasterDetailScaffold), findsNothing);
      },
      skip: _flagOn,
    );
  });

  // ── ON lane: scaffold-driven reading pane ─────────────────────────────────
  group('lane: ff.masterDetailLayout=true (ON / MasterDetailScaffold)', () {
    testWidgets(
      'always pane + expanded width (1280) + a selection → the detail pane '
      '(MatomeDetailScreen) is present',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        // Pre-select a matome so the pane has content.
        container.read(inboxSelectionProvider.notifier).state = 'm1';

        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        expect(find.byType(MatomeDetailScreen), findsOneWidget);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'onClick + expanded: nothing selected → full-width list (no detail, no '
      'empty hint); tapping a matome opens the pane (split appears)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.onClick);

        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();

        // Master full-width until a selection exists: no detail, no empty hint.
        expect(find.byType(MatomeDetailScreen), findsNothing);
        expect(find.text(t.inbox.selectHint), findsNothing);

        await tester.tap(find.text('Standup notes'));
        await tester.pumpAndSettle();

        // The tap selects in-pane (no navigation) and opens the split.
        expect(container.read(inboxSelectionProvider), 'm1');
        expect(find.byType(MatomeDetailScreen), findsOneWidget);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'reading pane = off → full-width list, no pane even at expanded width',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.off);
        // Even with a selection set, the OFF pane never renders a detail.
        container.read(inboxSelectionProvider.notifier).state = 'm1';

        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();

        expect(find.byType(MasterDetailScaffold), findsOneWidget);
        expect(find.byType(MatomeDetailScreen), findsNothing);
        expect(find.text(t.inbox.selectHint), findsNothing);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'compact width (400) → no pane (degrades to full-width list)',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(400, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(inboxSelectionProvider.notifier).state = 'm1';

        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();

        expect(find.byType(MatomeDetailScreen), findsNothing);
        expect(find.text(t.inbox.selectHint), findsNothing);
      },
      skip: !_flagOn,
    );

    testWidgets(
      'selection clears when the selected matome leaves the loaded list',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedMatome(db, id: 'm1', title: 'Standup notes');

        _setSize(tester, const Size(1280, 900));
        final container = _container(db, mode: ReadingPaneMode.always);
        container.read(inboxSelectionProvider.notifier).state = 'm1';

        await tester.pumpWidget(_app(container));
        await tester.pumpAndSettle();
        expect(find.byType(MatomeDetailScreen), findsOneWidget);

        // The selected matome is removed from the DB and the list reloads —
        // the pane must NOT keep pointing at the now-absent matome.
        await db.matomesDao.deleteMatome('m1');
        await container
            .read(matomeInboxControllerProvider.notifier)
            .reloadFromLocal();
        await tester.pumpAndSettle();

        expect(container.read(inboxSelectionProvider), isNull);
        expect(find.byType(MatomeDetailScreen), findsNothing);
        expect(find.text(t.inbox.selectHint), findsOneWidget);
      },
      skip: !_flagOn,
    );
  });

  test('FeatureFlags.masterDetailLayout matches the lane', () {
    expect(FeatureFlags.masterDetailLayout, _flagOn);
  });
}
