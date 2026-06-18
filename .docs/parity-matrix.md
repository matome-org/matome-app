# Flutter Consolidation — Per-Platform Parity Matrix

> The retirement gate for plan `flutter-consolidation` (#82). A legacy client
> (`apps/mobile`, `apps/web`, `apps/desktop`) is deleted ONLY when its column below is
> **100% green**, each green cell backed by **rerunnable evidence**. "Parity reached" is an
> author claim until the evidence here confirms it. See [ADR-0001](decisions/ADR-0001-consolidate-to-flutter.md).

## Evidence rules

Each cell is `pass` / `fail` / `n/a` and MUST cite, when `pass`:
- a **rerunnable local build+test command** (build LOCAL per platform is the gate — no cloud CI), AND/OR
- a **test id** (Flutter `integration_test` / unit), AND/OR
- a **screenshot or artifact traceable to a commit sha**.

A cell with no evidence is treated as `fail`. No `git rm apps/X` merges while any cell in
column X is non-green. The mobile reference is the RN app's `apps/mobile` Maestro flows +
`e2e-preflight.sh`.

## Matrix

Legend: ✅ pass · ❌ fail · ⬜ not yet verified · ➖ n/a

| Capability | mobile (android) | mobile (ios) | web | desktop (linux) | desktop (win) | desktop (macos) |
|---|---|---|---|---|---|---|
| Auth login + session survives reload | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Recording — mic capture (start/pause/resume/finish) | ⬜ | ⬜ | ⬜ (MediaRecorder) | ⬜ | ⬜ | ⬜ |
| Recording — system audio (loopback) | ➖ | ➖ | ➖ | ✅ `a51ee69` (#828) | ➖ deferred | ➖ deferred |
| Draft recovery (kill → resume) | ⬜ | ⬜ | ➖ | ⬜ | ⬜ | ⬜ |
| Recordings list + Core sync | ⬜ | ⬜ | ⬜ (online-only) | ⬜ | ⬜ | ⬜ |
| Local-first offline persistence (Drift) | ⬜ | ⬜ | ➖ (disabled on web) | ⬜ | ⬜ | ⬜ |
| Upload pipeline (presigned + status) | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Realtime status (Phoenix Channels) | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Audio playback + real duration | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Spaces | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Calendar | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Satori | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Settings | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| i18n (en / ja) | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Local build green | ✅ | ⬜ env (mac) | ✅ | ✅ | ⬜ env (win) | ⬜ env (mac) |
| Test suite green | ✅ | ⬜ | ✅ | ✅ | ⬜ | ⬜ |

### Retirement gates (derived from columns)

- **`git rm apps/mobile`** (task 1276) ← android + ios columns 100% green.
- **`git rm apps/web`** (task 1278) ← web column 100% green (note: offline persistence is ➖
  by design — web is online-only per ADR-0001 #2).
- **`git rm apps/desktop`** (task 1281) ← linux + win + macos columns green on the NON-capture
  capabilities + local build verified per OS. System-audio (loopback): ✅ on Linux (`a51ee69`);
  **Win/macOS system-audio is DEFERRED** (ADR-0001 #3 amended 2026-06-18, revisit later) and is
  NOT a retirement blocker — the legacy Tauri desktop had no loopback either, so no capability is
  lost. Mic capture (cross-platform via `record`) must still be green per OS.

## Evidence log

Record each cell flip here: `YYYY-MMDD · cell · evidence (cmd / test id / sha) · owner`.

- 2026-0618 · desktop(linux) system-audio · ✅ · pre-existing capture #828 / commit `a51ee69` (ffmpeg + PulseAudio/PipeWire) · —
- 2026-0618 · Test suite green (host dart/widget suite, platform-agnostic) · ✅ · `flutter test --concurrency=1` → **+334 passed, ~1 skipped (live)**, exit 0 · — (covers shared code for android/web/linux; ios/macos/windows device-run not verified on this Linux host)
- 2026-0618 · Mobile code-parity assessment · read-only · Flutter ≥ RN on 13/14 capabilities, 0 true gaps (see task #1275 comment) · — (assessment, not a green-build cell — device integration_test still required)
- 2026-0618 · Local build green (android) · ✅ · `flutter build apk --debug` → app-debug.apk (203M) + app-release.apk (61M) · —
- 2026-0618 · Local build green (web) · ✅ · `flutter build web` → build/web/ (main.dart.js 3.8M), wasm dry-run OK, exit 0 · —
- 2026-0618 · Web offline-persistence DISABLED (online-only, in-memory) · ✅ · commit `08e1f91` — WasmSqlite3 + InMemoryFileSystem + WasmDatabase.inMemory; no OPFS/IndexedDB at-rest store; rebuild `flutter build web` green · —
- 2026-0618 · Web RUNTIME boot · ✅ · `mise run backend` + `flutter run -d web-server :8080` → app loads in Chromium, welcome screen renders (i18n en+ja, assets), **zero console errors/warnings** → the in-memory online-only DB initializes cleanly at runtime (DB opens at startup; a VFS failure would crash boot). Backend `POST /api/auth/login` → 200. Screenshot /tmp/matome-web-home.png · —
- 2026-0618 · Local build green (linux desktop) · ✅ · `flutter build linux` → build/linux/x64/release/bundle/matome_flutter, exit 0 · —
- 2026-0618 · e2e integration flows (linux desktop) · ✅ 9/9 · `flutter test integration_test/{e2e_smoke,e2e_auth_guard,e2e_recording_flows}.dart -d linux` (run per-file — batching multiple files trips a desktop relaunch "log reader stopped" flake): smoke 2/2 (welcome→signin nav, unauth deep-link guard), auth_guard 3/3 (seeded boot→tabs, logout→welcome, login→tabs), recording_flows 4/4 (finish→upload→reconcile-done, kill→recover draft, discard-cleanup, back-to-back). Mirrors RN's Maestro flows. Fixed a stale assertion first (commit: test aligned to #43 local-id model) · —
- 2026-0618 · e2e integration flows (android) · ✅ 10/10 · disk freed (169G), pixel7 emulator booted (emulator-5554); `flutter test integration_test/{e2e_smoke,e2e_auth_guard,e2e_recording_flows}.dart -d emulator-5554` per-file: smoke ✅, auth_guard ✅, recording_flows ✅ +4 (after a force-stop+uninstall to clear a transient "unable to start the app" flake on the 3rd consecutive invocation). Same flows green on android + linux · —
- 2026-0618 · Web UI login E2E (login → home-from-Core → reload-persists) · ⬜ PENDING-MANUAL · Flutter CanvasKit does not expose the a11y tree to browser automation (only an "Enable accessibility" affordance), so the login form cannot be driven headlessly here. Verify by hand: `mise run backend` + `mise run flutter-web`, sign in dev@matome.test/devpassword123, confirm home loads from Core + survives a reload · —
