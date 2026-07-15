# Matome platform contract v1

This directory is the normative W0 contract for device work, Core state,
uploads, AI jobs, events, and non-secret system policy. `platform.json` is the
machine-readable catalog; `system-config.schema.json` and
`device-queue-snapshot.schema.json` are executable JSON Schemas;
`fixtures/canonical.json` contains valid shared envelopes.

Breaking wire changes create `contracts/v2`. Additive fields may be introduced
in v1 only when existing consumers ignore unknown response fields; requests and
event payloads remain closed and reject unknown keys.

## Work lifecycle

The canonical flow is:

```text
local_saved -> work_queued -> parent_item_reconciled
  -> uploading -> uploaded
  -> processing_queued -> processing
  -> succeeded | partial | failed
```

Text work skips upload. Upload-only file work finishes as `succeeded` with
`upload_state=uploaded` and `processing_state=not_requested`. Upload and
processing are independent axes: a processing failure never rolls a verified
upload backward.

Drift owns local durability, user-authored fields, and the device queue. Core
owns remote identity, verified upload state, the current processing run, and
accepted machine outputs. Oban executes Core work but is not product-state
authority. In particular, an Oban `completed` row does not mean a later manual
retry is complete.

Each work row is deduped by item, operation, and input revision. A worker may
act only while it owns an unexpired lease. Expired current work is requeued;
results from a stale run or input revision are acknowledged without mutation.
Transient automatic retries use exponential full jitter. Manual retry creates
a new run id, increments the Item's logical processing attempt, and resets its
executor attempt count; the failed run remains an immutable terminal
observation rather than being reused.

Parent reconciliation is work, not a precondition that can silently skip a
child forever. Queue the parent first, reconcile it, then create/reconcile the
child.

For files, the device stages are parent reconciliation, finalized-file hashing,
idempotent item creation, upload request/refresh, single PUT or missing multipart
parts, verified completion, then either process acceptance or upload-only
completion. Active and paused capture have no Item/work row, so they issue no
Core or storage request. Drift persists accepted part evidence and byte-derived
progress, but never persists presigned URLs or signed headers. The local
canonical file remains after success.

Core item creation accepts the device's permanent local item identity as
`client_id`. The key is scoped by authenticated owner: an exact replay returns
the existing item, a conflicting payload returns `409 client_id_conflict`, and
the same identifier under another owner is independent. File replays issue a
new valid upload descriptor without reserving quota or inserting another
payload row.

## Upload v1

All upload envelopes carry `contract_version=1`, the item input revision, and
an idempotency key. Core selects single or multipart for `mode=auto` using the
desired upload policy and declared byte size.

- `request` creates or resumes one active upload generation.
- `inspect` reloads provider-accepted parts after a Core or client restart.
- `presign_part` binds one part number, exact byte size, and SHA-256 to a fresh
  short-lived PUT while retaining the provider upload when that URL expires.
- `complete` verifies object byte size and SHA-256 before marking `uploaded`.
- `abort` is idempotent and applies only to the named active generation.
- Multipart parts are contiguous and 1-based. Retrying a part keeps the same
  upload id, generation, and part number. A resumed request reports accepted
  parts.
- An existing Core item always requests fresh upload state before processing;
  it cannot skip from an absent object directly to `/process`.
- The device completes unsupported/upload-only media at `uploaded` /
  `not_requested`; processing-capable media releases its work lease as soon as
  Core accepts processing and never waits for AI output.

`upload_id` is a logical envelope handle, not a requirement for an
`upload_sessions` domain table. The active bounded multipart context belongs on
the `file_blobs` row. S3 ETags and per-part provider checksums are matched before
completion; HEAD size and checksum facts are matched before `uploaded`. S3
ETags are transport evidence, not content integrity.

The 25 MiB value selects single PUT versus multipart; it is not a global audio
ceiling. Core also enforces the configured media limit, Space quota, 2 GiB
application upload limit, S3's 5 TiB object bound, 10,000-part bound, and minimum
non-final part size. A multipart context lives for 24 hours by default. Expired
presigns resume the same generation and return only missing parts; expired
contexts are provider-aborted by a persisted cleanup job before Core clears the
context.

## AI HTTP v1

Core dispatch uses a runtime bearer credential. Callback authentication is a
per-run HMAC bearer identity derived from a different runtime signing secret.
The dispatch credential is never accepted on the callback route; neither secret
appears in Oban args, Events, Item state, or `system_config`.

- `GET /v1/capabilities` advertises enabled input kinds, accepted content
  types, limits, and typed outputs.
- `POST /v1/jobs` returns `202` with the same job and run ids.
- The processor posts exactly one terminal `done` or `failed` callback to
  `job.callback.url`, using the signed identity supplied in callback headers.
- Core accepts a callback only when job id, run id, and input revision match the
  current run. Duplicate terminal callbacks are no-ops.

Audio, image, document, and text item jobs share one envelope. File inputs use
a short-lived Core-issued GET URL. Text input contains only the user-authored
text item body. File notes and Matome notes are never automatic AI input.
Capabilities and global policy both apply; the lower limit wins. Outputs are a
typed list, not arbitrary result JSON. Error messages are sanitized and carry
a stable code plus a `retryable` boolean.

