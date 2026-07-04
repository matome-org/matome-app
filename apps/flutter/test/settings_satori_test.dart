import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:matome_flutter/app/auth_state.dart';
import 'package:matome_flutter/app/navigation_guard.dart';
import 'package:matome_flutter/app/screens/satori_screen.dart' as satori;
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
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/auth/auth_repository.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/calendar/calendar_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/fake_inbox.dart';

/// Auth-aware shell harness for S6 (#785): unlike `shell_test`, the router's
/// redirect reads the *live* auth state so a logout from Settings actually
/// propagates to a welcome redirect. Backed by an in-memory token store + a
/// fake repo so nothing touches the network.

const _session = AuthSession(
  user: AuthUser(id: 1, email: 'dev@matome.test'),
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
);

/// Fake repo: `me()` validates the seeded session on startup, `logout()` clears
/// the tokens. Only the surface the controller touches is implemented.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._store);
  final InMemoryTokenStore _store;
  int logoutCalls = 0;

  @override
  Future<AuthUser> me() async => _session.user;

  @override
  Future<void> logout() async {
    logoutCalls++;
    await _store.clear();
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AuthSession> refresh() => throw UnimplementedError();
  @override
  Future<void> requestPasswordReset({required String email}) async {}
  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}
}

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

GoRouter _buildRouter(WidgetRef ref) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/inbox',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      return decideRedirect(
        isAuthenticated: auth.isAuthenticated,
        isLoading: auth.isLoading,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const WelcomeScreen()),
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
        ],
      ),
    ],
  );
}

/// Bridges the auth provider to go_router's `refreshListenable` so a logout
/// re-runs the redirect.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
  final WidgetRef _ref;
}

Widget _pumpApp({required AppDatabase db, required InMemoryTokenStore store}) {
  final repo = _FakeAuthRepository(store);
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      tokenStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(repo),
      appDatabaseProvider.overrideWithValue(db),
      matomeInboxControllerProvider.overrideWith(
        (ref) => FakeMatomeInboxController(ref, AsyncValue.data([_seedItem()])),
      ),
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
  late final GoRouter _router = _buildRouter(ref);

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

/// Fake path_provider so `AuthController.logout()`'s default playback-cache
/// sweep (`defaultPlaybackScratchDir` → `getTemporaryDirectory()`, okt-audit
/// PASS-2 FINDING-1, task #1867) resolves against a real temp dir instead of
/// a platform channel with no registered mock handler — which, in a
/// `testWidgets` harness, does not throw but never resolves, silently
/// stalling `logout()` before it reaches `state = AsyncValue.data(null)`.
/// Mirrors `matome_add_photo_e2e_test.dart`'s `_FakePathProvider`.
class _FakeTempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeTempPathProvider(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late AppDatabase db;
  late InMemoryTokenStore store;
  late Directory fakeTempRoot;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InMemoryTokenStore();
    fakeTempRoot = Directory.systemTemp.createTempSync('settings_satori_fake_temp_');
    PathProviderPlatform.instance = _FakeTempPathProvider(fakeTempRoot.path);
    // Seed a valid persisted session so startup restoreSession() lands authed.
    store.saveTokens(
      accessToken: _session.accessToken,
      refreshToken: _session.refreshToken!,
    );
  });
  tearDown(() async {
    await db.close();
    if (fakeTempRoot.existsSync()) fakeTempRoot.deleteSync(recursive: true);
  });

  testWidgets('Sign out from Settings clears tokens and returns to Welcome', (
    tester,
  ) async {
    await tester.pumpWidget(_pumpApp(db: db, store: store));
    await tester.pumpAndSettle();

    // Authed: inbox content visible.
    expect(find.text('Standup notes'), findsOneWidget);

    // Open Settings from the inbox stack.
    final ctx = tester.element(find.byType(HomeScreen));
    GoRouter.of(ctx).go('/inbox/settings');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    // The account section (user email + Sign out) is the tail of a lazy
    // ListView — with the #1468 "Default views" section added above it, neither
    // is materialized on first paint, so scroll the Sign out tile into view.
    final signOut = find.byIcon(Icons.logout);
    await tester.scrollUntilVisible(signOut, 200);
    await tester.pumpAndSettle();
    expect(find.text(_session.user.email), findsOneWidget);
    await tester.tap(signOut);
    // `AuthController.logout()` now also sweeps the playback scratch cache
    // (okt-audit PASS-2 FINDING-1, task #1867) via real `dart:io`
    // `Directory.exists()`/`delete()` calls. `testWidgets()`'s default zone
    // does not resolve real (non-mocked-channel) async I/O — only
    // `tester.runAsync()` runs in a real zone where it can actually
    // complete — so without this, `logout()` would stall forever before
    // ever reaching `state = AsyncValue.data(null)`, and the redirect to
    // Welcome below would never happen.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    // Tokens cleared and the guard redirected to the Welcome screen.
    expect(await store.readAccessToken(), isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Satori tab renders the medallion + roadmap cards', (
    tester,
  ) async {
    await tester.pumpWidget(_pumpApp(db: db, store: store));
    await tester.pumpAndSettle();

    // Navigate to the Satori tab via the bottom bar.
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(satori.SatoriScreen), findsOneWidget);

    final s = t.satori;
    // Under-construction medallion chrome.
    expect(find.text(s.soon), findsOneWidget);
    expect(find.text(s.underConstruction), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);

    // All four roadmap cards render their titles + statuses.
    expect(find.text(s.roadmapLabel), findsOneWidget);
    for (final title in [
      s.roadmapSearchTitle,
      s.roadmapQuestionsTitle,
      s.roadmapEmailsTitle,
      s.roadmapInsightsTitle,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // Shipped status detail + the "done" check mark.
    expect(find.text(s.roadmapSearchDetail), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Satori is a bottom-bar destination only under the LEGACY shell; under
    // ff.newNavShell the destination (and its route) is gone, so this nav-via-
    // dock-glyph test is meaningful only OFF. The ON build proves Satori is
    // unreachable (redirected) in test/app/new_nav_router_test.dart.
  }, skip: FeatureFlags.newNavShell);
}
