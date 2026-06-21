# ADR-0005 - Matome detail as a "letter", and the forthcoming responsive side panel

> Status: **Accepted** | Date: 2026-06-20 | Plan: `matome-centric-pivot`
> (W7 lands the letter detail; the responsive side panel is **deferred to W8**)

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

### The responsive side panel (W8, deferred)
- On a **wide viewport**, "Show more" is replaced by a **persistent side panel**
  (`MatomeDetailPanel`): the letter stays on the left as the reading column, the
  panel holds the management surface on the right (the same section order the
  inline reveal uses — Items, People, Space, Notes, Share).
- The breakpoint is a **layout choice, not a route change**: the same
  `/matome/:id` route renders either the stacked letter (narrow) or the
  letter+panel (wide). The detail does **not** get its own nested navigator;
  the existing go_router top-level route is reused. The mobile-first inline
  reveal and the wide side panel are two presentations of one screen.
- W8 owns the concrete breakpoint value and whether the panel is hosted via a
  `LayoutBuilder`/`MediaQuery` split inside the screen or a `StatefulShell`
  branch; this ADR fixes only that it is a **breakpoint-driven layout swap on
  the same route**, so no deep-link or back-stack semantics change between
  widths.

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
- W8 inherits a fixed navigation model: **one route, breakpoint-driven layout**.
  It does not need to introduce a nested navigator or change deep-link
  semantics; it only chooses the breakpoint and the panel host.
- The letter format is shared in spirit with the reworked matome **list** row
  (W6): both are tiny envelopes — title + a summary preview + a dense meta strip
  with the one normalized sync vocabulary.
