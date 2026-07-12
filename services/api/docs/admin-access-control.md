# /admin access control — email-OTP gate

Plan `p2-core-backoffice` §9.1, revised: **email allowlist + one-shot email OTP**
replaces password + authenticator TOTP. Staff identity does **not** require a
`users` row.

## Assets

- Admin capability (sessions revoke, future mutations).
- The audit trail (`admin_audit_events`).
- Metadata visible in Users / Audit / Sessions LiveViews.

## Layers (defense in depth)

| # | Layer | Enforced by | Failure mode |
|---|-------|-------------|--------------|
| 1 | Panel kill switch | `ADMIN_PANEL_ENABLED` via `AdminNetworkGuard` | **Fail closed**: unset/`false` in prod ⇒ every `/admin*` is 404 |
| 2 | Soft IP tier | `ADMIN_IP_ALLOWLIST` (optional) | Empty ⇒ all IPs reach the panel. Non-empty ⇒ IPs outside still allowed but under **stricter** per-IP rate limits (corporate laptop / no VPN) |
| 3 | Email allowlist | `ADMIN_EMAIL_ALLOWLIST` CSV | Non-members get **total silence** on `POST /admin/login` (200 re-render, no flash, no mail, no redirect) |
| 4 | Email OTP | `Admin.request_login_otp/2` + `verify_login_otp/2` | 6-digit code, SHA-256 at rest, 30-min TTL, one-shot consume; wrong code audited as `admin.login_failed` |
| 5 | Session | `MatomeApiWeb.AdminAuth` | Cookie session keyed by `admin_email`; absolute TTL (default 30 min); no sliding renewal |
| 6 | Sensitive re-auth | OTP freshness (`admin_otp_verified_at`, default 5 min) | Stale revoke → `/admin/otp?return_to=…` |
| 7 | Append-only audit | `admin_audit_events` + raise-triggers | `actor_id` nullable; `actor_email` always set from the allowlisted address |

### LiveView

`AdminAuth.on_mount/4` re-checks panel enabled + email allowlist + TTL. Soft IP
is not a hard deny on the websocket (rate limits apply on HTTP POSTs only).

## Env contract

| Var | Role |
|---|---|
| `ADMIN_PANEL_ENABLED` | `true`/`1` to expose `/admin`. Prod default off. Dev default on. |
| `ADMIN_EMAIL_ALLOWLIST` | CSV emails (lowercased). Empty ⇒ nobody can complete OTP. |
| `ADMIN_IP_ALLOWLIST` | Soft CIDR tier for rate limits only. |
| `ADMIN_TRUSTED_PROXIES` | CIDRs that may supply `X-Forwarded-For`. |
| `ADMIN_SESSION_TTL_SECONDS` | Absolute session TTL (default `1800`). |
| `MAILER_ADAPTER` | Prod: `mailgun` or `smtp` (Local disabled). Dev: Swoosh Local + `/dev/mailbox`. |

## Login flow

1. `GET /admin/login` — email only (W1 `text_field` + `submit_button`).
2. `POST /admin/login` — if allowlisted, store OTP hash, email code, redirect `/admin/otp`; else silence.
3. `POST /admin/otp` — verify one-shot code → session → `/admin`.

Dev: read the code at `http://127.0.0.1:7001/dev/mailbox`.

## Operational notes

- **No DB role promotion** for panel access — put the staff address in
  `ADMIN_EMAIL_ALLOWLIST` and redeploy/restart with the new env.
- **Revoking access** — remove the email from the allowlist; mid-flight
  sessions fail the next mount (`email_allowed?` re-check).
- **TOTP / `users.role` / SecretVault** — leftover from the prior gate; unused
  by login. App-user MFA badges in the Users directory may still read
  `totp_secrets` rows if present.
