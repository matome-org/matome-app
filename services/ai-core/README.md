# Matome AI Core

Internal FastAPI service for Matome's AI HTTP v1 contract. It advertises audio
transcription, durably accepts matching jobs, verifies fetched media, and
delivers one persisted terminal callback envelope. Verified audio is converted
with ffmpeg to 16 kHz mono PCM WAV before the configured Whisper backend emits a
v1 `transcript` output. Summary and title generation are not implemented.

`GET /health` is public. `GET /v1/capabilities` and `POST /v1/jobs` require the
Core service credential as `Authorization: Bearer <token>`. There are no
user-facing authentication routes, and interactive API documentation is
disabled.

## Run locally

```sh
cd services/ai-core
python3 -m venv .venv
.venv/bin/pip install -e '.[test,whisper-openai]'
AI_ENGINE_DISPATCH_TOKEN=dev-ai-dispatch-token \
  WHISPER_BACKEND=openai \
  WHISPER_MODEL=base \
  .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 7005
```

The host must provide `ffmpeg` on `PATH`. `WHISPER_BACKEND` accepts `openai`
(the default) or `whispercpp`; install `.[whisper-openai]` or `.[whispercpp]`
to match. `WHISPER_MODEL` defaults to `base`. Backend imports and model loading
are deferred until the first verified job, so the API and model-free test suite
start without loading model weights.

Point Core's `AI_ENGINE_ENDPOINT` at `http://127.0.0.1:7005/v1/jobs`. The token
must match Core's `AI_ENGINE_DISPATCH_TOKEN`; an unset or empty token authorizes
no requests.

The root `docker-compose.yml` intentionally keeps `ai-stub` as the default for
fast, deterministic local fixture development. Use this host-run command when
developing AI Core itself; production uses the dedicated Compose stack below.

Accepted jobs and exact terminal callback bytes are stored in SQLite at
`AI_JOB_DATA_PATH` (default: the system temporary directory under
`matome-ai-core/jobs.sqlite3`). Set this to durable storage for deployed
instances. Replays use `job_id`, `run_id`, and `input_revision`; renewed media
URLs and expirations retain the original semantic identity, while changed job
input returns `409`. Callback attempts use only the authorization supplied in
the accepted job and retry the persisted terminal bytes after transport
failure.

Unsupported media and invalid/corrupt audio produce stable non-retryable job
failures. Missing processor tools, model-load/transcription failures, and
conversion timeouts produce stable retryable failures. Error callbacks do not
include ffmpeg output, backend exceptions, credentials, URLs, or input content.

## Processor extension contract

`app.registry.ProcessorRegistry` is the internal expansion seam. Each
`ProcessorRegistration` pairs one input kind with its executor and a
`ProcessorCapability`; `/v1/capabilities` is derived from those registrations
rather than maintained as a second hard-coded list. Before dispatch, the
registry verifies that every `requested_outputs` value is advertised for the
input kind. An unadvertised request fails without running processor code.

To add a processor in a later task:

1. Define the input model and its allowed `requested_outputs` in the v1 request
   model. Keep the existing job identity, input, callback, and metadata envelope
   unchanged, so Core dispatch does not gain a processor-specific route.
2. Define typed v1 outputs as `TypedDict` values with a literal `type`
   discriminator, following the existing `TranscriptOutput`. Return only output
   shapes already admitted by the shared v1 contract.
3. Implement an executor with the existing `(input_bytes, job) -> outputs`
   boundary, then register it with its input kind, output names, applicable size
   limit, and content types. Registration makes the capability visible and
   dispatchable; do not advertise work that the runtime cannot execute. Extend
   the typed capability descriptor when a shared-contract input uses a different
   limit field, rather than placing an ad hoc field in the response.
4. Add contract tests for the capability document, accepted request model,
   typed terminal output, unsupported-output gate, and stable failure codes.

Planned features are deliberately not implemented here. Future summary and
title generation, OCR, document extraction, embeddings, and classification
must each arrive through that same capability gate and typed v1 outputs. Their
eventual input/output combinations belong in the shared contract before
registration; the registry is not permission to invent wire shapes locally.

The current shared contract admits these relevant v1 output discriminators:

| Feature | v1 output | Typed payload |
| --- | --- | --- |
| Transcription | `transcript` | `text`, optional `language` and `duration_ms` |
| Summary | `summary` | `markdown` |
| Title generation | `title` | `text` |
| OCR | `ocr_text` | `text`, optional `language` |
| Document extraction | `extracted_text` | `text`, optional `language` |

Embeddings and classification do not yet have v1 output discriminators. A
future task must first add their typed shapes and requested-output policy to the
shared contract, then add request models, registrations, and executors here.
That contract-first sequence preserves the existing Core dispatch envelope.

Processor API keys, model credentials, and backend settings are runtime secrets.
Read them from the runtime environment (or an injected secret store), never from
the capability response, request payload, source defaults, logs, or persisted
terminal outputs. Capability metadata is non-secret and describes only work the
configured runtime can perform.

AI Core remains internal-only: it has no user authentication or public ingress.
Only Core may reach it on the private service network, and both v1 routes keep
the bearer service-auth check. Media and callback URLs remain short-lived HTTPS
URLs validated by the existing job contract. Adding a processor does not add a
public endpoint, weaken service auth, or expose its runtime secrets.

## Production deployment

`docker-compose.production.yml` is the self-contained Dokploy/Dockploy stack:
Flutter Web, the production Core OTP release, AI Core, Postgres, and MinIO. It
does not use `ai-stub`, `ai-adapter`, or the external `matome-api-audio`
service. Start from the non-secret scaffold and validate before deployment:

