import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/app/navigation_guard.dart';

/// Mirrors the RN `navigationGuard.test` cases for `decideRedirect`.
void main() {
  group('decideRedirect', () {
    test('returns null while loading (no decision yet)', () {
      expect(
        decideRedirect(isAuthenticated: false, isLoading: true, location: '/'),
        isNull,
      );
      expect(
        decideRedirect(
            isAuthenticated: true, isLoading: true, location: '/inbox'),
        isNull,
      );
    });

    test('authed outside tabs/recording redirects to home (/inbox)', () {
      expect(
        decideRedirect(
            isAuthenticated: true, isLoading: false, location: '/'),
        GuardTargets.home,
      );
    });

    test('authed already in a tab stays put', () {
      for (final loc in [
        '/inbox',
        '/calendar',
        '/spaces',
        '/satori',
        '/contacts',
      ]) {
        expect(
          decideRedirect(
              isAuthenticated: true, isLoading: false, location: loc),
          isNull,
          reason: loc,
        );
      }
    });

    // Regression: the matome-centric pivot added /contacts (#1374) and the
    // matome hub /matome/:id (#1378) as authenticated routes. The guard's
    // allow-list was not updated, so it bounced them to /inbox — tapping
    // Contacts (or navigating to a matome) silently went nowhere.
    test('authed on pivot routes (/contacts, /matome/:id) stays put', () {
      for (final loc in ['/contacts', '/matome/mat_local_abc', '/matome/42']) {
        expect(
          decideRedirect(
              isAuthenticated: true, isLoading: false, location: loc),
          isNull,
          reason: loc,
        );
      }
    });

    test('authed in nested tab stack stays put', () {
      expect(
        decideRedirect(
            isAuthenticated: true,
            isLoading: false,
            location: '/inbox/settings'),
        isNull,
      );
      expect(
        decideRedirect(
            isAuthenticated: true, isLoading: false, location: '/spaces/42'),
        isNull,
      );
    });

    test('authed in recording modal stays put', () {
      expect(
        decideRedirect(
            isAuthenticated: true,
            isLoading: false,
            location: '/recording'),
        isNull,
      );
    });

    test('unauthed in tabs or recording redirects to welcome (/)', () {
      for (final loc in ['/inbox', '/calendar/9', '/spaces', '/recording']) {
        expect(
          decideRedirect(
              isAuthenticated: false, isLoading: false, location: loc),
          GuardTargets.welcome,
          reason: loc,
        );
      }
    });

    test('unauthed on welcome stays put', () {
      expect(
        decideRedirect(
            isAuthenticated: false, isLoading: false, location: '/'),
        isNull,
      );
    });

    test('unauthed on login/signup stays put (auth screens are reachable)', () {
      for (final loc in ['/login', '/signup']) {
        expect(
          decideRedirect(
              isAuthenticated: false, isLoading: false, location: loc),
          isNull,
          reason: loc,
        );
      }
    });

    test('authed on login/signup redirects into the tabs', () {
      for (final loc in ['/login', '/signup']) {
        expect(
          decideRedirect(
              isAuthenticated: true, isLoading: false, location: loc),
          GuardTargets.home,
          reason: loc,
        );
      }
    });
  });
}
