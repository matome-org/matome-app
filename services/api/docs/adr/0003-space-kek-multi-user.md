# ADR 0003: Multi-user Space-KEK (wrapper slot `0x05`)

## Status

Accepted (design). Implementation is plan `p2-core-backoffice` W9 (#1877).

**Related:**
- ADR-0002 — envelope hierarchy (DEK / KEK / FEK); this ADR extends it.
- Wire format: `.docs/internal/at-rest-key-flow.md` Appendix A (`wrapper_type = 0x05`).
- Permission vs crypto: §9.4 — admin manages membership; clients complete key-share.
- Core spaces schema: `docs/spaces-two-axis-reconcile.md` (W8).

## Context

Single-user cloud spaces encrypt under the owner's personal DEK (ADR-0002).
Shared / org spaces need **multiple members** to decrypt the same ciphertext
without giving Core (or an admin) plaintext keys.

Appendix A already reserved `wrapper_type = 0x05` (space-KEK) but left the
protocol undesigned. W9 cannot ship key-share UX against an empty slot.

## Decision

### Hierarchy

```
owner DEK ──wraps──► Space-DEK (per space, random 256-bit)
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
   wrap(Space-DEK,   wrap(Space-DEK,  wrap(Space-DEK,
        memberA-pub)      memberB-pub)     memberC-pub)
         = space-KEK wrap (payload_type=0x01, wrapper_type=0x05)
```

- **Space-DEK** — one random 256-bit key per encrypted multi-user space.
  Encrypts that space's FEKs / SQLCipher partition the same way a personal
  DEK does for single-user data. Never sent to Core in clear.
- **space-KEK wrap** — AES-256-GCM wrap of the Space-DEK under a
  **member-specific wrapping key** derived from that member's device/public
  material (v1: X25519 ECDH shared secret between sharer's ephemeral key and
  member's enrolled `device_pubkey` / keybundle public key). Wire layout is
  the frozen 64-byte blob with `wrapper_type = 0x05` (no `format_version` bump).
- **Personal spaces** keep using the owner's DEK; no Space-DEK is minted
  until the space becomes `shared`/`org` *and* E2E sharing is enabled.

### Who holds what

| Actor | Holds | Can decrypt space content? |
| --- | --- | --- |
| Space owner (client) | Space-DEK in memory after unlock; wraps for members | Yes |
| Existing member (client) | Own space-KEK wrap → unwraps Space-DEK | Yes |
| New member (pre-share) | Membership row only | **No** |
| Admin / Core | `space_members` permission list; ciphertext blobs | **No** |

Admin grant → permission only. Crypto access requires an existing member's
client to produce a `0x05` wrap for the new member and upload it.

### Storage (Core)

New table `space_key_wraps` (additive, W9 migration):

| Column | Notes |
| --- | --- |
| `workspace_id` | FK → `workspaces` |
| `user_id` | Recipient |
| `wrapper_blob` | base64 64-byte wrap (`0x05`) |
| `ephemeral_pubkey` | Sharer's ephemeral X25519 pub (32 bytes, base64) |
| `alg_id` | `0x01` AES-256-GCM (matches Appendix A) |
| `created_by` | Sharer user id |
| `revoked_at` | Soft revoke (membership revoke should set this) |

Core stores wraps as opaque bytes — zero-knowledge. Revoking membership
marks the wrap revoked; clients refuse to use revoked wraps. Re-key
(optional later): owner rotates Space-DEK and re-wraps remaining members.

### API surface (W9)

- `GET /api/spaces/:id/key-wraps` — caller's own wrap (if any).
- `PUT /api/spaces/:id/key-wraps/:user_id` — owner/admin-member uploads a wrap
  for `user_id` (must already be an active `space_members` row).
- `DELETE /api/spaces/:id/key-wraps/:user_id` — revoke wrap (membership revoke
  cascades).

Authz: membership role gates these routes; Core never inspects ciphertext.

### Client key-share UX

1. Admin (or owner) adds `space_members` row (permission).
2. Owner/member client sees "pending key share" for members without a wrap.
3. Client ECDH-wraps Space-DEK → `PUT` wrap.
4. New member unlocks personal DEK, fetches wrap, unwraps Space-DEK, opens space.

### Invariants

- `local ⟹ personal` still holds; local spaces never get Space-DEK / wraps.
- `org` / `shared` cloud spaces **may** use Space-DEK; personal cloud may stay
  on owner DEK until explicitly converted.
- Changing Appendix A layout requires a new `format_version` — **not** this ADR.
  Slot `0x05` is used as reserved; no version bump.

## Consequences

- W9 entry gate cleared once this ADR is merged.
- Membership enforcement (permission) can land independently of wrap upload;
  key-share is a second commit behind this design.
- Passkey-KEK (`0x04`) remains out of scope.
- Future: Space-DEK rotation, offline share via QR, org escrow — deferred.

## Alternatives considered

1. **Server-side space key** — rejected (breaks zero-knowledge §9.4).
2. **Re-encrypt all blobs per member** — rejected (O(n) media cost).
3. **Share owner's DEK** — rejected (over-shares every personal space).
