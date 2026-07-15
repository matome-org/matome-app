import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../core/providers.dart';
import '../ui/file_detail_page.dart';
import 'auth_state.dart';
import 'navigation_guard.dart';
import 'pages/auth_pages.dart';
import 'pages/primary_pages.dart';
import 'pages/secondary_pages.dart';
import 'screens/tab_screens.dart';
import 'shell_scaffold.dart';
import 'shell_tabs.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _inboxKey = GlobalKey<NavigatorState>(debugLabel: 'inbox');
final _calendarKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _spacesKey = GlobalKey<NavigatorState>(debugLabel: 'spaces');
final _satoriKey = GlobalKey<NavigatorState>(debugLabel: 'satori');
final _contactsKey = GlobalKey<NavigatorState>(debugLabel: 'contacts');
final _filesKey = GlobalKey<NavigatorState>(debugLabel: 'files');

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
  final ownerId = ref.read(currentOwnerIdProvider);
  if (ownerId == null) return null;
  final matomeId = await ref
      .read(matomesDaoProvider)
      .matomeIdForItem(recordingId, ownerId);
  if (matomeId == null) return null;
  return '/matome/$matomeId';
}

/// The app router (matome-centric, #1378). The primary detail route is the
/// **Matome hub** `/matome/:id`; the individual file [FileDetailScreen] is
/// reached from inside the hub via `/items/audio/:id`. Tree:
///   /                       welcome (unauthenticated landing)
///   /recording              fullscreen capture modal (root navigator)
///   /items/audio/:id        audio file details (drill-down from the hub)
///   /items/text/:id         plain-text item host (file-less drill-down)
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
/// Safety redirect for the Satori route once it is compiled out (DR-002,
/// #1467/#1474). Returns the home tab when [FeatureFlags.newNavShell] is ON and
/// [location] is `/satori` (or a sub-path); otherwise null (no redirect — under
/// the legacy shell Satori is a real branch and resolves normally). Pure +
/// flag-aware so a router-level test can assert "a restored `/satori` deep-link
/// never throws go_router's no-match exception" without spinning up the full
/// provider graph.
String? satoriSafetyRedirect(String location) {
  if (!FeatureFlags.newNavShell) return null;
  final isSatori = location == '/satori' || location.startsWith('/satori/');
  return isSatori ? GuardTargets.home : null;
}

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
      // Satori safety redirect (DR-002, #1467/#1474): under
      // [FeatureFlags.newNavShell] the Satori branch is dropped from
      // [shellBranches] and its `/satori` GoRoute is never registered, so a
      // bookmarked / restored `/satori` deep-link would otherwise fall through
      // to go_router's error page. Redirect it to the home tab instead of
      // throwing a "no routes for location" exception (Olivier A05). A no-op
      // when the flag is OFF (Satori is a real branch then).
      final satoriRedirect = satoriSafetyRedirect(state.matchedLocation);
      if (satoriRedirect != null) return satoriRedirect;

      final auth = ref.read(authStateProvider);
      return decideRedirect(
        isAuthenticated: auth.isAuthenticated,
        isLoading: auth.isLoading,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/recording',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            MaterialPage(fullscreenDialog: true, child: RecordingPage()),
      ),
      // Matome detail hub (#1371/#1378): the primary detail "page" for a Matome
      // and its Items. Reached from every list surface (inbox / calendar /
      // spaces) and as the redirect target for legacy recording deep-links.
      GoRoute(
        path: '/matome/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            MatomeDetailPage(id: state.pathParameters['id']!),
      ),
      // Files section (DR-003 / #1465): the cross-matome, owner-scoped Files
      // view (grid + table). Under the LEGACY shell it lives on the root
      // navigator as a deep-link-only route (NOT a tab). Under
      // [FeatureFlags.newNavShell] (#1467) `/files` is PROMOTED to a stateful
      // shell branch below, so this root route is compiled out to avoid a
      // duplicate `/files` GoRoute. Allow-listed in the auth guard so an authed
      // deep-link is not bounced to /inbox.
      if (!FeatureFlags.newNavShell)
        GoRoute(
          path: '/files',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const FilesPage(),
        ),
      // Single file details (#1378): the drill-DOWN route used from inside
      // the Matome hub to open ONE file Item. Distinct from legacy recording
      // deep-links, which now redirect UP to the parent matome — so this route
      // is the only non-redirecting path to the [FileDetailScreen].
      GoRoute(
        path: '/items/audio/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => fileDetailPage(
          context,
          FileDetailPage.audio(id: state.pathParameters['id']!),
        ),
      ),
      // Image drill-down by id. The id is in the PATH (not `extra`) so it
      // survives go_router rebuilds — `extra` is dropped on rebuild, which made
      // `state.extra!` throw a null-check and blow up the image detail. The
      // host loads only the row (no audio-source `downloadUrl`). Path stays
      // under `/items/` so the auth guard's allowed-prefix list lets it
      // through without a special case.
      GoRoute(
        path: '/items/image/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => fileDetailPage(
          context,
          FileDetailPage.image(id: state.pathParameters['id']!),
        ),
      ),
      // Document drill-down by id (#1450). A document must NEVER hit
      // `/items/audio/:id` (the AUDIO host, which awaits a presigned
      // audio-source `downloadUrl`). Mirrors the image route exactly: the id is
      // in the PATH (not `extra`, which go_router drops on rebuild → a
      // `state.extra!` null-check crash); the host loads only the row, with NO
      // audio load. Path stays under `/items/` so the auth guard's
      // allowed-prefix list lets it through. Wrapped in `fileDetailPage` so
      // desktop gets the bounded dialog and mobile gets full-screen.
      GoRoute(
        path: '/items/document/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => fileDetailPage(
          context,
          FileDetailPage.document(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/items/video/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => fileDetailPage(
          context,
          FileDetailPage.video(id: state.pathParameters['id']!),
        ),
      ),
      // Text-note drill-down by id. Text items are file-less, so this route uses
      // the text host directly and never touches file detail/audio presign paths.
      GoRoute(
        path: '/items/text/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            TextItemPage(id: state.pathParameters['id']!),
      ),
      // Desktop meeting recorder (loopback + mic, MVP Linux). Same fullscreen
      // modal as /recording, bound to the meeting (ffmpeg loopback) recorder.
      GoRoute(
        path: '/meeting',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            MaterialPage(fullscreenDialog: true, child: MeetingRecordingPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        // Branches are built from [shellBranches] — the SINGLE ordered list both
        // this route tree and the active shell's destinations derive from, so
        // `StatefulNavigationShell.currentIndex` / `goBranch(index)` always line
        // up no matter which tabs the flags drop and regardless of the new-shell
        // reorder. Each tab maps to its branch via [_branchFor]; a tab that is
        // not enabled (e.g. Satori under [FeatureFlags.newNavShell], whose route
        // is therefore COMPILED OUT and unreachable) never reaches this list.
        // Inbox is the fixed home and is always present.
        branches: [for (final tab in shellBranches) _branchFor(ref, tab)],
      ),
    ],
  );
});

