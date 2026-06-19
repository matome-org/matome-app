# ADR-0004 - Identity, permissions, and the triage lifecycle

> Status: **Accepted** | Date: 2026-06-19 | Plan: `matome-centric-pivot`
> (build of the collaboration behaviour is deferred — see "Schema-ready, build later")

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
