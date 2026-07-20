# UC-06 — Manage Spaces

> Part of the [Matome use-case catalog](../use-cases.md). Foundations:
> [PRD](../internal/prd.md) · [Architecture](../internal/architecture.md) ·
> [Requirements](../internal/requirements.md).

## Summary
A Space groups Matomes and directly filed Items. The visible create dialog asks
for a name and creates a local Drift Space; it does not offer cloud creation or
call Core. A local tile can then “Turn on sync.” After confirmation, promotion
creates the Core Space, atomically rekeys local references, drains eligible
Matomes/Items idempotently, and reports `cloud` or an internal resumable failure
state. The current screen reloads after promotion but does not expose detailed
failure/resume status. Space lists can open full-screen detail or, at expanded
width with the feature enabled, preview their real Matome table in a reading pane.

## Actors
- **Primary:** User managing and promoting Spaces.
- **Secondary:** Core API and Object Storage (engaged only during promotion/sync).

## Preconditions
- User is signed in.
- For promotion, a local space with items exists.

## Main flow
1. User enters a non-blank name; the app creates a local Space in Drift and
   reloads the directory.
2. User lists spaces (name plus matome count) and opens a space detail.
3. A long-press delete clears `workspaceId` from directly filed Items and removes
   the local Space row. The current DAO does not explicitly clear
   `matomes.spaceId`; documentation must not promise every Matome is refiled.
4. User selects “Turn on sync.” The confirmation shows the Space name and an
   aggregate Matome/Item count. On consent, the service creates the Core Space,
   atomically rekeys Matome and direct-Item references, drains sync work, and
   checks whether every remaining Item has a Core identity.

## Alternate & exception flows
- Dismissing the consent dialog makes no change.
- A partial failure returns `PromotionFailed` from the service and a repeated
  service call is idempotent. The current screen ignores that result and offers
  no explicit failed/resume UI after reload.
- Promotion is one-way; there is no cloud-to-local demotion in v1.
- The state is re-derived from `is_local` plus each item's `coreId`; there is no separate promotion-state column.

## Sequence
```mermaid
sequenceDiagram
  participant User
  participant App as SpacePromotionService / WorkspacesDao
  participant Gate as SyncPolicy gate
  participant Core as Core API
  participant Store as Object Storage
  User->>App: create space with non-blank name
  App->>App: INSERT local Drift space
  User->>App: promote local space
  App->>User: confirm Space name + aggregate count
  User->>App: consent
  App->>Core: POST /api/spaces
  App->>App: atomically re-key local references
  loop per item not yet on Core
    App->>Gate: can caller spaceSync space
    App->>Core: POST create or assign item
    App->>Store: PUT upload item file
  end
  App-->>User: reload tile; service result is cloud or failed
```

## Requirements satisfied
| Requirement | What it covers |
|---|---|
| **FR-SPC-1** | Create a named local Space in Drift; cloud creation occurs only through later promotion. |
| **FR-SPC-2** | In the enabled local-first lane, a local Space's Items do not sync while they remain in it. |
| **FR-SPC-3** | A cloud Space's items sync to Core. |
| **FR-SPC-4** | List Spaces (name + matome count) and open a Space detail. |
| **FR-SPC-5** | Delete a local Space after clearing directly filed Item references; the current DAO does not explicitly refile Matomes. |
| **FR-SPC-6** | Promote local → cloud after confirmation; Core create/rekey/drain is idempotent, while detailed failed/resume UI remains absent. |
| **FR-SPC-7** | Sync eligibility flows through one operation-keyed gate — no inline `if isCloud`, no role enum. |
| **FR-ORG-7** | In the enabled local-first lane, only a cloud effective Space permits sync. |
| **NFR-SYNC-3** | One resolver, one gate — no second predicate. |
| **NFR-SYNC-4** | Two axes never collapse (`is_local` ⟂ `space_type`; local ⟹ personal, org ⟹ cloud). |
| **NFR-SYNC-5** | Accepted local-only data-loss risk and the promotion egress boundary remain explicit; current consent copy shows an aggregate count. |
| **FR-PRF-6** | Spaces obey their independently persisted reading-pane mode on expanded layouts. |
| **NFR-SEC-2** | Object storage reached only via short-lived Core-issued presigned URLs (per-item upload). |

## Code anchors
- `apps/flutter/lib/features/spaces/space_promotion.dart` — `SpacePromotionService`, `PromotionState`: consent, per-item idempotent create/upload, resume.
- `apps/flutter/lib/core/db/daos/workspaces_dao.dart` — `WorkspacesDao.promoteToCloud`: the atomic local-to-cloud re-key.
- `apps/flutter/lib/features/spaces/spaces_controller.dart` — local Drift list/create/delete.
- `apps/flutter/lib/features/spaces/spaces_repository.dart` — Core Space creation during promotion.
- `apps/flutter/lib/features/spaces/sync_policy.dart` — `SyncPolicy`: the operation-keyed gate.
- `services/api/lib/.../router.ex` — Core `/api/spaces` endpoints.

The service-level promotion state is resumable/idempotent, but that must not be
confused with a complete user-visible recovery flow in the current screen.
