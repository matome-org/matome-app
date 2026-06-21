# ADR-0005 - Matome detail as a "letter", and the responsive side panel

> Status: **Accepted** | Date: 2026-06-20 (amended 2026-06-21, W8) | Plan: `matome-centric-pivot`
> (W7 landed the letter detail; W8 lands the responsive side panel and fixes the
> breakpoint — see "The responsive side panel (W8)" below)

## Context

The matome detail screen (`/matome/:id`) had grown into a long, flat,
section-stacked page: header, filing CTA, recordings list, summary, notes,
deferred actions — each always-on, each competing for the top of the fold. The
aggregated summary (ADR-0003), which is the thing a user actually wants to read
first, sat *below* the recordings list and was only reachable by scrolling.

The approved Widgetbook proposal (`proposals/matome_letter_proposal.dart`,
`MatomeLetterCard` + `MatomeDetailPanel`) reframes the screen as a **letter**: a
calm, read-first card whose body is the summary, with the supporting detail
summarized to one line each and the full management surface tucked behind a
"Show more" affordance. On wide viewports the proposal pairs the letter with a
persistent **detail side panel** rather than an inline expansion.

W7 (#1413) is mobile-first and ships only the letter. W8 adds the responsive
side panel. This ADR records the navigation/layout decision now so W8's
breakpoint and shell choice has a decision record to build against, and so the
W7 rewrite leaves a deliberate seam rather than an accident.

## Decision

### The letter detail (W7, shipped)
- The detail reads top-to-bottom like a letter: **title · date · the aggregated
  summary as the read-first hero · a divider · summarized one-line lists**
  (files count+preview, people count+preview, filing space-or-CTA) **· an
  always-visible sync chip · a "Show more" affordance**.
- The **summary is the hero** — promoted above the item list, visible without
  scrolling.
- The **sync chip is always visible** (the W1 / #1407 normalized-vocabulary
  decision: `MatomeSyncChip` is rollup-driven and shown for filed *and* inbox
  matomes). It keeps the `matome-on-device` ValueKey, whose *meaning* changed in
  W1 from an inbox-only hint to the always-on rollup chip.
- The summarized lists are previews, not the management surface. The full
  detail — the child-Items list (with add-photo / remove), the contacts slot
  (attach / detach), editable notes, and the deferred Share row — lives behind
  **"Show more"**, revealed **inline, expanded in place** on mobile.
- Secondary / rare / destructive actions (rename, edit date & time, regenerate
  summary, move to space, copy summary, archive) stay in the header `…`
  overflow (`MatomeActionsMenu`, W4). Primary inline actions (file, add item,
  add contact, edit notes) live in the card / detail, not the menu.

### The responsive side panel (W8, shipped #1414)
- On a **wide viewport**, "Show more" is replaced by a **persistent side panel**:
  the letter stays on the left as the reading column (narrowed, clamped to its
  720px reading width), the panel holds the management surface on the right (the
  same `_MatomeDetails` composition the inline reveal uses — Items, People,
  Space, Notes, Share). The panel is always visible; nothing is behind a tap.
- The breakpoint is a **layout choice, not a route change**: the same
  `/matome/:id` route renders either the stacked letter (narrow) or the
  letter+panel (wide). The detail does **not** get its own nested navigator;
  the existing go_router top-level route is reused. The mobile-first inline
  reveal and the wide side panel are two presentations of one screen.

#### Chosen breakpoint: **900 px** (`_matomeWidePanelBreakpoint`)
- **Value**: available width `>= 900` → persistent drawer; `< 900` → the mobile
  "Show more" sheet. The split is hosted by a **`LayoutBuilder`** inside
  `_MatomeDetailBody` (it reads `constraints.maxWidth`), not a `StatefulShell`
  branch — the shell already adapts its chrome, and a `LayoutBuilder` keeps the
  decision local to the screen and reacts to *available* width (so the panel
  respects the navigation rail on desktop) rather than raw device width.
- **Rationale**:
  - The reading letter is clamped to **720 px** and the panel is a fixed
    **360 px**. 720 + 360 + the inter-column gutter only fits comfortably above
    ~900 px; below it the panel would crush the letter, so the single-column
    sheet stays. 900 is the smallest width that gives both columns room.
  - It sits **above the 800 px default widget-test viewport**, so the existing
    detail/contacts/triage/archive/edit/remove suites — which tap
    `matome-show-more` and scroll to the inline keys — keep exercising the
    proven sheet presentation untouched. The new breakpoint suite pumps the
    screen at 420 px (sheet) and 1200 px (drawer) to verify both sides.
  - 900 maps to desktop and large tablet **landscape**; phones and tablet
    **portrait** stay on the one-column mobile sheet, matching where the
    summary-first letter reads best.
- **Seam resolution**: the W7 boolean (`_expanded` + `matome-show-more`) is now
  gated behind a `showDetailToggle` flag on `_MatomeLetterCard`. On wide the
  flag is `false`, so neither the toggle nor the inline `_MatomeDetails` is
  built — the panel is the *only* host (no duplicate keys). On narrow the flag
  is `true` and the W7 behaviour is unchanged.

### The seam (how W7 hands off to W8)
- The "Show more" reveal is gated by a single boolean in `_MatomeLetterCard`
  and the detailed sections are extracted into one reusable `_MatomeDetails`
  composition. W8 swaps the boolean-gated inline expansion for the
  breakpoint-driven side panel without touching the detail sections themselves.
- The seam is marked in code with a `W8 SEAM` comment on the state field and on
  the card doc-comment, so the swap point is unambiguous.

## Consequences

- The summary becomes the primary content of the screen; a matome with no
  summary now leads with the empty-summary state rather than burying it.
- Tap targets the test suite and the app rely on are **preserved by ValueKey**
  through the rewrite; the detail keys move behind "Show more", so callers
  (and tests) must reveal details before reaching them. A characterization test
  pins this contract.
- W8 honoured the fixed navigation model: **one route, breakpoint-driven
  layout**. No nested navigator and no deep-link change — the only new knobs are
  the 900 px breakpoint and the `LayoutBuilder` panel host inside the screen.
- The letter format is shared in spirit with the reworked matome **list** row
  (W6): both are tiny envelopes — title + a summary preview + a dense meta strip
  with the one normalized sync vocabulary.
- An **archived** matome stays openable on this same `/matome/:id` letter (the
  detail DAO deliberately does not filter archived rows). The letter now leads
  with an **archived banner + inline Restore** (`_ArchivedBanner`) above the
  header, so the archived state is explicit rather than silent. Archive/restore
  are **local-first and offline-first** (#1431): the Drift write is
  authoritative and the Core leg is best-effort, reconciling on the next pull —
  archiving a synced matome no longer requires connectivity (see
  `.docs/matome-lifecycle.md` §9).
