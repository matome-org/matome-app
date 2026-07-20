# Spaces two-axis reconcile (#102 → Core W8)

**Status:** accepted before W8 migration `20260710000000_add_workspace_two_axis_quota_lifecycle_members.exs`.

## Physical name

| Layer | Name |
| --- | --- |
| Postgres / Ecto | `workspaces` (unchanged) |
| Flutter Drift | `workspaces` (unchanged) |
| Product / admin UI | Space |

No rename to `spaces`. W8 quota/lifecycle/members columns land on `workspaces`.

## Two axes (architecture §5)

| Axis | Column | Values | Meaning |
| --- | --- | --- | --- |
| **A — sync** | `is_local` | boolean | local ⟹ never sync; cloud ⟹ sync |
| **B — tenancy** | `space_type` | `personal` \| `shared` \| `org` | who owns it |

Orthogonal — never collapse into one enum.

### Core vs Flutter defaults

| | Flutter (client) | Core (server) |
| --- | --- | --- |
| `is_local` default | `true` (local-first) | `false` (only cloud rows exist here) |
| `space_type` default | `personal` | `personal` |

Local spaces never reach Core. Every Core `workspaces` row is a **cloud** space (`is_local = false`) unless an admin explicitly marks otherwise (unsupported for sync; kept for schema parity).

### Invariants (changeset + DB check)

- `is_local = true` ⟹ `space_type = 'personal'`
- `space_type = 'org'` ⟹ `is_local = false`

## W8 additive columns (same migration)

| Column | Role |
| --- | --- |
| `quota_bytes` | Soft ceiling; `NULL` = unlimited |
| `used_bytes` | Ciphertext bytes reserved/committed (default 0) |
| `expires_at` | Optional expiry; Oban drives lifecycle |
| `status` | `active` → `suspended` → `archived` → `deleted` |

New table `space_members` (`workspace_id`, `user_id`, `role`, `granted_at`, `revoked_at`).

## Quota enforcement point

Reservation runs inside `Content.create_file_item/3` (the API path that creates the blob row before the client `PUT`s ciphertext). Incoming size is client-declared `content_length` / `byte_size` (ciphertext). Over-quota → `{:error, :quota_exceeded}` → HTTP **413**. Concurrent uploads serialize on `SELECT … FOR UPDATE` of the workspace row.
