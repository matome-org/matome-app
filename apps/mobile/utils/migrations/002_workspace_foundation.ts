export const up = `
  CREATE TABLE IF NOT EXISTS workspaces (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    isDefault INTEGER NOT NULL DEFAULT 0,
    createdAt INTEGER NOT NULL
  );

  INSERT OR IGNORE INTO workspaces (id, name, isDefault, createdAt)
  VALUES (
    'ws_default_personal',
    'Pessoal',
    1,
    CAST(strftime('%s', 'now') AS INTEGER) * 1000
  );

  ALTER TABLE recordings ADD COLUMN workspaceId TEXT REFERENCES workspaces(id);

  UPDATE recordings
  SET workspaceId = (
    SELECT id
    FROM workspaces
    WHERE isDefault = 1
    ORDER BY createdAt ASC
    LIMIT 1
  )
  WHERE workspaceId IS NULL OR workspaceId = '';

  CREATE INDEX IF NOT EXISTS idx_recordings_workspaceId
  ON recordings(workspaceId);

  CREATE INDEX IF NOT EXISTS idx_workspaces_isDefault
  ON workspaces(isDefault);
`;
