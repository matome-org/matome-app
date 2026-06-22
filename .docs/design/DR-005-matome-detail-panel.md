# DR-005 - Matome detail panel (`MatomeDetailPanel` scaffolding)

> Status: **Accepted** | Date: 2026-06-22 | Task: #1458
> Source: `apps/flutter_widgetbook/lib/proposals/matome_letter_proposal.dart` (`MatomeDetailPanel` use case)
> Canonical widgets: `apps/flutter/lib/ui/matome_detail_panel.dart`
> (`MatomePanelSection`, `MatomePanelRow`, `MatomePanelAddRow`, `matomeItemIcon`, `matomeItemSyncChip`)
> Graduated in: #1458 (this); precedent for [DR-000](./DR-000-convergence-procedure.md)

## Problem

The owner-approved Widgetbook proposal `MatomeDetailPanel` carried a **sectioned**
Details-panel layout — labeled, divider-framed sections (Items · N → People · N →
Space → Notes → Share) with compact item rows, a per-item sync chip, accent
"Add …" rows, and an inline Notes "Edit" — as a **hand-built mock**. The live
matome detail screen (`matome_detail_screen.dart` → `_MatomeDetails`) drifted
from it: it still rendered an older composition (big thumbnail item cards, a
split "Add photo / Add file" header, a separate filing CTA), so the shipped app
did **not** match the approved layout the screenshots showed. The mock and the
screen were two diverging implementations of the same panel — the exact failure
[DR-000](./DR-000-convergence-procedure.md) was written to prevent.

## Decision: which widget is canonical

The **canonical** Details-panel structure is the public, presentation-only
scaffolding in **`apps/flutter/lib/ui/matome_detail_panel.dart`**, NOT the
proposal mock. It lives in `lib/ui` (design-system surface — source-guard exempt
and Widgetbook-importable) so there is exactly one implementation that BOTH the
live screen and the catalog render:

- **`MatomePanelSection`** — an uppercase, muted, letter-spaced label, an
  optional accent trailing action (e.g. Notes' "Edit"), the section body, and a
  bottom `Divider` that frames it from the next section (`showDivider: false` on
  the final section).
- **`MatomePanelRow`** — a compact item/contact row: leading type icon (or a
  custom `leading`, e.g. a thumbnail / avatar), a title with an optional muted
  meta line, and an optional trailing slot (sync chip + overflow).
- **`MatomePanelAddRow`** — the accent "Add …" affordance (leading `+` glyph +
  accent label), optionally tappable.
- **`matomeItemIcon(mediaType)`** — the per-row type glyph (image → image,
  document/meeting/text → description, else audio → mic).
- **`matomeItemSyncChip(item)`** — the **real** per-item sync chip: it reuses the
  shipped `MatomeSyncChip` (`lib/ui/app_card.dart`) with a single-item rollup
  (`cloud` / `onDevice`), so the chip vocabulary stays identical to the
  Matome-level rollup chip and the per-tile badge — **no mock `_SyncChip`** in
  the app path, no second sync chip (mirrors [DR-000](./DR-000-convergence-procedure.md)
  / the shared-atoms rule).

## The convergence delta (what changed vs the mock)

1. **The live `_MatomeDetails` now composes the canonical sections** wired to
   real data and callbacks: Items · N (compact `MatomePanelRow`s, per-item
   `matomeItemSyncChip`, doc icon via `matomeItemIcon`) → People · N (real
   contacts) → Space (real filing flow) → Notes (real edit flow) → Share
   (deferred). `_MatomeDetails` is the **single composition point** for BOTH the
   wide desktop side panel (`_DetailSidePanel`) AND the narrow "Show more" sheet
   — fixing it fixed both.

2. **The Widgetbook "Detail panel" use case renders the REAL scaffolding.** The
   proposal's `MatomeDetailPanel` no longer hand-builds the panel structure — it
   imports `package:matome_flutter/ui/matome_detail_panel.dart` and composes the
   same `MatomePanelSection` / `MatomePanelRow` / `MatomePanelAddRow` +
   `MatomeSyncChip` with **static sample data**. Per DR-000, only the sample data
   lives in the catalog; the structure lives once, in `lib/ui`. They can no
   longer drift.

## Deltas from the original proposal (deliberate, regression-forbidden)

The app keeps shipped features the proposal mock did not model — these are
**intentional** divergences from the static mock, not drift:

- **TWO Add affordances**, not the proposal's single "Add item": `matome-add-photo`
  (image, unconditional) AND `matome-add-file` (document import, #1449,
  feature-flag gated), both styled as `MatomePanelAddRow`.
- **Document support** (#1450): document rows show the description glyph
  (from `original_extension` / media type) and tap-route to the **document host**
  (`/recording/document/:id`), never the audio host; the doc count is intact.
- **Real per-item sync** via `matomeItemSyncChip` / `MatomeSyncChip` rollup, not
  the mock `_SyncChip`.
- **Real** contacts, Notes edit, File-into-space ("Refile") and the deferred
  Share ("Coming soon") flows.
- All existing **ValueKeys** are preserved (`matome-details`,
  `matome-detail-panel`, `matome-item-<id>`, `matome-image-<id>`,
  `matome-item-overflow/-delete/-sync-<id>`, `matome-add-photo/-file/-contact`,
  `matome-edit-notes`, `matome-share`, `matome-file-cta/-filed/-refile`,
  `matome-contacts`).

## Rejected alternatives

- **Keep the hand-built mock and re-skin the screen to match it by eye.**
  Rejected — that is precisely the drift DR-000 forbids; it would leave two
  diverging panels and a stale catalog story.
- **Delete the whole `matome_letter_proposal.dart` file.** Rejected — the file
  also hosts the `MatomeLetterCard` and `MatomeActionsMenu` use cases, which
  belong to **other** graduation tasks. Only the panel-structure mock was
  retired (collapsed into the real scaffolding); the remaining use cases stay
  until their own tasks converge them.

## Why this record exists

The convergence retired the hand-built panel mock. This record captures the
rationale (which widget is canonical + the convergence delta + the deliberate
deltas from the proposal) so it does not die with the thinned mock — the Scribe
gate of [DR-000](./DR-000-convergence-procedure.md).
