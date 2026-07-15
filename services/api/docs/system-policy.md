# System policy v1

`system_configs` contains exactly one row, keyed `global`. Its `document` JSONB
column implements `contracts/v1/system-config.schema.json`; both the Ecto
changeset and the `system_configs_document_v1` database constraint reject
unknown keys, wrong schema versions, invalid types, unsafe ranges, and invalid
cross-field bounds.

## Revision and audit

- Admin submits a complete `desired` document and `base_revision`.
- A row lock rejects stale compare-and-swap writes with `stale_revision`.
- The revision increments once; existing Item, Oban, event, and Drift snapshots
  are never rewritten.
- Desired policy and mandatory `security.admin_config_changed.v2` before/after
  evidence commit in one transaction. Event failure rolls back the policy.
- The context repeats email-allowlist and recent-OTP checks. LiveView checks are
  only an early redirect, not the authorization boundary.

## Desired, applied, and effective

`desired.queue.paused` and `max_concurrency` are persisted intent for the local
AI Oban producer. `MatomeApi.SystemConfig.Reconciler` starts under the app
supervisor after Oban, reapplies that intent on boot and at the configured
reporting interval, then records `applied.core_revision`. It also reapplies the
same revision after a producer/node restart without creating a policy revision.

`GET /api/system-config` is authenticated and returns the policy plus a separate
effective queue observation. A different producer state is `mismatch=true`; an
unavailable local producer additionally reports `restart_required=true`.

Flutter validates and caches only accepted monotonic revisions. It fetches on
start, authentication, endpoint change, and foreground resume, retains the last
accepted policy offline, and sends a bounded application report to
`POST /api/system-config/application`. That endpoint intentionally stores no
per-device snapshot in this task; it is the seam for the subsequent device
snapshot/Work UI task.

## Runtime-only values

Credentials, Guardian/admin secrets, AI service tokens, signing material,
storage access keys, signed URLs, callback URLs, and service endpoints are not
valid policy keys. They remain in environment/runtime configuration and never
appear in the row, Admin form, application report, Oban args, or audit details.
