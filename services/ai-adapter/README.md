# matome AI adapter

Bridges the **Core AI-engine contract** (async `POST /v1/jobs` → `202`, then a
callback `POST` to `job.callback.url`) to the **synchronous whisper API**
(`POST /api/v1/transcribe`, multipart file → `{text}`).

It is a drop-in replacement for `services/ai-stub` when you want *real*
transcription instead of canned text. Core is unchanged — same dialect.

## Flow

```
Core ──POST /v1/jobs──▶ adapter ──202──▶ Core
                          │
                          ├─ GET job.media.url            (presigned MinIO object)
                          ├─ ffmpeg → 16k mono WAV        (any container → whisper's format)
                          ├─ POST multipart /api/v1/transcribe  (whisper GPU API)
                          └─ POST job.callback.url {status:"done", transcript}
```

Only `media_type: audio` is transcribed; anything else gets a `failed` callback
with `unsupported_media_type` (the whisper API has no image/OCR counterpart).
Fetch/transcode/transcribe errors post a `failed` callback with
`transcription_failed`.

## Run (host, next to the GPU whisper API)

The whisper API runs on the host GPU, and presigned MinIO URLs resolve to the
host-published port — so the adapter runs on the host too, where it can reach
all three of MinIO (`:7021`), the whisper API (`:8000`), and Core (`:7001`).

```sh
AI_ENGINE_TOKEN=dev-ai-token \
AUDIO_API_ENDPOINT=http://localhost:8000/api/v1/transcribe \
AI_ADAPTER_PORT=7005 \
node services/ai-adapter/src/server.js
```

Then point Core at the adapter instead of the stub (restart Core with):

```sh
AI_ENGINE_ENDPOINT=http://host.docker.internal:7005/v1/jobs   # Core (compose) → adapter (host)
AI_ENGINE_CALLBACK_BASE_URL=http://localhost:7001             # adapter (host) → Core (published)
```

Core's compose service needs `extra_hosts: ["host.docker.internal:host-gateway"]`
to resolve the host from inside the container.

## Env

| Var | Default | Notes |
| --- | --- | --- |
| `AI_ENGINE_TOKEN` | `""` | Must match Core's token. Empty = auth disabled. |
| `AUDIO_API_ENDPOINT` | `http://localhost:8000/api/v1/transcribe` | The whisper transcribe endpoint. |
| `AI_ADAPTER_HOST` | `0.0.0.0` (`127.0.0.1` under `node` default) | Bind host. |
| `AI_ADAPTER_PORT` | `7005` | Listen port. |

## Test

```sh
npm --prefix services/ai-adapter run check   # node:test, real ffmpeg, mocked whisper + Core
```
