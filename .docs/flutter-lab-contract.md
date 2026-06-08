# Flutter Lab — Backend API Contract

Input contract for the Flutter client lab (task #764). Source of truth is the
existing Phoenix backend in `services/api` — Guardian email/password auth
(no Supabase auth in this lab). Base URL in dev: `http://127.0.0.1:4000`.

Auth is JWT Bearer: send `Authorization: Bearer <access_token>` on protected
endpoints.

## CORS (for Flutter Web)

The endpoint enables CORS via `cors_plug` so a Flutter Web client served from a
different origin can call the API. Allowed origins are configurable through the
`CORS_ORIGINS` env var (comma-separated); the dev default already covers
`http://localhost:8080` / `127.0.0.1:8080` (use `flutter run -d chrome
--web-port 8080`) and the Next.js web client on `:3000`.

If `flutter run -d chrome` picks an ephemeral port, either pin it with
`--web-port 8080` or export the chosen origin:

```bash
CORS_ORIGINS="http://localhost:1234" mise run up   # or set before booting the API
```

Allowed request headers include `Authorization` and `Content-Type`; methods
include `GET, POST, PUT, PATCH, DELETE, OPTIONS` (preflight handled).

---

## POST /api/auth/login

Unauthenticated. Obtains tokens for the dev seed user.

### Request

```http
POST /api/auth/login
Content-Type: application/json

{ "email": "dev@matome.test", "password": "devpassword123" }
```

### Response — 200 OK

```json
{
  "user": { "id": 1, "email": "dev@matome.test" },
  "access_token": "<JWT>",
  "refresh_token": "<JWT>",
  "token_type": "Bearer"
}
```

| Field           | Type   | Notes                                              |
| --------------- | ------ | -------------------------------------------------- |
| `access_token`  | string | **The token the client stores and sends as Bearer.** |
| `refresh_token` | string | Used against `POST /api/auth/refresh`.             |
| `token_type`    | string | Always `"Bearer"`.                                 |
| `user.id`       | int    | Owner id.                                          |
| `user.email`    | string |                                                    |

### Errors

- `401` `{ "error": "invalid_credentials" }`
- `422` `{ "error": "email_and_password_required" }`

Related: `POST /api/auth/register` (same response shape, `201`), used by
`mise run up` to seed the dev user. `POST /api/auth/refresh` takes
`{ "refresh_token": "..." }` and returns the same auth shape. `GET /api/auth/me`
(Bearer) returns `{ "user": { "id", "email" } }`.

---

## GET /api/recordings

Authenticated (Bearer). Returns the current user's recordings — the list the
Home/Today screen consumes.

### Request

```http
GET /api/recordings
Authorization: Bearer <access_token>
```

`GET /api/recordings/search` accepts the same filter params and returns the same
shape (alias of index). The Home chips (Today / Work / Ideas / Unresolved) are
driven by query params + the `badge` / `status` / `inserted_at` fields below.

### Response — 200 OK

```json
{
  "recordings": [
    {
      "id": 1,
      "owner_id": 1,
      "title": "Standup notes",
      "summary": "Short AI summary or null",
      "transcript": "Full transcript or null",
      "media_type": "audio/m4a",
      "storage_key": "recordings/...",
      "status": "done",
      "error_reason": null,
      "duration": 132,
      "badge": "work",
      "workspace_id": null,
      "inserted_at": "2026-06-08T12:00:00Z",
      "updated_at": "2026-06-08T12:00:00Z"
    }
  ]
}
```

List item fields (each element of `recordings`):

| Field          | Type             | Notes                                                       |
| -------------- | ---------------- | ----------------------------------------------------------- |
| `id`           | int              |                                                             |
| `owner_id`     | int              |                                                             |
| `title`        | string           | Required; primary label on the Home card.                   |
| `summary`      | string \| null   | AI summary; may be null until processed.                    |
| `transcript`   | string \| null   | May be null until processed.                                |
| `media_type`   | string \| null   | e.g. `audio/m4a`.                                            |
| `storage_key`  | string \| null   | Object key in storage; resolve playback via download-url.   |
| `status`       | string           | One of `pending`, `processing`, `done`, `failed`.           |
| `error_reason` | string \| null   | Set when `status` = `failed`.                               |
| `duration`     | int \| null      | Seconds.                                                     |
| `badge`        | string \| null   | Free-form tag used for Home chips (e.g. `work`, `ideas`).   |
| `workspace_id` | int \| null      |                                                             |
| `inserted_at`  | string (ISO8601) | Used to group the Today section.                            |
| `updated_at`   | string (ISO8601) |                                                             |

Single recording: `GET /api/recordings/:id` → `{ "recording": { ...same fields } }`.
Playback URL: `GET /api/recordings/:id/download-url` → `{ "download": { ... } }`.

---

## Dev seed & sample data

- The dev user `dev@matome.test` / `devpassword123` is seeded automatically by
  `mise run up` via `POST /api/auth/register` (see `mise.toml`). Do not duplicate.
- Sample recordings are **not** seeded: they require a storage presign round-trip
  on `POST /api/recordings`. To populate the Home with real data after boot, log
  in and create a couple via the API (or use the existing web client). Example:

  ```bash
  TOKEN=$(curl -s -X POST http://127.0.0.1:4000/api/auth/login \
    -H 'content-type: application/json' \
    -d '{"email":"dev@matome.test","password":"devpassword123"}' | jq -r .access_token)

  curl -s -X POST http://127.0.0.1:4000/api/recordings \
    -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
    -d '{"title":"Standup notes","badge":"work","status":"done","duration":132}'
  ```

## Runtime verification (curl e2e)

Requires the full stack (`mise run up`, Postgres on :5432, API on :4000):

```bash
# 1. Login → expect access_token
curl -i -X POST http://127.0.0.1:4000/api/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"dev@matome.test","password":"devpassword123"}'

# 2. List recordings with Bearer → expect { "recordings": [...] }
curl -i http://127.0.0.1:4000/api/recordings -H "Authorization: Bearer $TOKEN"

# 3. CORS preflight from Flutter Web origin → expect 204 + access-control-allow-origin
curl -i -X OPTIONS http://127.0.0.1:4000/api/recordings \
  -H 'Origin: http://localhost:8080' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization'
```
