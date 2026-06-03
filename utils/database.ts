import * as SQLite from "expo-sqlite";

import { migrations } from "./migrations";

const DB_NAME = "matome.db";

let db: SQLite.SQLiteDatabase | null = null;
// Holds the in-flight init promise so concurrent callers all wait for the
// same initialization rather than racing past the db-assignment checkpoint.
let initPromise: Promise<SQLite.SQLiteDatabase> | null = null;

/**
 * Initialize the SQLite database and create tables if they don't exist
 */
export const initDatabase = async (): Promise<SQLite.SQLiteDatabase> => {
  if (db) {
    return db;
  }

  if (initPromise) {
    return initPromise;
  }

  initPromise = (async () => {
    const database = await SQLite.openDatabaseAsync(DB_NAME);

    // Create recordings table
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS recordings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT,
        timestamp TEXT NOT NULL,
        duration TEXT NOT NULL,
        badge TEXT NOT NULL DEFAULT 'Inbox',
        isProcessing INTEGER NOT NULL DEFAULT 1,
        audioFilePath TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      );
    `);

    // Create index for faster queries
    await database.execAsync(`
      CREATE INDEX IF NOT EXISTS idx_recordings_createdAt ON recordings(createdAt DESC);
    `);

    // CANONICAL / DEFENSIVE recording_drafts schema.
    //
    // This inline CREATE TABLE is intentionally duplicated with
    // utils/migrations/003_recording_drafts.ts. It is kept as a DEFENSIVE
    // copy so that devices which somehow skipped migration 003 (e.g. a
    // user_version drift) still get a working recording_drafts table. The two
    // definitions MUST stay byte-for-byte in sync: if you change one, change
    // the other (and consider a new appended migration for an in-place schema
    // change rather than editing 003). Do NOT remove this copy.
    await database.execAsync(`
      CREATE TABLE IF NOT EXISTS recording_drafts (
        id INTEGER PRIMARY KEY,
        created_at TEXT NOT NULL,
        segments_json TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0
      );
    `);

    // Run migrations
    await runMigrations(database);

    db = database;
    return db;
  })();

  return initPromise;
};

const runMigrations = async (db: SQLite.SQLiteDatabase) => {
  // APPEND-ONLY CONTRACT.
  //
  // `PRAGMA user_version` stores the number of migrations a device has already
  // applied, and migrations are run by their ARRAY INDEX (`migrations[i]`). This
  // is correct ONLY while the `migrations` array is strictly append-only:
  //   - a migration's position (index) is its permanent version number,
  //   - existing entries are never reordered, removed, or have their meaning
  //     changed.
  //
  // If a future change reorders or deletes an entry, a device that already
  // recorded user_version = N would silently SKIP the now-shifted migration,
  // leaving its schema corrupt with no error. There is no per-migration id to
  // cross-check against, so the index IS the contract. New migrations must only
  // ever be appended to the end of the array in utils/migrations/index.ts.
  const result = await db.getFirstAsync<{ user_version: number }>(
    "PRAGMA user_version;"
  );
  const currentVersion = result?.user_version ?? 0;

  // Invariant guard: a device can never have applied more migrations than the
  // app ships. If it has, the migrations array was truncated/reordered (the
  // append-only contract above was broken) and continuing would corrupt the
  // schema. Fail loudly instead of silently skipping.
  if (currentVersion > migrations.length) {
    throw new Error(
      `Migration invariant violated: stored user_version (${currentVersion}) ` +
        `exceeds shipped migration count (${migrations.length}). The migrations ` +
        `array must be append-only — do not reorder or remove entries.`
    );
  }

  for (let i = currentVersion; i < migrations.length; i++) {
    await db.execAsync(migrations[i]);
  }

  if (currentVersion < migrations.length) {
    await db.execAsync(`PRAGMA user_version = ${migrations.length};`);
  }
};

/**
 * Get the database instance
 */
export const getDatabase = async (): Promise<SQLite.SQLiteDatabase> => {
  if (db) {
    return db;
  }
  return initDatabase();
};

/**
 * Close the database connection
 */
export const closeDatabase = async (): Promise<void> => {
  if (db) {
    await db.closeAsync();
    db = null;
    initPromise = null;
  }
};
