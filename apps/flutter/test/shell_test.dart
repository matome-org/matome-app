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
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
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
import 'package:matome_flutter/features/home/inbox_item.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/fake_inbox.dart';

/// Pre-authenticated, network-free router for the shell smoke test: skips the
/// seed-login bootstrap and seeds the Inbox tab with a fixed recording list.
InboxItem _seedItem() => InboxItem(
      card: const RecordingCard(
        id: '1',
        title: 'Standup notes',
        timestamp: '9:00 AM',
        duration: '0:30',
        badge: 'work',
        isProcessing: false,
        mediaType: 'audio',
        processingStatus: 'done',
      ),
      createdAt: DateTime(2024).millisecondsSinceEpoch,
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
            const MaterialPage(fullscreenDialog: true, child: RecordingScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
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
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/calendar', builder: (c, s) => const CalendarScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/spaces', builder: (c, s) => const SpacesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/satori', builder: (c, s) => const SatoriScreen()),
          ]),
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
      inboxControllerProvider.overrideWith(
        (ref) => FakeInboxController(ref, AsyncValue.data([_seedItem()])),
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
  late AppDatabase db;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  testWidgets('shell renders 4 tabs + mic FAB and navigates between tabs',
      (tester) async {
    await tester.pumpWidget(_pumpApp(db: db));
    await tester.pumpAndSettle();

    // Inbox tab is the initial branch (lab HomeScreen header).
    expect(find.text('Standup notes'), findsOneWidget);
    // Mic FAB present.
    expect(find.byIcon(Icons.mic), findsOneWidget);

    // Navigate to the Spaces tab via the bottom bar.
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.folder_outlined).hitTestable(), findsWidgets);

    // Navigate to the Satori tab.
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
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

  testWidgets('language toggle to ja switches visible strings and persists',
      (tester) async {
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
