# Data plane — Postgres + S3-compatible storage

Matome Core talks to **standard PostgreSQL** (Ecto) and an **S3-compatible
object store** (AWS4 presigned URLs). Providers are interchangeable: swap
`DATABASE_URL` and `STORAGE_S3_*` only — no code fork for Neon vs RDS, or
MinIO vs R2 vs S3.

Auth is Guardian (not a hosted auth product). Realtime status uses Phoenix
Channels. The Flutter client never holds storage credentials; it only receives
presigned URLs.

## Daily DX vs compose

Every runtime dependency runs in its own container — there is no native/host
data plane. `mise run up` is a thin wrapper over `docker compose` that seeds
`.env` and maps host ports from `dev.ports.env`.

| Path | Role |
| --- | --- |
| **`mise run up`** | Daily local stack, containerized: Postgres + MinIO + AI stub + Core + Flutter Web (`docker compose up --build -d`). |
| **`mise run backend`** | Same, minus the web container — pair with a native `mise run flutter-*` client. |
| **`mise run down` / `nuke`** | `docker compose down` (keep data) / `--volumes` (drop Postgres + MinIO data). |
| **Dockploy** | Deploys the **app** images; point env at any Postgres + any S3-compatible store. |

## Data-plane environment

| Variable | Required | Notes |
| --- | --- | --- |
| `DATABASE_URL` | yes (prod); preferred in dev/test | Ecto URL, e.g. `postgres://user:pass@host:5432/matome_api_dev` |
| `DATABASE_SSL` | no | Default `true` in prod, `false` in dev/test. Set `true` for managed Postgres. |
| `POOL_SIZE` | no | Default `10` in prod. Keep conservative behind a pooler. |
| `STORAGE_S3_ENDPOINT` | yes (prod) | **Browser-reachable public base URL** baked into every presigned PUT/GET. Never an internal Docker hostname (`http://minio:9000`). Local example: `http://127.0.0.1:7021`. |
| `STORAGE_S3_INTERNAL_ENDPOINT` | no | Core-reachable S3 base URL for multipart control, HEAD, verification GET, and cleanup. Defaults to `STORAGE_S3_ENDPOINT`; Compose uses `http://minio:9000`. Never returned to clients. |
| `STORAGE_S3_ACCESS_KEY_ID` | yes (prod) | Access key for the object store. |
| `STORAGE_S3_SECRET_ACCESS_KEY` | yes (prod) | Secret key. |
| `STORAGE_S3_REGION` | no | Default `local`. Use the provider region (e.g. `auto` for R2, `us-east-1` for S3). |
| `STORAGE_MEDIA_BUCKET` | no | Default `media`. |
| `STORAGE_UPLOAD_URL_TTL` | no | Seconds; default `900`. |
| `STORAGE_DOWNLOAD_URL_TTL` | no | Seconds; default `300`. |

## Verified upload lifecycle

File items retain one stable `owners/{owner_id}/items/{uuid}` key and move
through `pending`, `uploading`, then provider-verified `uploaded` (or terminal
`failed`/`aborted`). Small files keep the existing single presigned PUT. The
25 MiB boundary selects multipart rather than rejecting larger audio; Core still
enforces media-specific limits, Space quota, the 2 GiB application limit, and
S3-compatible provider bounds.

Authenticated v1 routes are owner-scoped and return `404` across owners:

| Operation | Route |
| --- | --- |
| Create/resume | `POST /api/v1/items/{item_id}/uploads` |
| Inspect accepted/missing parts | `GET /api/v1/uploads/{upload_id}` |
| Presign one missing part | `POST /api/v1/uploads/{upload_id}/parts/{part_number}/presign` |
| Verify and complete | `POST /api/v1/uploads/{upload_id}/complete` |
| Abort and clean | `POST /api/v1/uploads/{upload_id}/abort` |

Multipart progress is provider state plus one bounded `file_blobs.multipart_context`
JSONB value; there is no upload-session table or node-local session. Core restart
therefore resumes the same generation by listing provider parts. Expired part
URLs are refreshed without replacing accepted parts. The persisted Oban cleanup
job aborts a context after 24 hours by default, and explicit abort is idempotent.

Completion compares contiguous part numbers, exact part sizes, provider ETags,
and provider-verified part SHA-256 values before assembling. It then HEADs the
object and compares exact total size plus SHA-256 metadata/checksum before setting
`uploaded_at`; processing continues to reject every non-verified state.

### Flutter device execution

Flutter drives this contract from the canonical Drift `work_queue`. Capture
creates no queue work until the recorder has finalized and the local Item/file
commit is durable, so recording and paused sessions have no network path. The
worker then reconciles the parent, hashes the stable local file, idempotently
creates the item, requests fresh upload state, uploads either the whole file or
only Core-reported missing ranges, and asks Core to verify completion.

`file_blobs.multipart_context` on the device stores bounded resume evidence
(logical upload id/generation, geometry, accepted part ETags/checksums/sizes or
the single PUT ETag). Presigned URLs and signed headers remain memory-only. A
restart re-requests credentials and trusts Core/provider accepted parts rather
than duplicating them. Progress counts accepted bytes only; local `uploaded` is
written only from Core's verified size and checksum response. Upload-only media
ends at `uploaded/not_requested`; capable media releases the device lease once
Core accepts processing, without polling or awaiting AI. The canonical local
file is retained in both cases.

After app-start and reachable retry drains, Flutter may report one throttled
queue observation to `POST /api/device/queue-snapshot`. The closed v1 request
contains aggregate state/stage/error counts, oldest age, progress, and at most
100 reconciled Core Item ids. It never contains local ids, paths, filenames,
names, content, raw errors, credentials, or key material. Local-only Spaces are
omitted by default; after product-metrics opt-in they contribute aggregate work
count and oldest age only. Core replaces the single Device JSONB value only for
a higher report sequence; there is no queue-report history table.

