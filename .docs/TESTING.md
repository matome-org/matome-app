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
| Maestro | — | E2E device flows — **harness scaffolded** (`.maestro/`, `e2e` scripts); CLI not installed in this repo, runs on the dev machine |

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
.maestro/        -> E2E device flows (smoke.yaml scaffolded; see E2E section)
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

bun run e2e            # maestro test .maestro       (all flows)
bun run e2e:smoke      # maestro test .maestro/smoke.yaml
mise run e2e           # same, but pre-checks emulator + installed app first
```

See the **E2E (Maestro)** section below for the device prerequisites — `e2e`
needs an emulator up (`mise run up`) and the app installed; it does NOT run in
CI or this repo's container without those.

## E2E (Maestro)

Device-level flows that static analysis and RTL cannot verify — record / pause /
kill / relaunch / resume / discard, and the unauthenticated deep-link auth
bounce. The harness is scaffolded in this repo; **execution happens on the dev
machine**, not in CI or the agent container.

### What is in the repo

```
.maestro/
  smoke.yaml                      -> launch app -> assert Welcome (first) screen
  record-pause-resume-finish.yaml -> record -> pause -> resume -> finish -> detail
  record-kill-recover.yaml        -> record -> pause -> kill -> relaunch -> Resume
  back-to-back-discard.yaml       -> record -> finish -> record again -> discard
  discard-cleanup.yaml            -> record -> discard -> no recording persists
  auth-deeplink-guard.yaml        -> unauth deep-link to /recording -> bounced
```

All flows use `appId: com.anonymous.matomeapp` (the `android.package` /
`ios.bundleIdentifier` from `app.json`).

`smoke.yaml` asserts three **hardcoded literal** strings on the unauthenticated
Welcome screen (`Views/welcome/Welcome.tsx`): `MATOME`, `Finally organized.`,
`Tap once. We handle the rest.`. These are not i18n keys, so the assertion is
locale-independent and needs no auth and no network call — it proves the harness
can launch the app and reach the first screen.

#### Recording + auth flows (task T10) — AUTHORED, NOT YET VALIDATED ON DEVICE

These five flows cover the device-only behaviors the three recording-persistence
audits flagged but static analysis / RTL could not exercise (killApp, relaunch,
deep-link bounce, cross-session disk state). Each file carries an `AUTHORED — not
yet validated on device` header. **None have been run** — there is no emulator
and no dev-client build in the authoring environment (see Status below); they are
ready-to-run scaffold to execute via `mise run up` + a dev-client build, then
`maestro test .maestro`.

Selectors are the **en-locale literals** rendered by the screens (`locales/en.ts`
`recording.*`: `Ready to Record`, `Recording`, `Paused`, `Pause`, `Finish`,
`Resume Recording?`, `Resume`; `common.cancel`: `Cancel`; `inbox.title`: `Inbox`;
Details segmented tab `Summary`) plus the Welcome literals, **plus three minimal
`testID`s added to app source** where no stable text exists:

- `navbar-mic-fab` — `components/NavBar/NavBar.tsx` (the center mic Pressable that
  opens `/recording`).
- `record-primary-button` — `app/recording.tsx` (the record/pause/resume circular
  Pressable, which has no text label).
- `recording-card` — `Views/Home/RecordingCard/Recordingcard.tsx` (an inbox list
  card; titles are dynamic so tapping by text is unstable).
- `fab-save` — `Views/Details/Details.tsx` (**pre-existing**, reused as a stable
  marker that the detail screen was reached).

| Flow | Asserts | Audit |
| --- | --- | --- |
| `record-pause-resume-finish.yaml` | record → pause (`Paused`) → resume (`Recording`) → finish lands on detail (`Summary` + `fab-save`); single-file span model + finish→detail nav | happy path |
| `record-kill-recover.yaml` | after `killApp` + relaunch the draft prompt (`Resume Recording?`) appears; Resume → record more → finish → detail; crash recovery | audit#1 / audit#3 |
| `back-to-back-discard.yaml` | session 1 finish persists a `recording-card`; session 2 `Cancel` discards without navigating to detail; S1 card still present | audit#2 E2 (state bleed) |
| `discard-cleanup.yaml` | record → `Cancel` → back in `Inbox`, no `Summary` detail reached; clean-account variant asserts `No recordings found` (commented) | audit#2 discard cleanup |
| `auth-deeplink-guard.yaml` | logged-out (`clearState: true`) `openLink: matomeapp://recording` → bounced to Welcome (`Finally organized.`), mic screen (`Ready to Record`) NOT visible | audit#3 A01 (auth gate) |

