# ADR-0004 - Identity, permissions, and the triage lifecycle

> Status: **Accepted (amended)** | Date: 2026-06-19 | Plan: `matome-centric-pivot`
> (build of the collaboration behaviour is deferred — see "Schema-ready, build later")
> Amended-by: **ADR-0006** (item organization decoupled from sync, plan #102,
> 2026-06-22). Two amendments below: (a) **filing no longer implies sync** — sync
> is gated on the new `is_local` space bit, not on "filed into a Space"; and
> (b) the **two-axis space model + invariants + the two forward-compat seams**
> are **locked** here as the binding forward path for the deferred org/RBAC work.
> See the "Amendment (ADR-0006, plan #102)" block at the foot of this file.

## Context

ADR-0003 makes the **Matome** the central entity. Two cross-cutting concerns
fall out of it: (1) how a Matome moves from creation to a filed, shareable
state, and (2) how the app represents other people and shared ownership. Both
push the product from a single-user local-first tool toward a collaborative
platform, so we separate the **schema** (landed now) from the **behaviour**
(deferred).

## Decision

### Triage lifecycle (meishi-style)
The mental model is how Japanese business cards are handled: you collect during
the day, then sort later.

```
create Matome ─► INBOX (spaceId = null, local-only, untriaged, NOT synced)
                   │
              TRIAGE (when the user chooses): add photos / notes /
                   │   tag contacts / optionally share, then FILE into a Space
                   ▼
              in a SPACE (default = personal) ─► now syncs
```

- **`spaceId == null` ⟺ Inbox ⟺ local-only / untriaged / unsynced.**
- **Sync is SPACE-scoped.** A Matome enters the sync domain only when triaged
  into a Space. Inbox Matomes never upload.
- **Default triage destination = the user's personal Space.**
- **Web carve-out.** The web client has no local-first store; its Inbox is
  server-backed (untriaged Matomes live on the server). The "local-only inbox"
  invariant holds for mobile/desktop only.

### Identity & contacts
- A **Contact** is owner-owned: `ownerId`, `displayName`, arbitrary `metadata`,
  and an optional **`linkedUserId`** pointing at a real platform user.
- When linked, the owner may view that user's Matome **profile without the
  linked user's consent**. Accepted decision (no-users-yet, fast iteration);
  recorded as a **revisitable privacy risk** — non-consenting attendee PII and
  GDPR/CCPA exposure must be re-examined before any public/multi-tenant launch.
- Edges: `matome_contacts` (tag a contact in a Matome), `space_contacts`
  (contact as a Space member), `matome_shares` (share a Matome with a user).

### Spaces & permissions
- `space.type` ∈ { `personal`, `shared`, `org` }; `space.owner_id`.
- `space_members` (spaceId, userId, role) with RBAC roles
  `owner / admin / member / viewer`.
- `organizations` may own Spaces (multi-tenant).

### Schema-ready, build later
Plan `matome-centric-pivot` lands the **fields/tables** above
(`linkedUserId`, `space.type/owner_id`, `space_members`, `organizations`,
`matome_shares`) but **not the behaviour**:
- linked-user profile viewing, Matome sharing, shared/org-space ACL
  enforcement, multi-user sync, and organization management are **deferred to
  the `matome-collaboration` plan**.
- RBAC columns are present but **unenforced** until then (documented as such).

## Consequences

- Sync logic is space-scoped: the Core sync wave must treat Inbox as a
  local-only state and only upload on triage (mobile/desktop) while the web
  client reads/writes the server inbox directly.
- The client gains a notion of **other users** (contacts → accounts), which the
  single-user local-first model never needed — a real surface for the
  collaboration plan.
- The no-consent profile decision is an **open risk**, not a closed one; flagged
  here so it is not silently inherited at launch.

## Amendment (ADR-0006, plan #102 `local-first-spaces`, 2026-06-22)

ADR-0006 decouples **organization** from **sync**. Two amendments to this ADR:

### (a) Filing no longer implies sync

The triage lifecycle above made "file into a Space" the single act that *both*
organized a Matome *and* started sync (`spaceId == null ⟺ local-only / unsynced`,
"now syncs" on filing). That **filing ⟹ sync** arrow is **cut**. A space now
carries `is_local` (m017):

- Sync happens **iff** an item's **effective space** is a **cloud** space
  (`is_local = false`) — not merely because it was filed.
- Filing into a **local** space organizes without syncing. The Inbox predicate is
  now over the **effective** space (`effectiveSpace == NULL`), a VIEW owned by the
  resolver — see ADR-0006 §2–§5.

### (b) LOCKED forward-compat contract (binding; the deferred org/RBAC path)

The deferred `matome-collaboration` / org / admin / data-policy / SSO / RBAC work
MUST plug into the seams below **without a rewrite**. This is the binding contract:

- **Two axes, never collapsed.** Axis A **sync mode** (`workspaces.is_local`:
  `local | cloud`, built in m017) is **orthogonal** to Axis B **tenancy**
  (`workspaces.space_type`: `personal | shared | org`, the m006 column, reserved /
  unenforced). The two columns do **NOT** merge. Sync keys off Axis A only;
  tenancy keys off Axis B only.
- **Invariants** couple them without collapsing: **`local ⟹ personal`**,
  **`org ⟹ cloud`**; `personal` may be `local` **or** `cloud`. A PR that keys sync
  off `space_type`, adds an `org_local` cell, or merges the columns violates this.
- **Seam 1 — the resolver (#1493) is the only sync-eligibility authority.** It
  consumes a Space value object `{ id, syncMode, tenancy, ownerId }`; `tenancy` /
  `ownerId` are constants today (personal / current user) but are in the signature
  so org-spaces add **one branch**, not a rewrite.
- **Seam 2 — authorization is OPERATION-KEYED at one decision point (#1498).** The
  access / drain predicate guards by a stable **operation catalog key**
  (`SyncPolicy.can(caller, Operation.spaceSync, space)`) — **NOT by a role**, never
  inline `if isCloud`. Today returns `isCloudSynced` (owner ⇒ allow); later a PDP
  resolves `caller → groups → (custom) roles → operations` from **data** behind the
  same call site, mirroring a future Core **Bodyguard/PDP** seam. The sync-status
  type is **sealed / exhaustive** (a future `orgManaged` / `policyBlocked` is a
  compile error at every switch).
- **No fixed role enum.** Roles and operations are future **DATA**, not enums. The
  reserved `space_members(role: owner|admin|member|viewer)` schema in this ADR is a
  placeholder, not the target — #102 must NOT freeze it. The full configurable
  model (**users × groups × custom roles × operations + PDP + engine choice**:
  OpenFGA/Oso/Casbin/hand-rolled) is a **separate deferred authorization plan**,
  captured in project comment **#74119** (tag **`#future-plan`**).
- **`owner_id` = stable user id** (not email) so SSO-linked identities map cleanly.
