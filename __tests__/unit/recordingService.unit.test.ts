/**
 * Unit tests for the CRUD + row-mapping surface of recordingService.ts
 * NOT already covered by recordingService.calendar.test.ts (which owns
 * getRecordingsByDateRange / getRecordingsByDay).
 *
 * Covered here:
 *   - createRecording        (INSERT columns + isProcessing/summary mapping)
 *   - getAllRecordings       (SELECT ... ORDER BY createdAt DESC, row passthrough)
 *   - getInboxRecordings     (workspaceId IS NULL filter)
 *   - getRecordingById       (getFirstAsync → record | null, bound id)
 *   - updateRecording        (dynamic UPDATE SET + bound params, isProcessing 0/1)
 *   - deleteRecording        (DELETE WHERE id = ?)
 *   - getRecordingsByDayWithWorkspace (LEFT JOIN window + bound params)
 *   - recordToCard           (RecordingRecord → RecordingCard, isProcessing 1 → boolean)
 */

jest.mock("@/utils/database");

import {
  createRecording,
  getAllRecordings,
  getInboxRecordings,
  getRecordingById,
  updateRecording,
  deleteRecording,
  getRecordingsByDayWithWorkspace,
  recordToCard,
  type RecordingRecord,
} from "@/services/recordingService";
import { getDatabase } from "@/utils/database";

const mockGetDatabase = getDatabase as jest.MockedFunction<typeof getDatabase>;

function makeDbMock(rows: object[] = [], firstRow: object | null = null) {
  return {
    getAllAsync: jest.fn().mockResolvedValue(rows),
    getFirstAsync: jest.fn().mockResolvedValue(firstRow),
    runAsync: jest.fn().mockResolvedValue(undefined),
  } as any;
}

function makeRow(overrides: Partial<RecordingRecord> = {}): RecordingRecord {
  return {
    id: "rec-abc",
    title: "Weekly review",
    summary: "",
    timestamp: "2026-04-10T10:00:00.000Z",
    duration: "3:12",
    badge: "Personal",
    isProcessing: 0,
    audioFilePath: "/audio/rec-abc.m4a",
    createdAt: new Date(2026, 3, 10, 10, 0, 0).getTime(),
    workspaceId: null as any,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// createRecording
// ---------------------------------------------------------------------------

describe("createRecording", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should INSERT into recordings with the full column list", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await createRecording(makeRow({ summary: "a summary" }) as any);

    expect(db.runAsync).toHaveBeenCalledTimes(1);
    const [sql] = db.runAsync.mock.calls[0];
    expect(sql).toContain("INSERT INTO recordings");
    expect(sql).toContain(
      "id, title, summary, timestamp, duration, badge, isProcessing, audioFilePath, createdAt",
    );
  });

  it("should bind the recording fields in column order", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    const createdAt = new Date(2026, 3, 10, 10, 0, 0).getTime();
    await createRecording(
      makeRow({
        id: "rec-1",
        title: "My title",
        summary: "My summary",
        timestamp: "2026-04-10T10:00:00.000Z",
        duration: "1:00",
        badge: "Work",
        audioFilePath: "/audio/rec-1.m4a",
        createdAt,
        isProcessing: true as any,
      }) as any,
    );

    const [, params] = db.runAsync.mock.calls[0];
    expect(params).toEqual([
      "rec-1",
      "My title",
      "My summary",
      "2026-04-10T10:00:00.000Z",
      "1:00",
      "Work",
      1, // isProcessing true → 1
      "/audio/rec-1.m4a",
      createdAt,
    ]);
  });

  it("should persist isProcessing as 0 when omitted/falsey", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    const { isProcessing, workspaceId, ...rest } = makeRow();
    await createRecording(rest as any);

    const [, params] = db.runAsync.mock.calls[0];
    expect(params[6]).toBe(0);
  });

  it("should normalize an undefined summary to an empty string", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    const row = makeRow();
    delete (row as any).summary;
    await createRecording(row as any);

    const [, params] = db.runAsync.mock.calls[0];
    expect(params[2]).toBe("");
  });

  it("should reject an invalid badge", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await expect(
      createRecording(makeRow({ badge: "Nope" as any }) as any),
    ).rejects.toThrow(/badge/i);
  });

  it("should propagate a DB write failure", async () => {
    const db = makeDbMock();
    db.runAsync.mockRejectedValueOnce(new Error("disk full"));
    mockGetDatabase.mockResolvedValue(db);

    await expect(createRecording(makeRow() as any)).rejects.toThrow("disk full");
  });
});

