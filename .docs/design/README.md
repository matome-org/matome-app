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

Source mocks live in `apps/flutter_widgetbook/lib/proposals/`. Each is a static,
provider-free Widgetbook mockup that carries the production interaction model so
the eventual host screen is a thin wiring layer over a real widget.

| Decision record | Source proposal | Public widget(s) |
| --- | --- | --- |
| [DR-001 Matome table](./DR-001-matome-table.md) | `matome_table_proposal.dart` | `MatomeTable` |
| [DR-002 Navigation](./DR-002-navigation.md) | `matome_nav_proposal.dart` | `MatomeBottomDock`, `MatomeSidebar` |
| [DR-003 Files](./DR-003-files.md) | `matome_files_proposal.dart` | `FilesGrid`, `FilesTable` |
| [DR-004 Contact detail](./DR-004-contact-detail.md) | `matome_contact_proposal.dart` | `ContactDetail` |
| [DR-000 Convergence procedure](./DR-000-convergence-procedure.md) | (cross-cutting; #1458 precedent) | — |

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

All four graduations follow the same convergence procedure — promote the real
widget, repoint the use-case, verify green, then delete the mock in its own
revertable commit. See [DR-000](./DR-000-convergence-procedure.md).

## Shared atoms (where the chips live)

`MatomeChip`, `SpaceChip`, `RoleChip`, and `PeopleCluster` graduate to
`apps/flutter/lib/ui/` (source-guard exempt + Widgetbook-importable) so the
files view, contact detail, and nav can all reuse them. **Reuse** the existing
`MatomeSyncChip` (`apps/flutter/lib/ui/app_card.dart:603`) and `StatusBadge`
(`apps/flutter/lib/ui/status_badge.dart:10`) — do **not** fork a second sync
chip. This is owned by task #1460.

## Traceability table

Every graduation task (#1459–#1468) → source proposal + region + the
owner-approved decision it implements.

| Task | What it does | Source proposal | Region / view-model | Owner-approved decision implemented |
| --- | --- | --- | --- | --- |
| **#1459** (this) | Decision-records + traceability | all 4 proposals | the records themselves | Capture rationale before any mock is deleted; record the convergence procedure |
| **#1460** Shared atoms | Promote `MatomeChip` / `SpaceChip` / `RoleChip` / `PeopleCluster` to `lib/ui` | all 4 | the four chip/cluster widgets used across files + contact + nav | Separate atom per relation axis; reuse existing `MatomeSyncChip` + `StatusBadge` (no second sync chip) |
| **#1461** Files data layer | `_File` → `FileRow` view-model + matome/space/people/sync fields | `matome_files_proposal.dart` | `_File` model (`unfiled`/`inInbox` getters; `matome`, `space`, `contacts`, `rollup`) | matome ≠ space ≠ people are three independent relations; Unfiled vs Inbox per-dimension absence |
| **#1462** Core contact fields | Add identity fields to Core | `matome_contact_proposal.dart` | identity section: `email` / `phone` / `company` / `title` | These fields are PROPOSED; today only `displayName` + `notes` exist → Core must add them |
| **#1463** Matome table graduation | Promote `MatomeTable` into the app | `matome_table_proposal.dart` | `MatomeTable` | Sortable columns, select-all + per-row select, bulk bar w/ confirm+undo, per-row menu, keyboard `x`-to-select, compact rows < 720dp |
| **#1464** Contact detail graduation | Promote `ContactDetail` into the app | `matome_contact_proposal.dart` | `ContactDetail` | Header + identity + notes + three relationship sections (Matomes w/ `RoleChip`, Spaces, Files); responsive 2-col / stacked |
| **#1465** Files graduation | Promote `FilesGrid` + `FilesTable` into the app | `matome_files_proposal.dart` | `FilesGrid`, `FilesTable` | Three independent indicators (`MatomeChip` filled, `SpaceChip` outlined, `PeopleCluster`, `MatomeSyncChip`); Unfiled/Inbox copy |
| **#1466** Nav widgets graduation | Promote `MatomeBottomDock` + `MatomeSidebar` | `matome_nav_proposal.dart` | `MatomeBottomDock`, `MatomeSidebar` | Floating dock w/ active label pill; offset gold "Add" FAB (menu, not record-only); branded sidebar, soft-tint active (NO left-stripe); Satori hidden |
| **#1467** Nav shell cutover | Wire the nav widgets into the shell | `matome_nav_proposal.dart` + `apps/flutter/lib/app/shell_scaffold.dart` | shell integration; the shell being replaced | Destinations + order: inbox · calendar · files · contacts · spaces; Satori excluded from visible list but kept in enum |
| **#1468** Config view-prefs | Persist cards↔table / grid↔table toggles | `matome_table_proposal.dart` + `matome_files_proposal.dart` | the view toggles | Table is a user-selectable view alongside cards; grid↔table toggle for files (config toggle) |