/// Maps a [ShellTab] to its [StatefulShellBranch] (route subtree). Driven from
/// [shellBranches] so the branch order matches the active shell's destination
/// order exactly — the indexed-stack indices the shell navigates with stay
/// aligned with the routes here under BOTH [FeatureFlags.newNavShell] states.
StatefulShellBranch _branchFor(Ref ref, ShellTab tab) {
  return switch (tab) {
    ShellTab.inbox => StatefulShellBranch(
      navigatorKey: _inboxKey,
      routes: [
        GoRoute(
          path: '/inbox',
          builder: (context, state) => const InboxPage(),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (context, state) => const SettingsPage(),
            ),
            GoRoute(
              // LEGACY recording deep-link → parent matome (#1378).
              path: ':id',
              redirect: (context, state) =>
                  _redirectRecordingToMatome(ref, state.pathParameters['id']),
              builder: (context, state) =>
                  RecordingDetailScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    ShellTab.calendar => StatefulShellBranch(
      navigatorKey: _calendarKey,
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const CalendarPage(),
          routes: [
            GoRoute(
              // LEGACY recording deep-link → parent matome (#1378).
              path: ':id',
              redirect: (context, state) =>
                  _redirectRecordingToMatome(ref, state.pathParameters['id']),
              builder: (context, state) =>
                  RecordingDetailScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    ShellTab.spaces => StatefulShellBranch(
      navigatorKey: _spacesKey,
      routes: [
        GoRoute(
          path: '/spaces',
          builder: (context, state) => const SpacesPage(),
          routes: [
            GoRoute(
              // LEGACY recording-in-a-space deep-link → parent matome.
              path: 'recording/:id',
              redirect: (context, state) =>
                  _redirectRecordingToMatome(ref, state.pathParameters['id']),
              builder: (context, state) =>
                  SpaceRecordingScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(
              path: ':spaceId',
              builder: (context, state) =>
                  SpaceDetailPage(spaceId: state.pathParameters['spaceId']!),
            ),
          ],
        ),
      ],
    ),
    ShellTab.satori => StatefulShellBranch(
      navigatorKey: _satoriKey,
      routes: [
        GoRoute(
          path: '/satori',
          builder: (context, state) => const SatoriScreen(),
        ),
      ],
    ),
    ShellTab.contacts => StatefulShellBranch(
      navigatorKey: _contactsKey,
      routes: [
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const ContactsPage(),
          routes: [
            // Contact detail (DR-004, #1464): the graduated ContactDetail
            // hosted at `/contacts/:id`, pushed from the list.
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  ContactDetailPage(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
    // Files (DR-002/#1467): a shell branch only under newNavShell. Under the
    // legacy shell `files` is never in [shellBranches], so this arm is unused
    // and `/files` stays the root deep-link route above.
    ShellTab.files => StatefulShellBranch(
      navigatorKey: _filesKey,
      routes: [
        GoRoute(path: '/files', builder: (context, state) => const FilesPage()),
      ],
    ),
  };
}
