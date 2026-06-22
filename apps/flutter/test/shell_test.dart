import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/app/navigation_guard.dart';
import 'package:matome_flutter/app/screens/recording_screen.dart';
import 'package:matome_flutter/app/screens/settings_screen.dart';
import 'package:matome_flutter/app/screens/tab_screens.dart';
import 'package:matome_flutter/app/shell_scaffold.dart';
import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/i18n/locale_controller.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/core/theme/theme_controller.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/calendar/calendar_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/fake_inbox.dart';

/// Pre-authenticated, network-free router for the shell smoke test: skips the
/// seed-login bootstrap and seeds the Inbox tab with a fixed **matome** list.
MatomeItem _seedItem() => MatomeItem(
  id: '1',
  spaceId: null,
  title: 'Standup notes',
  happenedAt: DateTime(2024).millisecondsSinceEpoch,
  createdAt: DateTime(2024).millisecondsSinceEpoch,
  summaryStale: false,
  recordingCount: 1,
  recordings: const [],
);

GoRouter _buildTestRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/inbox',
    redirect: (context, state) => decideRedirect(
      isAuthenticated: true,
      isLoading: false,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/', builder: (c, s) => const WelcomeScreen()),
      GoRoute(
        path: '/recording',
        parentNavigatorKey: rootKey,
        pageBuilder: (c, s) =>
            MaterialPage(fullscreenDialog: true, child: RecordingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (c, s) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (c, s) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (c, s) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/spaces', builder: (c, s) => const SpacesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/satori', builder: (c, s) => const SatoriScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (c, s) => const ContactsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _pumpApp({SettingsStore? store, required AppDatabase db}) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(store ?? InMemorySettingsStore()),
      // Network-free token store so the AuthController's startup session check
      // (settings screen reads authStateProvider) resolves to signed-out
      // without touching the secure-storage platform channel.
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      // The Calendar branch (built eagerly by the indexed-stack shell) reads
      // the Drift DAOs — back them with an in-memory DB so no native file opens.
      appDatabaseProvider.overrideWithValue(db),
      matomeInboxControllerProvider.overrideWith(
        (ref) => FakeMatomeInboxController(ref, AsyncValue.data([_seedItem()])),
      ),
      // The matome inbox controller listens to the recording-level inbox;
      // stub it so the listen target never builds a real Drift/Core controller.
      inboxControllerProvider.overrideWith(
        (ref) => FakeInboxController(ref, const AsyncValue.data([])),
      ),
    ],
    child: TranslationProvider(child: const _TestApp()),
  );
}

