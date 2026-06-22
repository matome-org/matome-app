# DR-004 - Contact detail (`ContactDetail`)

> Status: **Accepted** | Date: 2026-06-21 | Task: #1459
> Source: `apps/flutter_widgetbook/lib/proposals/matome_contact_proposal.dart`
> Public widget: `ContactDetail`
> Graduates in: #1462 (Core identity fields), #1464 (widget)

## Problem

There is **no contact detail screen** today. The Contacts feature is **list +
inline edit/delete only** — there is nowhere to see a contact's identity, their
notes, and how they relate to matomes, spaces, and files. This is the first
design pass at a real detail view.

## Key decisions

### Header

Avatar (tinted by space palette), name, `company · title` subtitle, the sync
chip, a primary **Edit** button, and an overflow menu (Edit / Merge / Delete).

### Identity section — PROPOSED fields (needs Core work, #1462)

The identity rows are **email / phone / company / title**. **These are PROPOSED
fields.** Today the Core contact model carries only `displayName` + `notes`
(historically these would live in extensible metadata JSON). Graduating this
view therefore depends on **#1462 adding the fields to Core**. When all identity
fields are absent the section shows an "Add" affordance rather than empty rows.

### Notes

A free-text notes block; "No notes yet" (italic, muted) when empty.

### Three relationship sections

The schema already models three contact relationships, surfaced as three
sections (this mirrors the three-axis independence in
[DR-003](./DR-003-files.md), from the contact's side):

1. **Matomes** — a role-bearing edge. Each matome row carries a **`RoleChip`**
   showing the contact's role on that matome: **organizer / attendee /
   speaker** (from the `matome_contacts` join). `RoleChip` is one of the shared
   atoms graduating in #1460.
2. **Spaces** — binary membership, shown as space chips.
3. **Files** — the file↔contact tie defined in DR-003 (the `PeopleCluster`
   relation, seen here from the contact end).

### Responsive layout

Two columns on desktop (**identity + notes** | **relationships**), stacked into
one column on mobile. Breakpoint: 720dp.

## Rejected alternatives

- **Cramming the detail into the existing list modal / inline editor.**
  Rejected: the contact has too much structure (identity + notes + three
  relationship sections) to fit a modal; it needs its own screen.