Under the Item row lock, a new logical request snapshots source/config
revisions, the advertised input capability, requested outputs, deadline, and a
new opaque run id before atomically inserting its dispatch, watchdog, and
transition event. Active transport retries reuse that run. A valid `done`
callback with all requested output kinds is `succeeded`; a strict subset is
`partial`; duplicate or unrequested kinds are rejected. Disabled global policy
stays `not_requested`, while an advertised unavailable or incompatible
capability is a terminal `not_available` run. Callback and timeout updates are
conditional on current run plus source revision, so exact duplicates are no-ops
and stale or conflicting observations never overwrite current outputs.

## Events and catalog

One event envelope and one append-only `events` table cover security,
operational, and product events. The separate `event_catalog` config table uses
stable keys such as `operational.work_transition.v1` and pins class, schema
version, enablement, retention, and a payload allowlist. Unknown payload keys,
nested objects, and payloads over 4096 bytes are rejected. Locked
security/operational events cannot be disabled.

The retention floors are 365 days for security, 90 for operational, and 30 for
product. Each event snapshots class and expiry at write time, so catalog edits
apply only to future rows and emit `security.event_catalog.changed.v1` in the
same transaction. Payloads never contain credentials, URLs with signatures,
item content, notes, transcripts, or summaries. Events about local Spaces never
egress with a Space id or content. Only the disabled-by-default aggregate
product fixture is eligible after opt-in.

The authenticated Flutter product ingress is `POST /api/events`. It accepts
only unlocked product catalog keys and a bounded `payload`; Core derives actor,
owner, and device from the bearer session. The client defaults product-event
consent off and sends no request until the user opts in. Local Space actions do
not egress individually: only the cataloged coarse local aggregate may leave
the device, without ids or content. Cloud Matome add/remove/archive use
payload-free product keys, while Core emits upload/processing operational
observations from server-known state.

## Desired and applied configuration

`system_config` is one versioned, non-secret global JSON document. Admin writes
`desired` at a monotonic revision using compare-and-swap `base_revision`.
Core marks that revision applied only when the policy write and mandatory audit
event commit together.

The queue policy carries desired AI-queue pause and concurrency state. A
supervised reconciler applies it to the local Oban producer after every Core
node boot and again on the bounded reporting interval. API and Admin responses
keep desired, persisted applied revision, and effective producer state
separate; an unavailable producer is shown as a mismatch requiring restart.

Devices fetch desired policy when online and report a separate sanitized queue
snapshot. An offline device keeps its last `applied_config_revision`; the
admin may display it as stale but must not present desired policy as applied or
send an individual device command. Rejected keys are explicit. Credentials and
signing material remain runtime secrets.

Flutter fetches on app start, authentication, endpoint change, and foreground
resume. It accepts and caches only a closed v1 document with a non-decreasing
revision, keeps the last accepted document offline, reports only the applied
revision plus rejected key paths to the application seam, and snapshots the
accepted revision into new device work. The queue reporter stores only one
monotonic, 64 KiB-bounded observation on the owner-scoped Device: aggregate
counts/stages/age/progress/stable error codes and at most 100 reconciled Core
Item ids. Paths, filenames, names, local-only ids, content, raw errors, keys,
and credentials are not fields. Local-only Spaces are omitted unless product
metrics are opted in, and then contribute aggregate count/age only.

`/admin/work` joins this observation with current Item upload/processing fields,
Oban dispatch metadata, and immutable Events. It labels stale snapshots and
unacknowledged desired configuration, distinguishes Oban acceptance from AI
terminal state, and is observation-only: no individual device command exists.

## Data model decisions

Keep `items` and exactly one 1:1 payload row in `file_blobs` or
`text_contents`. Do not add processing-attempt, derivation, or upload-session
domain tables. Device attempts live on Drift `work_queue`, physical Core
attempts live in Oban, current run fields live on `items`, and one active
multipart context lives on `file_blobs`.

There are no users and no deployment. The W2 schema work may therefore reset
Postgres and Drift cleanly instead of adding backfills, dual writes, or legacy
compatibility.

## Executable evidence

`fixtures/known-mismatches.json` is empty after W5 replaced item/blob Oban
uniqueness with run-keyed dispatch and live lifecycle/callback/watchdog tests.
Core supplies live current-state conformance: processing is rejected until a
file upload is verified, then persists truthful queued, processing, and terminal
state independently of upload state, with typed machine outputs on `items` and
history in Events. The canonical item-create fixture supplies live W1
conformance for the top-level `upload.request` envelope and permanent
`client_id`. Flutter's parent/Core boundary test supplies live W1 conformance
for automatic parent-first reconciliation, immediate child drain, streamed
upload, and restart-safe replay while preserving explicit durable block reasons.
The AI-stub suite executes the shared capabilities, job, and typed-callback
fixtures; adapter/stub transport conformance remains separately owned.