class _TestApp extends ConsumerStatefulWidget {
  const _TestApp();
  @override
  ConsumerState<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends ConsumerState<_TestApp> {
  // Build the router once so a locale/theme rebuild doesn't reset navigation
  // (mirrors the app's stable routerProvider).
  final _router = _buildTestRouter();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    ref.watch(localeControllerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}

void main() {
  // LEGACY-shell characterization (DR-002, #1474). These assertions are about
  // the OFF reality — the notched BottomAppBar + center-docked mic FAB on mobile
  // and the Material NavigationRail on desktop. Once `ff.newNavShell` defaults
  // ON, a plain `flutter test` builds the NEW shell, so this file would assert
  // chrome that no longer renders. Skip it under the ON build; the dual-flag
  // gate (`mise run flutter-design-system-check`) runs the suite once with
  // `--dart-define=ff.newNavShell=false`, which is where this OFF proof stays
  // green. The ON reality is characterized in test/app/new_nav_*_test.dart.
  if (FeatureFlags.newNavShell) {
    test('legacy shell characterization is skipped under the ON build', () {},
        skip: 'ff.newNavShell is ON; OFF chrome not rendered. '
            'Run with --dart-define=ff.newNavShell=false to exercise.');
    return;
  }

  late AppDatabase db;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  testWidgets('shell renders 5 tabs + mic FAB and navigates between tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();

    // Inbox tab is the initial branch (lab HomeScreen header).
    expect(find.text('Standup notes'), findsOneWidget);
    // Mic FAB present.
    expect(find.byIcon(Icons.mic), findsOneWidget);
    // All five bottom-bar destinations are present (Contacts is the 5th, #1374).
    // Scope to the BottomAppBar: the reworked matome rows (#1412) now carry
    // their own place-chip icons (inbox / folder), which would otherwise
    // collide with the destination glyphs.
    final bottomBar = find.byType(BottomAppBar);
    expect(
      find.descendant(of: bottomBar, matching: find.byIcon(Icons.inbox_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomBar,
        matching: find.byIcon(Icons.calendar_today_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomBar,
        matching: find.byIcon(Icons.folder_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomBar,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomBar,
        matching: find.byIcon(Icons.contacts_outlined),
      ),
      findsOneWidget,
    );

    // Drive tab switches through the router: with five bottom-bar items packed
    // around the FAB notch, an icon's centre can fall under the docked FAB in the
    // narrow test viewport, so a raw icon tap is layout-fragile. The branch
    // wiring (currentIndex/goBranch) is what we assert here.
    final BuildContext ctx = tester.element(find.byType(BottomAppBar));

    // Navigate to the Spaces tab.
    GoRouter.of(ctx).go('/spaces');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.folder_outlined).hitTestable(), findsWidgets);

    // Navigate to the Satori tab.
    GoRouter.of(ctx).go('/satori');
    await tester.pumpAndSettle();

    // Navigate to the Contacts tab (the 5th branch, #1374).
    GoRouter.of(ctx).go('/contacts');
    await tester.pumpAndSettle();
    expect(find.text(t.contacts.title), findsWidgets);
  });

  // Real user interaction: TAP each rail destination and assert the screen
  // actually switches. The prior test only drove GoRouter.go() programmatically
  // AND asserted the nav LABEL (a false positive), so it never exercised the
  // tap → goBranch → guard path — where the bug lived: the auth guard's
  // allow-list omitted /contacts (and /matome), so navigating there bounced
  // back to /inbox. (Bottom-bar taps are covered separately; the 5-item bar
  // packs an icon under the FAB notch on narrow widths — a distinct layout
  // follow-up.)
  testWidgets('tapping each rail destination navigates to its screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);

    Future<void> tapRail(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tapRail(t.calendar.title);
    expect(find.byType(CalendarScreen), findsOneWidget, reason: 'calendar');

    await tapRail(t.spaces.title);
    expect(find.byType(SpacesScreen), findsOneWidget, reason: 'spaces');

    await tapRail(t.satori.title);
    expect(find.byType(SatoriScreen), findsOneWidget, reason: 'satori');

    await tapRail(t.contacts.title);
    expect(find.byType(ContactsScreen), findsOneWidget, reason: 'contacts');
  });

  testWidgets('wide viewport renders a NavigationRail, not the bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();

    // Desktop layout: side rail replaces the bottom bar; the capture actions
    // are consolidated into the rail's single "+ New" menu, so there are no
    // loose mic/meeting FABs competing with the nav destinations (the mic icon
    // lives inside the menu and only mounts once it is opened).
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);

    // Inbox is a two-pane: the list is visible AND the empty detail pane shows
    // its teaching placeholder (nothing selected yet).
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text(t.inbox.selectHint), findsOneWidget);

    // Selecting the matome fills the detail pane (the embedded matome hub)
    // without leaving the list.
    await tester.tap(find.text('Standup notes'));
    await tester.pumpAndSettle();
    expect(find.text('Standup notes'), findsWidgets); // list row still present
    expect(find.text(t.inbox.selectHint), findsNothing);
  });

  testWidgets('the rail "+ New" menu exposes the capture actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();

    // Closed: the action labels are not mounted yet.
    expect(find.text(t.nav.recordAudio), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Opened: record audio + import file are reachable from the one entry point.
    expect(find.text(t.nav.recordAudio), findsOneWidget);
    expect(find.text(t.nav.importFile), findsOneWidget);
  });

  testWidgets('mic FAB opens the recording fullscreen modal', (tester) async {
    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    // The modal probes mic support asynchronously on entry (a real recorder
    // call that doesn't resolve under the test FakeAsync), so pump a few bounded
    // frames instead of settling on the entry spinner.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The fullscreen recording modal mounted over the shell.
    expect(find.byType(RecordingScreen), findsOneWidget);
  });

  testWidgets('theme toggle to dark persists and applies', (tester) async {
    final store = InMemorySettingsStore();
    await tester.pumpWidget(_pumpApp(store: store, db: db));
    await tester.pumpAndSettle();

    // Open settings from the inbox stack.
    final BuildContext ctx = tester.element(find.byType(HomeScreen));
    GoRouter.of(ctx).go('/inbox/settings');
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(await store.read('matome.theme_mode'), 'dark');
  });

  testWidgets('language toggle to ja switches visible strings and persists', (
    tester,
  ) async {
    final store = InMemorySettingsStore();
    await tester.pumpWidget(_pumpApp(store: store, db: db));
    await tester.pumpAndSettle();

    final BuildContext ctx = tester.element(find.byType(HomeScreen));
    GoRouter.of(ctx).go('/inbox/settings');
    await tester.pumpAndSettle();

    // English settings title visible.
    expect(find.text('Settings'), findsOneWidget);

    // Switch to Japanese.
    await tester.tap(find.text('日本語').last);
    await tester.pumpAndSettle();

    // Choice persisted, and the global translations now resolve to Japanese.
    expect(await store.read('matome.language'), 'ja');
    expect(t.settings.title, '設定');
    // Settings title is now Japanese in the tree.
    expect(find.text('設定'), findsOneWidget);
  });
}
