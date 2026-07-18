# UC-03 — Process media (AI ingestion)

> Part of the [Matome use-case catalog](../use-cases.md). Foundations:
> [PRD](../internal/prd.md) · [Architecture](../internal/architecture.md) ·
> [Requirements](../internal/requirements.md).

## Summary
Every supported input flows through **one** processing contract. For file input,
the client drains a locally captured `pending_upload` Item: it creates the Item
under a reconciled Matome, completes a provider-verified upload, then requests
processing. A standalone text Item is created/edited locally first and its
durable queue reconciles through `POST /api/items/text` or
`PATCH /api/items/:id/text`; it skips file hashing, presign, and byte upload
before processing is requested. Core snapshots capabilities and
creates one logical run with a UUID, attempt, source revision, requested output
kinds, and deadline before enqueuing run-keyed Oban work. The AI service returns
one bounded terminal callback. Core persists explicit state and typed outputs.
The client may observe the accepted run through bounded owner-scoped polling;
its timeout only stops observation and never fails Core's run. On failure the
User can retry, creating a newer run while prior successful output stays visible.

## Actors
- **Primary:** User (triggers ingestion; retries on failure).
- **Secondary:** AI Engine (transcribe / OCR / summarize) and Core API
  (orchestrator + system of record).

## Preconditions
- A file item exists locally as `pending_upload` (UC-02), or a text Item exists
  locally with durable create/edit work.
- The network is available so the durable queue can reconcile the Item.

## Main flow
1. The durable device queue drains an Item mutation.
2. For a file, the client POSTs `/api/matomes/:id/items`; Core returns the Item
   and upload envelope. For standalone text, the client POSTs
   `/api/items/text`, or PATCHes `/api/items/:id/text` with
   `expected_source_revision` after an edit. The client reconciles the numeric
   Core id and accepted source revision against its stable local PK.
3. A file declares its detected content type, streams bytes to object storage,
   and asks Core to verify generation, size, checksum, and provider ETag. Text
   skips this entire upload leg.
4. The client POSTs `/api/items/:id/process`; Core returns `queued` with the
   current run id, attempt, and requested output kinds, then owns execution.
5. For files, the AI Engine downloads media via a server-reachable presigned
   GET, then transcribes or describes/OCRs it. For text, Core sends canonical
   `input` exactly as `{kind,body}`, with `body` copied only from
   `text_contents.body`; `items.notes` and `matomes.description` are not
   concatenated or sent separately, and optional `locale` remains non-content
   metadata. The engine summarizes the selected input. An image run requests the
   configured `ocr_text`, `description`, and `summary` outputs (plus any other
   advertised typed output such as `title`). A document run passes the bounded
   stored filename plus verified MIME, byte size, and SHA-256, and requests only
   the service-advertised intersection of `extracted_text` and `summary`.
6. The AI Engine POSTs the single terminal result to
   `/internal/v1/jobs/:job_id/result` with the matching run and source revision.
7. Core conditionally persists `succeeded`, `partial`, or `failed` plus bounded
   typed outputs/error details only if that run is still current.
8. The client polls `GET /api/items/:id` for that run with one request in flight
   and bounded backoff. A 30-second client timeout is observational; Core's
   watchdog owns authoritative timeout failure.
9. Flutter persists the current typed output map in Drift. Routed image detail
   and the Files reading pane render description, OCR, and summary; document
   detail and the pane render extracted plain text plus summary. Both expose
   truthful `queued`, `processing`, `failed`, and `not_available` states while
   original media and user notes remain independent.

## Alternate & exception flows
- **Processor error** — Core sets `failed` with a bounded stable error code and
  retryability; upload/cloud state and user notes do not change.
- **Unavailable capability** — Core sets `not_available` without dispatch when
  policy or the discovered processor capability cannot serve the input.
- **Partial result** — Core sets `partial` when only a strict subset of requested
  output kinds succeeds.
- **Retry** — the User retries; Core creates a new run/attempt while the client
  retains prior successful output until newer output succeeds.
- **Idempotent callback** — exact duplicates are no-ops; stale run/revision
  callbacks are acknowledged without mutation.
- **Text mutation conflict** — Core returns `409 version_conflict` when
  `expected_source_revision` is stale. Flutter retains the local body or delete
  intent, records the accepted remote revision/body, and exposes an explicit
  durable sync conflict rather than treating it as AI processing failure.

