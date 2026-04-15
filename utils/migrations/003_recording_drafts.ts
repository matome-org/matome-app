export const up = `
  CREATE TABLE IF NOT EXISTS recording_drafts (
    id INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL,
    segments_json TEXT NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0
  );
`;
