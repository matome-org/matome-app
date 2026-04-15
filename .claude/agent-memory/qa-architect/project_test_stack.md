---
name: matome-app test stack
description: Testing framework, configuration, and existing test file inventory for matome-app
type: project
---

Jest with `jest-expo` preset. Test script: `npm test` (jest --passWithNoTests). Coverage: `npm run test:coverage`.

Module alias `@/` maps to `<rootDir>/` via `moduleNameMapper`.

Known typo in package.json jest config: `"setupFilesAfterFramework"` should be `"setupFilesAfterFramework"` → correct key is `"setupFilesAfterEachTest"`. Currently harmless (empty array) but will break if setup files are ever added.

**Why:** Discovered during commit-2 review on 2026-04-14.
**How to apply:** Flag this typo if the team tries to add Jest setup files and they silently don't run.

Existing project test files (as of 2026-04-14):
- `__tests__/unit/calendarData.test.ts` — fetchDaysWithRecordings + fetchDayRecordings (mocks recordingService)
- `__tests__/unit/recordingService.calendar.test.ts` — getRecordingsByDateRange + getRecordingsByDay
- `__tests__/unit/isDirty.unit.test.ts` — isDirty comparison and ref mutation logic (pure, no React)
- `__tests__/unit/insertMarkdown.unit.test.ts` — markdown toolbar helper (pure, no React)
- `__tests__/unit/Calendar.test.tsx` — Calendar component (not yet read)
- `__tests__/integration/DetailsContainer.integration.test.tsx` — DetailsContainer integration (not yet read)
- `__tests__/unit/CalendarContainer.test.tsx` — CalendarContainer render/filter/navigation tests

CRITICAL gap: `calendarData.test.ts` tests use the OLD duration format `"2:45"` and `"0:05"` (MM:SS), not the new `"2m 14s"` / `"45s"` format. These tests will FAIL against the new `parseDurationSeconds` implementation.