// ---------------------------------------------------------------------------
// getAllRecordings
// ---------------------------------------------------------------------------

describe("getAllRecordings", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should SELECT all recordings ordered by createdAt DESC", async () => {
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getAllRecordings();

    const [sql] = db.getAllAsync.mock.calls[0];
    expect(sql).toContain("SELECT * FROM recordings");
    expect(sql).toContain("ORDER BY createdAt DESC");
  });

  it("should return the rows the DB yields, preserving order", async () => {
    const rows = [makeRow({ id: "r1" }), makeRow({ id: "r2" })];
    const db = makeDbMock(rows);
    mockGetDatabase.mockResolvedValue(db);

    const result = await getAllRecordings();
    expect(result).toHaveLength(2);
    expect(result[0].id).toBe("r1");
    expect(result[1].id).toBe("r2");
  });

  it("should return an empty array when there are no recordings", async () => {
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);
    expect(await getAllRecordings()).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// getInboxRecordings
// ---------------------------------------------------------------------------

describe("getInboxRecordings", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should filter on workspaceId IS NULL ordered DESC", async () => {
    const db = makeDbMock([makeRow({ id: "inbox-1" })]);
    mockGetDatabase.mockResolvedValue(db);

    const result = await getInboxRecordings();

    const [sql] = db.getAllAsync.mock.calls[0];
    expect(sql).toContain("workspaceId IS NULL");
    expect(sql).toContain("ORDER BY createdAt DESC");
    expect(result[0].id).toBe("inbox-1");
  });
});

// ---------------------------------------------------------------------------
// getRecordingById
// ---------------------------------------------------------------------------

describe("getRecordingById", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should query by id with getFirstAsync and bind the id", async () => {
    const db = makeDbMock([], makeRow({ id: "rec-xyz" }));
    mockGetDatabase.mockResolvedValue(db);

    const result = await getRecordingById("rec-xyz");

    const [sql, boundId] = db.getFirstAsync.mock.calls[0];
    expect(sql).toContain("WHERE id = ?");
    expect(boundId).toBe("rec-xyz");
    expect(result?.id).toBe("rec-xyz");
  });

  it("should return null when no row is found", async () => {
    const db = makeDbMock([], null);
    mockGetDatabase.mockResolvedValue(db);

    expect(await getRecordingById("missing")).toBeNull();
  });

  it("should map the row fields through to the returned record", async () => {
    const row = makeRow({
      id: "rec-map",
      title: "Mapped",
      summary: "S",
      duration: "5:00",
      badge: "Work",
      isProcessing: 1,
      audioFilePath: "/audio/rec-map.m4a",
    });
    const db = makeDbMock([], row);
    mockGetDatabase.mockResolvedValue(db);

    const result = await getRecordingById("rec-map");
    expect(result).toMatchObject({
      id: "rec-map",
      title: "Mapped",
      summary: "S",
      duration: "5:00",
      badge: "Work",
      isProcessing: 1,
      audioFilePath: "/audio/rec-map.m4a",
    });
  });
});

// ---------------------------------------------------------------------------
// updateRecording
// ---------------------------------------------------------------------------

