import { up as m001 } from "./001_add_notes_column";
import { up as m002 } from "./002_workspace_foundation";
import { up as m003 } from "./003_recording_drafts";
import { up as m004 } from "./004_upload_recording_metadata";

/**
 * Ordered list of migrations. Each entry runs once, tracked by PRAGMA user_version.
 * To add a new migration:
 *   1. Create a new file: utils/migrations/00N_description.ts
 *   2. Export `up` with the SQL string
 *   3. Import it here and append to this array
 */
export const migrations: string[] = [m001, m002, m003, m004];
