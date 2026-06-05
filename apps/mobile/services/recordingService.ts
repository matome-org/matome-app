import { getDatabase } from "@/utils/database";
import type { RecordingCard, BadgeType } from "@/processes/homeData";

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

const BADGE_VALUES: BadgeType[] = ["Work", "Personal", "Inbox"];

type SQLitePrimitive = string | number | null;

/**
 * Force a value to a plain JS primitive suitable for expo-sqlite binding.
 * Eliminates boxed String/Number, exotic toString objects, and any
 * non-primitive that would cause "Cannot convert '[object Object]' to a Kotlin type".
 */
const coerceSqlitePrimitive = (value: SQLitePrimitive, label: string): SQLitePrimitive => {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return +value; // coerce Number objects to primitive
  if (typeof value === "string") return "" + value; // coerce String objects to primitive
  throw new Error(`[coerceSqlitePrimitive] unexpected type (${typeof value}) for ${label}: ${String(value)}`);
};

const getParamType = (value: unknown): string => {
  if (value === null) {
    return "null";
  }
  if (value instanceof Uint8Array) {
    return "Uint8Array";
  }
  if (Array.isArray(value)) {
    return "array";
  }
  return typeof value;
};

const normalizeStringLike = (value: unknown, field: string): string => {
  if (typeof value === "string") {
    return value;
  }
  if (value instanceof String) {
    return value.valueOf();
  }
  if (value && typeof value === "object" && typeof (value as { toString?: () => string }).toString === "function") {
    const converted = (value as { toString: () => string }).toString();
    if (converted && converted !== "[object Object]") {
      return converted;
    }
  }
  throw new Error(`Invalid ${field}: expected string-like value`);
};

const assertString = (value: unknown, field: string): string => {
  return normalizeStringLike(value, field);
};

const assertNumber = (value: unknown, field: string): number => {
  const normalized =
    typeof value === "number"
      ? value
      : value instanceof Number
        ? value.valueOf()
        : NaN;
  if (!Number.isFinite(normalized)) {
    throw new Error(`Invalid ${field}: expected finite number`);
  }
  return normalized;
};

const assertBadge = (value: unknown): BadgeType => {
  if (typeof value !== "string" || !BADGE_VALUES.includes(value as BadgeType)) {
    throw new Error("Invalid badge: expected Work, Personal, or Inbox");
  }
  return value as BadgeType;
};

/**
 * Normalize summary for SQLite binding.
 * Returns "" instead of null because expo-modules-core (Android, v3.0.x)
 * AnyFrontendConvert::convert does NOT handle JS null inside Map<String, Any?>
 * — it skips the null check and crashes at jsi::Value::asObject().
 * Empty string is used as a safe substitute for TEXT NULL columns.
 */
const normalizeSummary = (value: unknown): string => {
  if (value === undefined || value === null || value === "") {
    return "";
  }
  return assertString(value, "summary");
};

const normalizeOptionalString = (
  value: unknown,
  field: string,
): string | undefined => {
  if (value === undefined) {
    return undefined;
  }
  return assertString(value, field);
};


/**
 * Create a new recording in the database.
 * New recordings start in the Inbox (workspaceId = NULL).
 */
