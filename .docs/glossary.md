# Matome — ubiquitous language

Canonical terms for the Matome-centric model. Use these exact identifiers in
code, commits, PR titles, and docs so `git log --grep` and search stay reliable.
See ADR-0003 (entity) and ADR-0004 (identity/permissions/triage).

| Term | Canonical code id | Meaning |
| --- | --- | --- |
| **Matome** (entity) | `Matome` | The central unit: a fixed-structure "page" aggregating items + contacts + summaries + notes about one happening. NOT the same as the brand. |
| **Matome** (brand) | `Matome*` prefix (`MatomeColors`, `MatomeThemeContext`) | App/theme namespace. Pre-existing; never collapse into the entity. |
| **Space** | `Space` (table stays `workspaces`) | The Notion-*workspace* analogue: a container of Matomes. `type` = personal \| shared \| org. Logical rename of the legacy `workspace`. |
| **workspace** | `workspaces` table / `workspaceId` | Legacy *internal* name for Space. Physical table + FK keep this name (ADR-0003); display/code concept is `Space`. |
| **Inbox** | `spaceId == null` | A Matome's untriaged state: local-only, not synced (except web, which is server-backed). Not a table — a derived state. |
| **Triage** | — | The act of enriching a Matome (photos/notes/contacts/share) and filing it into a Space (default: personal). The trigger that ends local-only and starts sync. |
| **Item** | `recordings` row, `mediaType` audio\|image | A child of a Matome. Audio clip or photo. `recording.matomeId` FK. |
| **Recording summary** | `Recording.summary` | Per-item AI summary (single field). |
| **Aggregated summary** | `Matome.aggregatedSummary` | Stored, regenerated, Matome-level summary across its items (ADR-0003). |
| **Contact** | `Contact` (`contacts` table) | Owner-owned person record: `ownerId`, `displayName`, arbitrary `metadata`, optional `linkedUserId`. |
| **Linked user** | `contact.linkedUserId` → `users` | A Contact resolved to a real platform user (profile visible without consent — ADR-0004). |
| **matome_contacts** | join table | Tags a Contact in a Matome (with `role`). |
| **space_contacts** | join table | A Contact as a member of a Space. |
| **matome_shares** | join table | Shares a Matome with a user (behaviour deferred). |
| **space_members** | join table | Users + RBAC `role` (owner/admin/member/viewer) on a Space. Enforcement deferred. |
| **Organization** | `organizations` | A first-class owner of Spaces (multi-tenant). Management deferred. |
| **Personal space** | `space.type == personal` | The default triage destination for a user's Matomes. |
