# /admin access control — threat model (W3 #1871)

Plan `p2-core-backoffice` §9.1. Status: **shipped guard-first** — this gate
landed before any admin data view exists, so every later admin surface is
born behind it.

## Assets

- All user data reachable through a future admin surface (accounts, items,
  matomes, contacts, key bundles — the last are client-encrypted blobs, but
  metadata is still sensitive).
- The admin capability itself (mutations, exports, impersonation in later
  waves).
- The audit trail (its integrity is what makes every other control
  reviewable after the fact).

## Layers (defense in depth, outermost first)

| # | Layer | Enforced by | Failure mode |
|---|-------|-------------|--------------|
| 1 | Network allowlist | `MatomeApiWeb.Plugs.AdminNetworkGuard` → `MatomeApi.Admin.NetworkPolicy` | **Fail closed**: empty/missing/unparseable config denies; denials are 404 + log |
| 2 | First factor | `MatomeApi.Admin.authenticate_admin/2` (Argon2) + rate limit (`:admin_login`, per-IP + per-email) | Uniform `invalid_credentials`; unknown emails burn a dummy Argon2 pass (no timing oracle); failures audited |
| 3 | Role allowlist | `users.role ∈ (admin, superadmin)` + DB CHECK; re-checked on **every** request/mount | No signup/API path casts `role`; provisioning is out-of-band SQL only; revocation applies mid-session |
| 4 | Second factor (mandatory TOTP) | `MatomeApi.Admin.verify_totp/3` | Secret AES-256-GCM at rest (`SecretVault`; prod boots only with `ADMIN_SECRET_VAULT_KEY`); ±1 timestep skew; **replay rejected** via atomic timestep high-water mark; 5 attempts/min then 5-min lockout |
| 5 | Session | `MatomeApiWeb.AdminAuth` | Separate cookie session (not Guardian JWTs); renewed at each privilege change (fixation); **30-min absolute TTL**, no sliding renewal |
| 6 | Sensitive-action re-auth | `MatomeApiWeb.Plugs.RequireRecentTotp` | TOTP freshness ≤ 5 min or bounce to `/admin/mfa`; ready for the first data-mutating wave |
| 7 | Append-only audit | `admin_audit_events` + raise-triggers | UPDATE/DELETE/TRUNCATE raise at the DB **for every role incl. the table owner**; `Admin.audit!/2` raises on failure so actions cannot proceed unaudited |

### LiveView specifics

The websocket upgrade does not traverse the `/admin` router pipelines, so a
valid session could otherwise ride a socket opened from outside the
allowlist. `AdminAuth.on_mount/4` re-checks the session **and** re-runs the
network policy against `connect_info` (`peer_data` + `x_headers`) on every
connected mount.

## Threats → mitigations

- **Credential stuffing / password brute force** — per-IP + per-email rate
  limit on the first factor; Argon2; uniform errors; audited failures.
- **Phishing/leak of an admin password** — mandatory TOTP; password alone
  yields only a pending marker that opens nothing.
- **TOTP code interception/replay** — one-time use enforced atomically
  (`UPDATE … WHERE last_used_timestep < matched`); an observed code is dead
  the moment it is used, even across concurrent requests.
- **TOTP brute force** — 6-digit space vs 5 attempts/min + 5-min lockout
  (per user id, ETS-backed `MatomeApi.RateLimiter`).
- **DB dump / at-rest disclosure** — TOTP secrets are AES-256-GCM
  ciphertexts; key lives only in the runtime env, never in the repo or DB.
- **Session fixation / theft** — session id renewed on login; absolute TTL
  bounds any stolen cookie's usefulness; sensitive actions additionally
  demand a fresh TOTP; logout clears everything. Cookies are signed
  (tamper-proof); contents are ids + unix stamps only.
- **Privilege self-escalation** — `role` is not castable by any changeset;
  DB CHECK constrains values; registration test pins the "role param is
  ignored" behavior.
- **IP spoofing via X-Forwarded-For** — the header participates only when
  the direct peer is inside the pinned trusted-proxy CIDRs; the client is
  the rightmost hop not itself a trusted proxy, so client-prepended entries
  are never believed; unparseable chains deny.
- **Audit tampering by a compromised app/DB role** — UPDATE/DELETE/TRUNCATE
  raise via triggers (binding even the owner); rewriting history would
  require `ALTER TABLE … DISABLE TRIGGER` DDL — a louder, separately
  visible act. `REVOKE` additionally strips non-owner roles.
- **Back-office discovery/scanning** — out-of-allowlist requests get a
  bare 404; the login surface itself is inside the guard.

## Recorded gaps (explicit, tracked)

1. **Passkey/WebAuthn deferred.** The §9.1 target state includes
   phishing-resistant credentials; this wave ships TOTP only. The
   `webauthn_credentials` schema delta is partial/deferred — TOTP remains
   vulnerable to real-time phishing proxies in a way WebAuthn is not.
   Follow-up belongs to a later wave of `p2-core-backoffice`.
2. **Deploy/network topology UNDECIDED.** Whether /admin sits behind a VPN,
   which reverse proxy terminates TLS, and therefore what
   `ADMIN_IP_ALLOWLIST` / `ADMIN_TRUSTED_PROXIES` must contain, has not been
   decided. The guard ships config-driven and **fail-closed**: in prod with
   nothing configured, every /admin request is denied. Nothing must be
   "opened temporarily" to work around this — decide the topology, then
   configure it.

## Operational notes

- **Provisioning an admin** (out-of-band, by design):
  `UPDATE users SET role = 'admin' WHERE email = '…';` via a trusted DB
  path (release task/psql). First login forces TOTP enrollment.
- **Prod env contract**: `ADMIN_SECRET_VAULT_KEY` (base64, 32 bytes —
  `openssl rand -base64 32`) is REQUIRED at boot; `ADMIN_IP_ALLOWLIST` /
  `ADMIN_TRUSTED_PROXIES` are comma-separated CIDRs, empty ⇒ deny-all.
- **Rotating a TOTP factor** is deliberately not a silent overwrite
  (`{:error, :already_enrolled}`); rotation lands as an explicit,
  audited flow in a later wave. Interim: delete the `totp_secrets` row
  out-of-band; the next login re-enrolls.
- **Audit retention/erasure** (e.g. GDPR) requires a DBA acting outside
  the app role (drop/disable triggers in a maintenance window) — a
  deliberate, visible operation.
