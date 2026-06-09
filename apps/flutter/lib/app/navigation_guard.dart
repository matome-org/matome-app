/// Pure auth-redirect decision for the go_router `redirect` callback.
///
/// Direct port of `apps/mobile/app/navigationGuard.ts` (`decideRedirect`),
/// kept dependency-free (no Flutter, no go_router) so it can be unit-tested in
/// isolation. Given the resolved auth state and the current location, returns
/// the path to redirect to, or `null` when the current location is already
/// valid (a stable fixpoint — no redirect, no loop).
///
/// Behaviour (mirrors the RN guard):
///   - while loading            → null (guard waits, no decision yet)
///   - authed, not in tabs and
///     not recording            → '/inbox' (the first tab)
///   - authed, recording        → null
///   - unauthed, in tabs or
///     in recording             → '/' (welcome)
///   - otherwise                → null
library;

/// Redirect targets the guard may emit.
abstract final class GuardTargets {
  /// Welcome / unauthenticated landing route.
  static const welcome = '/';

  /// First authenticated tab (Inbox), the RN equivalent of the tabs group.
  static const home = '/inbox';
}

/// Route prefixes that belong to the authenticated shell.
const _tabPrefixes = ['/inbox', '/calendar', '/spaces', '/satori'];
const _recordingPrefix = '/recording';

bool _hasPrefix(String location, String prefix) =>
    location == prefix || location.startsWith('$prefix/');

String? decideRedirect({
  required bool isAuthenticated,
  required bool isLoading,
  required String location,
}) {
  if (isLoading) return null;

  final inTabs = _tabPrefixes.any((p) => _hasPrefix(location, p));
  final inRecording = _hasPrefix(location, _recordingPrefix);

  if (isAuthenticated && !inTabs && !inRecording) {
    return GuardTargets.home;
  }
  if (!isAuthenticated && (inTabs || inRecording)) {
    return GuardTargets.welcome;
  }
  return null;
}
