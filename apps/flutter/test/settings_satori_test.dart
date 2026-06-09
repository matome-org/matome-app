import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/app/auth_state.dart';
import 'package:matome_flutter/app/navigation_guard.dart';
import 'package:matome_flutter/app/screens/satori_screen.dart' as satori;
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
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/auth/auth_repository.dart';
import 'package:matome_flutter/features/auth/welcome_screen.dart';
import 'package:matome_flutter/features/calendar/calendar_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';
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
  Future<AuthSession> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();
  @override
  Future<AuthSession> refresh() => throw UnimplementedError();
}

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

void main() {
  late AppDatabase db;
  late InMemoryTokenStore store;

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = InMemoryTokenStore();
    // Seed a valid persisted session so startup restoreSession() lands authed.
    store.saveTokens(
      accessToken: _session.accessToken,
      refreshToken: _session.refreshToken!,
    );
  });
  tearDown(() => db.close());

  testWidgets('Sign out from Settings clears tokens and returns to Welcome',
      (tester) async {
    await tester.pumpWidget(_pumpApp(db: db, store: store));
    await tester.pumpAndSettle();

    // Authed: inbox content visible.
    expect(find.text('Standup notes'), findsOneWidget);

    // Open Settings from the inbox stack.
    final ctx = tester.element(find.byType(HomeScreen));
    GoRouter.of(ctx).go('/inbox/settings');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text(_session.user.email), findsOneWidget);

    // The Sign out tile is the last row of a lazy ListView, so it may not be
    // materialized yet — scroll it into view before tapping.
    final signOut = find.byIcon(Icons.logout);
    await tester.scrollUntilVisible(signOut, 200);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    // Tokens cleared and the guard redirected to the Welcome screen.
    expect(await store.readAccessToken(), isNull);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Satori tab renders the medallion + roadmap cards',
      (tester) async {
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
  });
}
