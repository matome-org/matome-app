/**
 * Unit tests for the calendar-specific additions to recordingService.ts:
 *   - getRecordingsByDateRange
 *   - getRecordingsByDay
 */

jest.mock("@/utils/database");

import { getRecordingsByDateRange, getRecordingsByDay } from "@/services/recordingService";
import { getDatabase } from "@/utils/database";

const mockGetDatabase = getDatabase as jest.MockedFunction<typeof getDatabase>;

function makeDbMock(rows: object[] = []) {
  return {
    getAllAsync: jest.fn().mockResolvedValue(rows),
    runAsync: jest.fn().mockResolvedValue(undefined),
  } as any;
}

function makeRow(overrides: Partial<{ id: string; createdAt: number }> = {}) {
  return {
    id: overrides.id ?? "rec-abc",
    title: "Weekly review",
    summary: "",
    timestamp: "2026-04-10T10:00:00.000Z",
    duration: "3:12",
    badge: "Personal",
    isProcessing: 0,
    audioFilePath: "/audio/rec-abc.m4a",
    createdAt: overrides.createdAt ?? new Date(2026, 3, 10, 10, 0, 0).getTime(),
    workspaceId: null,
  };
}

// ---------------------------------------------------------------------------
// getRecordingsByDateRange
// ---------------------------------------------------------------------------

describe("getRecordingsByDateRange", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should return an empty array when no recordings fall within the range", async () => {
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);
    const result = await getRecordingsByDateRange(0, 1000);
    expect(result).toEqual([]);
    expect(db.getAllAsync).toHaveBeenCalledTimes(1);
  });

  it("should return all matching recordings from the DB", async () => {
    const rows = [
      makeRow({ id: "r1", createdAt: new Date(2026, 3, 10).getTime() }),
      makeRow({ id: "r2", createdAt: new Date(2026, 3, 20).getTime() }),
    ];
    const db = makeDbMock(rows);
    mockGetDatabase.mockResolvedValue(db);

    const start = new Date(2026, 3, 1).getTime();
    const end = new Date(2026, 3, 30).getTime();
    const result = await getRecordingsByDateRange(start, end);
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe("r1");
    expect(result[1].id).toBe("r2");
  });

  it("should pass start and end epoch values as SQL parameters", async () => {
    const start = 1_000_000;
    const end = 9_999_999;
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getRecordingsByDateRange(start, end);

    const [sql, params] = db.getAllAsync.mock.calls[0];
    expect(sql).toContain("createdAt >= ?");
    expect(sql).toContain("createdAt <= ?");
    expect(params).toContain(start);
    expect(params).toContain(end);
  });

  it("should throw when startEpoch is NaN", async () => {
    await expect(getRecordingsByDateRange(NaN, 1000)).rejects.toThrow();
  });

  it("should include a recording whose createdAt exactly equals a boundary value", async () => {
    const boundary = new Date(2026, 3, 15, 0, 0, 0).getTime();
    const db = makeDbMock([makeRow({ id: "boundary-rec", createdAt: boundary })]);
    mockGetDatabase.mockResolvedValue(db);
    const result = await getRecordingsByDateRange(boundary, boundary);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe("boundary-rec");
  });

  it("should preserve DB result order (newest first, as imposed by ORDER BY createdAt DESC)", async () => {
    const rows = [
      makeRow({ id: "newest", createdAt: 2000 }),
      makeRow({ id: "oldest", createdAt: 1000 }),
    ];
    const db = makeDbMock(rows);
    mockGetDatabase.mockResolvedValue(db);
    const result = await getRecordingsByDateRange(1000, 2000);
    expect(result[0].id).toBe("newest");
    expect(result[1].id).toBe("oldest");
  });
});

// ---------------------------------------------------------------------------
// getRecordingsByDay
// ---------------------------------------------------------------------------

describe("getRecordingsByDay", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should query a 24-hour window starting from the provided midnight epoch", async () => {
    const dayStart = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getRecordingsByDay(dayStart);

    const [, params] = db.getAllAsync.mock.calls[0];
    const [passedStart, passedEnd] = params as number[];
    expect(passedStart).toBe(dayStart);
    expect(passedEnd).toBe(dayStart + 24 * 60 * 60 * 1000 - 1);
  });

  it("should return recordings that fall within the computed day window", async () => {
    const dayStart = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const midday = new Date(2026, 3, 10, 12, 0, 0).getTime();
    const db = makeDbMock([makeRow({ id: "midday-rec", createdAt: midday })]);
    mockGetDatabase.mockResolvedValue(db);

    const result = await getRecordingsByDay(dayStart);
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe("midday-rec");
  });

  it("should return an empty array when no recordings fall on that day", async () => {
    const dayStart = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);
    const result = await getRecordingsByDay(dayStart);
    expect(result).toEqual([]);
  });

  it("should throw when dayEpoch is NaN", async () => {
    await expect(getRecordingsByDay(NaN)).rejects.toThrow();
  });

  it("should set the end boundary to 23:59:59.999 of the given day", async () => {
    const midnight = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getRecordingsByDay(midnight);

    const [, params] = db.getAllAsync.mock.calls[0];
    const end = params[1] as number;
    const endDate = new Date(end);
    expect(endDate.getHours()).toBe(23);
    expect(endDate.getMinutes()).toBe(59);
    expect(endDate.getSeconds()).toBe(59);
    expect(endDate.getMilliseconds()).toBe(999);
  });

  it("should set end boundary on the correct calendar date (not the next day)", async () => {
    const midnight = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getRecordingsByDay(midnight);

    const [, params] = db.getAllAsync.mock.calls[0];
    const end = params[1] as number;
    const endDate = new Date(end);
    expect(endDate.getDate()).toBe(10);
    expect(endDate.getMonth()).toBe(3);
  });
});
