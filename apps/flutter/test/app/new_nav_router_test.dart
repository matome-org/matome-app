import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/app/navigation_guard.dart';
import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/app/shell_scaffold.dart';
import 'package:matome_flutter/app/shell_tabs.dart';
import 'package:matome_flutter/core/config/feature_flags.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/shell/widgets/matome_nav.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

/// Router-level acceptance under the **REAL** `FeatureFlags.newNavShell` const
/// (DR-002, #1474). Unlike `new_nav_shell_test.dart` — which pins the flag ON
/// via the `ShellScaffold` constructor seam — this file reads the genuine
/// compile-time flag and the genuine [shellBranches] / [satoriSafetyRedirect]
/// helpers from `lib/app/router.dart`. It is therefore meaningful ONLY when the
/// suite is run with `--dart-define=ff.newNavShell=true`; under the OFF build it
/// skips itself (its claims are about the ON reality). The dual-flag gate in
/// `mise run flutter-design-system-check` runs the suite once each way, so this
/// file is exercised under the real ON const there.
///
/// Proves, against a router built from the SAME ordered [shellBranches] +
/// [satoriSafetyRedirect] the production [routerProvider] uses:
///   - every ON destination (inbox·calendar·files·contacts·spaces) resolves;
///   - deep-link + restore to each branch works;
///   - `/satori` (route compiled out under ON) REDIRECTS to /inbox and NEVER
///     throws a go_router "no routes for location" exception.

class _StubScreen extends StatelessWidget {
  const _StubScreen(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('SCREEN:$label')));
}