## Sequence
```mermaid
sequenceDiagram
  participant C as Flutter durable queue
  participant API as Core API
  participant ST as Object Storage
  participant OB as Oban
  participant AI as AI Engine
  alt file Item
    C->>API: POST /api/matomes/:id/items
    API-->>C: Item + upload envelope
    C->>ST: PUT bytes, presigned and streamed
    C->>API: POST /api/v1/uploads/:id/complete
    API-->>C: provider-verified uploaded state
  else standalone text Item
    C->>API: POST /api/items/text or PATCH /api/items/:id/text
    API-->>C: Item + accepted source_revision
    Note over C,ST: no hashing, presign, or byte upload
  end
  C->>API: POST /api/items/:id/process
  API->>OB: enqueue run-keyed dispatch + watchdog
  API-->>C: 202, queued + run id + attempt
  OB->>AI: dispatch job
  alt text
    Note over API,AI: input={kind:text, body:text_contents.body}
  else file
    AI->>ST: GET raw bytes, presigned
  end
  alt audio or meeting
    AI->>AI: transcribe
  else image
    AI->>AI: ocr
  end
  AI->>AI: summarize
  AI->>API: POST /internal/v1/jobs/:job_id/result
  API->>API: conditionally persist terminal state + typed outputs
  loop bounded current-run observation
    C->>API: GET /api/items/:id
    API-->>C: explicit state + same run id
  end
  Note over C,API: Client timeout ends observation only; Core watchdog remains authoritative
```

## Requirements satisfied
| Requirement | What it covers |
|---|---|
| **FR-ING-1** | Every supported input uses the explicit Item processing lifecycle and typed outputs. |
| **FR-ING-2** | Client creates a file Item under a reconciled Matome and receives a verified-upload envelope. |
| **FR-ING-3** | Client uploads raw bytes directly to object storage (streamed); never through Core. |
| **FR-ING-4** | Client requests processing (`POST /api/items/:id/process`); Core creates/replays run-keyed Oban work. |
| **FR-ING-5** | AI Engine downloads via presigned GET, runs transcribe/OCR + summarize, POSTs one terminal result. |
| **FR-ING-6** | Core persists explicit terminal state and bounded typed outputs independently of user notes. |
| **FR-ING-7** | Client observes only the accepted current run through bounded poll-only REST; timeout is non-authoritative. |
| **FR-ING-8** | On `failed`, the User can retry; retry re-enqueues server-side — never processed locally. |
| **FR-ING-9** | Callback handling is idempotent and guarded by job/run/Item/revision identity. |
| **FR-ING-10** | Text skips upload and dispatches body-only canonical AI input; notes/descriptions are excluded. |
| **FR-ITM-8** | Standalone text create/edit uses durable local-first work and source-revision conflict handling. |
| **NFR-ARCH-1** | Thin client: it only captures, uploads bytes, and reads results — never runs processing. |
| **NFR-ARCH-2** | Backend owns processing; adding a media type/model is a backend change. |
| **NFR-ARCH-4** | One processing contract for every input kind; only file inputs perform verified upload. |
| **NFR-ARCH-5** | Boundary: client talks only to Core + storage; only Core talks to the AI Engine. |
| **NFR-SEC-2** | Object storage is reached only via short-lived Core-issued presigned URLs. |
| **NFR-SEC-3** | The AI Engine is internal-only behind a shared service token, never client-facing. |

## Code anchors
- `apps/flutter/lib/features/recordings/upload_queue.dart` — durable verified upload through Core processing acceptance.
- `apps/flutter/lib/features/recordings/recordings_repository.dart` — Item creation, verified upload, process request, and owner-scoped Item reads.
- `apps/flutter/lib/features/recordings/recording_result_waiter.dart` — current-run guarded, single-flight polling with bounded backoff and observational timeout.
- `apps/flutter/test/recordings/live_image_processing_e2e_test.dart` — opt-in real image queue → Core → MinIO → ai-stub callback → Drift → routed detail proof (`--dart-define=LIVE_CORE_URL=http://127.0.0.1:7001`).
- `apps/flutter/test/recordings/live_document_processing_e2e_test.dart` — the same opt-in real stack proves PDF and `text/plain` document fixtures reach typed terminal output and routed rendering without a parser/model implementation.
- `services/api/lib/matome_api/content.ex` — run creation, dispatch/watchdog insertion, current-run callback application, and typed outputs.
- `services/api/docs/processing-lifecycle.md` — authoritative processing lifecycle and callback identity contract.
