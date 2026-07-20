# ADR 0001: Items Use an Exclusive Arc for Payloads

## Status

Accepted.

## Context

Matomes need ordered content blocks that can represent files, text, and future item
types. The previous `recordings` table mixed file storage, transcript, summary,
status, and matome placement into one rigid shape. This project has no production
data yet, so the schema is replaced directly with no backfill, dual-write, or
backward compatibility window.

Contacts remain modeled as `contacts` plus `matome_contacts`. They describe who
participated in a happening, not renderable item payloads, so they stay M:N with
matomes and are not folded into `items`.

## Decision

Use an `items` table with:

- `owner_id` plus optional `client_id`; `(owner_id, client_id)` is the remote
  idempotency key and its create fingerprint detects conflicting replays.
- Nullable `matome_id` and direct `workspace_id`. Both may be set because Matome
  placement shadows, rather than destroys, direct Space placement. A nullable
  `position` is present only while the item is in a Matome.
- `item_type` as the discriminator.
- Scalar `title` and user-authored `notes`.
- `metadata jsonb` for display/render hints only.
- Nullable payload foreign keys, currently `file_blob_id` and `text_content_id`.
- The current `processing_state`, one `processing_run_id`, logical attempt,
  source/config revisions, capability/requested-output/deadline snapshots, and
  bounded current outputs/error JSONB. Physical executor attempts remain in
  Oban; no processing-attempt or derivation table exists.

The database owns the exclusive arc:

- `item_type = 'file'` requires exactly `file_blob_id` and forbids
  `text_content_id`.
- `item_type = 'text'` requires exactly `text_content_id` and forbids
  `file_blob_id`.

The rationale is cascade integrity > column count. The extra nullable payload
columns are acceptable because real foreign keys, uniqueness, and explicit
transactional deletes keep owned payload rows accountable. A pure polymorphic
`payload_type`/`payload_id` pair would reduce columns but would give up database
FK enforcement.

## Metadata Contract

`items.metadata` is render-hints-only. Any field that must be queried, joined,
validated, authorized, or indexed must be promoted to a real column or table.

Current key inventory:

- `file`: optional presentation hints such as `display`, `thumbnail_variant`,
  `caption`, and client layout hints.
- `text`: optional presentation hints such as `display`, `language`, `collapsed`,
  and client layout hints.

Metadata must not hold contact IDs, storage keys, byte sizes, media classes,
transcripts, summaries, text bodies, title, notes, status, workspace placement,
upload state, or processing state.

## File and Current-State Contract

`file_blobs` owns the stable storage key, filename, MIME content type, declared
byte size, SHA-256 checksum, media class/duration, upload state/generation,
`uploaded_at`, and at most one active multipart context JSONB. It does not own
transcripts, summaries, user notes, or workspace placement.

The database enforces supported item/media/upload/processing states, the 1:1
payload arc, positive source/upload generations, SHA-256 shape, uploaded-state
timestamp coherence, and owner-matching Matome/Space foreign keys. Current
processing outputs are limited to 4 MiB, processing errors to 16 KiB, the
capability snapshot to 64 KiB, and the single multipart context to 256 KiB.
Application transitions additionally reject file processing until
`upload_state = uploaded`, enforce typed requested outputs, and conditionally
apply terminal state only to the current run and source revision.

Text bodies are non-empty and capped at 200,000 characters. No
`processing_attempts`, `derivations`, or `upload_sessions` tables are created.

This is a destructive rewrite of the original item migration. There has been no
production deployment and there is no production data, so there is deliberately
no backfill, dual-write, compatibility migration, or legacy metadata fallback.

## Rejected Alternatives

- Keep extending `recordings`: rejected because files, text, and future items
  would keep accumulating unrelated nullable columns in one table without a clean
  ownership boundary.
- Pure polymorphic payload reference: rejected because PostgreSQL cannot enforce
  a single FK that points to multiple payload tables.
- Store all payloads in JSONB: rejected because queried or validated data would
  lose column constraints, indexes, and clear ownership semantics.
- Add processing/upload history tables: rejected for the current model. One
  current run lives on `items`, one active upload generation lives on
  `file_blobs`, and physical attempt history remains in Oban/events.
- Fold contacts into items: rejected because contacts are participants attached
  M:N to a matome, not ordered renderable payloads.

## Consequences

Deleting an item must delete its owned payload in the same transaction. The item
row holds the payload FK, so reverse cascade cannot clean up payload tables by
itself.

Adding a new payload type requires a new payload table, a nullable FK on `items`,
and an updated exclusive-arc check constraint.
