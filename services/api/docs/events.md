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
`Admin.update_event_catalog/3` requires an allowlisted actor, recent OTP, and a
derived client IP; it limits changes to `enabled`, `description`, and
`retention_days`, and commits `security.event_catalog.changed.v2` in the same
transaction. Database constraints and a trigger prevent weakening security
policy or changing stable identity/detail policy.

## Write paths

- `MatomeApi.Events.write_security!/2` accepts only enabled security keys and
  raises for unknown keys, disabled policy, invalid details, or storage errors.
  Security-sensitive callers must not continue when this write fails.
- `MatomeApi.Events.put_security/4` adds the same mandatory insert to a caller's
  `Ecto.Multi`. Admin mutation contexts use this path so the action and its
  event commit or roll back as one transaction.
- `MatomeApi.Events.write_optional/2` accepts operational and product keys. It
  returns `{:ok, :disabled}` without inserting when collection is disabled and
  returns a bounded error tuple instead of raising when best-effort reporting
  fails.
- `POST /api/events` is the authenticated Flutter ingress for optional product
  keys only. The request must assert current user opt-in, and Core derives
  actor, owner, and session device from the bearer session. Client-supplied
  identity fields are ignored; security, operational, unknown, locked, nested,
  and oversized payloads are rejected. A disabled product key returns
  `202 disabled` and inserts nothing.
- `MatomeApi.Admin.audit!/2` maps every current `admin.*` action to a stable
  security catalog key and uses the fail-closed path. Mutations that gained
  bounded before/after state use v2 keys; immutable v1 entries remain readable.

`details` is a JSON object capped at 4096 encoded bytes. Its top-level keys must
match the code-defined and catalog-pinned allowlist. Values are scalars or
bounded flat scalar lists; nested objects, credentials, signed URLs, item
content, notes, transcripts, and summaries are not accepted. Actor, owner,
subject, device, run, correlation, severity, occurrence, and retention fields
remain scalar columns with purpose-built indexes.

Admin before/after snapshots are JSON-encoded scalar strings rather than nested
event objects. Their builders explicitly select control fields (for example
Space quota, expiry, lifecycle, and sync type), keeping content and names out of
the event payload.

Flutter also keeps a code-defined product allowlist and a secure
`matome.product_events_opt_in` setting. Opt-out is the default and suppresses
the request before transport, so catalog enablement cannot grant consent.
Cloud Matome add, remove, and archive actions use payload-free stable keys.
Local-only Space actions never use those keys; only
`product.local_space_aggregate.v1` may egress after opt-in, with coarse bucket
fields and no Space id or content.

Core records representative upload and processing observations under
`operational.upload_completed.v1` and
`operational.processing_completed.v1`. These writes are best effort and obey
current catalog enablement. Payloads contain only bounded mode, size, input,
output-type, and result metadata; item content and storage credentials are not
eligible.

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

Admin reads of cross-user metadata are themselves security events under
`security.admin.sensitive_read.v1`; actor email, subject, and proxy-derived
client IP are recorded before the caller receives the result.

`/admin/events` exposes this cursor through a 50-row Events timeline with
indexed class, key, actor id/email, owner, subject type/id, device, run,
severity, and UTC range filters. `/admin/events/security` is a locked saved view
that always applies `event_class=security`, regardless of submitted params.

`/admin/event-catalog` lists stable collection policy by class. Rows marked
`locked` are read-only. Optional rows expose enablement and retention controls;
every submit re-checks the current email allowlist and five-minute OTP freshness
and commits `security.event_catalog.changed.v2` atomically with the policy
change. The admin views use the existing browser/admin LiveView session and
design-system components; they add no Work or system-configuration controls.
