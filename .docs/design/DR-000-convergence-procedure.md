# DR-000 - The graduation convergence procedure

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459 | Precedent: FileView / #1458 (ADR-0005)

## Problem

We have approved Widgetbook proposals (`apps/flutter_widgetbook/lib/proposals/`)
that carry the production interaction model as static, provider-free mockups.
Each needs to become a real, app-hosted widget. The naive approach — "treat the
mock as throwaway, rewrite the screen from scratch, delete the mock" — is what
caused the **#1458 drift**: the mock and the shipped widget diverged, the
Widgetbook use-case kept rendering a stale copy, and the design intent had to be
re-derived by hand.

## Decision: every graduation follows the same ordered steps

1. **Promote the public proposal widget into the app.**
   - Shared atoms → `apps/flutter/lib/ui/` (e.g. `MatomeChip`, `SpaceChip`,
     `RoleChip`, `PeopleCluster`).
   - Feature widgets → `apps/flutter/lib/features/<x>/widgets/`
     (e.g. `MatomeTable`, `FilesGrid`/`FilesTable`, `ContactDetail`,
     `MatomeBottomDock`/`MatomeSidebar`).
   - Replace the proposal's private `_Row` / `_File` / `_Contact` sample classes
     with a **plain props/data class** (a view-model the host can build from
     real providers), and replace the inline `_Copy` localisation with
     **slang `t.*` i18n** keys. No inline `_Copy` survives into the app.
   - Reuse existing shared widgets rather than forking them — notably
     `MatomeSyncChip` (`apps/flutter/lib/ui/app_card.dart`) and `StatusBadge`.

2. **Repoint the Widgetbook `@UseCase` to render the REAL widget** with sample
   props. The use-case stops constructing the mock and instead imports the
   graduated widget from `package:matome_flutter/...`, feeding it sample data.
   This is what prevents drift: there is now exactly one implementation, and the
   Widgetbook story exercises it directly.

3. **Verify green** before deleting anything:
   - `flutter analyze`
   - the test suite (widget + golden tests)
   - `mise run flutter-design-system-check`

4. **DELETE the proposal mock in its OWN, revertable commit**, performed
   **after** the repoint (step 2) and the green check (step 3). Keeping the
   delete in a separate commit means the mock can be restored with a single
   revert if the graduation needs to be reworked.

## Rejected alternative

- **Keep the mocks as throwaway scaffolding, rewrite the screen independently,
  delete the mock whenever.** Rejected: this is exactly what produced the #1458
  drift — two diverging implementations and a stale Widgetbook story. The
  repoint-before-delete ordering is the fix.

## Why this record exists

This procedure is the contract every downstream graduation task (#1463–#1467)
builds against. It is recorded here once and referenced from each per-proposal
record so the steps do not have to be restated — or, worse, re-derived — per
task.
