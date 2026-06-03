import { getDatabase } from "@/utils/database";

// ---------------------------------------------------------------------------
// Draft Recording Service
//
// Persists in-progress multi-segment recording sessions to the SQLite
// recording_drafts table. Only one draft is maintained at a time — saving
// always replaces any prior row.
// ---------------------------------------------------------------------------

interface RecordingDraftRow {
  id: number;
  created_at: string;
  segments_json: string;
  duration_ms: number;
}

export interface RecordingDraft {
  segments: string[];
  durationMs: number;
}

/**
 * Save (or replace) the current recording draft.
 * Persists the list of segment file paths and accumulated duration so the
 * session can be resumed after an app restart.
 */
export const saveDraft = async (
  segments: string[],
  durationMs: number,
): Promise<void> => {
  const db = await getDatabase();
  // Keep only one draft row at a time; replace any existing row.
  // Wrap the DELETE-then-INSERT in a transaction so a draft can never be left
  // deleted-but-not-reinserted if the INSERT fails midway.
  await db.withTransactionAsync(async () => {
    await db.runAsync("DELETE FROM recording_drafts;");
    await db.runAsync(
      "INSERT INTO recording_drafts (created_at, segments_json, duration_ms) VALUES (?, ?, ?);",
      [new Date().toISOString(), JSON.stringify(segments), durationMs],
    );
  });
};

/**
 * Load the current draft, or return null if none exists.
 */
export const loadDraft = async (): Promise<RecordingDraft | null> => {
  const db = await getDatabase();
  const row = await db.getFirstAsync<RecordingDraftRow>(
    "SELECT * FROM recording_drafts ORDER BY id DESC LIMIT 1;",
  );

  if (!row) return null;

  let segments: string[] = [];
  try {
    const parsed = JSON.parse(row.segments_json);
    if (Array.isArray(parsed)) {
      segments = parsed as string[];
    }
  } catch {
    console.error("draftRecordingService: Failed to parse segments_json");
    return null;
  }

  return {
    segments,
    durationMs: row.duration_ms,
  };
};

/**
 * Delete the current draft record from the database.
 * Does NOT delete segment files from disk — call discardSegments() in
 * audioRecordingService for that.
 */
export const deleteDraft = async (): Promise<void> => {
  const db = await getDatabase();
  await db.runAsync("DELETE FROM recording_drafts;");
};
