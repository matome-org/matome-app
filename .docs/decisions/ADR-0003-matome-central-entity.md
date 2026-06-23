# ADR-0003 - Matome as the central entity

> Status: **Superseded** | Date: 2026-06-19 | Plan: `matome-centric-pivot`
> Superseded-by: **ADR-0006** (item organization decoupled from sync, plan #102,
> 2026-06-22). The **forced-Matome invariant** below — "every recording belongs
> to exactly one Matome" (invariants 1–4) — is **repealed**: items may now land
> **loose** (no matome, no space). The m007 forced-mint backfill is reversed by
> the plan-#102 W5 migration. The Matome-as-central-*entity* concept and the
> Space/containment/`aggregatedSummary` decisions still stand; only the *forced*
> 1-recording-→-1-Matome rule is superseded. Read ADR-0006 for the current model.

## Context

The app is driven by a single audio **recording** as the unit the user manages
(Inbox / Calendar / Spaces / Details all key on a recording). In practice a real
"thing the user wants to make sense of" is rarely one audio clip — it is a
meeting, a class, an interview, a brainstorm, or a quick note — and it gathers
several recordings, photos, notes, people, and summaries.

We are pivoting the managed unit from **recording** to **Matome** (まとめ — "a
gathering / a compiled whole"). A Matome is the philosophical core of the
product: the thing the app exists to produce. The Notion analogy is a *page*
(fixed structure, no block editor), with a **Space** as the Notion *workspace*.

## Decision

Introduce **`Matome`** as the central entity. Containment:

```
Space ⊃ Matome ⊃ { Items(audio|image), Contacts, Summaries, Notes }
```

### Naming
- Entity code identifier **and** display name = `Matome`. No bare `Matome`
  symbol exists today (brand symbols are `Matome*`-prefixed: `MatomeColors`,
  `MatomeThemeContext`), so the entity class is free. The glossary
  (`.docs/glossary.md`) disambiguates brand vs entity.

### Invariants (testable)
1. Every recording belongs to **exactly one** Matome. A quick voice note is a
   Matome with one item.
2. **1 recording → 1 Matome** (`recording.matomeId` FK; move, never copy).
3. A Matome's items are recordings carrying `mediaType` of `audio` or `image`
   (photos added during triage are items too).
4. A Matome is created in the **same local transaction** as its first item in
   every write path (capture / import / m006 backfill) — the NOT-NULL FK never
   sees an orphan window.

### Open decisions — now resolved
- **`aggregatedSummary` = stored (denormalized).** Held as a nullable column on
  the Matome. Regenerated when its item set changes; a `summaryStale` marker
  flags pending regeneration. It syncs as its own field with a `mergeText`-style
  null-wipe guard (a sparse Core payload must not erase a local aggregate).
  Rationale: the Matome is the synced unit and must render its summary offline;
  derived-on-read cannot sync or show consistently offline.
- **Matome `coreId` timing = local-only until triaged.** A Matome is minted
  `mat_local_<uuid>` at creation and stays Core-less while in the Inbox
  (`spaceId == null`). `coreId` is assigned on first sync, which only happens
  once the Matome is filed into a (synced) Space. Mirrors the proven
  `recording_ids.dart` / m005 reconciliation pattern. See ADR-0004 for the
  triage/sync lifecycle.
- **Space rename = logical.** The physical table stays `workspaces` (preserving
  m002 history + the existing `recordings.workspaceId` FK lineage); code and UI
  call it **Space**, and new columns/tables (`space_type`, `owner_id`,
  `space_members`, `organizations`) extend it. Avoids a destructive table
  rename; the glossary records `workspace` = legacy internal name, `Space` =
  canonical.
- **Contacts/PII cascade.** Deleting a Contact cascades its edges
  (`matome_contacts`, `space_contacts`, `matome_shares`). Deleting a Matome
  cascades `matome_contacts` / `matome_shares` but **not** the Contacts
  themselves (Contacts are owner-level and survive). Contacts are authz-scoped
  to `ownerId`.

## Consequences

- Migrations: `m006` (schemaVersion → 6) evolves Spaces (the `workspaces`
  table); `m007` (schemaVersion → 7) adds the `matomes` table +
  `recordings.matomeId` FK + backfills one Matome per existing recording
  (`matome.spaceId = old workspaceId`). Additive and — with no production users
  yet — low-risk; tested down-migrations are still written for discipline.
- The navigation unit flips recording → Matome (deferred to the plan's last
  wave); the Matome detail screen becomes the product hub.
- `aggregatedSummary` adds a third reconcilable sync field beyond the existing
  recording-level guards.
- Out of scope (this ADR): identity, permissions, sharing, triage lifecycle —
  see ADR-0004. Diarization and a Notion-style block editor are explicitly
  excluded.
