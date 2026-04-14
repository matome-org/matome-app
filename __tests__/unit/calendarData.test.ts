/**
 * Unit tests for processes/calendarData.ts
 *
 * All DB/service calls are mocked at the module boundary.
 * No real SQLite database is opened.
 */

jest.mock("@/utils/database");
jest.mock("@/services/recordingService");

import { fetchDaysWithRecordings, fetchDayRecordings } from "@/processes/calendarData";
import { getRecordingsByDateRange } from "@/services/recordingService";
import { getDatabase } from "@/utils/database";

const mockGetRecordingsByDateRange = getRecordingsByDateRange as jest.MockedFunction<
  typeof getRecordingsByDateRange
>;
const mockGetDatabase = getDatabase as jest.MockedFunction<typeof getDatabase>;

function makeRecord(overrides: Partial<{ id: string; createdAt: number }> = {}) {
  return {
    id: overrides.id ?? "rec-1",
    title: "Stand-up call",
    summary: "",
    timestamp: "2026-04-10T09:00:00.000Z",
    duration: "1m 23s",
    badge: "Work" as const,
    isProcessing: 0 as const,
    audioFilePath: "/audio/rec-1.m4a",
    createdAt: overrides.createdAt ?? new Date(2026, 3, 10, 9, 0, 0).getTime(),
    workspaceId: "ws-1",
  };
}

// ---------------------------------------------------------------------------
// fetchDaysWithRecordings
// ---------------------------------------------------------------------------

describe("fetchDaysWithRecordings", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should return an empty Set when no recordings exist in the month", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([]);
    const result = await fetchDaysWithRecordings(2026, 3);
    expect(result).toBeInstanceOf(Set);
    expect(result.size).toBe(0);
  });

  it("should return day numbers for all days that have recordings", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([
      makeRecord({ id: "r1", createdAt: new Date(2026, 3, 1, 8, 0, 0).getTime() }),
      makeRecord({ id: "r2", createdAt: new Date(2026, 3, 15, 12, 0, 0).getTime() }),
      makeRecord({ id: "r3", createdAt: new Date(2026, 3, 28, 20, 0, 0).getTime() }),
    ]);
    const result = await fetchDaysWithRecordings(2026, 3);
    expect(result).toEqual(new Set([1, 15, 28]));
  });

  it("should deduplicate day numbers when multiple recordings fall on the same day", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([
      makeRecord({ id: "r1", createdAt: new Date(2026, 3, 10, 8, 0, 0).getTime() }),
      makeRecord({ id: "r2", createdAt: new Date(2026, 3, 10, 12, 0, 0).getTime() }),
      makeRecord({ id: "r3", createdAt: new Date(2026, 3, 10, 18, 0, 0).getTime() }),
    ]);
    const result = await fetchDaysWithRecordings(2026, 3);
    expect(result.size).toBe(1);
    expect(result.has(10)).toBe(true);
  });

  it("should query the correct epoch range for January (month 0)", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([]);
    await fetchDaysWithRecordings(2026, 0);

    const [startArg, endArg] = mockGetRecordingsByDateRange.mock.calls[0];
    const startDate = new Date(startArg);
    const endDate = new Date(endArg);

    expect(startDate.getMonth()).toBe(0);
    expect(startDate.getDate()).toBe(1);
    expect(startDate.getHours()).toBe(0);
    expect(endDate.getMonth()).toBe(0);
    expect(endDate.getDate()).toBe(31);
    expect(endDate.getHours()).toBe(23);
    expect(endDate.getMinutes()).toBe(59);
    expect(endDate.getSeconds()).toBe(59);
  });

  it("should query 29 days for February in a leap year (2028)", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([]);
    await fetchDaysWithRecordings(2028, 1);
    const [, endArg] = mockGetRecordingsByDateRange.mock.calls[0];
    expect(new Date(endArg).getDate()).toBe(29);
  });

  it("should query 28 days for February in a non-leap year (2026)", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([]);
    await fetchDaysWithRecordings(2026, 1);
    const [, endArg] = mockGetRecordingsByDateRange.mock.calls[0];
    expect(new Date(endArg).getDate()).toBe(28);
  });

  it("should query 31 days for December (month 11)", async () => {
    mockGetRecordingsByDateRange.mockResolvedValueOnce([]);
    await fetchDaysWithRecordings(2026, 11);
    const [, endArg] = mockGetRecordingsByDateRange.mock.calls[0];
    const endDate = new Date(endArg);
    expect(endDate.getDate()).toBe(31);
    expect(endDate.getMonth()).toBe(11);
  });

  it("should propagate errors thrown by the recording service", async () => {
    mockGetRecordingsByDateRange.mockRejectedValueOnce(new Error("DB error"));
    await expect(fetchDaysWithRecordings(2026, 3)).rejects.toThrow("DB error");
  });
});

