import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/details/details_screen.dart';
import '../features/home/home_screen.dart';
import '../features/matome/matome_detail_screen.dart';
import 'auth_state.dart';
import 'navigation_guard.dart';
import 'screens/recording_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tab_screens.dart';
import 'shell_scaffold.dart';
import 'shell_tabs.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _inboxKey = GlobalKey<NavigatorState>(debugLabel: 'inbox');
final _calendarKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _spacesKey = GlobalKey<NavigatorState>(debugLabel: 'spaces');
final _satoriKey = GlobalKey<NavigatorState>(debugLabel: 'satori');
final _contactsKey = GlobalKey<NavigatorState>(debugLabel: 'contacts');

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

/// Resolves an OLD recording-centric deep-link (`:id` is a recordingId) to its
/// parent Matome hub (#1378). The 1-recording→1-matome backfill invariant makes
/// this deterministic: look up `recording.matomeId` and redirect to
/// `/matome/<matomeId>`. Returns null (no redirect → the route's own builder
/// runs) when the recording has no resolvable Matome, so the link degrades to
/// the legacy single-recording view rather than dead-ending.
Future<String?> _redirectRecordingToMatome(Ref ref, String? recordingId) async {
  if (recordingId == null) return null;
  final matomeId =
      await ref.read(matomesDaoProvider).matomeIdForRecording(recordingId);
  if (matomeId == null) return null;
  return '/matome/$matomeId';
}

/// The app router (matome-centric, #1378). The primary detail route is the
/// **Matome hub** `/matome/:id`; the individual-recording [DetailsScreen] is
/// reached from inside the hub via `/recording/detail/:id`. Tree:
///   /                       welcome (unauthenticated landing)
///   /recording              fullscreen capture modal (root navigator)
///   /recording/detail/:id   single-recording details (drill-down from the hub)
///   /matome/:id             the Matome hub (primary detail)
///   [shell]                 5 stateful tab branches:
///     /inbox                inbox root (inbox MATOMES)
///       /inbox/settings     settings
///       /inbox/:id          LEGACY recording link → redirects to parent matome
///     /calendar             calendar root (matomes by happenedAt)
///       /calendar/:id       LEGACY recording link → redirects to parent matome
///     /spaces               spaces root
///       /spaces/:spaceId    space details (its matomes)
///       /spaces/recording/:id  LEGACY recording link → redirects to parent matome
///     /satori               satori root
///     /contacts             contacts directory root (#1374)
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
      // Matome detail hub (#1371/#1378): the primary detail "page" for a Matome
      // and its Items. Reached from every list surface (inbox / calendar /
      // spaces) and as the redirect target for legacy recording deep-links.
      GoRoute(
        path: '/matome/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => MatomeDetailScreen(
          id: state.pathParameters['id']!,
        ),
      ),
      // Single-recording details (#1378): the drill-DOWN route used from inside
      // the Matome hub to open ONE Item. Distinct from the legacy recording
      // deep-links, which now redirect UP to the parent matome — so this route
      // is the only non-redirecting path to the [DetailsScreen].
      GoRoute(
        path: '/recording/detail/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => DetailsScreen(
          id: state.pathParameters['id']!,
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
        // Branches are gated by the same build-time flags as the shell's
        // destinations (see [ShellTab]/[enabledTabs]); a disabled tab drops its
        // whole branch here AND its destination there, so the StatefulShell
        // indices stay aligned. Inbox is the fixed home and is always present.
        branches: [
          if (ShellTab.inbox.enabled)
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
                    // LEGACY recording deep-link → parent matome (#1378).
                    path: ':id',
                    redirect: (context, state) => _redirectRecordingToMatome(
                      ref,
                      state.pathParameters['id'],
                    ),
                    builder: (context, state) => RecordingDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ShellTab.calendar.enabled)
            StatefulShellBranch(
            navigatorKey: _calendarKey,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    // LEGACY recording deep-link → parent matome (#1378).
                    path: ':id',
                    redirect: (context, state) => _redirectRecordingToMatome(
                      ref,
                      state.pathParameters['id'],
                    ),
                    builder: (context, state) => RecordingDetailScreen(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ShellTab.spaces.enabled)
            StatefulShellBranch(
            navigatorKey: _spacesKey,
            routes: [
              GoRoute(
                path: '/spaces',
                builder: (context, state) => const SpacesScreen(),
                routes: [
                  GoRoute(
                    // LEGACY recording-in-a-space deep-link → parent matome.
                    path: 'recording/:id',
                    redirect: (context, state) => _redirectRecordingToMatome(
                      ref,
                      state.pathParameters['id'],
                    ),
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
          if (ShellTab.satori.enabled)
            StatefulShellBranch(
            navigatorKey: _satoriKey,
            routes: [
              GoRoute(
                path: '/satori',
                builder: (context, state) => const SatoriScreen(),
              ),
            ],
          ),
          if (ShellTab.contacts.enabled)
            StatefulShellBranch(
            navigatorKey: _contactsKey,
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (context, state) => const ContactsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
