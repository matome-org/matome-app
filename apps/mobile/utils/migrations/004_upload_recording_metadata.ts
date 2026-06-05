export const up = `
  ALTER TABLE recordings ADD COLUMN mediaType TEXT NOT NULL DEFAULT 'audio';
  ALTER TABLE recordings ADD COLUMN processingStatus TEXT NOT NULL DEFAULT 'done';
`;