describe("updateRecording", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should UPDATE summary and bind value + id", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", { summary: "new summary" });

    const [sql, values] = db.runAsync.mock.calls[0];
    expect(sql).toContain("UPDATE recordings SET");
    expect(sql).toContain("summary = ?");
    expect(sql).toContain("WHERE id = ?");
    expect(values).toEqual(["new summary", "rec-1"]);
  });

  it("should map isProcessing=true to 1 and append the id last", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", { isProcessing: true });

    const [sql, values] = db.runAsync.mock.calls[0];
    expect(sql).toContain("isProcessing = ?");
    expect(values).toEqual([1, "rec-1"]);
  });

  it("should map isProcessing=false to 0", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", { isProcessing: false });

    const [, values] = db.runAsync.mock.calls[0];
    expect(values).toEqual([0, "rec-1"]);
  });

  it("should build a multi-field SET clause in declaration order", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", {
      summary: "S",
      title: "T",
      isProcessing: true,
      badge: "Work",
    });

    const [sql, values] = db.runAsync.mock.calls[0];
    expect(sql).toBe(
      "UPDATE recordings SET summary = ?, title = ?, isProcessing = ?, badge = ? WHERE id = ?",
    );
    expect(values).toEqual(["S", "T", 1, "Work", "rec-1"]);
  });

  it("should not issue any DB call when there are no updatable fields", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", {});

    expect(db.runAsync).not.toHaveBeenCalled();
  });

  it("should reject a non-boolean isProcessing", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await expect(
      updateRecording("rec-1", { isProcessing: 1 as any }),
    ).rejects.toThrow(/isProcessing/i);
  });

  it("should reject a blank workspaceId", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await expect(
      updateRecording("rec-1", { workspaceId: "   " }),
    ).rejects.toThrow(/workspaceId/i);
  });

  it("should persist a provided notes value", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await updateRecording("rec-1", { notes: "remember this" });

    const [sql, values] = db.runAsync.mock.calls[0];
    expect(sql).toContain("notes = ?");
    expect(values).toEqual(["remember this", "rec-1"]);
  });
});

// ---------------------------------------------------------------------------
// deleteRecording
// ---------------------------------------------------------------------------

describe("deleteRecording", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should DELETE the row by id", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await deleteRecording("rec-1");

    const [sql, params] = db.runAsync.mock.calls[0];
    expect(sql).toBe("DELETE FROM recordings WHERE id = ?");
    expect(params).toEqual(["rec-1"]);
  });

  it("should propagate a DB delete failure", async () => {
    const db = makeDbMock();
    db.runAsync.mockRejectedValueOnce(new Error("locked"));
    mockGetDatabase.mockResolvedValue(db);

    await expect(deleteRecording("rec-1")).rejects.toThrow("locked");
  });
});

// ---------------------------------------------------------------------------
// getRecordingsByDayWithWorkspace
// ---------------------------------------------------------------------------

describe("getRecordingsByDayWithWorkspace", () => {
  beforeEach(() => jest.clearAllMocks());

  it("should LEFT JOIN workspaces and bind the [dayStart, dayEnd] window", async () => {
    const dayStart = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);

    await getRecordingsByDayWithWorkspace(dayStart);

    const [sql, params] = db.getAllAsync.mock.calls[0];
    expect(sql).toContain("LEFT JOIN workspaces");
    expect(sql).toContain("w.name AS workspaceName");
    expect(params[0]).toBe(dayStart);
    expect(params[1]).toBe(dayStart + 24 * 60 * 60 * 1000 - 1);
  });

  it("should return joined rows including workspaceName", async () => {
    const dayStart = new Date(2026, 3, 10, 0, 0, 0, 0).getTime();
    const db = makeDbMock([
      { ...makeRow({ id: "joined" }), workspaceName: "My Space" },
    ]);
    mockGetDatabase.mockResolvedValue(db);

    const result = await getRecordingsByDayWithWorkspace(dayStart);
    expect(result[0].id).toBe("joined");
    expect(result[0].workspaceName).toBe("My Space");
  });

  it("should throw when dayEpoch is NaN", async () => {
    const db = makeDbMock([]);
    mockGetDatabase.mockResolvedValue(db);
    await expect(getRecordingsByDayWithWorkspace(NaN)).rejects.toThrow();
  });
});

// ---------------------------------------------------------------------------
// recordToCard
// ---------------------------------------------------------------------------

describe("recordToCard", () => {
  it("should map isProcessing=1 to boolean true", () => {
    const card = recordToCard(makeRow({ isProcessing: 1 }));
    expect(card.isProcessing).toBe(true);
  });

  it("should map isProcessing=0 to boolean false", () => {
    const card = recordToCard(makeRow({ isProcessing: 0 }));
    expect(card.isProcessing).toBe(false);
  });

  it("should carry the display fields through to the card", () => {
    const card = recordToCard(
      makeRow({
        id: "rec-card",
        title: "Card title",
        summary: "Card summary",
        timestamp: "2026-04-10T10:00:00.000Z",
        duration: "2:30",
        badge: "Personal",
        notes: "some notes",
      }),
    );
    expect(card).toMatchObject({
      id: "rec-card",
      title: "Card title",
      summary: "Card summary",
      timestamp: "2026-04-10T10:00:00.000Z",
      duration: "2:30",
      badge: "Personal",
      notes: "some notes",
    });
  });
});
