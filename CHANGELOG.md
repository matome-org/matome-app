# Changelog

All notable changes to this project will be documented in this file.

---

## [Unreleased]

### Added

#### Calendar Tab
- New **Calendar** tab in the bottom navigation bar, giving users a month-grid view of all their recordings.
- Month grid displays a dot indicator beneath any day that has at least one recording. Tapping a day loads the recording list for that date in a panel below the grid.
- Month navigation arrows let the user step forward and backward through months. The selected day is clamped automatically when navigating to a shorter month (e.g. from March 31 to February, which has no 31st).
- Space filter strip below the grid allows filtering the day's recording list by workspace. Filtering is applied in memory — no extra database round-trip — and is keyed by workspace ID so two spaces with identical names never bleed into each other's results.
- Each recording card in the day list shows the title, workspace badge, and duration formatted as `m:ss`. Tapping a card navigates to the Details screen.
- The Calendar reacts to the global recordings store `refreshKey`, so the dots and day list update automatically after a new recording is saved without requiring a manual refresh.
- New `processes/calendarData.ts` process layer providing `fetchDaysWithRecordings` and `fetchDayRecordings`, keeping all SQL concerns out of the container component.
- New `getRecordingsByDateRange` and `getRecordingsByDayWithWorkspace` queries in `recordingService.ts`. The workspace query does a `LEFT JOIN` on the workspaces table so the workspace name is available alongside each recording for display.

#### Details Screen — Markdown Editing
- The Notes section of the Details screen now renders saved notes as formatted Markdown in preview mode, replacing the previous plain-text display. Supported formatting includes bold, italic, headings (H1–H3), bulleted and ordered lists, inline code, fenced code blocks, blockquotes, and horizontal rules.
- A formatting toolbar appears above the text editor when the user switches to Edit mode. Toolbar buttons insert Markdown syntax for **Bold**, *Italic*, `# Heading`, `- bullet list`, and `- [ ] task list` items, applied at the current cursor position or around selected text.
- An **Edit / Preview** toggle button in the Notes section header switches between the raw editor (with toolbar) and the rendered Markdown view. The button label updates to reflect the current mode.
- A **floating action button (FAB)** with a checkmark is always visible on the Details screen to save notes. A small dot appears on the FAB whenever there are unsaved changes, providing a persistent dirty-state indicator regardless of whether the user is in Edit or Preview mode.
- The screen now opens in Edit mode automatically when a recording has no notes yet, and in Preview mode otherwise.
- Added `react-native-markdown-display` as a runtime dependency to power the Markdown renderer.

#### Unsaved-Changes Guard
- Navigating away from the Details screen with unsaved notes now triggers an alert: "You have unsaved changes. Do you want to discard them?" The user must confirm the discard or choose to keep editing. The guard fires in both Edit and Preview modes, so changes made in the editor are never silently lost by switching to preview before going back.

#### Localisation
- New `calendar` namespace keys added to both the English (`en.ts`) and Japanese (`ja.ts`) locale files: `calendar.title`, `calendar.noRecordings`, `calendar.allSpaces`.
- New `details.edit`, `details.preview`, and `details.notesPlaceholder` keys added to support the markdown editing UI.

---

### Fixed

- **Month navigation stale data**: Navigating to a new month no longer leaves the day-recording panel showing the previous month's recordings. The container now always reloads day recordings after a month change, even when the day number is valid in both months.
- **Space filter by ID instead of name**: The space filter in the Calendar previously compared workspace names, which caused recordings to appear in the wrong filter bucket when two spaces shared a name. The filter now uses the unique workspace ID (`workspaceId`) for comparison.
- **Android SQLite parameter type crash**: Queries in `getRecordingsByDayWithWorkspace` now pass all bound parameters through `coerceSqlitePrimitive`, which forces JavaScript `Number` and `String` objects (as opposed to primitives) down to plain primitives. This prevents the `"Cannot convert '[object Object]' to a Kotlin type"` crash that occurred on Android with uncoerced values.
- **Duration parsing in Calendar recording cards**: The duration stored in the database uses a human-readable format (`"2m 14s"`, `"45s"`) produced by `audioRecordingService`. The Calendar was previously passing this string directly to a seconds-based formatter, resulting in `"0:00"` for all cards. A dedicated `parseDurationSeconds` parser now converts both the `Xm Ys` and `Xs` formats to an integer number of seconds before display.
- **`beforeRemove` unsaved-changes guard not firing**: The navigation event listener was registered on the wrong lifecycle phase, so the "discard changes?" alert never appeared. The guard is now registered correctly via `navigation.addListener("beforeRemove", ...)` and fires reliably in both Edit and Preview modes.

---

### Tests

Six new unit/integration test files were added under `__tests__/unit/`:

- `calendarData.test.ts` — unit tests for `fetchDaysWithRecordings` and `fetchDayRecordings`, including the duration parser and badge coercion.
- `recordingService.calendar.test.ts` — tests for `getRecordingsByDateRange` and `getRecordingsByDayWithWorkspace`, verifying correct SQL behaviour and parameter coercion.
- `Calendar.test.tsx` — component tests for the Calendar UI: month grid rendering, dot indicators, day selection, space filter chip interactions, and the empty-state view.
- `CalendarContainer.test.tsx` — container-level tests covering month navigation, auto-refresh on `refreshKey` change, and space filter state management.
- `insertMarkdown.unit.test.ts` — unit tests for the `insertMarkdown` helper in Details, covering Bold, Italic, Heading, bullet list, and task-list insertion at arbitrary cursor positions and with selected text.
- `isDirty.unit.test.ts` — unit tests for the dirty-state logic that drives the unsaved-changes guard and the FAB indicator.

Jest infrastructure was set up for the first time in this project:
- `jest`, `jest-expo`, `babel-jest`, `@testing-library/react-native`, `@testing-library/jest-native`, and `@types/jest` added as dev dependencies.
- `jest` configuration block added to `package.json` with `jest-expo` preset, `@/` path alias mapping, and a `transformIgnorePatterns` list that covers all Expo and UI Kitten packages.
- `npm test`, `npm run test:watch`, and `npm run test:coverage` scripts added.

---

### Build

- **Transcription API URL updated**: All three EAS build profiles (`development`, `preview`, `production`) now point to `https://api.matome.io/` instead of the previous hard-coded IP address `https://187.77.228.183:8000/`.
- **`expo-build-properties` plugin** added to `app.json` plugins and to `package.json` dependencies.
- **`expo-constants`**, **`react-native-svg`**, and **`fs-extra`** added as dependencies (required by new Calendar and test tooling).
- **`postinstall` script** (`scripts/patch-expo-updates.js`) added to `package.json` to apply a post-install patch for `expo-updates` compatibility.
- Several Expo SDK packages bumped to their latest patch versions within the `^55` range: `expo-asset`, `expo-audio`, `expo-file-system`, `expo-linking`, `expo-localization`, `expo-router`, `expo-secure-store`, `expo-splash-screen`, `expo-sqlite`, `expo-updates`, and `expo-web-browser`.
- `@react-navigation/bottom-tabs` bumped from `^7.4.0` to `^7.10.1`.
