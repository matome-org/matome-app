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

    // Ensure recording_drafts exists independently of the migration version so
    // devices that got into a state where migration 003 was skipped still work.
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
  const result = await db.getFirstAsync<{ user_version: number }>(
    "PRAGMA user_version;"
  );
  const currentVersion = result?.user_version ?? 0;

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