export const createRecording = async (
  recording: Omit<RecordingRecord, "isProcessing" | "workspaceId"> & {
    isProcessing?: boolean;
  },
): Promise<void> => {
  const db = await getDatabase();
  const recordId = assertString(recording.id, "id");
  const params: SQLitePrimitive[] = [
    coerceSqlitePrimitive(recordId, "id"),
    coerceSqlitePrimitive(assertString(recording.title, "title"), "title"),
    coerceSqlitePrimitive(normalizeSummary(recording.summary), "summary"),
    coerceSqlitePrimitive(assertString(recording.timestamp, "timestamp"), "timestamp"),
    coerceSqlitePrimitive(assertString(recording.duration, "duration"), "duration"),
    coerceSqlitePrimitive(assertBadge(recording.badge), "badge"),
    coerceSqlitePrimitive(recording.isProcessing ? 1 : 0, "isProcessing"),
    coerceSqlitePrimitive(assertString(recording.audioFilePath, "audioFilePath"), "audioFilePath"),
    coerceSqlitePrimitive(assertNumber(recording.createdAt, "createdAt"), "createdAt"),
  ];

  try {
    await db.runAsync(
      `INSERT INTO recordings (id, title, summary, timestamp, duration, badge, isProcessing, audioFilePath, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      params,
    );
  } catch (error) {
    console.error(
      "SQLite createRecording failed",
      {
        operation: "createRecording",
        recordingId: recordId,
        parameterTypes: params.map(getParamType),
      },
      error,
    );
    throw error;
  }
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
 * Get inbox recordings (workspaceId IS NULL), ordered by creation date (newest first)
 */
export const getInboxRecordings = async (): Promise<RecordingRecord[]> => {
  const db = await getDatabase();

  const result = await db.getAllAsync<RecordingRecord>(
    `SELECT * FROM recordings WHERE workspaceId IS NULL ORDER BY createdAt DESC`,
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
    id,
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
  const recordId = assertString(id, "id");

  const fields: string[] = [];
  const values: (string | number | null)[] = [];

  if (updates.summary !== undefined && updates.summary !== null && updates.summary !== "") {
    fields.push("summary = ?");
    values.push(coerceSqlitePrimitive(assertString(updates.summary, "summary"), "summary"));
  }

  if (updates.title !== undefined && updates.title !== null && updates.title !== "") {
    fields.push("title = ?");
    values.push(coerceSqlitePrimitive(assertString(updates.title, "title"), "title"));
  }

  if (updates.isProcessing !== undefined) {
    if (typeof updates.isProcessing !== "boolean") {
      throw new Error("Invalid isProcessing: expected boolean");
    }
    fields.push("isProcessing = ?");
    values.push(coerceSqlitePrimitive(updates.isProcessing ? 1 : 0, "isProcessing"));
  }

  if (updates.badge !== undefined && updates.badge !== null) {
    fields.push("badge = ?");
    values.push(coerceSqlitePrimitive(assertBadge(updates.badge), "badge"));
  }

  if (updates.notes !== undefined) {
    const notes = normalizeOptionalString(updates.notes, "notes");
    fields.push("notes = ?");
    // Use "" instead of null — see normalizeSummary comment for the Android bridge bug.
    values.push(coerceSqlitePrimitive(notes ?? "", "notes"));
  }

  if (updates.workspaceId !== undefined) {
    const workspaceId = normalizeOptionalString(updates.workspaceId, "workspaceId");
    if (!workspaceId || !workspaceId.trim()) {
      throw new Error("Invalid workspaceId: expected non-empty string");
    }
    fields.push("workspaceId = ?");
    values.push(coerceSqlitePrimitive(workspaceId, "workspaceId"));
  }

  if (fields.length === 0) {
    return; // No updates to make
  }

  values.push(coerceSqlitePrimitive(recordId, "id"));

  try {
    await db.runAsync(`UPDATE recordings SET ${fields.join(", ")} WHERE id = ?`, values);
  } catch (error) {
    console.error(
      "SQLite updateRecording failed",
      { operation: "updateRecording", recordingId: recordId },
      error,
    );
    throw error;
  }
};

/**
 * Delete a recording
 */
export const deleteRecording = async (id: string): Promise<void> => {
  const db = await getDatabase();
  const recordId = assertString(id, "id");

  try {
    await db.runAsync(`DELETE FROM recordings WHERE id = ?`, [coerceSqlitePrimitive(recordId, "id")]);
  } catch (error) {
    console.error(
      "SQLite deleteRecording failed",
      { operation: "deleteRecording", recordingId: recordId },
      error,
    );
    throw error;
  }
};

/**
 * Get recordings where createdAt is between startEpoch and endEpoch (inclusive),
 * ordered by createdAt DESC.
 */
export const getRecordingsByDateRange = async (
  startEpoch: number,
  endEpoch: number,
): Promise<RecordingRecord[]> => {
  const db = await getDatabase();

  const result = await db.getAllAsync<RecordingRecord>(
    `SELECT * FROM recordings WHERE createdAt >= ? AND createdAt <= ? ORDER BY createdAt DESC`,
    [
      coerceSqlitePrimitive(assertNumber(startEpoch, "startEpoch"), "startEpoch"),
      coerceSqlitePrimitive(assertNumber(endEpoch, "endEpoch"), "endEpoch"),
    ],
  );

  return result;
};

/**
 * Get recordings for a single calendar day (midnight to midnight local time),
 * ordered by createdAt DESC.
 * dayEpoch must be the start-of-day epoch (midnight local time) for the target day.
 */
export const getRecordingsByDay = async (
  dayEpoch: number,
): Promise<RecordingRecord[]> => {
  const dayStart = assertNumber(dayEpoch, "dayEpoch");
  // End of the same calendar day — next midnight minus 1 ms
  const dayEnd = dayStart + 24 * 60 * 60 * 1000 - 1;

  return getRecordingsByDateRange(dayStart, dayEnd);
};

export interface RecordingWithWorkspaceName extends RecordingRecord {
  workspaceName: string | null;
}

/**
 * Get recordings for a single calendar day, LEFT JOINed with workspaces so
 * that the workspace name is available for display and the workspaceId is
 * available for ID-based filtering.
 *
 * Uses coerceSqlitePrimitive on every bound parameter to avoid the Android
 * "Cannot convert to Kotlin type" crash that occurs with uncoerced values.
 */
export const getRecordingsByDayWithWorkspace = async (
  dayEpoch: number,
): Promise<RecordingWithWorkspaceName[]> => {
  const db = await getDatabase();
  const dayStart = coerceSqlitePrimitive(assertNumber(dayEpoch, "dayEpoch"), "dayEpoch");
  const dayEnd = coerceSqlitePrimitive(
    (dayStart as number) + 24 * 60 * 60 * 1000 - 1,
    "dayEnd",
  );

  try {
    const rows = await db.getAllAsync<RecordingWithWorkspaceName>(
      `SELECT
         r.id,
         r.title,
         r.summary,
         r.timestamp,
         r.duration,
         r.badge,
         r.isProcessing,
         r.audioFilePath,
         r.createdAt,
         r.workspaceId,
         r.notes,
         w.name AS workspaceName
       FROM recordings r
       LEFT JOIN workspaces w ON r.workspaceId = w.id
       WHERE r.createdAt >= ? AND r.createdAt <= ?
       ORDER BY r.createdAt DESC`,
      [dayStart, dayEnd],
    );
    return rows;
  } catch (error) {
    console.error(
      "SQLite getRecordingsByDayWithWorkspace failed",
      { operation: "getRecordingsByDayWithWorkspace", dayEpoch },
      error,
    );
    throw error;
  }
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
