# Token revocation contract (W5 #1873)

Per-request revocation for access tokens: a revoked session's access token
stops working on the **next authenticated request**, not at `exp`. This
document is the contract for how a token is bound to its session, how the
per-request check resolves, its caching/invalidation semantics, the
staleness bound, and the rollout runbook.

Plan: p2-core-backoffice, Wave 5. Builds on W4 (#1872: `jti` / `family_id` /
`revoked_at` on `refresh_tokens`, `devices` table).

## 1. Claims binding (access token → session row)

`MatomeApi.Auth.issue_tokens/2` mints the **refresh token first** and embeds
its Guardian `jti` — the same value stored on the `refresh_tokens` row — into
the access token as the **`sid` claim**:

```
access_token.claims["sid"] == refresh_tokens.jti  (the session's live row)
```

- Every login/refresh/register/password-reset issues the pair atomically, so
  every access token minted after this wave carries `sid`.
- An access token **without** `sid` (minted before this wave) cannot be
  correlated to a session and is **denied** under `:enforce`
  (`:missing_binding`). Access TTL is 15 minutes, so waiting one TTL after
  deploying the binding drains these (see runbook).
- Rotation consequence: refreshing revokes the presented refresh row
  (`revoked_at` set) and mints a successor row + new pair. The **old access
  token** (bound to the rotated-out `jti`) is therefore denied under
  `:enforce` as soon as the rotation lands. Clients must swap both tokens
  atomically on refresh; `:shadow` mode surfaces violators in logs before
  anything breaks.

## 2. Row shape and revocation writes

The allowlist **is** the `refresh_tokens` table (no extra table): one row per
session generation, keyed by `jti` (indexed, migration `20260709120000`).

| column       | role in revocation                                    |
|--------------|-------------------------------------------------------|
| `jti`        | lookup key; equals the access token's `sid` claim     |
| `revoked_at` | `NULL` = live; set = revoked (rows retained, not deleted — W4 audit seam) |
| `family_id`  | logical session: login mints one, refreshes inherit it |
| `user_id`    | disconnect target (`user_socket:<user_id>`)           |

Revocation writers (all soft — `revoked_at := now()`, then per-jti cache
invalidation, then socket disconnect):

- **`Auth.logout/1`** — revokes every live row in the presented token's
  family (pre-W4 rows without `family_id`: just that row).
- **`Auth.refresh/2`** — rotation revokes the presented row and invalidates
  its `jti` (successor row is live).
- **`Auth.reset_password/3`** — revokes every live row for the user, then
  issues the fresh session.

## 3. Lookup order (per request)

`MatomeApi.Auth.verify_access_token/1` — the single choke point used by both
`MatomeApiWeb.Plugs.RequireAuth` (every authenticated HTTP request) and
`MatomeApiWeb.UserSocket.connect/3` — runs, in order:

1. Guardian `decode_and_verify` (signature, `exp`, `typ == "access"`).
2. `TokenAllowlist.check(claims["sid"])`, which resolves:
   1. **ETS cache** `:matome_token_allowlist` (public table owned by the
      supervised `TokenAllowlist.Cache` GenServer). Entry fresher than
      `cache_ttl_ms` → answer from cache.
   2. **Database** (cache miss/stale/disabled): `refresh_tokens` by `jti`,
      `SELECT id, revoked_at LIMIT 1` on the indexed column.
      - no row → `:unknown` → **deny** (hard allowlist: absent means not
        allowed)
      - `revoked_at IS NULL` → `:active` → allow
      - `revoked_at` set → `:revoked` → deny
      The result is written back to the cache (all three statuses cache;
      revocation never un-happens, and `:unknown` cannot become known —
      rows are inserted before the token pair is ever returned).
3. `resource_from_claims` (user load).

**Cold-cache behavior:** first check after boot/crash/TTL pays one indexed
DB read per distinct `jti`, then serves from ETS. A crash of the Cache owner
drops the whole table; the allowlist then degrades to per-request DB reads
(never to a bypass) until entries repopulate.

## 4. Fail-closed

Any allowlist lookup failure (DB down, query error — anything raised)
returns `{:denied, :unavailable}`:

- `:enforce` → the request is **rejected** (401). An outage narrows access,
  never widens it. This is deliberate: the allowlist gate must not have a
  fail-open path an attacker can induce.
- Failures are **never cached**, so recovery is immediate on the next
  request once the DB is back.
- The failure is logged (`token_allowlist lookup failed (fail-closed, ...)`).

