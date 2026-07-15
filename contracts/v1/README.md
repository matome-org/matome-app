# Matome platform contract v1

This directory is the normative W0 contract for device work, Core state,
uploads, AI jobs, events, and non-secret system policy. `platform.json` is the
machine-readable catalog; `system-config.schema.json` is the executable JSON
Schema; `fixtures/canonical.json` contains valid shared envelopes.

Breaking wire changes create `contracts/v2`. Additive fields may be introduced
in v1 only when existing consumers ignore unknown response fields; requests and
event payloads remain closed and reject unknown keys.

## Work lifecycle

The canonical flow is:

```text
local_saved -> work_queued -> parent_item_reconciled
  -> uploading -> uploaded
  -> processing_queued -> processing
  -> succeeded | failed
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
a new run id and resets its executor attempt count; the failed run remains an
immutable terminal observation rather than being reused.

Parent reconciliation is work, not a precondition that can silently skip a
child forever. Queue the parent first, reconcile it, then create/reconcile the
child.

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
- `complete` verifies object byte size and SHA-256 before marking `uploaded`.
- `abort` is idempotent and applies only to the named active generation.
- Multipart parts are contiguous and 1-based. Retrying a part keeps the same
  upload id, generation, and part number. A resumed request reports accepted
  parts.

`upload_id` is a logical envelope handle, not a requirement for an
`upload_sessions` domain table. The active bounded multipart context belongs on
the `file_blobs` row. S3 ETags are transport evidence, not content integrity.

## AI HTTP v1

Core and the external processor authenticate both job dispatch and callback
with `Authorization: Bearer <service token>`. The token comes from runtime
secret configuration and never appears in a job, event, or `system_config`.

- `GET /v1/capabilities` advertises enabled input kinds, accepted content
  types, limits, and typed outputs.
- `POST /v1/jobs` returns `202` with the same job and run ids.
- The processor posts exactly one terminal `done` or `failed` callback to
  `job.callback.url`.
- Core accepts a callback only when job id, run id, and input revision match the
  current run. Duplicate terminal callbacks are no-ops.

Audio, image, document, and text item jobs share one envelope. File inputs use
a short-lived Core-issued GET URL. Text input contains only the user-authored
text item body. File notes and Matome notes are never automatic AI input.
Capabilities and global policy both apply; the lower limit wins. Outputs are a
typed list, not arbitrary result JSON. Error messages are sanitized and carry
a stable code plus a `retryable` boolean.

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

## Desired and applied configuration

`system_config` is one versioned, non-secret global JSON document. Admin writes
`desired` at a monotonic revision using compare-and-swap `base_revision`.
Core marks that revision applied only when the policy write and mandatory audit
event commit together.

Devices fetch desired policy when online and report a separate sanitized
application snapshot. An offline device keeps its last `applied_revision`; the
admin may display it as stale but must not present desired policy as applied or
send an individual device command. Rejected keys are explicit. Credentials and
signing material remain runtime secrets.

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

`fixtures/known-mismatches.json` captures one current failure without making
the default suites red:

1. Oban uniqueness includes completed jobs forever, so manual retry reuses the
   completed identity instead of creating a run.
Core and Flutter tests execute a detector against that fixture and assert the
specific v1 violation. Core W2 now supplies live current-state conformance:
processing is rejected until a file upload is verified, then persists
`queued`/`processing`/`succeeded` independently of upload state, with machine
outputs on `items`. The canonical item-create fixture supplies live W1
conformance for the top-level `upload.request` envelope and permanent
`client_id`. Flutter's parent/Core boundary test supplies live W1 conformance
for automatic parent-first reconciliation, immediate child drain, streamed
upload, and restart-safe replay while preserving explicit durable block reasons.
The AI-stub suite executes the shared capabilities, job, and typed-callback
fixtures. W5 replaces the remaining retry characterization with live
conformance.
