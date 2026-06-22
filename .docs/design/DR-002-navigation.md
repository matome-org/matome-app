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
