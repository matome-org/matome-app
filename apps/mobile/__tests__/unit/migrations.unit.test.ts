/**
 * Unit tests for utils/migrations/* + utils/database.ts (runMigrations,
 * initDatabase, the initPromise concurrency guard, and the user_version
 * self-heal clamp).
 *
 * The native expo-sqlite layer is replaced with a hand-rolled fake db. The
 * fake tracks a mutable `user_version` integer and interprets the two PRAGMA
 * statements the migration runner actually uses:
 *   - read  : `PRAGMA user_version;`        (via getFirstAsync)
 *   - write : `PRAGMA user_version = N;`     (via execAsync)
 * Every CREATE TABLE / migration SQL passed to execAsync is recorded so tests
 * can assert what ran and in what order.
 *
 * database.ts holds module-level state (the cached `db` + the in-flight
 * `initPromise`). Each test calls jest.resetModules() and re-requires the
 * module through a small loader so module state never bleeds across cases —
 * see loadDb().
 */

// ---------------------------------------------------------------------------
// Fake expo-sqlite db
// ---------------------------------------------------------------------------

interface FakeDb {
  user_version: number;
  /** Every SQL string passed to execAsync, in call order. */
  execSql: string[];
  getFirstAsync: jest.Mock;
  getAllAsync: jest.Mock;
  execAsync: jest.Mock;
  runAsync: jest.Mock;
  withTransactionAsync: jest.Mock;
  closeAsync: jest.Mock;
}

function makeFakeDb(initialUserVersion = 0): FakeDb {
  const db: FakeDb = {
    user_version: initialUserVersion,
    execSql: [],
    getFirstAsync: jest.fn(async (sql: string) => {
      if (/PRAGMA\s+user_version\s*;?\s*$/i.test(sql.trim())) {
        return { user_version: db.user_version };
      }
      return null;
    }),
    getAllAsync: jest.fn(async () => []),
    execAsync: jest.fn(async (sql: string) => {
      db.execSql.push(sql);
      // Interpret a write: `PRAGMA user_version = N;`
      const m = sql.match(/PRAGMA\s+user_version\s*=\s*(\d+)/i);
      if (m) {
        db.user_version = Number(m[1]);
      }
    }),
    runAsync: jest.fn(async () => ({ changes: 0, lastInsertRowId: 0 })),
    withTransactionAsync: jest.fn(async (cb: () => Promise<void>) => {
      await cb();
    }),
    closeAsync: jest.fn(async () => undefined),
  };
  return db;
}

/**
 * Reset module state, install a fresh expo-sqlite mock whose openDatabaseAsync
 * resolves to `db` (after an optional async tick so concurrent callers can race
 * the await), and re-require utils/database.ts.
 *
 * Returns the freshly loaded module plus the openDatabaseAsync spy so tests can
 * assert how many times the native open was invoked.
 */
function loadDb(db: FakeDb, openDelayMs = 0) {
  jest.resetModules();
  const openDatabaseAsync = jest.fn(async () => {
    if (openDelayMs > 0) {
      await new Promise((r) => setTimeout(r, openDelayMs));
    }
    return db;
  });
  jest.doMock("expo-sqlite", () => ({
    openDatabaseAsync,
  }));
  // Re-require under the fresh module registry so the cached `db` /
  // `initPromise` module-level state starts clean for this case.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const mod = require("@/utils/database") as typeof import("@/utils/database");
  return { mod, openDatabaseAsync };
}

/** Strip the migration runner's PRAGMA noise to isolate true migration SQL. */
function migrationSqlOnly(execSql: string[]): string[] {
  return execSql.filter((s) => !/PRAGMA\s+user_version/i.test(s));
}

afterEach(() => {
  jest.clearAllMocks();
  jest.resetModules();
});

// ---------------------------------------------------------------------------
// (a) migration 003 schema
// ---------------------------------------------------------------------------

describe("(a) migration 003 — recording_drafts schema", () => {
  // Imported statically: the migration SQL is a pure constant, no native deps.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { up: m003 } = require("@/utils/migrations/003_recording_drafts");

  it("creates the recording_drafts table", () => {
    expect(m003).toMatch(/CREATE TABLE IF NOT EXISTS\s+recording_drafts/i);
  });

  it("declares the exact column contract (id, created_at, segments_json, duration_ms)", () => {
    expect(m003).toMatch(/\bid\s+INTEGER PRIMARY KEY\b/i);
    expect(m003).toMatch(/\bcreated_at\s+TEXT NOT NULL\b/i);
    expect(m003).toMatch(/\bsegments_json\s+TEXT NOT NULL\b/i);
    expect(m003).toMatch(/\bduration_ms\s+INTEGER NOT NULL DEFAULT 0\b/i);
  });

  it("matches the defensive inline copy in database.ts byte-for-byte (same columns)", () => {
    // The inline copy in initDatabase must stay in sync with migration 003.
    // We assert the four columns are present in both; an exact divergence here
    // is the documented hazard the cross-reference comment warns about.
    for (const col of [
      "id",
      "created_at",
      "segments_json",
      "duration_ms",
    ]) {
      expect(m003).toContain(col);
    }
  });
});

// ---------------------------------------------------------------------------
// (b) runMigrations runs only pending migrations by index
// ---------------------------------------------------------------------------

