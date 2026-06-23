# SPEC — sync gate, effective space, promotion runbook & migration map

> Status: **Normative** | Date: 2026-06-22 | Plan: `local-first-spaces` (#102), W0 gate
> Source of truth for: [ADR-0006](../decisions/ADR-0006-item-organization-decoupled-from-sync.md)
> (item organization decoupled from sync). This spec is the **normative
> companion** the build cites — ADR-0006 holds the *decision*, this file holds the
> *binding contract* every implementation (client AND Core) must satisfy.
> Terminology is pinned by [`.docs/glossary.md`](../glossary.md). The banned term
> **"unfiled"** does not appear here — use **loose** / **draft** / **Inbox**.

This document is the **single source of truth** for every sync-eligibility
decision. If code, a review, or another doc disagrees with this file on the
effective-space rule, the sync gate, the promotion state machine, or the
migration mapping, **this file wins** (it in turn never contradicts ADR-0006 —
the two are kept bidirectionally cross-linked; see "Cross-links" at the foot).

Tasks referenced: resolver **#1493**, drain/gate **#1498**, promotion **#1499**,
W5 backfill migration **#1500**.

---

## 1. The effectiveSpace rule (NORMATIVE)

> **R1.** The space an item *effectively* belongs to is **resolved, never stored
> twice**, by exactly one rule:

```
effectiveSpace(item) =
    matome.space_id            if item is IN A MATOME      (matome WINS)
    else item.workspace_id     if filed directly into a space
    else NULL                  (loose item, or draft matome)
```

In the compact form the plan uses (identical semantics):

```
effective = matome.space_id ?? recording.workspace_id     // matome wins; NULL ⇒ Inbox
```

> **R1.1 — Matome membership wins.** If an item is IN A MATOME, the **matome's**
> space is authoritative. The item's own `recording.workspace_id` does **not**
> override it — it is **shadowed**, never read directly, and never cleared on
> join/leave (ADR-0006 §4). Reading `recording.workspace_id` directly is a bug for
> any item that is (or ever was) in a matome.

> **R1.2 — One resolver, both tiers.** `effectiveSpace` is owned by **one
> resolver** (#1493) and is the **sole sync-eligibility authority** for the whole
> program. The **client** and **Core** MUST compute the effective space by this
> identical rule. Neither tier may invent a second predicate, a shortcut column,
> or an inline `if (workspaceId != null)`.

> **R1.3 — NULL ⇒ Inbox (a VIEW).**

```
INBOX(item) ⟺ effectiveSpace(item) == NULL
```

> Inbox = loose items + draft matomes. It is a **derived VIEW over the resolver**,
> computed on read. It MUST NOT be a stored column, a boolean, a sentinel space
> id, or a magic row — there is no `is_inbox`, no `inbox` space, no reserved id
> (ADR-0006 §3, binding rule).

> **R1.4 — Space value object (forward-compat seam).** The resolver consumes a
> Space **value object** `{ id, syncMode, tenancy, ownerId }` (ADR-0006 H4 seam 1).
> In #102 `tenancy` is constant `personal` and `ownerId` is the current user, but
> they are **present in the signature** so org-spaces add one branch, not a
> rewrite. `effectiveSpace` and `isCloudSynced` live here and **nowhere else**.

---

## 2. The sync gate (NORMATIVE)

> **R2 — the sync predicate.** An item syncs to Core **iff** its effective space is
> a **cloud** space:

```
SYNC(item) ⟺ effectiveSpace(item) is a CLOUD space
           ⟺ effectiveSpace(item) != NULL  AND  thatSpace.is_local == false
```

Consequences (all follow from R2 alone — no second rule):

- **Loose items never sync** (effective space NULL).
- **Draft matomes never sync** (effective space NULL).
- **Anything in a LOCAL space never syncs** (`is_local == true`) — no Core row, no
  upload, ever, while it stays in a local space.
- **Filing is NOT the sync trigger.** Filing into a *local* space organizes
  without syncing. **Landing in a cloud space** is what syncs (ADR-0004 amendment
  (a) — the "file ⟹ sync" arrow is cut).

### 2.1 One operation-keyed gate (NORMATIVE)

> **R2.1.** The decision flows through **one** decision point — the upload queue's
> single drain gate (#1498) — and that gate is **OPERATION-KEYED**, not
> role-keyed and never an inline `if isCloud`:

```
SyncPolicy.can(caller, Operation.spaceSync, space)
```

- Today this returns `isCloudSynced(space)` (owner ⇒ allow). The whole sync gate
  collapses to: *does the effective space pass `SyncPolicy.can(..., spaceSync, ...)`?*
- The guard key is a **stable operation catalog key** (`Operation.spaceSync`), not
  a fixed `owner|admin|member|viewer` enum. Roles and operations are future
  **DATA**, not enums (ADR-0006 H4 seam 2). A future PDP resolves
  `caller → groups → (custom) roles → operations` behind this same call site with
  **zero** call-site changes.
- The **sync-status type is sealed / exhaustive**, so a future state
  (`orgManaged` / `policyBlocked`) is a **compile error** at every switch — no
  silent default arm.

> **R2.2 — two axes, never collapsed.** Sync keys off **Axis A** (`is_local`,
> `local | cloud`) only. **Axis B** tenancy (`space_type`, `personal | shared |
> org`) is orthogonal and unenforced in #102. Invariants couple them without
> merging: **`local ⟹ personal`**, **`org ⟹ cloud`**; `personal` may be `local`
> OR `cloud`. Keying sync off `space_type`, adding an `org_local` cell, or merging
> the columns violates this spec and ADR-0006.

---

## 3. Promotion runbook — local → cloud (v1)

Promotion turns a **local** space (and therefore all items whose effective space
is that space) into a **cloud** space, draining its previously-local items to
Core for the first time. v1 **includes** promotion (#1499).

### 3.1 One-way (NORMATIVE)

> **R3.1.** Promotion is **one-way in v1**: `local → cloud` only. There is **NO
> cloud → local demotion** in v1. A space that has become cloud stays cloud. (This
> is recorded so the build does not implement a reverse path or assume one
> exists.) Rationale: demoting would require deleting server copies and re-deriving
> local-only state — out of scope for #102.

### 3.2 Consent UX contract (NORMATIVE)

> **R3.2.** Promotion MUST NOT proceed without **explicit, itemized consent**.
> Because local items exist only on the device (ADR-0006 §6 accepted data-loss
> risk), promotion is the moment data **leaves the device**, so the user is told
> exactly what and how much:

- The consent prompt MUST state the **count of items that will leave this device**,
  e.g. **"N items will leave this device"** (itemized — the actual N, computed from
  the items whose effective space is this space and that have **no Core row yet**).
- The prompt MUST name it as a **one-way** action ("This can't be undone" /
  cannot be made local again in v1).
- Promotion proceeds **only on affirmative consent**. Dismiss/cancel ⇒ no state
  change, space stays local.
- The count N is computed from the **resolver** (items with `effectiveSpace ==
  thisSpace`), not from a raw column, so matome-membership precedence (R1.1) is
  honoured (items shadowed into this space via their matome are counted; items
  shadowed *out* are not).

### 3.3 Idempotency key (NORMATIVE)

> **R3.3.** Every per-item Core create/assign during promotion is keyed by a
> **stable idempotency key**: the item's **stable/Core id** (the recording's stable
> client id, which becomes / maps to its Core id). Re-running promotion (resume
> after failure, double-tap, retry) MUST be **idempotent** — the same item is
> never created twice on Core. Core upsert/create-if-absent is keyed on this id.

### 3.4 State machine (NORMATIVE)

> **R3.4.** A space under promotion moves through exactly these states:

```
        consent granted            all items drained
 local ───────────────► promoting ───────────────► cloud
                            │
                            │ any item fails to reach Core
                            ▼
                          failed ──────────► (resume) ──► promoting
                            │
                            └──► (user cancels resume) ──► stays failed
```

| State | Meaning | Out-edges |
|---|---|---|
| `local` | `is_local == true`; items local-only. | → `promoting` (on consent) |
| `promoting` | consent granted; per-item Core create/assign + upload in flight. | → `cloud` (all items reached Core) · → `failed` (≥1 item failed) |
| `cloud` | `is_local == false`; **terminal success**; all items have Core rows; new items in this space sync normally via R2. | (terminal — no demote, R3.1) |
| `failed` | ≥1 item did not reach Core; promotion incomplete. | → `promoting` (resume) · stays `failed` (until resumed) |

- **No silent default arm.** The promotion-state type is sealed/exhaustive; a new
  state is a compile error at every switch (mirrors R2.1).

### 3.5 Partial failure & resume (NORMATIVE)

> **R3.5.** Promotion is **per-item and resumable**:

- Each item is promoted independently: Core create/assign (R3.6) → upload → mark
  that item synced. An item that **already has a Core row** (R3.3) is **skipped**,
  not recreated.
- If **any** item fails (network, Core error), the space enters **`failed`** —
  **not** `cloud`. Items that **did** succeed keep their Core rows (no rollback of
  successful items; promotion is forward-only and idempotent).
- **Resume** re-runs the drain over the space's items; idempotency (R3.3) makes
  already-promoted items no-ops, so resume completes only the remainder.
- A space reaches **`cloud`** **only** when **every** item whose effective space is
  this space has a Core row. Until then it is `promoting` or `failed`, and the
  sync gate (R2) treats not-yet-promoted items honestly: an item without a Core
  row is still "on device".
- Resume is itself idempotent and may run any number of times.

### 3.6 Owner-scope authorization (NORMATIVE)

> **R3.6.** The Core create/assign performed during promotion is guarded by
> **owner-scope** authorization, through the **same operation-keyed gate** as the
> sync drain (R2.1):

- Promotion's Core writes (create space-as-cloud, create/assign each item) are
  permitted **iff** `SyncPolicy.can(caller, Operation.spaceSync, space)` — today
  **owner ⇒ allow** (the caller owns the space; `space.owner_id` is the caller's
  **stable user id**, not an email).
- No new role enum is introduced for promotion; it reuses the `Operation.spaceSync`
  key so the deferred PDP governs it later with zero call-site change.
- A non-owner caller (a future shared/org case) is rejected at this one gate, not
  by an inline check scattered across the promotion path.

---

## 4. Migration mapping table (VERIFIABLE)

The W5 backfill migration (#1500) is **backfill-only and tested-reversible**. The
table below is the **verifiable contract**: each pre-migration state maps to a
resulting `is_local`, effective space, and sync status. (This is a table, not
prose, on purpose — each row is independently checkable.)

### 4.1 Verified pre-migration fact (the gate for "→ cloud")

> **VERIFICATION (done, 2026-06-22).** Today (pre-#102) sync-eligibility is gated
> by **`matome.space_id != null`** — a Matome uploads to Core **iff** it is filed
> into a Space (any space). Evidence:
> `apps/flutter/lib/core/db/daos/matomes_dao.dart:115` (`listFiledMatomes`:
> `spaceId IS NOT NULL` ⇒ "exactly the Matomes eligible for Core push") and
> `apps/flutter/lib/features/matome/matome_sync_service.dart:192`
> (`if (matome.spaceId == null) continue;` — push gate). **No `is_local` column
> exists** (schema at m016; `is_local` is the new m017). Therefore **every existing
> filed space syncs today**, so mapping existing (filed) spaces → **cloud** does
> **not** promote any local-only data into the cloud — it preserves today's
> behaviour exactly.
>
> **Binding rule:** an existing space may map to **cloud** **only because** this
> verification holds (it truly syncs today). If a future codebase introduces a
> local-only space *before* migration, that assumption breaks and the migration
> MUST re-verify per-space rather than blanket-mapping to cloud.

### 4.2 The table

| # | Pre-migration state | resulting `is_local` | resulting effective space | resulting sync status | Verification requirement |
|---|---|---|---|---|---|
| M1 | **Filed Matome** — `matome.space_id != null` (the only state that syncs today) | space → **cloud** (`is_local = false`) | the matome's space (unchanged) | **synced** (Core rows preserved; keeps syncing) | The space **truly syncs today** (§4.1 — verified: filed ⇒ pushed). Map to cloud **only** because this holds. |
| M2 | **Inbox Matome** — `matome.space_id == null` (untriaged, local-only today) | n/a (no space) → becomes a **draft matome** | **NULL** (Inbox) | **on device** (unchanged; never synced) | None — already local-only today; stays Inbox/unsynced. Becomes a *draft matome* per ADR-0006 §1. |
| M3 | **Existing Space row** (`workspaces`), reachable by a filed Matome | **cloud** (`is_local = false`) | itself | items in it: **synced** | Same gate as M1 — existing spaces are cloud **only because** their filed items sync today (§4.1). |
| M4 | **New space created after migration** | **local** (`is_local = true`) — the m017 default | itself | **on device** until promoted (R3) or created as cloud | Default-local (ADR-0006 §5). Cloud only on explicit user choice at creation or via promotion. |
| M5 | **Loose item backfill** — item with no matome (the m007 forced-mint reversal, #1500) | n/a (no space) | **NULL** (Inbox) | **on device** | Backfill-only + tested-reversible (#1500). Reverses ADR-0003's forced-Matome mint; item lands **loose**. |
| M6 | **Item filed directly into a space** (no matome wrapper) | inherits its space's bit | `recording.workspace_id` (R1: matome absent ⇒ direct file wins) | per R2 on that space | Effective space = the directly-filed space; sync follows R2. |

Notes binding the table:

- **m017 is additive and default-local.** No existing row's data is destroyed; the
  column is added with default `local` and then the filed-space rows (M1/M3) are
  set to `cloud` by the backfill because they sync today (§4.1).
- **No data leaves the device on migration.** M1/M3 map to cloud because they were
  **already** syncing; migration changes the *label*, not the sync reality. New
  exposure happens only later, via consented **promotion** (R3) of a local space.
- **Reversibility (#1500).** The migration is backfill-only; the down-path restores
  the pre-#102 labels (drop `is_local`; M5 loose backfill is the only data shape
  change and is tested-reversible).

---

## 5. Rollback / flag

- The whole behaviour is behind the **`localFirstSpaces`** flag (single-flip
  rollback). m017 is additive and default-local; per-wave commits are reversible.
- This spec is docs-only: `git revert` of its commit removes it with zero runtime
  effect. Schema/behaviour are introduced by later W-tasks, each separately
  reversible.

---

## Cross-links

- **ADR-0006** — the decision this spec makes binding:
  [`../decisions/ADR-0006-item-organization-decoupled-from-sync.md`](../decisions/ADR-0006-item-organization-decoupled-from-sync.md)
  (§2 effective space, §3 Inbox VIEW, §4 shadowed workspaceId, §5 sync gate /
  `is_local`, §6 accepted data-loss, H4 forward-compat seams).
- **ADR-0004 amendment** — "filing no longer implies sync" + the locked two-axis
  forward-compat contract:
  [`../decisions/ADR-0004-identity-permissions-triage.md`](../decisions/ADR-0004-identity-permissions-triage.md).
- **Glossary** — ubiquitous language (loose / draft / Inbox / local space / cloud
  space; "unfiled" banned): [`../glossary.md`](../glossary.md).
</content>
</invoke>
