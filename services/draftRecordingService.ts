import { getDatabase } from "@/utils/database";
import * as FileSystem from "expo-file-system/legacy";

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

const isValidDraftSegmentUri = async (uri: unknown): Promise<boolean> => {
  if (typeof uri !== "string" || uri.length === 0) return false;

  const documentsDir = FileSystem.documentDirectory;
  if (!documentsDir || !uri.startsWith(documentsDir) || uri.includes("..")) {
    return false;
  }

  const fileName = uri.split("/").pop() || "";
  if (!/^segment_[-A-Za-z0-9_.]+\.m4a$/.test(fileName)) {
    return false;
  }

  const info = await FileSystem.getInfoAsync(uri);
  return info.exists;
};

const validateDraftSegments = async (segments: unknown[]): Promise<string[]> => {
  const validSegments: string[] = [];

  for (const segment of segments) {
    if (!(await isValidDraftSegmentUri(segment))) {
      throw new Error("draftRecordingService: invalid draft segment URI");
    }
    validSegments.push(segment as string);
  }

  return validSegments;
};

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
  const validatedSegments = await validateDraftSegments(segments);
  // Keep only one draft row at a time; replace any existing row.
  // Wrap the DELETE-then-INSERT in a transaction so a draft can never be left
  // deleted-but-not-reinserted if the INSERT fails midway.
  await db.withTransactionAsync(async () => {
    await db.runAsync("DELETE FROM recording_drafts;");
    await db.runAsync(
      "INSERT INTO recording_drafts (created_at, segments_json, duration_ms) VALUES (?, ?, ?);",
      [new Date().toISOString(), JSON.stringify(validatedSegments), durationMs],
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
      segments = await validateDraftSegments(parsed);
    }
  } catch (error) {
    console.error("draftRecordingService: Failed to load draft segments", error);
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
