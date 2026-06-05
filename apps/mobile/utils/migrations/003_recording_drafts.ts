// NOTE: This schema is intentionally duplicated as a defensive inline
// CREATE TABLE in utils/database.ts (initDatabase). The two MUST stay in
// sync — see the "CANONICAL / DEFENSIVE recording_drafts schema" comment
// there. Keep this migration append-only (do not edit it in place once
// shipped); add a new migration for schema changes.
export const up = `
  CREATE TABLE IF NOT EXISTS recording_drafts (
    id INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL,
    segments_json TEXT NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0
  );
`;
