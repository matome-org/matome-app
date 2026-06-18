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
| Local build green | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Test suite green | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

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

_(empty — populated as parity work lands in W2–W4)_
