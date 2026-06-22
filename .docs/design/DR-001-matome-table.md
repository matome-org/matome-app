# DR-001 - Matome table view (`MatomeTable`)

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459
> Source: `apps/flutter_widgetbook/lib/proposals/matome_table_proposal.dart`
> Public widget: `MatomeTable` | Graduates in: #1463 (widget), #1468 (view toggle)

## Problem

The matome list ships today as **cards** (the "letter" list, ADR-0005). Cards
answer *"what is this matome about"* well, but they can't **scan, sort, or act
on many matomes at once**. There is no way to sort by recency or item count, no
multi-select, no bulk move/archive/delete. As the number of matomes grows, the
card list stops scaling.

`MatomeTable` is the columnar counterpart: a header row of sortable columns,
per-row selection with a bulk-action bar, a per-row overflow menu, and aligned
data cells. It becomes a **user-selectable view alongside cards** (a config
toggle, owned by #1468), not a replacement.

## Key decisions

- **Sortable columns.** Columns: Title+summary peek · When · Items
  (audio/image/doc mix) · People · Space · Sync. Sortable keys:
  Title, When, Items, People. "When" defaults to most-recent-first.
- **Selection model: select-all (tristate header checkbox) + per-row
  selection.** Selection is keyed by a stable row `id` that survives sort and
  removal.
- **Bulk-action bar** with **move / archive / delete**, where destructive ops
  carry a **CONFIRM dialog + UNDO**. Undo restores removed rows at their
  original master-list index (so order is preserved) and restores the prior
  selection. The bar floats *above* the header so column labels and the current
  sort stay visible while a selection is active.
- **Per-row overflow menu** (Open / Move to space / Archive / Delete) — a real
  affordance, not a decorative icon.
- **Keyboard focus + `x`-to-select.** Rows are Tab-reachable with a visible
  focus ring; Enter/Space opens, `x` toggles selection — no reliance on
  hover/mouse.
- **Right-aligned numerics** (When, Items, People) so columns of numbers scan.
- **Compact rows on mobile (< 720dp).** Below the breakpoint each matome folds
  into a condensed two-line row + a compact sort selector. Selection, bulk bar,
  per-row menu, and undo all survive both layouts (this is #82 single-codebase:
  responsive, not amputated).

## Space chip and Inbox

In the table, the Space cell shows a filled pill: a folder icon + the space
name, or — when `space == null` — the **"Inbox"** label. This is the same
per-dimension absence semantics defined in [DR-003](./DR-003-files.md): *Inbox*
means "no space relation". (The matome table does not surface an Unfiled state
because a matome *is* the filing unit; Unfiled is a file-level concept.)

## Rejected alternatives

- **A denser card list** (smaller cards, more per screen). Rejected: it raises
  density but still gives no columnar scan, no sortable columns, and no
  multi-select — it does not solve the actual problem.
