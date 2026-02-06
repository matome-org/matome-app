import { up as m001 } from "./001_add_notes_column";

/**
 * Ordered list of migrations. Each entry runs once, tracked by PRAGMA user_version.
 * To add a new migration:
 *   1. Create a new file: utils/migrations/002_description.ts
 *   2. Export `up` with the SQL string
 *   3. Import it here and append to this array
 */
export const migrations: string[] = [m001];
