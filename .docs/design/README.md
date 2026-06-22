# Graduation design decision-records

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459 | Branch: `migration/flutter-lab`

This directory captures the design rationale from the graduation design session
**before any Widgetbook proposal mock is thinned or deleted**, so an implementer
who was not in the session can build the data model and the widgets correctly.

These records sit alongside the formal ADRs in [`../decisions/`](../decisions/)
(notably [ADR-0005](../decisions/ADR-0005-matome-detail-letter-and-panel.md),
the FileView/letter precedent from #1458). The ADRs record architecture-level
decisions; these design records are proposal-scoped and trace each downstream
graduation task back to the owner-approved decision it implements.

## The proposals being graduated

> **[Proposals] → [Catalog] migration complete (#1470).** Every proposal mock
> under `apps/flutter_widgetbook/lib/proposals/` has graduated into a real
> widget and been deleted; the directory and the Widgetbook `[Proposals]`
> section no longer exist. The "Graduated widget" column below now points at the
> shipped widget each proposal became — there are no live source mocks left.

Each row was a static, provider-free Widgetbook mockup that carried the
production interaction model so the host screen became a thin wiring layer over
the now-shipped widget.

| Decision record | Graduated widget(s) (was a `proposals/*` mock) |
| --- | --- |
| [DR-001 Matome table](./DR-001-matome-table.md) | `MatomeTable` (`apps/flutter/lib/features/matome/widgets/matome_table.dart`) |
| [DR-002 Navigation](./DR-002-navigation.md) | `MatomeBottomDock`, `MatomeSidebar` (`apps/flutter/lib/features/shell/widgets/matome_nav.dart`) |
| [DR-003 Files](./DR-003-files.md) | `FilesGrid`, `FilesTable` (`apps/flutter/lib/features/files/widgets/files_grid.dart`, `.../files_table.dart`) |
| [DR-004 Contact detail](./DR-004-contact-detail.md) | `ContactDetail` (`apps/flutter/lib/features/contacts/widgets/contact_detail.dart`) |
| [DR-005 Matome detail (letter + panel)](./DR-005-matome-detail-panel.md) | `MatomePanelSection`/`MatomePanelRow`/`MatomePanelAddRow` (`apps/flutter/lib/ui/matome_detail_panel.dart`); `_MatomeLetterCard` (`apps/flutter/lib/features/matome/matome_detail_screen.dart`); `MatomeActionsMenu` (`apps/flutter/lib/features/matome/matome_actions_menu.dart`) |
| [DR-000 Convergence procedure](./DR-000-convergence-procedure.md) | (cross-cutting; #1458 precedent) — |

## The load-bearing decisions (read these first)

Two decisions are easy to get wrong and silently break the model. They are
called out in full in the relevant records, summarised here:

1. **A file relates INDEPENDENTLY along three axes — matome, space, and
   people.** These are three separate relations, not one polymorphic
   "container" foreign key. Each gets its **own** indicator atom:
   `MatomeChip`, `SpaceChip`, `PeopleCluster` (+ the existing `MatomeSyncChip`).
   See [DR-003](./DR-003-files.md).

2. **"Unfiled" and "Inbox" are distinct, per-dimension absences.**
   *Unfiled* = no matome relation. *Inbox* = no space relation. A file can be
   Unfiled yet filed in a space (e.g. `voice-memo.m4a` = Unfiled + space
   "Personal"), or both at once. They are NOT synonyms.
   See [DR-003](./DR-003-files.md).

Every graduation followed the same convergence procedure — promote the real
widget, repoint the use-case, verify green, then delete the mock in its own
revertable commit. The last mock (`matome_letter_proposal.dart`) and the empty
`proposals/` directory were removed in #1470. See
[DR-000](./DR-000-convergence-procedure.md).

## Shared atoms (where the chips live)

`MatomeChip`, `SpaceChip`, `RoleChip`, and `PeopleCluster` graduate to
`apps/flutter/lib/ui/` (source-guard exempt + Widgetbook-importable) so the
files view, contact detail, and nav can all reuse them. **Reuse** the existing
`MatomeSyncChip` (`apps/flutter/lib/ui/app_card.dart:603`) and `StatusBadge`
(`apps/flutter/lib/ui/status_badge.dart:10`) — do **not** fork a second sync
chip. This is owned by task #1460.

## Traceability table

Every graduation task (#1459–#1468) → the widget it graduated (the
`proposals/*` mocks it came from are all deleted; this column now points at the
shipped widget) + region + the owner-approved decision it implements.

| Task | What it does | Graduated widget (was a `proposals/*` mock) | Region / view-model | Owner-approved decision implemented |
| --- | --- | --- | --- | --- |
| **#1459** | Decision-records + traceability | (the records themselves) | the records themselves | Capture rationale before any mock is deleted; record the convergence procedure |
| **#1460** Shared atoms | Promote `MatomeChip` / `SpaceChip` / `RoleChip` / `PeopleCluster` to `lib/ui` | `apps/flutter/lib/ui/matome_chip.dart`, `space_chip.dart`, `role_chip.dart`, `people_cluster.dart` | the four chip/cluster widgets used across files + contact + nav | Separate atom per relation axis; reuse existing `MatomeSyncChip` + `StatusBadge` (no second sync chip) |
| **#1461** Files data layer | `_File` → `FileRow` view-model + matome/space/people/sync fields | `FileRow` view-model (in `apps/flutter/lib/features/files/`) | `FileRow` model (`unfiled`/`inInbox` getters; `matome`, `space`, `contacts`, `rollup`) | matome ≠ space ≠ people are three independent relations; Unfiled vs Inbox per-dimension absence |
| **#1462** Core contact fields | Add identity fields to Core | Core contact identity fields (`apps/flutter/lib/core/db/tables.dart`) | identity section: `email` / `phone` / `company` / `title` | These fields were PROPOSED; Core added them alongside `displayName` + `notes` |
| **#1463** Matome table graduation | Promote `MatomeTable` into the app | `MatomeTable` (`apps/flutter/lib/features/matome/widgets/matome_table.dart`) | `MatomeTable` | Sortable columns, select-all + per-row select, bulk bar w/ confirm+undo, per-row menu, keyboard `x`-to-select, compact rows < 720dp |
| **#1464** Contact detail graduation | Promote `ContactDetail` into the app | `ContactDetail` (`apps/flutter/lib/features/contacts/widgets/contact_detail.dart`) | `ContactDetail` | Header + identity + notes + three relationship sections (Matomes w/ `RoleChip`, Spaces, Files); responsive 2-col / stacked |
| **#1465** Files graduation | Promote `FilesGrid` + `FilesTable` into the app | `FilesGrid`, `FilesTable` (`apps/flutter/lib/features/files/widgets/files_grid.dart`, `.../files_table.dart`) | `FilesGrid`, `FilesTable` | Three independent indicators (`MatomeChip` filled, `SpaceChip` outlined, `PeopleCluster`, `MatomeSyncChip`); Unfiled/Inbox copy |
| **#1466** Nav widgets graduation | Promote `MatomeBottomDock` + `MatomeSidebar` | `MatomeBottomDock`, `MatomeSidebar` (`apps/flutter/lib/features/shell/widgets/matome_nav.dart`) | `MatomeBottomDock`, `MatomeSidebar` | Floating dock w/ active label pill; offset gold "Add" FAB (menu, not record-only); branded sidebar, soft-tint active (NO left-stripe); Satori hidden |
| **#1467** Nav shell cutover | Wire the nav widgets into the shell | `MatomeBottomDock`/`MatomeSidebar` wired in the shell (`apps/flutter/lib/features/shell/`) | shell integration; the shell being replaced | Destinations + order: inbox · calendar · files · contacts · spaces; Satori excluded from visible list but kept in enum |
| **#1468** Config view-prefs | Persist cards↔table / grid↔table toggles | view-pref toggles on `MatomeTable` + `FilesGrid`/`FilesTable` | the view toggles | Table is a user-selectable view alongside cards; grid↔table toggle for files (config toggle) |
| **#1470** [Proposals] teardown | Delete last mock + empty `proposals/`; repoint this table | (no widget — cleanup) | this README + `widgetbook.directories.g.dart` | [Proposals] → [Catalog] migration complete; every proposal mock has graduated, so the source-proposal references are repointed at the shipped widgets |
