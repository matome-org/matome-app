# /admin access control — email-OTP gate

Plan `p2-core-backoffice` §9.1, revised: **email allowlist + one-shot email OTP**
replaces password + authenticator TOTP. Staff identity does **not** require a
`users` row.

## Assets

- Admin capability (sessions revoke, future mutations).
- Security-class rows in the canonical `events` trail.
- Metadata visible in Users / Audit / Sessions / Events / Event Catalog / System Settings LiveViews.

## Layers (defense in depth)

| # | Layer | Enforced by | Failure mode |
|---|-------|-------------|--------------|
| 1 | Panel kill switch | `ADMIN_PANEL_ENABLED` via `AdminNetworkGuard` | **Fail closed**: unset/`false` in prod ⇒ every `/admin*` is 404 |
| 2 | Soft IP tier | `ADMIN_IP_ALLOWLIST` (optional) | Empty ⇒ all IPs reach the panel. Non-empty ⇒ IPs outside still allowed but under **stricter** per-IP rate limits (corporate laptop / no VPN) |
| 3 | Email allowlist | `ADMIN_EMAIL_ALLOWLIST` CSV | Non-members get **total silence** on `POST /admin/login` (200 re-render, no flash, no mail, no redirect) |
| 4 | Email OTP | `Admin.request_login_otp/2` + `verify_login_otp/3` | 6-digit CSPRNG code, HMAC-SHA-256 with `ADMIN_OTP_PEPPER` at rest, 30-min TTL, one-shot consume; wrong code audited as `admin.login_failed` |
| 5 | Session | `MatomeApiWeb.AdminAuth` | Cookie session keyed by `admin_email`; absolute TTL (default 30 min); no sliding renewal |
| 6 | Sensitive re-auth | OTP freshness (`admin_otp_verified_at`, default 5 min) | Every session, Space, operational, or configuration mutation fails closed when stale; LiveView redirects to `/admin/otp?return_to=…` |
| 7 | Transactional audit | canonical `events` + `Ecto.Multi` + append-only triggers | Every privileged database mutation and mandatory event commit together; event failure rolls back the action |

### LiveView

`AdminAuth.on_mount/4` re-checks panel enabled + email allowlist + TTL. It also
resolves the client address from LiveView `peer_data` and `X-Forwarded-For`, but
honors forwarding headers only when the direct peer belongs to
`ADMIN_TRUSTED_PROXIES`. HTTP login, rate limiting, and LiveView events use the
same policy. An invalid forwarded chain fails closed.

The context layer repeats allowlist and OTP-freshness checks at mutation time;
UI checks are not the authorization boundary. `users.role` is not consulted.

## Env contract

| Var | Role |
|---|---|
| `ADMIN_PANEL_ENABLED` | `true`/`1` to expose `/admin`. Prod default off. Dev default on. |
| `ADMIN_EMAIL_ALLOWLIST` | CSV emails (lowercased). Empty ⇒ nobody can complete OTP. |
| `ADMIN_OTP_PEPPER` | Production-only secret used as the HMAC-SHA-256 key for OTP verification. Required, at least 32 bytes, and independent from cookie/JWT keys. Rotation invalidates outstanding codes. |
| `ADMIN_IP_ALLOWLIST` | Soft CIDR tier for rate limits only. |
| `ADMIN_TRUSTED_PROXIES` | CIDRs that may supply `X-Forwarded-For`. |
| `ADMIN_SESSION_TTL_SECONDS` | Absolute session TTL (default `1800`). |
| `MAILER_ADAPTER` | Prod: `mailgun` or `smtp` (Local disabled). Dev: Swoosh Local + `/dev/mailbox`. |

## Login flow

1. `GET /admin/login` — email only (W1 `text_field` + `submit_button`).
2. `POST /admin/login` — if allowlisted, store OTP hash, email code, redirect `/admin/otp`; else silence.
3. `POST /admin/otp` — verify one-shot code → session → `/admin`.

OTP consumption and the successful login/reauth event share one transaction.
If the mandatory event cannot be stored, the code remains unconsumed and no
admin session is established.

## Privileged events

Session and Space controls use versioned security events whose scalar details
include bounded `before` and `after` state. Targets live in indexed
`subject_type`/`subject_id` columns; actors and proxy-derived IPs are mandatory
at the context seam. Snapshots contain only control-plane policy fields, never
workspace names, user content, tokens, local paths, or signed URLs.

Sensitive cross-user reads of Dashboard, Users, Sessions, Spaces, individual
Space metadata, Audit data, and paginated Events data append
`security.admin.sensitive_read.v1`. A
failed required read event prevents the result from being returned.

The Event Catalog renders locked rows as read-only. Optional enablement and
retention changes re-check both the current allowlist and OTP freshness in the
context, then commit policy and `security.event_catalog.changed.v2` in one
transaction. The Events security saved view fixes the class filter to
`security`; submitted filter params cannot widen it.

System Settings at `/admin/settings` exposes only the closed, non-secret v1
policy. Pause/resume, desired local AI Oban concurrency, client lease/retry
bounds, upload thresholds, processing kinds/timeouts, and reporting intervals
all re-check the allowlist and recent OTP at the context seam. Updates use the
displayed revision as compare-and-swap input and commit with
`security.admin_config_changed.v2`, whose bounded `before`/`after` values are
policy only. Tokens, credentials, signing material, storage URLs, and service
endpoints are not fields and remain runtime environment configuration.

Phoenix filters credential, OTP, content, local-path, and presigned-credential
parameter names before request logging. `MatomeApi.LogRedaction` is the fallback
for already-materialized exception text and never reads a raw request body.

Dev: read the code at `http://127.0.0.1:7001/dev/mailbox`.

## Operational notes

- **No DB role promotion** for panel access — put the staff address in
  `ADMIN_EMAIL_ALLOWLIST` and redeploy/restart with the new env.
- **Revoking access** — remove the email from the allowlist; mid-flight
  sessions fail the next mount (`email_allowed?` re-check).
- **TOTP / `users.role` / SecretVault** — leftover from the prior gate; unused
  by login. App-user MFA badges in the Users directory may still read
  `totp_secrets` rows if present.
