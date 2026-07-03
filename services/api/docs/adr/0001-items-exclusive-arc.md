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

- `matome_id` and `position` for ownership and ordering.
- `item_type` as the discriminator.
- `metadata jsonb` for display/render hints only.
- Nullable payload foreign keys, currently `file_blob_id` and `text_content_id`.

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
transcripts, summaries, or text bodies.

## Rejected Alternatives

- Keep extending `recordings`: rejected because files, text, and future items
  would keep accumulating unrelated nullable columns in one table without a clean
  ownership boundary.
- Pure polymorphic payload reference: rejected because PostgreSQL cannot enforce
  a single FK that points to multiple payload tables.
- Store all payloads in JSONB: rejected because queried or validated data would
  lose column constraints, indexes, and clear ownership semantics.
- Fold contacts into items: rejected because contacts are participants attached
  M:N to a matome, not ordered renderable payloads.

## Consequences

Deleting an item must delete its owned payload in the same transaction. The item
row holds the payload FK, so reverse cascade cannot clean up payload tables by
itself.

Adding a new payload type requires a new payload table, a nullable FK on `items`,
and an updated exclusive-arc check constraint.