Preconditions per flow are in each file's header. The recording flows require an
**authenticated session already present** on the device (auth setup is out of
scope for these flows); `auth-deeplink-guard.yaml` is the exception — it
intentionally runs logged-out via `clearState: true`. On-disk leak assertions
(zero `recording_*.mp3` / `segment_*.m4a` after discard) are verified by the
service **unit** tests (tasks 493/479), not by Maestro, which can only observe
the user-visible outcome. The deep `record → transcription` flows depend on the
transcription-stub network boundary described below.

Runners: `package.json` scripts `e2e` (`maestro test .maestro`) and `e2e:smoke`,
plus `mise run e2e` (which pre-checks Maestro + an online emulator + the app
being installed before delegating to `maestro test .maestro`).

### Prerequisites to run it

1. **Maestro CLI** (not a repo dependency; install once on the machine):
   `curl -fsSL "https://get.maestro.mobile.dev" | bash`
2. **Emulator + Metro + local Supabase up**: `mise run up` (boots the `pixel7`
   AVD, starts Supabase, regenerates `.env.local`, `adb reverse 54321`, and runs
   `expo start --dev-client`).
3. **The app installed on the emulator** under `com.anonymous.matomeapp` — see
   the feasibility note below; this is the gating step.

### Feasibility — how Maestro drives THIS app

Maestro drives an **installed** package by `appId`; it does not host JS. So the
question is which build of `com.anonymous.matomeapp` is on the device.

- **Expo Go is NOT viable.** The project depends on custom native config
  (`expo-build-properties`, `expo-secure-store`, `expo-sqlite`, `expo-audio`,
  `expo-updates`) — Expo Go's prebuilt shell cannot host these. Also, under
  Expo Go the OS package id is Expo Go's own (`host.exp.exponent`), not
  `com.anonymous.matomeapp`, so `launchApp: com.anonymous.matomeapp` would not
  resolve.
- **A dev-client build IS required.** `mise.toml [tasks.up]` already runs
  `expo start --dev-client`, which expects a **dev-client** build of this app
  installed on the device. Note: `expo-dev-client` is **not currently a
  dependency** in `package.json`, and there is no committed APK — so the
  dev-client must be produced before E2E can run:
  - Local: `npx expo run:android` (compiles + installs the native dev build on
    the running emulator). First build is the cost — full native compile
    (Gradle), single-digit to low-double-digit minutes, plus Android SDK/NDK
    setup. Subsequent runs are fast (JS-only over Metro).
  - Or a remote **EAS development build** (`eas.json` already has a
    `development` profile: `developmentClient: true`, internal apk), then
    install the artifact on the emulator.
- **Release/preview APK** also works for E2E (it carries the same `appId`); it
  drops the Metro dependency but is a slower iteration loop.

**Verdict:** Maestro can drive this app, but **needs a dev-client (or release)
build** — it cannot run via Expo Go. Producing that build is a native
compile/EAS step the repo owner should run on their machine; this task does not
trigger a native build unilaterally.

### Network boundary for E2E

Decision: **use the local Supabase from `mise run up`**. The `up` task already
points the app at `http://localhost:54321` (writes `EXPO_PUBLIC_SUPABASE_URL`
into `.env.local`) and `adb reverse tcp:54321 tcp:54321` makes it reachable from
the emulator. So auth + DB reads/writes in E2E hit the local stack — no
production Supabase, no shared test data.