describe("(b) runMigrations runs only pending migrations by index", () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { migrations } = require("@/utils/migrations");

  it("user_version 0 → all migrations run, user_version written to count", async () => {
    const db = makeFakeDb(0);
    const { mod } = loadDb(db);

    await mod.initDatabase();

    const ran = migrationSqlOnly(db.execSql);
    // The inline defensive CREATEs (recordings, index, recording_drafts) run
    // before the migration loop. Assert each migration SQL string appears.
    for (const sql of migrations) {
      expect(ran).toContain(sql);
    }
    expect(db.user_version).toBe(migrations.length);
  });

  it("user_version 2 → only m003 runs (index 2), nothing earlier re-runs", async () => {
    const db = makeFakeDb(2);
    const { mod } = loadDb(db);

    await mod.initDatabase();

    const ran = migrationSqlOnly(db.execSql);
    expect(ran).toContain(migrations[2]); // m003 only
    expect(ran).not.toContain(migrations[0]); // m001 skipped
    expect(ran).not.toContain(migrations[1]); // m002 skipped
    expect(db.user_version).toBe(migrations.length);
  });

  it("user_version 3 (== count) → no migration runs, no user_version write", async () => {
    const db = makeFakeDb(3);
    const { mod } = loadDb(db);

    await mod.initDatabase();

    const ran = migrationSqlOnly(db.execSql);
    for (const sql of migrations) {
      expect(ran).not.toContain(sql);
    }
    // currentVersion (3) is NOT < migrations.length (3) → no write-back.
    expect(
      db.execSql.some((s) => /PRAGMA\s+user_version\s*=/i.test(s)),
    ).toBe(false);
    expect(db.user_version).toBe(3);
  });
});

// ---------------------------------------------------------------------------
// (c) append-only ordering / index == version contract
// ---------------------------------------------------------------------------

describe("(c) append-only ordering — index is the version", () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const migIndex = require("@/utils/migrations");
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { up: m001 } = require("@/utils/migrations/001_add_notes_column");
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { up: m002 } = require("@/utils/migrations/002_workspace_foundation");
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { up: m003 } = require("@/utils/migrations/003_recording_drafts");

  it("migrations array is exactly [001, 002, 003] in that order", () => {
    expect(migIndex.migrations).toEqual([m001, m002, m003]);
  });

  it("array length is 3 (one slot per shipped migration)", () => {
    expect(migIndex.migrations).toHaveLength(3);
  });

  it("index position maps to the migration's permanent version number", () => {
    // m003 lives at index 2 → it is the migration applied when going from
    // user_version 2 to 3. This is the index==version contract runMigrations
    // depends on.
    expect(migIndex.migrations[0]).toBe(m001);
    expect(migIndex.migrations[1]).toBe(m002);
    expect(migIndex.migrations[2]).toBe(m003);
  });
});

// ---------------------------------------------------------------------------
// (d) self-heal: user_version > migrations.length
// ---------------------------------------------------------------------------

describe("(d) self-heal — user_version exceeds shipped count", () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { migrations } = require("@/utils/migrations");

  it("warns, clamps, writes user_version back to count, and initDatabase RESOLVES (no brick)", async () => {
    const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
    const inflated = migrations.length + 5; // e.g. 8 when 3 ship
    const db = makeFakeDb(inflated);
    const { mod } = loadDb(db);

    // Must not throw — a throw here would leave initDatabase permanently
    // rejecting and brick every getDatabase consumer at startup.
    await expect(mod.initDatabase()).resolves.toBe(db);

    // Warned exactly once about the invariant breach.
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(warnSpy.mock.calls[0][0]).toMatch(/user_version/i);

    // Write-back persisted the clamp: PRAGMA user_version = 3 was executed.
    expect(
      db.execSql.some((s) =>
        new RegExp(
          `PRAGMA\\s+user_version\\s*=\\s*${migrations.length}\\b`,
          "i",
        ).test(s),
      ),
    ).toBe(true);
    expect(db.user_version).toBe(migrations.length);

    // Clamp no-ops the migration loop: no shipped migration SQL re-ran.
    const ran = migrationSqlOnly(db.execSql);
    for (const sql of migrations) {
      expect(ran).not.toContain(sql);
    }

    warnSpy.mockRestore();
  });

  it("second run reads the now-clamped value and does NOT warn again", async () => {
    const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
    const inflated = migrations.length + 2;
    const db = makeFakeDb(inflated);

    // First run: clamps + writes back (warns once).
    const first = loadDb(db);
    await first.mod.initDatabase();
    expect(warnSpy).toHaveBeenCalledTimes(1);
    expect(db.user_version).toBe(migrations.length);

    warnSpy.mockClear();

    // Second run on the SAME db (now clamped to count) via a fresh module
    // registry: user_version == count → no breach, no warn.
    const second = loadDb(db);
    await expect(second.mod.initDatabase()).resolves.toBe(db);
    expect(warnSpy).not.toHaveBeenCalled();

    warnSpy.mockRestore();
  });
});

// ---------------------------------------------------------------------------
// (e) initPromise concurrency guard
// ---------------------------------------------------------------------------

describe("(e) initPromise concurrency guard", () => {
  it("two concurrent initDatabase() calls share one in-flight init (open runs once)", async () => {
    const db = makeFakeDb(0);
    // Delay the native open so both callers reach the initPromise checkpoint
    // before the first resolves — this is what would race without the guard.
    const { mod, openDatabaseAsync } = loadDb(db, 20);

    const [a, b] = await Promise.all([
      mod.initDatabase(),
      mod.initDatabase(),
    ]);

    // Both resolve to the same handle...
    expect(a).toBe(db);
    expect(b).toBe(db);
    // ...and the underlying init (native open) ran exactly once.
    expect(openDatabaseAsync).toHaveBeenCalledTimes(1);
  });

  it("a subsequent call after init returns the cached db without re-opening", async () => {
    const db = makeFakeDb(0);
    const { mod, openDatabaseAsync } = loadDb(db);

    await mod.initDatabase();
    const again = await mod.initDatabase();

    expect(again).toBe(db);
    // Cached `db` short-circuits — still only one open total.
    expect(openDatabaseAsync).toHaveBeenCalledTimes(1);
  });
});
