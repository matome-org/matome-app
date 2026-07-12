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
| `STORAGE_S3_ACCESS_KEY_ID` | yes (prod) | Access key for the object store. |
| `STORAGE_S3_SECRET_ACCESS_KEY` | yes (prod) | Secret key. |
| `STORAGE_S3_REGION` | no | Default `local`. Use the provider region (e.g. `auto` for R2, `us-east-1` for S3). |
| `STORAGE_MEDIA_BUCKET` | no | Default `media`. |
| `STORAGE_UPLOAD_URL_TTL` | no | Seconds; default `900`. |
| `STORAGE_DOWNLOAD_URL_TTL` | no | Seconds; default `300`. |

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
`CORS_ORIGINS` (or the deployed web origin).

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
| `ADMIN_IP_ALLOWLIST` | Optional soft IP tier for rate limits |
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
