# ADR-0006 - Item organization decoupled from sync

> Status: **Accepted** | Date: 2026-06-22 | Plan: `local-first-spaces` (#102)
> Supersedes: **ADR-0003** (forced-Matome invariant / m007) — the "every recording
> belongs to exactly one Matome" rule is repealed.
> Amends: **ADR-0004** (triage lifecycle) — filing no longer implies sync; see the
> ADR-0004 amendment block for the locked forward-compat contract.
> Owner sign-off: project decision comment **#74124** (W0 gate cleared, 2026-06-22).
> Normative companion: **[W0 spec — sync gate, effective space, promotion runbook
> & migration map](../specs/sync-gate-and-promotion.md)** (the binding contract the
> build cites; this ADR holds the decision, the spec holds the rules).

## Context

Two earlier decisions welded **organization** to **sync**:

- **ADR-0003 / m007** forced *every* recording into *exactly one* Matome (a quick
  voice note became a one-item Matome). Organization was mandatory.
- **ADR-0004** made `spaceId == null` ⟺ Inbox ⟺ local-only, and "file into a
  Space" the single act that *both* organized the Matome *and* started sync. Sync
  was a side effect of filing.

That coupling forces two unrelated choices into one. A user who just wants to
capture a thought is made to mint a Matome; a user who files something for
organization is made to upload it. Plan #102 separates the two questions:

1. **How is this item organized?** (loose / in a matome / filed into a space)
2. **Does this item sync?** (only if its *effective space* is a cloud space)

The answer to (2) is a pure function of (1) plus one new per-space bit
(`is_local`). Filing is no longer the sync trigger; **landing in a cloud space**
is.

## Decision

### 1. Membership lattice (composable, not a ladder)

An item (a `recordings` row — audio, image, file, or note) sits in **one** of
three membership states, and these compose freely with the matome/space graph —
they are not a forced linear progression:

```
LOOSE              item has no matome AND no space          (recording.matomeId = NULL, recording.workspaceId = NULL)
IN A MATOME        item.matomeId set                        (the matome may itself be a draft — no space)
FILED INTO A SPACE item.workspaceId set, no matome          (filed directly, no matome wrapper)
```

- A **matome** may be a **draft**: it exists with items but has **no space**
  (`matome.spaceId = NULL`). A draft matome and its items are organized but
  not yet filed into a space.
- The forced-Matome invariant of ADR-0003 is **repealed**: an audio recording (or
  any item) may now land **loose**, with no matome at all. This is the reversal
  m007 has to undo (the W5 migration backfills, see #1500 / the
  [W0 spec](../specs/sync-gate-and-promotion.md#4-migration-mapping-table-verifiable)).

These three states + the draft-matome flag are **composable**: "loose item",
"draft matome with loose-from-a-space items", and "item filed directly into a
space" are all first-class. Nothing requires a matome before a space, or a space
before sync.

### 2. Effective space (the single precedence rule)

The space an item *effectively* belongs to is resolved, never stored twice:

```
effectiveSpace(item) =
    matome.spaceId        if item is IN A MATOME   (matome WINS)
    else item.workspaceId                          (filed directly)
    else NULL                                       (loose, or draft matome)
```

**Matome membership wins.** If an item is in a matome, the **matome's** space is
authoritative — the item's own `workspaceId` does not override it. This is the
only precedence rule, and it is owned by **one resolver** (#1493), which is the
**sole sync-eligibility authority** for the whole program.

### 3. INBOX = effective space NULL (a VIEW, never a stored field)

```
INBOX ⟺ effectiveSpace(item) == NULL
```

The Inbox is the set of everything whose effective space is NULL: **loose items
+ draft matomes**. It is a **derived VIEW over the resolver**, computed on read.

> **Binding rule.** Inbox MUST NOT be a stored column, a boolean, a sentinel
> space id, or a magic row. There is no `is_inbox`, no `inbox` space, no
> reserved id. Any future schema that adds such a field violates this ADR. The
> Inbox exists only as `effectiveSpace == NULL`.

This generalizes the ADR-0004 rule (`spaceId == null ⟺ Inbox`): the predicate is
now over the *effective* space (so an item in a draft matome is also Inbox), and
it is keyed on the resolver, not on a raw column.

### 4. `recording.workspaceId` when an item joins / leaves a matome — SHADOWED (decided)

When an item **joins** a matome, its own `recording.workspaceId` is **NOT
cleared** — it is **shadowed** by the precedence rule (the matome's space wins in
`effectiveSpace`, the raw column is left as-is). When the item **leaves** the
matome, its `recording.workspaceId` **reappears** as authoritative.

- **Chosen: shadowed (non-destructive).** Join/leave a matome is a reversible,
  lossless operation on the membership graph; it never mutates the item's filed
  space. Precedence — not mutation — decides the effective space.
- **Rejected: cleared (destructive).** Clearing `workspaceId` on join would lose
  the item's prior filing, so leaving a matome would silently drop the item into
  the Inbox even though the user had previously filed it. That is a data loss the
  precedence rule avoids for free.

Consequence: `effectiveSpace` is the **only** correct way to ask "what space is
this item in"; reading `recording.workspaceId` directly is wrong for any item
that is (or ever was) in a matome. The resolver (#1493) encapsulates this so no
call site reads the raw column.

### 5. `space.is_local` → local | cloud; sync ⟺ effective space is a cloud space

A space carries a new bit (m017, additive, default local):

- **`is_local = true` → LOCAL space.** Client-only. Its items **never** sync —
  no Core row, no upload, ever, while they stay in a local space.
- **`is_local = false` → CLOUD space.** Its items sync to Core.
- **Default = local.** A newly created space is local unless the user chooses
  cloud at creation.
- **Promotable local → cloud** (one-way, in v1, with consent + idempotency + a
  state machine + partial-failure handling — see #1499 / the
  [W0 spec §3](../specs/sync-gate-and-promotion.md#3-promotion-runbook--local--cloud-v1)). There is
  no cloud → local demotion in v1.

The sync predicate is therefore:

```
SYNC(item) ⟺ effectiveSpace(item) is a CLOUD space
           ⟺ effectiveSpace(item) != NULL  AND  that space.is_local == false
```

Loose items, draft matomes, and anything in a **local** space are **never**
drained to Core. Only the upload queue's single drain decision (#1498) acts on
this, and it does so through one **operation-keyed** gate (see ADR-0004
amendment).

### 6. Accepted risk — local-default data loss (conscious decision)

Because spaces default to **local** and a recording stays **local-only** until it
is filed into a **cloud** space (or its space is promoted to cloud), a recording
that is captured and never filed into a cloud space exists **only on the device**.
**A device wipe / loss / uninstall loses it** — there is no server copy.

This is an **owner-accepted, conscious trade-off** (plan #102 owner decisions;
sign-off #74124): the "where did my recording go?" risk on a device wipe is the
price of a true local-first default, and it is accepted rather than mitigated in
v1. It is recorded here so it is not silently inherited. The promotion path
(local → cloud) and clear local/cloud affordances in the UI (W0 widgets) are the
user-facing mitigations; an automatic local backup is explicitly **out of scope**
for #102.

## Forward-compat — the two-axis space model (binding contract, H4)

Plan #102 leaves **seams**, not features, for the deferred
orgs/admin/data-policy/SSO/RBAC work. The contract below is **binding** and is
**locked into ADR-0004** (see its amendment) as the forward path. **None of this
is built in #102** — only the seams are.

### Two axes, never collapsed

| Axis | Question | Column | Values | Status in #102 |
|---|---|---|---|---|
| **A — sync mode** | does it sync? | `workspaces.is_local` | `local` \| `cloud` | **built** (m017) |
| **B — tenancy / ownership** | who owns it? | `workspaces.space_type` (m006) | `personal` \| `shared` \| `org` | **reserved / unenforced** |

The two columns are **orthogonal and do NOT merge**. Sync is keyed off Axis A
only; tenancy is keyed off Axis B only. Invariants couple them without collapsing
them:

- **`local ⟹ personal`** — a local space is always personal (a shared/org space
  is inherently multi-user and therefore cloud).
- **`org ⟹ cloud`** — an org-owned space always syncs.
- **`personal` may be `local` OR `cloud`** — the personal/cloud cell is the
  normal "my synced space" case.

A future PR that keys sync off `space_type`, or that adds an `org_local` cell, or
that merges the two columns, violates this ADR.

### The two seams the deferred work plugs into

1. **The resolver (#1493) is the only sync-eligibility authority.** It consumes a
   Space **value object** `{ id, syncMode, tenancy, ownerId }`. Today `tenancy`
   is constant `personal` and `ownerId` is the current user, but they are
   **present in the signature** so org-spaces add **one branch**, not a rewrite.
   `effectiveSpace` / `isCloudSynced` live here and nowhere else.

2. **Authorization is OPERATION-KEYED at one decision point (#1498).** The
   access / drain predicate guards by a stable **operation catalog key** —
   `SyncPolicy.can(caller, Operation.spaceSync, space)` — **NOT by a role**, and
   **never** an inline `if isCloud`. Today it returns `isCloudSynced`
   (owner ⇒ allow). Later a Policy Decision Point resolves
   `caller → groups → (custom) roles → operations` from **data**, behind the same
   call site. This client gate mirrors a future **Core Bodyguard/PDP** seam.

   - **Roles and operations are future DATA, not enums.** #102 MUST NOT freeze a
     fixed role set. Guarding by *operation* (not by a fixed `owner|admin|member|
     viewer` enum) is exactly what keeps **configurable RBAC** possible: custom
     roles add **zero** call-site changes.
   - The **sync-status type is sealed / exhaustive**, so a future state
     (`orgManaged` / `policyBlocked`) is a **compile error** at every `switch` —
     no silent default arm.

### The deferred configurable-RBAC model is a SEPARATE plan

The full data-driven model — **users × groups × custom roles × operations + a
PDP + an engine choice (OpenFGA/Zanzibar, Oso/Polar, Casbin, or hand-rolled)** —
is a **separate, deferred authorization plan**, not part of #102. It is captured
in project comment **#74119** (tag **`#future-plan`**, "Configurable
authorization"). #102 adopts only the operation-keyed seam so it does not block
that model.

### `owner_id` = stable user id

`space.owner_id` is a **stable user id** (not an email), so SSO-linked identities
map cleanly when the deferred SSO work lands. SSO stays fully independent of
#102.

## Glossary

These terms are pinned in [`.docs/glossary.md`](../glossary.md) (the canonical
ubiquitous-language source); defined here once for self-containment:

- **Loose item** — an item with no matome **and** no space
  (`matomeId = NULL`, `workspaceId = NULL`). Its effective space is NULL → it is
  in the Inbox and never syncs.
- **Draft matome** — a matome with items but **no space** (`spaceId = NULL`). Its
  effective space is NULL → Inbox, unsynced, until it is filed into a space.
- **Inbox** — a **VIEW**: the set of items + matomes whose **effective space is
  NULL** (loose items + draft matomes). Never a stored field, boolean, sentinel
  id, or row.
- **Local space** — a space with `is_local = true`. Client-only; its items never
  sync. The default for a new space.
- **Cloud space** — a space with `is_local = false`. Its items sync to Core.
  Sync happens **iff** an item's effective space is a cloud space.

> **BANNED term: "unfiled".** Do not use "unfiled" in code, UI, commits, or docs.
> It conflates the three distinct states above. Use the precise term: an item is
> **loose**, a matome is a **draft**, and the derived view is the **Inbox**.

## Consequences

- **ADR-0003 superseded.** The forced-Matome invariant ("every recording belongs
  to exactly one Matome", invariants 1–4 of ADR-0003) no longer holds. Items may
  be loose. m007's forced-mint backfill is reversed by the W5 migration (#1500),
  which is backfill-only and tested-reversible.
- **ADR-0004 amended.** Filing into a space no longer implies sync; sync is gated
  on `is_local`. The triage lifecycle's "file ⟹ sync" arrow is cut. ADR-0004
  carries the locked two-axis forward-compat contract (its amendment block).
- **One resolver, one gate.** `effectiveSpace` / `isCloudSynced` live in the
  #1493 resolver; the drain/access decision is the single operation-keyed gate
  (#1498). No call site reads `recording.workspaceId` directly or inlines
  `if isCloud`.
- **The whole behaviour is flag-gated.** `localFirstSpaces` (single-flip
  rollback); m017 is additive and default-local; per-wave reversible commits.
- **Out of scope (this ADR):** the storage-decoupled ingestion trigger (separate
  proposal), any orgs/SSO/policy/RBAC *behaviour* (deferred, seams only), and an
  automatic local backup for the accepted data-loss risk.
