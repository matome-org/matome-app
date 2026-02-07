import * as SQLite from "expo-sqlite";

import { migrations } from "./migrations";

const DB_NAME = "matome.db";

let db: SQLite.SQLiteDatabase | null = null;

/**
 * Initialize the SQLite database and create tables if they don't exist
 */
export const initDatabase = async (): Promise<SQLite.SQLiteDatabase> => {
  if (db) {
    return db;
  }

  db = await SQLite.openDatabaseAsync(DB_NAME);

  // Create recordings table
  await db.execAsync(`
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
  await db.execAsync(`
    CREATE INDEX IF NOT EXISTS idx_recordings_createdAt ON recordings(createdAt DESC);
  `);

  // Run migrations
  await runMigrations(db);

  return db;
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
  if (!db) {
    return await initDatabase();
  }
  return db;
};

/**
 * Close the database connection
 */
export const closeDatabase = async (): Promise<void> => {
  if (db) {
    await db.closeAsync();
    db = null;
  }
};
