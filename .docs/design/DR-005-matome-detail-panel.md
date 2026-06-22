# DR-005 - Matome detail panel (`MatomeDetailPanel` scaffolding)

> Status: **Accepted** | Date: 2026-06-22 | Task: #1458, reconciled #1475
> Source: `apps/flutter_widgetbook/lib/proposals/matome_letter_proposal.dart` (`MatomeDetailPanel` use case — restored as the alignment spec in #1475, re-deleted after the green repoint)
> Canonical widgets: `apps/flutter/lib/ui/matome_detail_panel.dart`
> (`MatomePanelSection`, `MatomePanelRow`, `MatomePanelAddRow`, `matomeItemIcon`, `matomeItemSyncChip`)
> Graduated in: #1458; reconciled to the approved proposal in #1475; precedent for [DR-000](./DR-000-convergence-procedure.md)

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

## Reconciliation to the approved proposal (#1475)

The #1458 graduation kept several **visual** divergences from the approved
proposal as "deliberate deltas". The owner rejected that: the shipped panel
visibly differed from the screenshot they approved, and #1470 (commit `7a009c4`)
compounded it by deleting the approval reference. #1475 restores the proposal as
the alignment spec and brings the live `_MatomeDetails` (the SINGLE composition
for BOTH the desktop side panel AND the mobile "Show more" sheet) back to the
approved **layout**, keeping every real **function** ("proposal visual + real
functions"):

1. **One "Add item" accent row** (`matome-add-item`), not the old split
   "Add photo / Add file" header. It opens an anchored menu → **Add photo**
   (`matome-add-photo`, image, unconditional) + **Add file** (`matome-add-file`,
   document import #1449, feature-flag gated; dropped from the menu when off).
   Both real import flows are preserved behind the single affordance.
2. **No inline per-item "…"** on the item row — the row is now the clean
   approved shape: leading type icon + title + meta (time/duration) + trailing
   real `matomeItemSyncChip`, nothing else. **Per-item-action relocation
   decision:** Delete moves to a row **long-press → actions bottom sheet**
   (`matome-item-overflow-<id>` → `matome-item-delete-<id>` keys preserved on the
   sheet). Long-press is the cross-surface affordance — it fires on mobile touch
   AND on desktop secondary-click / press-hold, so the one path serves both the
   mobile sheet and the desktop side panel without a hover-only reveal a touch
   laptop or a test driver can't reach. Tap still opens the Item.
3. **"Add person"** (`matome-add-contact`), the proposal's slang, not "Add contact".
4. **Notes trailing "Edit"** (`matome-edit-notes`), the proposal's slang, not
   "Edit notes".
5. **Share** matches the proposal's plain row (`ios_share` glyph + "Share" in the
   primary colour, `matome-share`). The deferred state stays honest via a
   "Coming soon" tooltip + a11y hint and no tap handler — not a dimmed inline
   "· Coming soon" row.
6. **Space / "Refile"** was already the correct inbox-vs-filed state — left as-is.

Regression-forbidden features kept intact through the reconciliation: document
add-file flow + doc icon (`matomeItemIcon`) + doc-host routing
(`/recording/document/:id`, #1450); the real per-item `MatomeSyncChip` rollup
(not the mock `_SyncChip`); real contacts, Notes edit, File-into-space; Share
deferred. All existing **ValueKeys** are preserved (`matome-details`,
`matome-detail-panel`, `matome-item-<id>`, `matome-image-<id>`,
`matome-item-overflow/-delete/-sync-<id>`, `matome-add-item`,
`matome-add-photo/-file/-contact`, `matome-edit-notes`, `matome-share`,
`matome-file-cta/-filed/-refile`, `matome-contacts`); `MatomePanelRow` gained an
`onLongPress` hook for the relocated per-item actions.

### Convergence procedure followed (DR-000, done right)

1. Restored the approved `matome_letter_proposal.dart` from `7a009c4~1` as the
   alignment spec.
2. Aligned the live widget to it (the six points above), updating the widget
   tests in lockstep.
3. Re-pointed the "[Proposals]/Matome detail" use-cases at the restored proposal
   (which composes the real `lib/ui` scaffolding) and verified GREEN — widgetbook
   smoke + the "matome detail panel sections" golden of the matched panel.
4. ONLY THEN re-deleted `matome_letter_proposal.dart` in its own commit, after
   the green repoint, with this record updated alongside it (the Scribe gate).

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
