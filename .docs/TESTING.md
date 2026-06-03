# Testing

This document codifies the testing strategy for matome-app. It describes the
**configured** test stack, the conventions the existing tests actually follow,
and the parts that are **(planned)** but not yet built. Keep it honest: when you
add a tool or a script, update this file; when a section says **(planned)**, it
does not exist in the repo yet.

## Stack

| Tool | Version | Role |
| --- | --- | --- |
| `jest` | 30 | Test runner |
| `jest-expo` | 55.0.16 | Expo SDK 55 preset (transforms, RN/Expo module mocks) |
| `@testing-library/react-native` | 13 | Component / integration rendering (`render`, `fireEvent`, `screen`, `waitFor`, `act`) |
| `@testing-library/jest-native` | 5.4 | Extra RN matchers |
| `babel-jest`, `@types/jest`, `typescript` | — | Transform + types |
| Maestro | — | E2E device flows **(planned — not installed)** |

Jest is wired in `package.json` under the `"jest"` key: `preset: "jest-expo"`,
a single `setupFiles` entry (`<rootDir>/jest.setup.js`), a `transformIgnorePatterns`
allow-list for Expo / RN / UI Kitten / `@testing-library`, and a
`moduleNameMapper` that maps the `@/*` alias to `<rootDir>/$1` (matching
`tsconfig.json`).

## The SDK 55 harness gotcha — DO NOT DELETE `jest.setup.js`

`jest.setup.js` exists for one reason: to stop jest-expo@55 + Jest 30 from
crashing **every** suite at import time. **Do not remove it.**

Root cause: the jest-expo preset's setup loads `expo/src/winter`
(`runtime.native.ts`), which installs **lazy getters** on `globalThis` for a set
of WinterCG polyfills — `TextDecoder`, `TextEncoder`, `URL`, `URLSearchParams`,
`structuredClone`, and `__ExpoImportMetaRegistry`. The first time any of those
getters is *read*, it fires a deferred `require(...)`. Under Jest 30, a `require`
executed from inside a global getter (rather than from a module's own evaluation
frame) is rejected with:

```
ReferenceError: You are trying to `import` a file outside of the scope of the test code.
```

That fires at import time, before any assertion runs, so the whole run reports
0 tests / all suites failed.

The fix (`jest.setup.js`) **eagerly re-defines** those globals as plain values,
resolved from the setup file's own (test-scope-valid) frame, replacing the lazy
getters before anything reads them. The file is careful to **never read**
`globalThis.<name>` for these props first (reading would trigger the very getter
we are defusing) — it references the Node-provided bindings lexically instead.
`__ExpoImportMetaRegistry` is shimmed because `import.meta` is rewritten by
babel-preset-expo to read it.

If someone deletes this file or empties `setupFiles`, all suites go back to
crashing on import. (Harness fix landed in commit `49dbeb4`.)

## Structure

```
__tests__/
  unit/          -> pure logic + service/process units (mocked deps)
  integration/   -> Containers rendered via @testing-library/react-native
.maestro/        -> E2E device flows (planned — does not exist yet)
```

Today there are 7 suites: 6 in `__tests__/unit/`, 1 in `__tests__/integration/`.

## Naming

- `*.unit.test.ts` — pure-logic units (e.g. `isDirty.unit.test.ts`,
  `insertMarkdown.unit.test.ts`).
- `*.integration.test.tsx` — Container/component integration via RTL
  (e.g. `DetailsContainer.integration.test.tsx`).
- `*.test.ts` / `*.test.tsx` — also accepted; several existing units use the
  plain form (e.g. `recordingService.calendar.test.ts`, `CalendarContainer.test.tsx`).

Prefer the explicit `.unit` / `.integration` infix for new files; reserve plain
`.test.tsx` for ambiguous cases.

## Mock conventions

These are pulled from the real tests — follow them:

- **Mock the data layer by alias path**: `jest.mock("@/utils/database")` (the
  `moduleNameMapper` makes `@/` work in mocks too).
- **Type the mock**: cast with `jest.MockedFunction`, e.g.
  `const mockGetDatabase = getDatabase as jest.MockedFunction<typeof getDatabase>;`,
  then `mockGetDatabase.mockResolvedValue(db)`.
- **Factory helpers** for DB rows and the db handle:
  - `makeDbMock(rows)` → `{ getAllAsync: jest.fn().mockResolvedValue(rows), runAsync: jest.fn() }`.
  - `makeRow(overrides)` → a realistic recordings row; spread `overrides` for
    per-test fields. (See `recordingService.calendar.test.ts`.)
- **`beforeEach(() => jest.clearAllMocks())`** between cases.
- **Extract pure logic and test it without React.** `isDirty.unit.test.ts`
  reproduces the `transcript !== savedTextRef.current` comparison and the
  ref-mutation sequence as plain functions — no hooks, no render.
  `insertMarkdown.unit.test.ts` reproduces the string-transform helper the same way.
- **Components / Containers use `@testing-library/react-native`**: `render`,
  `fireEvent`, `screen`, `waitFor`, wrapped in `act(...)` for async effects.
  Mock `expo-router` (`useRouter`/`useLocalSearchParams`/`useNavigation`),
  `react-i18next` (`useTranslation` → `t: (key) => key`), `@expo/vector-icons`
  (icon name as a string), and the relevant `@/services` / `@/processes`.
  Wrap UI Kitten consumers in `<ApplicationProvider {...eva} theme={eva.light}>`.
  Component tests may require `testID` props on the component under test (see the
  header note in `DetailsContainer.integration.test.tsx`).

## What to cover per layer

- **Unit** (`__tests__/unit/`): `services/`, `utils/`, `utils/migrations/`, and
  `processes/` — pure logic and DB CRUD with the data layer mocked. No real
  SQLite, no native modules.
- **Integration / component** (`__tests__/integration/`): `*Container.tsx` and
  screens rendered via RTL with services/router/i18n mocked. Assert the
  state machine, navigation guards, and dirty-state behavior.
- **E2E (Maestro — planned)**: device-only flows that static analysis cannot
  verify — record / pause / kill / relaunch / resume / discard, and the
  unauthenticated-deep-link auth bounce.

## How to run

```bash
bun test               # jest --passWithNoTests (the "test" script)
bun run test:watch     # jest --watch
bun run test:coverage  # jest --coverage

# scoped runs
npx jest recordingService
npx jest __tests__/integration/DetailsContainer.integration.test.tsx

bun run e2e            # (planned — no script yet)
maestro test .maestro/ # (planned — Maestro not installed, no .maestro/ dir)
```

## Risk priority for new tests

Add coverage in this order — highest blast-radius / audit-flagged first:

1. `services/audioRecordingService.ts` — session state model, segment
   merge/restore, file cleanup (the three audits found the most defects here).
2. `services/draftRecordingService.ts` — draft save/load/delete, transactional
   replace, malformed-JSON guards.
3. `utils/migrations/*` + `utils/database.ts` — migration 003 schema, ordering /
   append-only invariant, `user_version` self-heal.
4. `app/_layout.tsx` NavigationGuard — unauthenticated redirect for `(tabs)` and
   `recording`, authenticated draft-recovery push.
5. `services/recordingService.ts` — CRUD + row mapping (extend the existing
   `recordingService.calendar.test.ts`).

## Current baseline

100 / 135 passing, ~55% statements (after the SDK 55 harness fix in `49dbeb4`).
The 35 failures are **real logic / stale-test issues, not harness crashes**, and
are tracked separately — do not treat them as a reason to revert `jest.setup.js`.
