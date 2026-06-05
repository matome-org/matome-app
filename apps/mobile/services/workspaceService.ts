import { getDatabase } from "@/utils/database";
import type { RecordingRecord } from "./recordingService";

export interface Workspace {
  id: string;
  name: string;
  isDefault: number;
  createdAt: number;
}

/**
 * Get all workspaces ordered by creation date
 */
export const getWorkspaces = async (): Promise<Workspace[]> => {
  const db = await getDatabase();
  return db.getAllAsync<Workspace>(
    `SELECT * FROM workspaces ORDER BY createdAt ASC`,
  );
};

/**
 * Create a new workspace
 */
export const createWorkspace = async (name: string): Promise<Workspace> => {
  const db = await getDatabase();
  const id = `ws_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
  const createdAt = Date.now();

  await db.runAsync(
    `INSERT INTO workspaces (id, name, isDefault, createdAt) VALUES (?, ?, 0, ?)`,
    [id, name.trim(), createdAt],
  );

  return { id, name: name.trim(), isDefault: 0, createdAt };
};

/**
 * Delete a workspace. Recordings that belonged to it are returned to Inbox (workspaceId = NULL).
 */
export const deleteWorkspace = async (id: string): Promise<void> => {
  const db = await getDatabase();
  await db.runAsync(`UPDATE recordings SET workspaceId = NULL WHERE workspaceId = ?`, [id]);
  await db.runAsync(`DELETE FROM workspaces WHERE id = ?`, [id]);
};

/**
 * Get all recordings in a specific workspace
 */
export const getRecordingsInWorkspace = async (
  workspaceId: string,
): Promise<RecordingRecord[]> => {
  const db = await getDatabase();
  return db.getAllAsync<RecordingRecord>(
    `SELECT * FROM recordings WHERE workspaceId = ? ORDER BY createdAt DESC`,
    [workspaceId],
  );
};
