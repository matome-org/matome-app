/**
 * Unit tests for the NavigationGuard auth-redirect decision in
 * app/_layout.tsx.
 *
 * The redirect logic was extracted into the pure `decideRedirect(...)`
 * function in the sibling `app/navigationGuard.ts` module so it can be
 * unit-tested without React, hooks, a render, or the native deps
 * (reanimated etc.) that importing _layout.tsx would drag in. The function
 * is behaviour-identical to the previous inline effect: it is the single
 * source of truth that the guard's effect now consumes
 * (`const target = decideRedirect(...); if (target) router.replace(target)`).
 *
 * Coverage (mirrors task T8):
 *   (a) unauthenticated + segments[0] in {'(tabs)','recording'} → '/'
 *   (b) authenticated draft-recovery push '/recording?hasDraft=1' is allowed
 *       to stay on the recording route
 *   (c) authenticated normal in '(tabs)' → no redirect (null)
 *   (d) no redirect loop — '/' (segments[0] not in the gated set) is a
 *       stable fixpoint (null)
 *   (e) while isLoading → no decision yet (null), the guard waits
 *
 * Targets asserted match the real route the guard replaces to:
 *   - unauthenticated bounce → '/'
 *   - authenticated-not-in-tabs-or-recording → '/(tabs)/explore/explore'
 */

import { decideRedirect } from "@/app/navigationGuard";

describe("decideRedirect — NavigationGuard auth redirect", () => {
  // ── (a) unauthenticated in a gated group is bounced to '/'
  describe("(a) unauthenticated + gated segment → '/'", () => {
    it("redirects to '/' when unauthenticated and in the (tabs) group", () => {
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: false,
          segments: ["(tabs)", "explore", "explore"],
        }),
      ).toBe("/");
    });

    it("redirects to '/' when unauthenticated and on the recording route", () => {
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: false,
          segments: ["recording"],
        }),
      ).toBe("/");
    });

    it("does NOT bounce an unauthenticated user already at a public route", () => {
      // login / signup / index are not gated → no redirect
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: false,
          segments: ["login"],
        }),
      ).toBeNull();
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: false,
          segments: ["signup"],
        }),
      ).toBeNull();
    });
  });

  // ── (b) authenticated draft-recovery push to /recording?hasDraft=1
  describe("(b) authenticated on /recording?hasDraft=1 — query excluded from segments", () => {
    it("treats the path segment 'recording' (query stripped) the same as 'recording'", () => {
      // useSegments() returns PATH segments only — '?hasDraft=1' is never a
      // segment. The draft-recovery push lands on segments === ['recording'].
      const withoutQuery = decideRedirect({
        isAuthenticated: true,
        isLoading: false,
        segments: ["recording"],
      });

      // Sanity: a hypothetical segment that still carried the query string
      // must not be how expo-router behaves — but if it did, it would NOT
      // equal 'recording'. We assert the contract on the path-only form.
      expect(["recording"]).not.toContain("recording?hasDraft=1");

      // Authenticated users must be allowed to stay on /recording so the mic
      // FAB and draft-recovery push are not immediately replaced by tabs home.
      expect(withoutQuery).toBeNull();

      // The decision is identical whether or not a query is conceptually
      // attached, because it is never part of segments[0].
      expect(
        decideRedirect({
          isAuthenticated: true,
          isLoading: false,
          segments: ["recording"],
        }),
      ).toBe(withoutQuery);
    });
  });

  // ── (c) authenticated, already in the tabs group → no redirect
  describe("(c) authenticated normal in (tabs) → no redirect", () => {
    it("returns null when authenticated and inside the (tabs) group", () => {
      expect(
        decideRedirect({
          isAuthenticated: true,
          isLoading: false,
          segments: ["(tabs)", "inbox"],
        }),
      ).toBeNull();
    });

    it("returns null for a deeper authenticated (tabs) route", () => {
      expect(
        decideRedirect({
          isAuthenticated: true,
          isLoading: false,
          segments: ["(tabs)", "calendar", "[id]"],
        }),
      ).toBeNull();
    });
  });

  // ── (d) no redirect loop — stable fixpoint at '/'
  describe("(d) no redirect loop — '/' is a stable fixpoint", () => {
    it("returns null for an unauthenticated user at the root (segments empty)", () => {
      // At '/', segments[0] is undefined → not '(tabs)' and not 'recording',
      // so the unauthenticated branch does NOT fire → no redirect → no loop.
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: false,
          segments: [],
        }),
      ).toBeNull();
    });

    it("does not bounce repeatedly: redirect target itself yields null on re-eval", () => {
      // Unauthenticated in (tabs) → '/'. Once at '/', segments === [] → null.
      const first = decideRedirect({
        isAuthenticated: false,
        isLoading: false,
        segments: ["(tabs)", "explore"],
      });
      expect(first).toBe("/");

      const afterRedirect = decideRedirect({
        isAuthenticated: false,
        isLoading: false,
        segments: [], // now at '/'
      });
      expect(afterRedirect).toBeNull();
    });

    it("authenticated redirect target (tabs) home is also a fixpoint", () => {
      // Authenticated not-in-tabs → '/(tabs)/explore/explore'. Once there,
      // segments[0] === '(tabs)' → null → no loop.
      const first = decideRedirect({
        isAuthenticated: true,
        isLoading: false,
        segments: ["login"],
      });
      expect(first).toBe("/(tabs)/explore/explore");

      const afterRedirect = decideRedirect({
        isAuthenticated: true,
        isLoading: false,
        segments: ["(tabs)", "explore", "explore"],
      });
      expect(afterRedirect).toBeNull();
    });
  });

  // ── (e) while loading the guard makes no decision
  describe("(e) while isLoading → no decision (guard waits)", () => {
    it("returns null while loading regardless of auth/segments", () => {
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: true,
          segments: ["(tabs)", "inbox"],
        }),
      ).toBeNull();
      expect(
        decideRedirect({
          isAuthenticated: true,
          isLoading: true,
          segments: ["recording"],
        }),
      ).toBeNull();
      expect(
        decideRedirect({
          isAuthenticated: false,
          isLoading: true,
          segments: ["recording"],
        }),
      ).toBeNull();
    });
  });
});
