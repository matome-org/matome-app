import { getRecordingsByDateRange, getRecordingsByDayWithWorkspace } from "@/services/recordingService";
import type { BadgeType } from "@/processes/homeData";

export type CalendarRecordingCard = {
  id: string;
  title: string;
  duration: number;
  badge: BadgeType;
  workspaceName: string | null;
  workspaceId: string | null;
  createdAt: number;
};


/**
 * Parse a duration string produced by audioRecordingService.formatDuration.
 *
 * formatDuration outputs:
 *   - "2m 14s"  (minutes + seconds)
 *   - "45s"     (seconds only, when < 60)
 *
 * Falls back to 0 for unrecognisable formats.
 */
const parseDurationSeconds = (duration: string): number => {
  if (!duration || typeof duration !== "string") return 0;

  // "Xm Ys" — e.g. "2m 14s"
  const minsAndSecs = duration.match(/^(\d+)m\s+(\d+)s$/);
  if (minsAndSecs) {
    const minutes = Number(minsAndSecs[1]);
    const seconds = Number(minsAndSecs[2]);
    if (Number.isFinite(minutes) && Number.isFinite(seconds)) {
      return minutes * 60 + seconds;
    }
  }

  // "Xs" — e.g. "45s"
  const secsOnly = duration.match(/^(\d+)s$/);
  if (secsOnly) {
    const seconds = Number(secsOnly[1]);
    if (Number.isFinite(seconds)) {
      return seconds;
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
 * Delegates to getRecordingsByDayWithWorkspace so all SQL parameters are
 * coerced through coerceSqlitePrimitive — avoids the Android Kotlin-type crash.
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

  const rows = await getRecordingsByDayWithWorkspace(dayStart);

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
    workspaceId:
      row.workspaceId != null
        ? typeof row.workspaceId === "string"
          ? row.workspaceId
          : String(row.workspaceId)
        : null,
    createdAt:
      typeof row.createdAt === "number"
        ? row.createdAt
        : Number(row.createdAt),
  }));
};
