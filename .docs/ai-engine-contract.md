# AI Engine Integration Contract

This document defines the private HTTP contract between Matome Core API and the external AI Engine.

The real AI Engine lives in a separate repository. This monorepo owns only the Core-side contract and the local integration stub in `services/ai-stub`.

## Boundary

- Core API is the system of record for users, recordings, storage keys, job state, and retries.
- AI Engine is stateless and internal-only. It downloads media using Core-provided presigned GET URLs and returns results to Core through a callback.
- Clients never call the AI Engine directly.
- This contract is not part of the public client OpenAPI surface.

## Authentication

Both directions use a shared internal service token:

```http
Authorization: Bearer <AI_ENGINE_TOKEN>
```

For local development, use a non-production token such as `dev-ai-token`. Production tokens must be supplied by deployment secrets.

## Core To AI: Dispatch Job

Core dispatches a job after a recording has been created, media has been uploaded, and Core has issued a short-lived presigned GET URL.

```http
POST /v1/jobs
Content-Type: application/json
Authorization: Bearer <AI_ENGINE_TOKEN>
```

### Request Body

```json
{
  "job_id": "recording:123:attempt:1",
  "recording_id": 123,
  "media_type": "audio",
  "storage_key": "owners/42/recordings/123/media",
  "media": {
    "method": "GET",
    "url": "http://127.0.0.1:54321/storage/v1/s3/media/owners/42/recordings/123/media?X-Amz-...",
    "expires_at": "2026-06-05T03:15:00Z"
  },
  "callback": {
    "url": "http://127.0.0.1:4000/internal/jobs/recording%3A123%3Aattempt%3A1/result",
    "method": "POST"
  },
  "metadata": {
    "owner_id": 42,
    "workspace_id": null,
    "locale": "en",
    "attempt": 1
  }
}
```

### Required Fields

| Field | Type | Notes |
|---|---:|---|
| `job_id` | string | Idempotency key for this processing attempt. |
| `recording_id` | integer | Core recording id to update on callback. |
| `media_type` | string | `audio`, `meeting`, `image`; future values must be treated as unsupported unless implemented. |
| `storage_key` | string | Core-owned object key for audit/debugging. |
| `media.method` | string | Must be `GET`. |
| `media.url` | string | Short-lived presigned GET URL. |
| `callback.method` | string | Must be `POST`. |
| `callback.url` | string | Core internal result endpoint. |

Optional `metadata` values are advisory and must not be used for authorization.

### Response

AI should accept the job quickly and process asynchronously.

```http
202 Accepted
Content-Type: application/json
```

```json
{
  "job_id": "recording:123:attempt:1",
  "accepted": true
}
```

If the request is invalid, AI returns `400`; if the token is missing or invalid, AI returns `401`.

## AI To Core: Result Callback

AI posts exactly one terminal result for each accepted `job_id`. Core must make callback handling idempotent by `job_id` and/or the recording's current status.

```http
POST /internal/jobs/:job_id/result
Content-Type: application/json
Authorization: Bearer <AI_ENGINE_TOKEN>
```

### Successful Result

```json
{
  "job_id": "recording:123:attempt:1",
  "recording_id": 123,
  "status": "done",
  "title": "Weekly planning notes",
  "transcript": "Canned local transcript for recording 123.",
  "summary": "A short summary of the recording.",
  "duration": 42,
  "badge": "Inbox"
}
```

### Failed Result

```json
{
  "job_id": "recording:123:attempt:1",
  "recording_id": 123,
  "status": "failed",
  "error": {
    "code": "unsupported_media_type",
    "message": "AI stub only supports audio, meeting, and image media types."
  }
}
```

### Core Callback Semantics

- `status: "done"` updates `recordings.status`, `title`, `transcript`, `summary`, `duration`, and `badge` when present.
- `status: "failed"` updates `recordings.status` and `error_reason` from `error.message`.
- Core broadcasts the resulting `recording:status` event over the authenticated user channel.
- Core returns `204 No Content` or `200 OK` after persisting the result.
- AI may retry callback delivery on network failures or `5xx`. AI must not retry permanent `4xx` responses without a new job.

## Local Stub

Run the local stub from this monorepo:

```sh
bun run ai:stub
```

Or run its package-local command from `services/ai-stub` with `bun run start`.

Default endpoint: `http://127.0.0.1:5055/v1/jobs`.

Useful environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `AI_STUB_HOST` | `127.0.0.1` | Listen host. |
| `AI_STUB_PORT` | `5055` | Listen port. |
| `AI_ENGINE_TOKEN` | empty | Required bearer token when set. |
| `AI_STUB_CALLBACK_DELAY_MS` | `25` | Delay before posting callback. |
| `AI_STUB_PROBE_MEDIA` | `false` | When `true`, performs a GET against `media.url` before callback. |
| `AI_STUB_FORCE_FAILURE` | `false` | When `true`, always posts a failed result. |

The stub intentionally does not implement transcription, OCR, or summarization. It only validates the contract and posts deterministic canned results so Core orchestration can be tested locally without the external AI repository.