## 5. Cache invalidation and the staleness bound

- Revoke → `TokenAllowlist.invalidate(jti)`: deletes the local ETS entry
  synchronously (this node is consistent immediately) and broadcasts
  `{:token_allowlist_invalidate, jti}` on Phoenix.PubSub topic
  `"token_allowlist"`; every node's Cache GenServer deletes its entry.
- **Bounded staleness:** a node that misses the broadcast (partition,
  restart race) answers from its cached `:active` entry for at most
  **`cache_ttl_ms` (default 30s)** past revocation, after which the entry is
  stale and the DB is re-read. Worst-case acceptance of a revoked token on a
  broadcast-missing node is therefore ≤ 30s — the stated bound. Tighten by
  lowering `cache_ttl_ms` (more DB reads) or set `cache: false` (zero
  staleness, every request reads the DB).

## 6. Remote-lock signal (socket disconnect)

Every revocation path broadcasts `"disconnect"` on the user's socket id
topic (`UserSocket.id/1` = `"user_socket:<user_id>"`), which Phoenix socket
transports honor by terminating all of the user's connections — same-jwt
reconnects then fail at `connect/3` under `:enforce`. **Client contract
(out of scope here, §9.3 of the E2E design): on this disconnect the client
drops its in-memory DEK**, completing the remote lock.

## 7. Configuration (feature flag)

```elixir
# config/config.exs
config :matome_api, MatomeApi.Auth.TokenAllowlist,
  mode: :off,          # :off (dark, default) | :shadow | :enforce
  cache: true,         # false = revert to no-cache path (per-request DB read)
  cache_ttl_ms: 30_000 # staleness bound for missed invalidations
```

- `:off` — no allowlist work at all (pre-W5 behavior). Default.
- `:shadow` — runs the full check on every request and logs would-be
  denials (`token_allowlist shadow: would deny ... reason=... sid=... sub=...`)
  but **never rejects**. Adds the same latency as `:enforce`.
- `:enforce` — denials are 401s; fail-closed active.

**Core does not hot-reload config** (`services/api/config/*.exs` changes
require killing :4000 and `mise run backend` — auth 500s otherwise).

## 8. Latency budget

Steady-state added cost per authenticated request is one ETS lookup.
**Budget: p99 < 1ms on the ETS-hit path.** Measured by
`test/matome_api/auth/token_allowlist_bench_test.exs` (10k samples,
`:timer.tc`, asserts the budget): **p50 = 0µs, p99 = 1µs** on the dev
machine — roughly three orders of magnitude inside budget. The cold path
adds one indexed single-row read per distinct token per TTL window.

## 9. Rollout runbook

1. **Deploy dark** (`mode: :off`, the default). Claims binding is already
   live: all newly minted access tokens carry `sid`. No request-path change.
2. **Wait ≥ 1 access TTL (15 min)** so every live access token has `sid`.
3. **Shadow**: set `mode: :shadow`, restart Core. Watch logs for
   `token_allowlist shadow: would deny`. Expected noise sources: clients
   holding the pre-refresh access token after rotating (see §1), tokens
   minted before the binding deploy. Zero (or explained) shadow denials over
   a comfortable window is the gate to enforce.
4. **Enforce**: set `mode: :enforce`, restart Core. The char-test behavior
   is now live: logout/reset revocation 401s the session's access token on
   its next request.
5. **Revert paths** (each needs a restart):
   - Latency/DB pressure from the cache layer → `cache: false` keeps
     enforcement with zero staleness at one DB read per request (tested).
   - Enforcement regression (lockouts) → `mode: :shadow` (keeps telemetry)
     or `mode: :off` (full pre-W5 behavior). Revocation **writes** (soft
     revoke, invalidation, disconnect) are flag-independent and keep
     running, so re-enabling later loses nothing.

## 10. Invariants (tested)

- Char-test: `revoked_at` set (logout) → next request with the same,
  still-unexpired access token → 401 (`require_auth_revocation_test.exs`).
- Revoke busts the ETS entry — no stale-cache bypass (`token_allowlist_test.exs`).
- Fail-closed under lookup failure; failures never cached.
- TTL-stale entries re-read the DB (the staleness bound in action).
- `cache: false` revert path denies immediately with no invalidation traffic.
- Socket connect refuses revoked sessions; revocation broadcasts the
  disconnect remote-lock signal.
- With `mode: :off` (default) the entire pre-W5 suite passes unchanged.
