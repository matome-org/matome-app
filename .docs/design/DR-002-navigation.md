# DR-002 - Primary navigation (`MatomeBottomDock` + `MatomeSidebar`)

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459
> Source: `apps/flutter_widgetbook/lib/proposals/matome_nav_proposal.dart`
> Public widgets: `MatomeBottomDock` (mobile), `MatomeSidebar` (desktop)
> Graduates in: #1466 (widgets), #1467 (shell cutover into `apps/flutter/lib/app/shell_scaffold.dart`)

## Problem

We ship a **dated, off-the-shelf navigation**: a notched `BottomAppBar` with a
center-docked mic FAB on mobile, and Material's default `NavigationRail` on
desktop. It is generic, the notch cut-out is a tired pattern, and the capture
action is mic-only — it does not reflect that you can add audio, photos, files,
*or* a meeting recording to a matome.

This proposal replaces both with one branded, warm-editorial navigation
language.

## Key decisions

### Destinations and order

- Visible destinations, in order: **inbox · calendar · files · contacts ·
  spaces**.
- **Satori is HIDDEN for now.** It is kept in the `NavDest` enum and the
  `_specs` map (icon/label specs) but excluded from the visible destination
  list, so it can be re-enabled later **without rework**.

### Mobile — `MatomeBottomDock`

- A **floating rounded dock** (not a full-width bar, not notched).
- The **active destination expands into a gold-tinted label pill**; the others
  stay **icon-only**. The label animates in/out of layout so the dock stays
  compact.
- Capture is a **clean, OFFSET gold FAB** sitting just above the dock on the
  trailing side — **no notch cut-out, no center-docked hack.**

### Desktop — `MatomeSidebar`

- A **branded left sidebar**: the **wordmark** ("matome", display type), a
  prominent **Add** button with a caret, the destination list, and a footer
  with **Settings + the account avatar**.
- The active destination's state is a **soft rounded tint**. Explicitly **NO
  colored left-stripe** — that is a banned, over-templated AI tell we
  deliberately avoid.
- Two widths: **expanded** (wordmark + labels + full Add button) and
  **collapsed icon-only rail** (animated between).

### The hero action is "Add", not record-only

- Both the mobile FAB and the desktop sidebar button are an **"Add"** action
  (icon `+`), **not a record-only mic button**.
- Tapping it opens a **menu** with: **Record audio · Add photo · Add file ·
  Record meeting.** This is the single entry point for everything you can bring
  into a matome.

## Rejected alternatives

- **Keeping the notch FAB** (the center-docked mic on a notched bar). Rejected:
  dated pattern; the notch is the visual tell we are removing.
- **A mic-only capture button.** Rejected: capture is broader than audio (photo
  / file / meeting), so a record-only button mis-states the model and hides the
  other entry points.

## Rollout / enablement (#1474 — the cutover)

> Status update: **Enabled by default** | Date: 2026-06-22 | Task: #1474

The graduated shell shipped behind `FeatureFlags.newNavShell` (default OFF) in
#1467. #1474 flips the **default to ON** — the highest-blast-radius change in the
migration (it changes navigation for every user).

### What "ON" changes (vs. the legacy shell)

- **Mobile**: floating `MatomeBottomDock` + offset gold `MatomeAddFab` replace
  the notched `BottomAppBar` + center-docked mic FAB.
- **Desktop**: branded `MatomeSidebar` (expand/collapse) replaces Material's
  `NavigationRail`.
- **Destinations** reorder to **inbox · calendar · files · contacts · spaces**.
- **`/files`** is promoted from a root deep-link route to a **stateful shell
  branch** (populated now that owner-reconcile #1469 landed).
- **Satori** is removed as a destination and its **`/satori` route is compiled
  out**. A restored/bookmarked `/satori` deep-link **redirects to `/inbox`**
  (`satoriSafetyRedirect` in `lib/app/router.dart`) — it never throws a
  go_router "no routes for location" exception.
- The dock/sidebar **Add** menu opens the 4 real flows: Record audio · Add
  photo · Add file · Record meeting.

### How both flag states stay graded

`ff.newNavShell` is a compile-time `const`, so once the default is ON a plain
`flutter test` only exercises the NEW shell. `mise run flutter-design-system-check`
therefore runs the nav suite **twice** —
`--dart-define=ff.newNavShell=true` and `=false` — so both realities are graded.
Flag-state-specific tests self-skip under the wrong build:

- `test/shell_test.dart` (legacy chrome) + `settings_satori_test.dart`'s
  Satori-tab test → run only under **OFF**.
- `test/app/new_nav_router_test.dart` (real ON router + a11y) → runs only under
  **ON**.

### Rollback (single step)

Rollback is **one `git revert` of the flag-flip commit** (the standalone
`feat(nav): turn the graduated nav shell ON by default` commit, which touches
only `feature_flags.dart`), restoring `defaultValue: false`. No other code
change is required — the legacy shell, its routes, and `/files`-as-deep-link all
return. For a build-time-only rollback without a revert, ship
`--dart-define=ff.newNavShell=false`. The dual-flag gate guarantees the OFF path
is still green at the moment of rollback.

### Manual-verify checklist (not golden-provable end-to-end)

Run the app once per form factor (`mise run flutter-linux` desktop; a phone-size
window / device for mobile) and confirm:

**Mobile (narrow):**
- [ ] Floating `MatomeBottomDock` renders (rounded, NOT a notched full-width
      bar); no center-docked mic FAB.
- [ ] Active destination expands into the gold label pill; inactive ones are
      icon-only.
- [ ] Offset gold **Add** FAB sits above the dock (trailing side).
- [ ] Destinations appear in order: inbox · calendar · files · contacts ·
      spaces. **Satori is absent.**
- [ ] Tapping each destination switches the branch and preserves its stack.
- [ ] Bottom content of a long list (e.g. Settings "Sign out") is reachable —
      not hidden under the floating dock.

**Desktop (wide):**
- [ ] Branded `MatomeSidebar` renders (wordmark, Add button, destination list,
      Settings + avatar footer); NOT the Material `NavigationRail`.
- [ ] Sidebar expand ↔ collapse toggle works (labels + wordmark animate).
- [ ] Active destination uses the soft rounded tint (NO colored left-stripe).

**Both:**
- [ ] **Add** menu opens the 4 options: Record audio · Add photo · Add file ·
      Record meeting, and each routes to its real flow.
- [ ] `/files` is reachable as a destination AND is **populated** (owner-scoped
      rows, #1469) — not empty.
- [ ] Navigating to `/satori` (e.g. paste the URL / restore a bookmark) lands on
      `/inbox` with **no error page / no exception**.
