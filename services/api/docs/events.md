# Canonical events and catalog

Core stores security, operational, and product events in one append-only
Postgres table, `events`. `event_catalog` is configuration, not a second event
instance store.

## Stable keys and retention

Catalog keys include their schema version, for example
`security.admin.login.v1` and `operational.work_transition.v1`. A breaking
detail schema creates a new key; existing keys are never repurposed.

| Class | Retention floor | Default collection |
|---|---:|---|
| security | 365 days | enabled and locked |
| operational | 90 days | enabled; required keys locked |
| product | 30 days | disabled until explicit opt-in |

An event insert reads the current catalog entry and snapshots `event_class` and
`retention_until`. Later catalog changes therefore affect only future writes.
`Events.update_catalog!/3` limits changes to `enabled`, `description`, and
`retention_days`, and commits `security.event_catalog.changed.v1` in the same
transaction. Database constraints and a trigger prevent weakening security
policy or changing stable identity/detail policy.

## Write paths

- `MatomeApi.Events.write_security!/2` accepts only enabled security keys and
  raises for unknown keys, disabled policy, invalid details, or storage errors.
  Security-sensitive callers must not continue when this write fails.
- `MatomeApi.Events.write_optional/2` accepts operational and product keys. It
  returns `{:ok, :disabled}` without inserting when collection is disabled and
  returns a bounded error tuple instead of raising when best-effort reporting
  fails.
- `MatomeApi.Admin.audit!/2` maps every current `admin.*` action to a stable
  security catalog key and uses the fail-closed path.

`details` is a JSON object capped at 4096 encoded bytes. Its top-level keys must
match the code-defined and catalog-pinned allowlist. Values are scalars or
bounded flat scalar lists; nested objects, credentials, signed URLs, item
content, notes, transcripts, and summaries are not accepted. Actor, owner,
subject, device, run, correlation, severity, occurrence, and retention fields
remain scalar columns with purpose-built indexes.

## Immutability and pruning

Database triggers reject `UPDATE`, ordinary `DELETE`, and `TRUNCATE` on
`events`, including attempts by the table owner. Expired rows are deleted only
through `MatomeApi.Events.prune_expired!/1`, which invokes the
`prune_expired_events(timestamptz)` security-definer function. The function is
owned by a no-login retention role, clamps its cutoff to database time, and can
delete only rows whose snapshotted `retention_until` has passed.

## Reading

`MatomeApi.Events.list_events/1` filters scalar dimensions before applying a
maximum page size of 100. Results sort by `(occurred_at DESC, id DESC)` and use
an opaque cursor encoding both values, so equal timestamps paginate without
duplicates or gaps.
