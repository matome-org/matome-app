# DR-003 - Files view (`FilesGrid` + `FilesTable`)

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459
> Source: `apps/flutter_widgetbook/lib/proposals/matome_files_proposal.dart`
> Public widgets: `FilesGrid`, `FilesTable`
> Graduates in: #1461 (data layer), #1465 (widgets), #1468 (grid↔table toggle)

This is the **load-bearing** record. Two decisions here are easy to get wrong
and will silently break the data model if collapsed. Build the model from this
record, not from intuition.

## Problem

There is no cross-cutting view of files. A captured/imported artifact (audio,
image, document) may live **inside a matome** OR be **loose** (in no matome).
Today neither is browsable as files; the "loose / Unfiled" state is invisible.
The Files view exists to make every file — filed or not — scannable and
manageable.

Two takes, both responsive (desktop multi-column / mobile condensed) and both
sharing the selection / bulk-action / undo model:

- **`FilesGrid`** — visual browsing. Tiles with a type/preview block, name,
  meta, and the relationship indicators. Best for images + mixed media.
- **`FilesTable`** — the columnar counterpart (same machinery as the matome
  table: sortable columns, selection + bulk bar, per-row menu, confirm + undo).
  Best for managing many files at once.

## LOAD-BEARING DECISION 1 — three independent relations, three separate atoms

A file relates **INDEPENDENTLY along THREE axes**:

1. **matome** — which matome (if any) the file belongs to.
2. **space** — which space/folder (if any) the file is filed into.
3. **people (contacts)** — which contacts are tagged on the file.

These are **three separate relations**, not facets of one "container". A file
can be in a matome but no space, in a space but no matome, tagged with people
but in neither, and so on — every combination is valid. **Sync** is a fourth,
orthogonal dimension (cloud / partial / on-device rollup).

Therefore each axis gets its **OWN indicator atom**, NOT one polymorphic chip:

| Axis | Atom | Visual | Absent state |
| --- | --- | --- | --- |
| matome | **`MatomeChip`** | **filled** pill, `workspaces` icon | **"Unfiled"** (italic) |
| space | **`SpaceChip`** | **outlined** pill, `folder` icon | **"Inbox"** (italic) |
| people | **`PeopleCluster`** | overlapping initials avatars + "+N" | renders nothing (caller adds a dash) |
| sync | **`MatomeSyncChip`** (existing) | tinted pill / dot | — |

The matome chip is **filled** and the space chip is **outlined** specifically so
the two relationships read as **distinct categories at a glance** rather than as
two instances of the same thing.

### People data source — the DIRECT file↔contact edge (#1472)

The **people** axis is a **first-class, direct relation**: a `recording_contacts`
join (Core `recording_contacts`, Drift m016) links a contact DIRECTLY to a file.
This is the **source of truth** for `PeopleCluster`.

> Historical note: when the Files view first shipped (#1461), there was no
> per-file contact edge, so people were **matome-mediated** — a file's "people"
> were its *matome's* tagged contacts (`matome_contacts`), and a loose/Unfiled
> file therefore showed no people at all. #1472 closed that gap by adding the
> direct edge. The relation is no longer matome-mediated; do not reintroduce a
> JOIN-through-matome as the primary source.

**Resolution rule (decided, #1472):** `PeopleCluster` (grid + table) and the
Contact detail "Files" section read the **direct edge UNIONed with the
matome-mediated set, de-duplicated by contact / file id** (direct wins on a tie,
so nothing double-counts). The direct edge is authoritative; the matome-mediated
set is kept only as an additional union so a person reachable via the file's
matome still surfaces. An Unfiled file (no matome) now correctly shows the people
linked to it directly — previously impossible. See `RecordingsDao.filesForOwner`
(people union per file) and `ContactsDao.listFilesForContactUnion` (Contact
detail). Both endpoints are **owner-scoped** server-side
(`MatomeApi.Content.link_contact_to_recording` verifies the file AND the contact
belong to the actor before linking).

## LOAD-BEARING DECISION 2 — "Unfiled" vs "Inbox" are distinct per-dimension absences

These are **NOT synonyms**. Each is the absence of a *different* relation:

- **Unfiled** = the file has **no matome relation** (`matome == null`,
  exposed as the `unfiled` getter). Shown by `MatomeChip` as the italic
  **"Unfiled"** label.
- **Inbox** = the file has **no space relation** (`space == null`, exposed as
  the `inInbox` getter). Shown by `SpaceChip` as the italic **"Inbox"** label.

Because the two relations are independent, a file can be:

- **Unfiled but filed in a space** — e.g. the sample `voice-memo.m4a` is
  `matome: null` (Unfiled) yet `space: 'Personal'`. Space ≠ matome.
- **Both Unfiled and in Inbox** — e.g. `whiteboard.jpg` / `budget.xlsx` have
  `matome == null` AND `space == null`.
- Filed in a matome but still in Inbox (no space), etc.

Empty-state copy each absence produces:

| Dimension | Absence condition | Label (en / ja) | Style |
| --- | --- | --- | --- |
| matome | `matome == null` | **Unfiled** / 未整理 | italic, muted |
| space | `space == null` | **Inbox** / 受信箱 | italic, muted |

Collapsing these into a single "is it filed" boolean, or sharing one label,
would erase the distinction and mis-file data. They must stay separate.

## Other decisions

- **Shared selection / bulk / undo** with the matome table: select-all, per-row
  selection, a bulk bar (move to matome / download / delete), CONFIRM + UNDO on
  delete (restores at original index), and `x`-to-select keyboard focus.
- **Grid layout** is self-adjusting (~200dp tiles, 2 on phones, more on wide).
  Tiles surface matome+sync on one line and space+people on the next so neither
  relationship is truncated.
- **Sortable columns** in the table: Name · When · Size (When defaults
  most-recent-first); Matome / Space / People / Sync are display columns.
- **Grid↔table is a user toggle** (config, #1468), mirroring the cards↔table
  toggle for matomes.

## Rejected alternatives

- **Collapsing matome and space into one foreign key / one chip.** Rejected:
  they are independent relations; a single FK would make "Unfiled + in a space"
  unrepresentable and would silently break the model.
- **A single generic "relation chip"** that polymorphically shows whichever
  relation exists. Rejected: it hides that the axes are independent and makes
  the three-way combinations illegible.
