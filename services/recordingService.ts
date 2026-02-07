import { getDatabase } from "@/utils/database";
import type { RecordingCard, BadgeType } from "@/processes/homeData";

const DEFAULT_WORKSPACE_ID = "ws_default_personal";
const DEFAULT_WORKSPACE_NAME = "Pessoal";

export interface RecordingRecord {
  id: string;
  title: string;
  summary?: string;
  timestamp: string;
  duration: string;
  badge: BadgeType;
  isProcessing: number; // SQLite stores as INTEGER (0 or 1)
  audioFilePath: string;
  createdAt: number;
  workspaceId: string;
  notes?: string;
}

const getDefaultWorkspaceId = async (
  db: Awaited<ReturnType<typeof getDatabase>>,
): Promise<string> => {
  const existingDefault = await db.getFirstAsync<{ id: string }>(
    `SELECT id FROM workspaces WHERE isDefault = 1 ORDER BY createdAt ASC LIMIT 1`,
  );

  if (existingDefault?.id) {
    return existingDefault.id;
  }

  const existingByName = await db.getFirstAsync<{ id: string }>(
    `SELECT id FROM workspaces WHERE name = ? LIMIT 1`,
    [DEFAULT_WORKSPACE_NAME],
  );

  if (existingByName?.id) {
    await db.runAsync(`UPDATE workspaces SET isDefault = 1 WHERE id = ?`, [
      existingByName.id,
    ]);
    return existingByName.id;
  }

  await db.runAsync(
    `INSERT OR IGNORE INTO workspaces (id, name, isDefault, createdAt) VALUES (?, ?, 1, ?)`,
    [DEFAULT_WORKSPACE_ID, DEFAULT_WORKSPACE_NAME, Date.now()],
  );

  const insertedDefault = await db.getFirstAsync<{ id: string }>(
    `SELECT id FROM workspaces WHERE name = ? LIMIT 1`,
    [DEFAULT_WORKSPACE_NAME],
  );

  return insertedDefault?.id ?? DEFAULT_WORKSPACE_ID;
};

/**
 * Create a new recording in the database
 */
export const createRecording = async (
  recording: Omit<RecordingRecord, "isProcessing" | "workspaceId"> & {
    isProcessing?: boolean;
    workspaceId?: string;
  },
): Promise<void> => {
  const db = await getDatabase();
  const workspaceId = recording.workspaceId ?? (await getDefaultWorkspaceId(db));

  await db.runAsync(
    `INSERT INTO recordings (id, title, summary, timestamp, duration, badge, isProcessing, audioFilePath, createdAt, workspaceId)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      recording.id,
      recording.title,
      recording.summary || null,
      recording.timestamp,
      recording.duration,
      recording.badge,
      recording.isProcessing ? 1 : 0,
      recording.audioFilePath,
      recording.createdAt,
      workspaceId,
    ],
  );
};

/**
 * Get all recordings, ordered by creation date (newest first)
 */
export const getAllRecordings = async (): Promise<RecordingRecord[]> => {
  const db = await getDatabase();

  const result = await db.getAllAsync<RecordingRecord>(
    `SELECT * FROM recordings ORDER BY createdAt DESC`,
  );

  return result;
};

/**
 * Get a recording by ID
 */
export const getRecordingById = async (
  id: string,
): Promise<RecordingRecord | null> => {
  const db = await getDatabase();

  const result = await db.getFirstAsync<RecordingRecord>(
    `SELECT * FROM recordings WHERE id = ?`,
    [id],
  );

  return result || null;
};

/**
 * Update a recording (typically to add transcription or update processing status)
 */
export const updateRecording = async (
  id: string,
  updates: Partial<
    Pick<RecordingRecord, "summary" | "title" | "badge" | "notes" | "workspaceId">
  > & {
    isProcessing?: boolean;
  },
): Promise<void> => {
  const db = await getDatabase();

  const fields: string[] = [];
  const values: any[] = [];

  if (!!updates.summary) {
    fields.push("summary = ?");
    values.push(updates.summary);
  }

  if (!!updates.title) {
    fields.push("title = ?");
    values.push(updates.title);
  }

  if (updates.isProcessing !== undefined) {
    fields.push("isProcessing = ?");
    values.push(updates.isProcessing ? 1 : 0);
  }

  if (!!updates.badge) {
    fields.push("badge = ?");
    values.push(updates.badge);
  }

  if (updates.notes !== undefined) {
    fields.push("notes = ?");
    values.push(updates.notes);
  }

  if (updates.workspaceId !== undefined) {
    fields.push("workspaceId = ?");
    values.push(updates.workspaceId);
  }

  if (fields.length === 0) {
    return; // No updates to make
  }

  values.push(id);

  await db.runAsync(
    `UPDATE recordings SET ${fields.join(", ")} WHERE id = ?`,
    values,
  );
};

/**
 * Delete a recording
 */
export const deleteRecording = async (id: string): Promise<void> => {
  const db = await getDatabase();

  await db.runAsync(`DELETE FROM recordings WHERE id = ?`, [id]);
};

/**
 * Convert a RecordingRecord to RecordingCard format
 */
export const recordToCard = (record: RecordingRecord): RecordingCard => {
  return {
    id: record.id,
    title: record.title,
    summary: record.summary,
    timestamp: record.timestamp,
    duration: record.duration,
    badge: record.badge,
    notes: record.notes,
    isProcessing: record.isProcessing === 1,
  };
};
