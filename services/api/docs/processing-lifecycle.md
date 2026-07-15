# Processing lifecycle v1

Core owns one truthful current processing run on each Item. There is no
`processing_runs` table: immutable history is in Events and physical execution
history is in Oban.

## Request and dispatch

`POST /api/items/:id/process` locks the Item. An active `queued` or `processing`
request is a transport replay and returns the same run. A terminal retry creates
a new UUID run, increments `processing_attempt`, and snapshots source revision,
system-config revision, the processor's v1 input capability, requested outputs,
request time, and deadline. Core inserts the run-keyed dispatch job, run-keyed
watchdog, and `operational.work_transition.v1` event in the same transaction.

File input requires a verified upload and is tagged `audio`, `image`, or
`document`; dispatch carries a short-lived GET URL and bounded media facts,
never the storage key. Text input is the bounded user-authored text body only.
Global policy exclusion remains `not_requested`. A disabled, incompatible, or
limit-exceeded advertised capability records terminal `not_available` without
Oban work.

Oban uniqueness is scoped to `processing_run_id`. Automatic transport retries
therefore reuse the run, while a user retry has independent Oban history.

## Callback and timeout

Dispatch uses `AI_ENGINE_DISPATCH_TOKEN`. The callback uses a per-run HMAC
bearer identity derived with `AI_ENGINE_CALLBACK_SIGNING_SECRET`; the outbound
dispatch credential is not valid on `/internal/v1/jobs/:job_id/result`.

Core accepts only the closed v1 terminal envelope. Job id, run id, Item id, and
source revision must match persisted dispatch args. Bodies, capability
snapshots, aggregate outputs, each typed output, error code/message, and output
kinds are bounded. `done` with every requested kind becomes `succeeded`; a
strict subset becomes `partial`; `failed` stores only stable code, sanitized
message, and `retryable`.

Terminal writes lock the Item and update only when run id and source revision
remain current and state is `queued` or `processing`. An exact duplicate is a
no-op. Stale or conflicting callbacks are acknowledged without mutation. This
also makes a callback arriving before the dispatch HTTP acknowledgement safe.
The scheduled watchdog applies the same conditional update and records stable
error code `timeout` only while its run remains active.