```sh
cp .env.production.example .env.production
# Replace every CHANGE_ME value, then:
docker compose --env-file .env.production \
  -f docker-compose.production.yml config --quiet
docker compose --env-file .env.production \
  -f docker-compose.production.yml up --build -d
```

AI Core is private: it has no published host port. Core reaches it only over the
Compose network at `AI_ENGINE_ENDPOINT=http://ai-core:8000/v1/jobs`. Do not put
that internal URL behind a public proxy. The shared `AI_ENGINE_DISPATCH_TOKEN`
must be a generated, non-default value of at least 32 bytes. Keep it distinct
from the independently generated, 32+ byte
`AI_ENGINE_CALLBACK_SIGNING_SECRET`.

The image runs as a non-root user, includes ffmpeg and the OpenAI Whisper Python
backend, and exposes `/health` only to the Compose network. `AI_JOB_DATA_PATH`
is fixed at `/var/lib/matome-ai-core/jobs.sqlite3`; the
`matome_ai_core_jobs` named volume preserves accepted jobs and exact callback
bytes across replacement or restart. Back up this volume with the database and
object store. Model weights are loaded lazily and are not downloaded by config
validation or health checks.

### URL and environment rules

| Setting | Scope | Production rule |
| --- | --- | --- |
| `API_BASE_URL` | Flutter Web build arg | Browser-public HTTPS Core URL; changing it requires rebuilding Web. |
| `STORAGE_S3_ENDPOINT` | Presigned media URL origin | Browser-public HTTPS object URL. It is also the URL AI Core fetches, so its certificate and DNS must work from the AI Core container. Never use `http://minio:9000`. |
| `STORAGE_S3_INTERNAL_ENDPOINT` | Core-only object operations | Compose sets `http://minio:9000`; this URL is never returned to a browser or AI job. |
| `AI_ENGINE_CALLBACK_BASE_URL` | Callback URLs generated by Core | Core-public HTTPS origin, normally the same origin as `API_BASE_URL`. Never use `http://core:7001`; AI Core enforces HTTPS for callback and media URLs in production. |
| `AI_ENGINE_ENDPOINT` | Core-to-processor dispatch | Fixed private URL `http://ai-core:8000/v1/jobs`; this exact internal HTTP exception is accepted by Core's production boot guard. |
| `AI_ENGINE_DISPATCH_TOKEN` | Core-to-AI-Core credential | Required, random, non-default, at least 32 bytes, identical in Core and AI Core. |
| `AI_ENGINE_CALLBACK_SIGNING_SECRET` | Per-run callback signing | Required, random, at least 32 bytes, and different from the dispatch token. |
| `AI_JOB_DATA_PATH` | AI Core SQLite state | `/var/lib/matome-ai-core/jobs.sqlite3` on the durable named volume. |
| `WHISPER_BACKEND` / `WHISPER_MODEL` | Transcription runtime | Image default is `openai` / `base`; choose a model appropriate for host resources. |

Postgres and MinIO are included for a single-host deployment. Operators using
managed services may remove `db`, `minio`, and `minio-init`, then set
`DATABASE_URL`, `DATABASE_SSL`, `STORAGE_S3_ENDPOINT`, and
`STORAGE_S3_INTERNAL_ENDPOINT` for those services. In either layout, expose
only Web, Core, and the browser-facing object endpoint; never publish AI Core,
Postgres, or storage credentials.

## Test

```sh
cd services/ai-core
.venv/bin/pytest
```

## Live OpenAI-compatible integration

Provider-backed tests are opt-in and use the standard OpenAI-compatible
`POST /v1/chat/completions` wire contract. The same client covers text,
multimodal `image_url` content, and function tools; changing providers does not
require changing Python code when the provider accepts standard Bearer
authentication. Provider-specific query parameters or custom authentication
headers are deliberately outside this client contract.

The checked-in example targets the local LM Studio server currently used by the
project:

```sh
cd services/ai-core
cp .env.live.example .env.live.local
# Edit OPENAI_BASE_URL, OPENAI_API_KEY or OPENAI_MODEL when the provider changes.
sh test-live-ai.sh
```

`test-live-ai.sh` loads the ignored `.env.live.local` file and runs the
`live_ai` marker. The suite verifies a bounded text completion, an explicit
tool-use request with `tool_choice=auto`, and vision with an in-memory
solid-color PNG. These are live
model capability tests, so an incompatible or differently configured model
should fail them rather than being treated as wire-compatible. Normal
`.venv/bin/pytest` runs remain deterministic and skip these three network/model
tests.

| Variable | Purpose |
| --- | --- |
| `OPENAI_BASE_URL` | Provider origin, with or without `/v1`; the client normalizes it. |
| `OPENAI_API_KEY` | Bearer credential. LM Studio accepts the configured local token; hosted providers use a real secret. |
| `OPENAI_MODEL` | Exact model identifier exposed by `GET /v1/models`. |
| `OPENAI_TIMEOUT_SECONDS` | Bounded request timeout; defaults to 60 seconds. |

The configured `google/gemma-4-e4b` model was verified for text, tool calling,
and vision. This LM Studio server does **not** expose OpenAI-compatible multipart
`/v1/audio/transcriptions`: it rejects multipart requests and requires JSON.
Audio transcription therefore remains on the local Whisper backend. Do not
route audio to chat completions or claim provider-backed speech-to-text until a
server actually implements the OpenAI audio transcription endpoint.
