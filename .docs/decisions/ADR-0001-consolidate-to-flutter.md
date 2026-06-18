# ADR-0001 — Consolidate to a single Flutter codebase

> Status: **Accepted** · Date: 2026-06-18 · Supersedes: `architecture.md` §1.5, §5, §6, §10, §11, §13 (client topology)
> Plan: `flutter-consolidation` (#82)

## Context

matome shipped as a monorepo with **three separate client stacks** (delivered by plan #28,
"Platform Architecture Migration", 100% complete):

- **Mobile** — Expo / React Native (`apps/mobile`)
- **Web** — Next.js (`apps/web`)
- **Desktop** — Tauri, Rust shell + system webview reusing the web React (`apps/desktop`)

`architecture.md` §13 currently **locks** this three-JS/TS-client topology and §1.5 forbids
non-JS frontends ("No Dart/Flutter"). Since then, a Flutter app (`apps/flutter`) was built to
mobile parity (plans #36/#38) and already targets all six platforms — android, ios, linux,
macos, web, windows — including a working web build. Maintaining four client codebases (three
legacy JS stacks + Flutter) is the cost this decision removes.

## Decision

Consolidate to **one Flutter codebase** serving web + desktop + mobile, all consuming the
single client-facing **Elixir Core API**. Retire the three legacy clients (`apps/mobile`,
`apps/web`, `apps/desktop`) — but only after Flutter reaches **proven per-platform parity**.

### Locked constraints

1. **Backend unchanged.** The Elixir Core API is already the single client entrypoint; the
   Python AI engine stays behind it, NOT rewritten. "Single backend" = client-facing.
2. **Web = authenticated app, ONLINE-ONLY.** No SSR/SEO. Drift offline persistence is
   DISABLED on web (reads from Core API, no local store) — this removes the at-rest-encryption
   regression, since there is no SQLCipher equivalent on the wasm build. Any public landing
   page is a separate concern and OUT of scope.
3. **Native recording = mic + system audio (loopback).** ~~System-audio capture is a REQUIRED
   deliverable on all three desktops; Windows/macOS mandatory.~~
   **AMENDED 2026-06-18 (user):** Linux system-audio capture **already works** (#828 / `a51ee69`,
   ffmpeg + PulseAudio/PipeWire) and stays. Windows (WASAPI loopback) and macOS (ScreenCaptureKit /
   virtual driver) system-audio capture are **DEFERRED — revisited later**, NOT a blocker for the
   rest of the consolidation. Rationale: the legacy Tauri desktop was mic-only (no loopback) and
   not shipped, so deferring Win/macOS loopback loses no existing capability. Mic capture stays
   cross-platform via the `record` package. The `MeetingCaptureBackend` interface formalization is
   likewise deferred. Win/macOS capture tasks (#1279/#1280) are detached from plan #82 and parked
   as standalone backlog for a future native-capture effort.
4. **Build LOCAL per platform is the parity gate.** No cloud CI required; a green local
   build+test per platform is what proves a capability before any client deletion.
5. **Conservative teardown.** A legacy client directory is deleted only when its Flutter
   equivalent's parity matrix is fully green. Each `git rm apps/X` is a pure, revertable
   deletion commit linked (`Refs:`) to its parity proof.
6. **Big-bang on direction, incremental on delivery.** Effort focuses entirely on Flutter now;
   deletion is staged and reversible until each platform is proven.

## What this supersedes (and what it does NOT)

Plan #28 **shipped and stands** — the monorepo, the Elixir Core API, Guardian auth, the
ingestion contract, and Supabase-as-DB/Storage are all kept. This ADR reverses **only the
client topology** §28 chose (three JS/TS thin clients → one Flutter client). #28 is recorded
`done`, not abandoned; the reversal is recorded forward here rather than by rewriting history.

Superseded specifically:
- §1.5 "No Dart/Flutter" → Flutter is the sole frontend.
- §5 client table (Expo/Next/Tauri) → one Flutter app, six targets.
- §6 "OpenAPI → TS client generated" → Flutter uses a hand-rolled Dart API client + Dart
  Phoenix Channels (it never consumed `packages/api-client`).
- §10 monorepo layout (`apps/{mobile,web,desktop}` + `packages/{api-client,ui}`) → `apps/flutter`
  sole client; the JS packages become dead weight retired in cleanup.
- §11 design system (Figma → CSS-vars + RN theme, two bindings) → one Flutter theme binding.
- §13 Locked list → this ADR is the new lock.

## Consequences

- **Positive:** one client codebase; one theme binding; one API-client surface (once the JS
  clients are gone); no RN/Next/Tauri toolchains to maintain.
- **Cost during migration:** two client contracts coexist (Dart hand-rolled + the JS
  `packages/api-client`) until the last JS client is retired — any Core API change lands twice
  in that window.
- **Risk carried:** desktop system-audio capture on Windows/macOS is net-new engineering, not a
  port (gated by the W1 spike). Flutter Web cold-start payload (CanvasKit) behind a login wall.
  iOS/macOS/Windows targets are configured but not yet build-verified on the Linux dev host.

## Out of scope (recorded gaps)

- **OTA updates** (RN had EAS OTA) → store releases; no Flutter equivalent now.
- **Web auth** → token-in-storage (consistent with mobile), prove session survives reload; do
  NOT replicate Next's httpOnly-cookie model.
- **Council dissent:** Edward favored capability×platform slicing over platform-waves; recorded,
  plan uses platform-waves for legibility.

## Status of the canonical doc

`architecture.md` carries a supersession banner pointing here from 2026-06-18; its full rewrite
to the single-Flutter reality is deferred to the cleanup wave (W5) so it is rewritten against the
final tree, not a half-migrated one.
