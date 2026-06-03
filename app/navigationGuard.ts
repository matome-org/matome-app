/**
 * Pure auth-redirect decision for the NavigationGuard in `app/_layout.tsx`.
 *
 * Lives in its own dependency-free module (no React, no react-native,
 * no expo-router, no UI-Kitten) so it can be unit-tested directly without
 * dragging the full layout module — and its native deps (reanimated, etc.) —
 * into the test runner.
 *
 * Given the resolved auth state and the current route segments, returns the
 * route to `router.replace(...)` to, or `null` when the current location is
 * already valid (a stable fixpoint — no redirect, no loop).
 *
 * `segments` are expo-router path segments only: the query string (e.g.
 * `?hasDraft=1` on `/recording?hasDraft=1`) is NOT part of segments, so the
 * comparison against `'recording'` keys off the path segment alone.
 *
 * Behaviour is identical to the previous inline effect logic in _layout.tsx:
 *   - while loading        → `null` (guard waits, no decision yet)
 *   - authed, not in tabs
 *     and not recording      → `/(tabs)/explore/explore`
 *   - authed, recording      → `null`
 *   - unauthed, in (tabs)
 *     or in recording      → `/`
 *   - otherwise            → `null`
 */
/**
 * The concrete redirect targets the guard may replace to. Kept as a literal
 * union (not a bare `string`) so the values remain assignable to
 * expo-router's typed `Href` at the `router.replace(...)` call site without
 * importing expo-router into this dependency-free module.
 */
export type RedirectTarget = '/' | '/(tabs)/explore/explore';

export const decideRedirect = ({
  isAuthenticated,
  isLoading,
  segments,
}: {
  isAuthenticated: boolean;
  isLoading: boolean;
  segments: string[];
}): RedirectTarget | null => {
  if (isLoading) return null;

  const inTabsGroup = segments[0] === '(tabs)';
  const inRecording = segments[0] === 'recording';

  if (isAuthenticated && !inTabsGroup && !inRecording) {
    return '/(tabs)/explore/explore';
  }
  if (!isAuthenticated && (inTabsGroup || inRecording)) {
    return '/';
  }
  return null;
};
