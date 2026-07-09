# Session metadata — data minimization & retention (W4 #1872)

Plan `p2-core-backoffice` §9.5. Companion to
[`admin-access-control.md`](./admin-access-control.md) (W3). Status:
**policy defined with capture**; the enforcement job ships with the first
consumer wave (W5/W6) — see "Enforcement" below.

## What is collected, and why

W4 widened the correlation surface the plan's §6 warns about: `ip`,
`user_agent` and a per-user device identifier are now stored per session.
Each datum exists for exactly one purpose — letting a user (and an admin,
W6) recognise *"is this session/device mine?"* and revoke what is not
(W5). Nothing here feeds analytics, profiling, or ranking.

| Datum | Where | Source | Purpose |
|---|---|---|---|
| `ip` | `refresh_tokens.ip` | `NetworkPolicy.client_ip/3` (trusted-proxy resolution; unresolvable ⇒ `NULL`, never attacker input) | "Session from an unexpected place" recognition |
| `user_agent` | `refresh_tokens.user_agent`, `devices.user_agent` | `User-Agent` header, verbatim | Session/device recognition; fallback correlation key |
| `client_id` | `devices.client_id` | Client-generated stable UUID (`device.id` in the login body), optional | Device correlation without fingerprinting |
| `platform`, `display_name` | `devices` | Client-sent, optional | Human-readable device labels for the sessions view |
| `login_method`, `jti`, `family_id`, `rotated_from`, `last_seen_at`, `revoked_at` | `refresh_tokens` | Server-generated | Rotation chain, replay detection (W5), sessions view (W6) |

Deliberate non-collection:

- **No geolocation**, no IP-derived city/country is stored or looked up.
- **No fingerprinting**: the device identifier is client-*declared*, not
  derived from hardware/canvas/etc. A client that sends nothing degrades
  to coarse user-agent correlation — worse UX in the sessions view, by
  design, not compensated by covert identification.
- **IP is per-token only**, never copied onto `devices` — a device row
  outlives sessions, and a long-lived IP history per device would be a
  movement profile.

## Retention rules

| Data | Bound | Rationale |
|---|---|---|
| Active refresh-token rows (incl. ip/ua) | Life of the token: ≤ 30 days (`@refresh_ttl`), sliding via rotation | The session itself is the purpose |
| Expired/revoked/rotated token rows | **60 days after `expires_at`/`revoked_at`, then deleted** | Rotated rows must outlive the family enough for replay detection (W5) and "recently ended sessions" (W6); 60 days ≈ one full token lifetime of slack, after which a replayed JWT is expired anyway and the row is pure liability |
| `devices` rows | **Deleted when the user's last token referencing them is gone AND `last_seen_at` is > 180 days old** (unless `device_key_enrolled` — then kept until explicitly revoked, since the row anchors an E2E device key) | A returning seasonal device should still be recognisable; half a year of inactivity without an enrolled key means the label has no session left to explain |
| Everything, on account deletion | Immediate: `users` cascade (`on_delete: :delete_all`) removes tokens and devices in the same transaction | Erasure must not depend on a sweeper |
| Logout / password reset | Immediate hard delete of the affected token rows (existing behavior, kept) | The user asked for the session to be gone; minimization wins over history |

`revoked_at` (tokens *and* devices) is the W5 revocation seam: revocation
sets it, capture never does, and revoked rows ride the same 60-day/180-day
deletion bounds above — revocation is not an archive.

## Enforcement

The bounds above are enforced by a periodic prune job (Oban, daily):

```sql
DELETE FROM refresh_tokens
 WHERE COALESCE(revoked_at, expires_at) < now() - interval '60 days';

DELETE FROM devices d
 WHERE d.device_key_enrolled = false
   AND d.last_seen_at < now() - interval '180 days'
   AND NOT EXISTS (SELECT 1 FROM refresh_tokens t WHERE t.device_id = d.id);
```

The job lands with W5 (it belongs with revocation, whose replay window it
bounds); until then volumes are tiny (rotated rows accrue one per refresh)
and the SQL above is runnable out-of-band. **This is a recorded gap, not a
decision to keep data indefinitely.**

## Access

- No API or admin surface exposes these columns yet. W6 (sessions
  LiveView) will show a user's own sessions/devices behind the full W3
  admin gate (network allowlist → role → TOTP → audit); every admin read
  of another user's session metadata must be audited via
  `admin_audit_events` like any other admin action.
- Raw `ip`/`user_agent` never appear in application logs as part of this
  capture path (nothing is logged on login beyond what Phoenix already
  logs).

## Revisit triggers

Re-open this policy when: W5/W6 land (activate the prune job — remove the
gap note above), orgs/SSO arrive (plan #102 seams — org policies may
demand *longer* session history), or a jurisdiction-specific retention
requirement appears.