The **transcription call** (`EXPO_PUBLIC_TRANSCRIBE_API_URL`, prod default
`https://api.matome.io/`) is the one external dependency. For E2E it is **not
exercised by the committed `smoke.yaml`** (the smoke flow stops at the Welcome
screen, before any recording → transcription). For the deeper recording flows
(task T10), the chosen approach is to **stub the transcription boundary**: point
`EXPO_PUBLIC_TRANSCRIBE_API_URL` at a local stub server returning a canned
transcript, so flows are deterministic and offline. (Alternative — a dedicated
throwaway test account against the real endpoint — is rejected for E2E: it is
non-deterministic, costs real API calls, and couples tests to network/SLA.)

### Status in this environment

The harness (`.maestro/smoke.yaml` + the five T10 recording/auth flows,
`e2e`/`e2e:smoke` scripts, `mise run e2e`) is committed and ready. It was **not
executed here**: Maestro is not installed in this container, no emulator is
online (`adb devices` empty), and no dev-client build of
`com.anonymous.matomeapp` exists. The five T10 flows are therefore **AUTHORED but
not yet validated on device** (so marked in each file header) — they have never
run, so treat them as scaffold pending a first device run, not as known-green.
Running them requires the dev machine with `mise run up` + an installed
dev-client build (see Feasibility above). This is an expected environment
boundary, not a harness defect.

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

## Coverage baseline (2026-06-03)

Captured via `npx jest --coverage` at the close of the test-suite plan (T11).
**No threshold gate yet** (per decision) — this is the future **ratchet floor**:
new work should not drop these numbers, and the next pass should raise them.

**Overall:** statements **67.57%** (769/1138) · branches **58.36%** (314/538) ·
functions **65.07%** (123/189) · lines **68.13%** (744/1092).

Per critical module (the risk-priority targets above):

| Module | Stmts | Branch | Funcs | Lines |
| --- | --- | --- | --- | --- |
| `services/audioRecordingService.ts` | 55.61% | 37.86% | 61.36% | 55.39% |
| `services/draftRecordingService.ts` | 100% | 100% | 100% | 100% |
| `services/recordingService.ts` | 85.15% | 71.25% | 100% | 85.60% |
| `utils/database.ts` | 82.05% | 64.28% | 60% | 81.57% |
| `utils/migrations/001_add_notes_column.ts` | 100% | 100% | 100% | 100% |
| `utils/migrations/002_workspace_foundation.ts` | 100% | 100% | 100% | 100% |
| `utils/migrations/003_recording_drafts.ts` | 100% | 100% | 100% | 100% |
| `utils/migrations/index.ts` | 100% | 100% | 100% | 100% |
| `app/navigationGuard.ts` | 100% | 100% | 100% | 100% |
| `app/recording.tsx` | 68.26% | 86.20% | 67.85% | 67.87% |

`audioRecordingService.ts` is the lowest-covered critical module and the
highest-risk one (the three audits found the most defects there) — it is the
top ratchet target.

**Run totals:** 180 passed / 36 failed (216 total) across 13 suites
(7 passed, 6 failed). The failures are **real logic / stale-test issues, not
harness crashes** — do not treat them as a reason to revert `jest.setup.js`.

### KNOWN FOLLOWUP — 36 pre-existing failing tests

These failures pre-date / are out of scope for the test-suite plan and are left
**unfixed here** by decision. They should be triaged to green the baseline in a
future task. Failing suites:

- `__tests__/unit/insertMarkdown.unit.test.ts` — string-transform edge cases
  (unicode emoji boundary, whitespace-only transcript).
- `__tests__/unit/calendarData.test.ts` — `fetchDayRecordings` maps an
  undefined result (`processes/calendarData.ts:102`).
- `__tests__/unit/Calendar.test.tsx` — V2 Calendar component assertions stale.
- `__tests__/unit/CalendarContainer.test.tsx` — Calendar container wiring stale.
- `__tests__/integration/DetailsContainer.integration.test.tsx` — details
  container integration stale.
- `__tests__/unit/audioRecordingService.unit.test.ts` — one case
  (per-session temp-snapshot concurrent-tracker cleanup) asserts a count that
  is now 0; the rest of the suite passes.

Triaging these to green is the **ratchet entry point**: green the baseline,
then turn the numbers above into a `coverageThreshold` gate.