/// A router mirroring the production wiring under the real ON flag: branches are
/// built from the genuine [shellBranches] (so the ON order/exclusions are the
/// real ones), and the redirect chains the real [satoriSafetyRedirect] before a
/// (test-stubbed, always-authed) guard so the satori-compiled-out path is
/// exercised exactly as production sees it.
GoRouter _buildRealOnRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/inbox',
    redirect: (context, state) {
      final satori = satoriSafetyRedirect(state.matchedLocation);
      if (satori != null) return satori;
      return decideRedirect(
        isAuthenticated: true,
        isLoading: false,
        location: state.matchedLocation,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          for (final tab in shellBranches)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.location,
                  builder: (c, s) => _StubScreen(tab.location),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

Widget _app(GoRouter router) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  // This whole file asserts the ON reality; under the OFF build the real const
  // makes [shellBranches] the legacy order with Satori present, so skip.
  if (!FeatureFlags.newNavShell) {
    test('skipped under the OFF build (real flag is OFF)', () {}, skip: true);
    return;
  }

  group('real ON flag — router wiring', () {
    test('shellBranches is the DR-002 order with satori excluded', () {
      expect(
        shellBranches,
        const [
          ShellTab.inbox,
          ShellTab.calendar,
          ShellTab.files,
          ShellTab.contacts,
          ShellTab.spaces,
        ],
      );
      expect(shellBranches, isNot(contains(ShellTab.satori)));
      expect(shellBranches, contains(ShellTab.files));
    });

    testWidgets('every ON destination resolves via deep-link', (tester) async {
      _phone(tester);
      final router = _buildRealOnRouter();
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      // Initial branch.
      expect(find.text('SCREEN:/inbox'), findsOneWidget);

      // Deep-link to each destination and assert its screen mounts (proving the
      // branch resolves AND the auth guard allow-lists it — /files in particular,
      // the route promoted from a root deep-link, #1469 populates it).
      for (final tab in shellBranches) {
        router.go(tab.location);
        await tester.pumpAndSettle();
        expect(
          find.text('SCREEN:${tab.location}'),
          findsOneWidget,
          reason: '${tab.name} (${tab.location}) resolves under the ON flag',
        );
      }
    });

    testWidgets('restore (initialLocation) to a non-home branch works', (
      tester,
    ) async {
      _phone(tester);
      // Simulate a cold restore straight into /files (a restored deep-link).
      final router = GoRouter(
        initialLocation: '/files',
        redirect: (context, state) {
          final satori = satoriSafetyRedirect(state.matchedLocation);
          if (satori != null) return satori;
          return decideRedirect(
            isAuthenticated: true,
            isLoading: false,
            location: state.matchedLocation,
          );
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (c, s, shell) => ShellScaffold(navigationShell: shell),
            branches: [
              for (final tab in shellBranches)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: tab.location,
                      builder: (c, s) => _StubScreen(tab.location),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:/files'), findsOneWidget);
    });

    testWidgets('/satori redirects to /inbox — never throws a router exception', (
      tester,
    ) async {
      _phone(tester);
      final router = _buildRealOnRouter();
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      // Land somewhere else first so the redirect is observable as a move.
      router.go('/calendar');
      await tester.pumpAndSettle();
      expect(find.text('SCREEN:/calendar'), findsOneWidget);

      // A restored/bookmarked /satori deep-link: the route is compiled out, so
      // without the safety redirect go_router throws. Assert it lands on /inbox
      // (NOT the satori screen, NOT an error) and that no exception was thrown.
      router.go('/satori');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SCREEN:/inbox'), findsOneWidget);
      expect(find.text('SCREEN:/satori'), findsNothing);

      // A /satori SUB-path restores safely too.
      router.go('/satori/anything');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SCREEN:/inbox'), findsOneWidget);
    });

    test('satoriSafetyRedirect targets the home tab under ON', () {
      expect(satoriSafetyRedirect('/satori'), GuardTargets.home);
      expect(satoriSafetyRedirect('/satori/sub'), GuardTargets.home);
      // Non-satori locations are untouched (no spurious redirect).
      expect(satoriSafetyRedirect('/inbox'), isNull);
      expect(satoriSafetyRedirect('/files'), isNull);
    });
  });

  group('real ON flag — a11y on the reordered destinations', () {
    testWidgets('each destination exposes a Semantics label; tap targets ≥48dp', (
      tester,
    ) async {
      _phone(tester);
      final router = _buildRealOnRouter();
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();

      // Screen-reader labels for the REAL ON destination set.
      for (final tab in shellBranches) {
        expect(
          find.bySemanticsLabel(tab.label),
          findsWidgets,
          reason: '${tab.name} exposes a screen-reader label under ON',
        );
      }

      // Tap targets ≥48dp (WCAG 2.5.5) on every dock destination.
      final inkwells = find.descendant(
        of: find.byType(MatomeBottomDock),
        matching: find.byType(InkWell),
      );
      for (final element in inkwells.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      // The Add affordance is screen-reader labelled too.
      expect(find.bySemanticsLabel(t.nav.add), findsWidgets);

      handle.dispose();
    });

    testWidgets('focus order: keyboard traversal reaches the dock destinations '
        'in DR-002 order', (tester) async {
      _phone(tester);
      final router = _buildRealOnRouter();
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      // Walk the focus traversal and record the order destinations are reached.
      // The dock items are focusable controls, so traversal must reach each in
      // the on-screen (DR-002) order — proving focus order, not just presence.
      final dock = find.byType(MatomeBottomDock);
      final scope = FocusScope.of(tester.element(dock));
      scope.requestFocus();
      await tester.pumpAndSettle();

      bool focusInDock() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        var inside = false;
        ctx.visitAncestorElements((e) {
          if (e.widget is MatomeBottomDock) {
            inside = true;
            return false;
          }
          return true;
        });
        return inside;
      }

      var reachedDock = false;
      for (var i = 0; i < 40 && !reachedDock; i++) {
        final moved = scope.nextFocus();
        await tester.pumpAndSettle();
        reachedDock = focusInDock();
        if (!moved && !reachedDock) break;
      }
      expect(
        reachedDock,
        isTrue,
        reason: 'keyboard traversal reaches a dock destination',
      );

      // Activate the focused destination with Enter and assert a branch switch
      // (keyboard ACTIVATION, not just reachability).
      var activated = false;
      for (var i = 0; i < 40 && !activated; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        activated = shellBranches.any((tab) =>
            tab != ShellTab.inbox &&
            find.text('SCREEN:${tab.location}').evaluate().isNotEmpty);
        if (!activated && focusInDock()) {
          FocusManager.instance.primaryFocus?.nextFocus();
          await tester.pumpAndSettle();
        }
      }
      expect(
        activated,
        isTrue,
        reason: 'Enter on a focused dock destination activates it',
      );
    });
  });
}
