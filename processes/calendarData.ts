import { getDatabase } from "@/utils/database";
import { getRecordingsByDay, getRecordingsByDateRange } from "@/services/recordingService";
import type { BadgeType } from "@/processes/homeData";

export type CalendarRecordingCard = {
  id: string;
  title: string;
  duration: number;
  badge: BadgeType;
  workspaceName: string | null;
  createdAt: number;
};

/**
 * Internal row type returned by the JOIN query.
 */
type RecordingWithWorkspace = {
  id: string;
  title: string;
  duration: string;
  badge: string;
  createdAt: number;
  workspaceName: string | null;
};

/**
 * Parse duration string (e.g. "1:23" or "0:45") to total seconds.
 * Falls back to 0 for unrecognisable formats.
 */
const parseDurationSeconds = (duration: string): number => {
  if (!duration || typeof duration !== "string") return 0;
  const parts = duration.split(":").map(Number);
  if (parts.length === 2) {
    const [minutes, seconds] = parts;
    if (Number.isFinite(minutes) && Number.isFinite(seconds)) {
      return minutes * 60 + seconds;
    }
  }
  return 0;
};

const BADGE_VALUES: BadgeType[] = ["Work", "Personal", "Inbox"];

const coerceBadge = (value: unknown): BadgeType => {
  if (typeof value === "string" && BADGE_VALUES.includes(value as BadgeType)) {
    return value as BadgeType;
  }
  return "Inbox";
};

/**
 * Fetch the set of day-of-month numbers (1–31) that have at least one recording
 * in the given month.
 *
 * @param year  Full year, e.g. 2026
 * @param month 0-indexed month, e.g. 0 = January
 */
export const fetchDaysWithRecordings = async (
  year: number,
  month: number,
): Promise<Set<number>> => {
  // Month start: midnight local time on the 1st
  const monthStart = new Date(year, month, 1).setHours(0, 0, 0, 0);
  // Month end: last millisecond of the last day
  const monthEnd = new Date(year, month + 1, 0).setHours(23, 59, 59, 999);

  const records = await getRecordingsByDateRange(monthStart, monthEnd);

  const days = new Set<number>();
  for (const record of records) {
    const day = new Date(record.createdAt).getDate();
    days.add(day);
  }

  return days;
};

/**
 * Fetch CalendarRecordingCard list for the given calendar day.
 * Joins recordings with workspaces to include workspace name.
 */
export const fetchDayRecordings = async (
  date: Date,
): Promise<CalendarRecordingCard[]> => {
  // Compute midnight local time for the target day
  const dayStart = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
  ).setHours(0, 0, 0, 0);

  const dayEnd = dayStart + 24 * 60 * 60 * 1000 - 1;

  const db = await getDatabase();

  const rows = await db.getAllAsync<RecordingWithWorkspace>(
    `SELECT
       r.id,
       r.title,
       r.duration,
       r.badge,
       r.createdAt,
       w.name AS workspaceName
     FROM recordings r
     LEFT JOIN workspaces w ON r.workspaceId = w.id
     WHERE r.createdAt >= ? AND r.createdAt <= ?
     ORDER BY r.createdAt DESC`,
    [dayStart, dayEnd],
  );

  return rows.map((row) => ({
    id: typeof row.id === "string" ? row.id : String(row.id),
    title: typeof row.title === "string" ? row.title : String(row.title ?? ""),
    duration: parseDurationSeconds(row.duration),
    badge: coerceBadge(row.badge),
    workspaceName:
      row.workspaceName != null
        ? typeof row.workspaceName === "string"
          ? row.workspaceName
          : String(row.workspaceName)
        : null,
    createdAt:
      typeof row.createdAt === "number"
        ? row.createdAt
        : Number(row.createdAt),
  }));
};
