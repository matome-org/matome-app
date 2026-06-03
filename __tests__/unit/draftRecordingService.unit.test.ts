/**
 * Unit tests for services/draftRecordingService.ts
 *
 * Covers the single-row draft persistence contract against the
 * recording_drafts table (migration 003 — columns: id, created_at,
 * segments_json, duration_ms):
 *   - saveDraft  : DELETE+INSERT wrapped in withTransactionAsync (atomic
 *                  single-row replace), bound params for segments_json +
 *                  duration_ms.
 *   - loadDraft  : parses segments_json → { segments, durationMs }; null on
 *                  empty; null + no-throw on malformed / non-array JSON.
 *   - deleteDraft: issues a DELETE.
 *
 * The data layer is mocked by alias path per the repo convention
 * (see .docs/TESTING.md + recordingService.calendar.test.ts).
 */

jest.mock("@/utils/database");

import {
  saveDraft,
  loadDraft,
  deleteDraft,
} from "@/services/draftRecordingService";
import { getDatabase } from "@/utils/database";

const mockGetDatabase = getDatabase as jest.MockedFunction<typeof getDatabase>;

/**
 * Factory for a mocked SQLite db handle. Extends the existing makeDbMock
 * pattern with getFirstAsync (used by loadDraft) and withTransactionAsync
 * (used by saveDraft). withTransactionAsync invokes its callback inline so
 * the runAsync calls inside the transaction are observable.
 */
function makeDbMock(firstRow: object | null = null) {
  const db = {
    runAsync: jest.fn().mockResolvedValue(undefined),
    getFirstAsync: jest.fn().mockResolvedValue(firstRow),
    withTransactionAsync: jest.fn(async (cb: () => Promise<void>) => {
      await cb();
    }),
  } as any;
  return db;
}

function makeDraftRow(
  overrides: Partial<{
    id: number;
    created_at: string;
    segments_json: string;
    duration_ms: number;
  }> = {},
) {
  return {
    id: overrides.id ?? 1,
    created_at: overrides.created_at ?? "2026-06-03T10:00:00.000Z",
    segments_json:
      overrides.segments_json ??
      JSON.stringify(["/audio/seg_0.m4a", "/audio/seg_1.m4a"]),
    duration_ms: overrides.duration_ms ?? 42000,
  };
}

// ---------------------------------------------------------------------------
// saveDraft
// ---------------------------------------------------------------------------

describe("saveDraft", () => {
  beforeEach(() => jest.clearAllMocks());

  it("wraps the DELETE+INSERT in withTransactionAsync", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await saveDraft(["/audio/seg_0.m4a"], 1000);

    expect(db.withTransactionAsync).toHaveBeenCalledTimes(1);
    // Both writes must have happened inside the transaction callback.
    expect(db.runAsync).toHaveBeenCalledTimes(2);
  });

  it("issues DELETE before INSERT inside the transaction (replace semantics)", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await saveDraft(["/audio/seg_0.m4a"], 1000);

    const firstSql = db.runAsync.mock.calls[0][0] as string;
    const secondSql = db.runAsync.mock.calls[1][0] as string;
    expect(firstSql).toMatch(/DELETE\s+FROM\s+recording_drafts/i);
    expect(secondSql).toMatch(/INSERT\s+INTO\s+recording_drafts/i);
  });

  it("binds segments_json (JSON.stringify) and duration_ms as INSERT params", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    const segments = ["/audio/seg_0.m4a", "/audio/seg_1.m4a"];
    const durationMs = 73210;
    await saveDraft(segments, durationMs);

    const [insertSql, params] = db.runAsync.mock.calls[1];
    // Column contract: created_at, segments_json, duration_ms (migration 003).
    expect(insertSql).toContain("created_at");
    expect(insertSql).toContain("segments_json");
    expect(insertSql).toContain("duration_ms");

    expect(Array.isArray(params)).toBe(true);
    // created_at (ISO string), segments_json (stringified array), duration_ms.
    expect(typeof params[0]).toBe("string");
    expect(params[1]).toBe(JSON.stringify(segments));
    expect(params[2]).toBe(durationMs);
  });

  it("keeps a single row: exactly one DELETE then one INSERT per save", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await saveDraft([], 0);

    const deletes = db.runAsync.mock.calls.filter((c: any[]) =>
      /DELETE/i.test(c[0]),
    );
    const inserts = db.runAsync.mock.calls.filter((c: any[]) =>
      /INSERT/i.test(c[0]),
    );
    expect(deletes).toHaveLength(1);
    expect(inserts).toHaveLength(1);
  });
});

// ---------------------------------------------------------------------------
// loadDraft
// ---------------------------------------------------------------------------

describe("loadDraft", () => {
  beforeEach(() => jest.clearAllMocks());

  it("returns { segments, durationMs } for a valid row (segments_json parsed to array)", async () => {
    const segments = ["/audio/a.m4a", "/audio/b.m4a"];
    const db = makeDbMock(
      makeDraftRow({
        segments_json: JSON.stringify(segments),
        duration_ms: 12345,
      }),
    );
    mockGetDatabase.mockResolvedValue(db);

    const result = await loadDraft();

    expect(result).toEqual({ segments, durationMs: 12345 });
    expect(Array.isArray(result?.segments)).toBe(true);
  });

  it("queries the recording_drafts table (column contract)", async () => {
    const db = makeDbMock(makeDraftRow());
    mockGetDatabase.mockResolvedValue(db);

    await loadDraft();

    const sql = db.getFirstAsync.mock.calls[0][0] as string;
    expect(sql).toMatch(/FROM\s+recording_drafts/i);
  });

  it("returns null when there is no draft row (empty)", async () => {
    const db = makeDbMock(null);
    mockGetDatabase.mockResolvedValue(db);

    const result = await loadDraft();
    expect(result).toBeNull();
  });

  it("returns null and does NOT throw on malformed segments_json (bad JSON)", async () => {
    const db = makeDbMock(
      makeDraftRow({ segments_json: "{not valid json" }),
    );
    mockGetDatabase.mockResolvedValue(db);

    await expect(loadDraft()).resolves.toBeNull();
  });

  it("does NOT throw on non-array JSON; Array.isArray guard yields empty segments", async () => {
    const db = makeDbMock(
      makeDraftRow({
        segments_json: JSON.stringify({ foo: "bar" }),
        duration_ms: 5000,
      }),
    );
    mockGetDatabase.mockResolvedValue(db);

    // Non-array parses cleanly (no catch) but fails the Array.isArray guard,
    // so segments stays the empty default — must never throw, never leak the
    // non-array value.
    const result = await loadDraft();
    expect(result).toEqual({ segments: [], durationMs: 5000 });
  });
});

// ---------------------------------------------------------------------------
// deleteDraft
// ---------------------------------------------------------------------------

describe("deleteDraft", () => {
  beforeEach(() => jest.clearAllMocks());

  it("issues a DELETE against recording_drafts", async () => {
    const db = makeDbMock();
    mockGetDatabase.mockResolvedValue(db);

    await deleteDraft();

    expect(db.runAsync).toHaveBeenCalledTimes(1);
    const sql = db.runAsync.mock.calls[0][0] as string;
    expect(sql).toMatch(/DELETE\s+FROM\s+recording_drafts/i);
  });
});