### Presign addressing (path-style)

`MatomeApi.Storage.Presigner` signs **path-style** URLs:

```text
{STORAGE_S3_ENDPOINT}/{bucket}/{storage_key}?X-Amz-...
```

That matches MinIO and Cloudflare R2 path-style. Some AWS S3 setups prefer
**virtual-host** (`https://{bucket}.s3.{region}.amazonaws.com/...`). If a
provider rejects path-style PUTs, either enable path-style on the bucket/API
or claim W4 of `retire-supabase` to adjust the Presigner — do not silently
change the contract.

### CORS

Browser uploads (Flutter Web) need the object store to allow the web origin
for `PUT`/`GET` on the media bucket. Configure CORS on MinIO/R2/S3 to match
`CORS_ORIGINS` (or the deployed web origin), allow the checksum request header,
and expose `ETag` plus provider checksum headers for multipart completion.

## Dockploy / production checklist

### Image

| Artifact | Role |
| --- | --- |
| `services/api/Dockerfile` | **Dockploy default** — `MIX_ENV=prod` OTP **release** (`mix release`), entrypoint `docker-entrypoint.prod.sh` |
| `services/api/Dockerfile.dev` | Local `docker compose` only — `mix phx.server` |
| `MatomeApi.Release.migrate/0` | Migrate without Mix: `bin/matome_api eval "MatomeApi.Release.migrate()"` |

Build example:

```sh
docker build -f services/api/Dockerfile -t matome-api:prod services/api
```

### Env matrix

Set once per environment (do not rotate casually — invalidates sessions):

| Variable | Notes |
| --- | --- |
| `SECRET_KEY_BASE` | `mix phx.gen.secret` |
| `GUARDIAN_SECRET_KEY` | `mix phx.gen.secret` |
| `PHX_HOST` | Public hostname of the Core API |
| `PHX_SERVER` | `true` for releases (entrypoint sets this) |
| `PORT` | Container listen port (default `7001`) |
| `CORS_ORIGINS` | Comma-separated Flutter Web origins |
| `MAILER_ADAPTER` | `mailgun` or `smtp` (Local disabled in prod) |
| `MAILGUN_API_KEY` / `MAILGUN_DOMAIN` | When `MAILER_ADAPTER=mailgun` |
| `SMTP_*` | When `MAILER_ADAPTER=smtp` |
| `ADMIN_PANEL_ENABLED` | `true` to expose `/admin` |
| `ADMIN_EMAIL_ALLOWLIST` | CSV of staff emails (OTP gate) |
| `ADMIN_OTP_PEPPER` | Independent random secret (minimum 32 bytes) for keyed admin OTP verification |
| `ADMIN_IP_ALLOWLIST` | Optional soft IP tier for rate limits |
| `ADMIN_TRUSTED_PROXIES` | CIDRs allowed to supply `X-Forwarded-For` for admin attribution |
| `AI_ENGINE_ENDPOINT` / `AI_ENGINE_TOKEN` / `AI_ENGINE_CALLBACK_BASE_URL` | AI stub or real engine |
| Plus all **data-plane** vars above | Postgres + S3-compatible |

Flutter Web build arg / runtime: `API_BASE_URL` must be the **browser-facing**
Core URL (same rule as `STORAGE_S3_ENDPOINT`).

### Migrate on deploy

The prod entrypoint runs `MatomeApi.Release.migrate()` before `bin/matome_api start`.
Own migrations explicitly — do not assume Dockploy runs them unless this
entrypoint (or an equivalent release eval) is configured.

### Fail-closed boot

In `:prod`, missing `DATABASE_URL`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`,
`STORAGE_S3_ENDPOINT`, or storage keys raises at boot (`config/runtime.exs`).

### Deploy smoke checklist

1. Point Dockploy at `services/api/Dockerfile` (prod release).
2. Attach managed Postgres + S3-compatible store; set the full env matrix.
3. Confirm `STORAGE_S3_ENDPOINT` is the **public** URL browsers use for PUT/GET.
4. Deploy Flutter Web with `API_BASE_URL` = public Core URL; set `CORS_ORIGINS`.
5. Register → create file item → presign PUT → GET object → optional AI process.
6. Deliberate failure: unset `DATABASE_URL` or `STORAGE_S3_ENDPOINT` → container must exit at boot.
## Local ports (containerized DX)

See `dev.ports.env`. `mise run up` publishes each container on these host ports:

| Service | Port env | Typical |
| --- | --- | --- |
| Flutter Web | `MATOME_FLUTTER_WEB_PORT` | `7000` |
| Core API | `MATOME_CORE_PORT` | `7001` |
| AI stub | `MATOME_AI_STUB_PORT` | `7002` (internal) |
| Postgres | `MATOME_COMPOSE_DB_PORT` | `7020` |
| MinIO API | `MATOME_MINIO_PORT` | `7021` |
| MinIO console | `MATOME_MINIO_CONSOLE_PORT` | `7022` |

## Commands

```sh
# From services/api, with DATABASE_URL set:
mix ecto.create
mix ecto.migrate
mix phx.server
```

Oban shares `MatomeApi.Repo` (same Postgres).

## Undeployed schema reset

The current item model is a clean, destructive schema rewrite. Matome has never
been deployed and has no production users or production data, so there is no
production migration, backfill, dual write, or compatibility path for the old
recordings/item shape. Existing local development volumes must be recreated
with `mise run nuke` (or the equivalent explicit database drop/create/migrate)
rather than carried across this reset.
