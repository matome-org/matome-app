import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/home/home_screen.dart';
import 'auth_state.dart';
import 'navigation_guard.dart';
import 'screens/recording_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tab_screens.dart';
import 'shell_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _inboxKey = GlobalKey<NavigatorState>(debugLabel: 'inbox');
final _calendarKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _spacesKey = GlobalKey<NavigatorState>(debugLabel: 'spaces');
final _satoriKey = GlobalKey<NavigatorState>(debugLabel: 'satori');

/// Bridges Riverpod auth state into go_router's [GoRouter.refreshListenable]
/// so the redirect re-runs whenever auth resolves.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _sub = _ref.listen<AuthState>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// The app router. Mirrors the expo-router tree:
///   /                       welcome (unauthenticated landing)
///   /recording              fullscreen modal (root navigator, above the shell)
///   [shell]                 4 stateful tab branches:
///     /inbox                inbox root (lab HomeScreen)
///       /inbox/settings     settings
///       /inbox/:id          recording details
///     /calendar             calendar root
///       /calendar/:id       day / recording details
///     /spaces               spaces root
///       /spaces/:spaceId    space details
///       /spaces/recording/:id  recording in a space
///     /satori               satori root
final routerProvider = Provider<GoRouter>((ref) {
  // Real auth: the AuthController restores the persisted session on creation
  // (validates tokens via /api/auth/me). Touch it so that bootstrap kicks off
  // as soon as the router is built and the guard observes loading -> resolved.
  ref.read(authStateProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
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
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/recording',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: RecordingScreen(),
        ),
      ),
      // Desktop meeting recorder (loopback + mic, MVP Linux). Same fullscreen
      // modal as /recording, bound to the meeting (ffmpeg loopback) recorder.
      GoRoute(
        path: '/meeting',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: RecordingScreen(binding: RecorderBinding.meeting),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _inboxKey,
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RecordingDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _calendarKey,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RecordingDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _spacesKey,
            routes: [
              GoRoute(
                path: '/spaces',
                builder: (context, state) => const SpacesScreen(),
                routes: [
                  GoRoute(
                    path: 'recording/:id',
                    builder: (context, state) => SpaceRecordingScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: ':spaceId',
                    builder: (context, state) => SpaceDetailScreen(
                      spaceId: state.pathParameters['spaceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _satoriKey,
            routes: [
              GoRoute(
                path: '/satori',
                builder: (context, state) => const SatoriScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