// ---------------------------------------------------------------------------
// fetchDayRecordings
// ---------------------------------------------------------------------------

describe("fetchDayRecordings", () => {
  function mockDb(rows: object[]) {
    mockGetDatabase.mockResolvedValue({
      getAllAsync: jest.fn().mockResolvedValue(rows),
    } as any);
  }

  beforeEach(() => jest.clearAllMocks());

  it("should return an empty array when no recordings exist for the day", async () => {
    mockDb([]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result).toEqual([]);
  });

  it("should map duration '2m 45s' to 165 seconds", async () => {
    mockDb([{
      id: "rec-1", title: "Meeting", duration: "2m 45s", badge: "Work",
      createdAt: new Date(2026, 3, 10, 9, 0, 0).getTime(), workspaceName: "Engineering",
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].duration).toBe(165);
  });

  it("should map duration '5s' to 5 seconds", async () => {
    mockDb([{
      id: "rec-2", title: "Short", duration: "5s", badge: "Inbox",
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].duration).toBe(5);
  });

  it("should return 0 duration for unrecognised duration strings", async () => {
    mockDb([{
      id: "rec-3", title: "Bad", duration: "invalid", badge: "Inbox",
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].duration).toBe(0);
  });

  it("should return 0 duration for empty string", async () => {
    mockDb([{
      id: "rec-4", title: "Empty", duration: "", badge: "Inbox",
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].duration).toBe(0);
  });

  it("should coerce an unknown badge value to 'Inbox'", async () => {
    mockDb([{
      id: "rec-5", title: "Unknown", duration: "1m 0s", badge: "WeirdValue",
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].badge).toBe("Inbox");
  });

  it("should coerce a null badge value to 'Inbox'", async () => {
    mockDb([{
      id: "rec-6", title: "Null badge", duration: "1m 0s", badge: null,
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].badge).toBe("Inbox");
  });

  it("should preserve all valid badge values: Work, Personal, Inbox", async () => {
    mockDb([
      { id: "r1", title: "A", duration: "1m 0s", badge: "Work", createdAt: Date.now(), workspaceName: "Eng" },
      { id: "r2", title: "B", duration: "1m 0s", badge: "Personal", createdAt: Date.now(), workspaceName: null },
      { id: "r3", title: "C", duration: "1m 0s", badge: "Inbox", createdAt: Date.now(), workspaceName: null },
    ]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].badge).toBe("Work");
    expect(result[1].badge).toBe("Personal");
    expect(result[2].badge).toBe("Inbox");
  });

  it("should pass workspaceName as null for inbox recordings (LEFT JOIN returns NULL)", async () => {
    mockDb([{
      id: "rec-7", title: "Inbox item", duration: "0:30", badge: "Inbox",
      createdAt: new Date(2026, 3, 10).getTime(), workspaceName: null,
    }]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].workspaceName).toBeNull();
  });

  it("should query a midnight-to-end-of-day epoch window for the target date", async () => {
    const mockGetAllAsync = jest.fn().mockResolvedValue([]);
    mockGetDatabase.mockResolvedValue({ getAllAsync: mockGetAllAsync } as any);
    await fetchDayRecordings(new Date(2026, 3, 15));

    const [, params] = mockGetAllAsync.mock.calls[0];
    const [startEpoch, endEpoch] = params as number[];
    const startDate = new Date(startEpoch);

    expect(startDate.getFullYear()).toBe(2026);
    expect(startDate.getMonth()).toBe(3);
    expect(startDate.getDate()).toBe(15);
    expect(startDate.getHours()).toBe(0);
    expect(startDate.getMinutes()).toBe(0);
    expect(startDate.getSeconds()).toBe(0);
    expect(endEpoch - startEpoch).toBe(24 * 60 * 60 * 1000 - 1);
  });

  it("should preserve the DB-ordered result without client-side re-sorting", async () => {
    const t1 = new Date(2026, 3, 10, 18, 0, 0).getTime();
    const t2 = new Date(2026, 3, 10, 9, 0, 0).getTime();
    mockDb([
      { id: "r-late", title: "Evening", duration: "1m 0s", badge: "Inbox", createdAt: t1, workspaceName: null },
      { id: "r-early", title: "Morning", duration: "1m 0s", badge: "Inbox", createdAt: t2, workspaceName: null },
    ]);
    const result = await fetchDayRecordings(new Date(2026, 3, 10));
    expect(result[0].id).toBe("r-late");
    expect(result[1].id).toBe("r-early");
  });
});
