# Flutter Lab — Home/Today cross-platform — Report

**Plan:** `flutter-lab-home` · **Branch:** `migration/flutter-lab` · **Date:** 2026-06-08
**Goal:** de-risk a possible Flutter migration by building one real screen (Home/Today)
on the real Phoenix-Guardian backend, running on Web + Desktop Linux + Android, to
decide go/no-go before committing to a full migration.

## Outcome

**The lab succeeded.** The Home/Today screen runs on all three target platforms
against the live backend, with visual consistency held across Web, Desktop Linux,
and Android (verified live by the owner).

- Single Dart/Flutter codebase → Web (Chromium :8080), Linux desktop (native window),
  Android (pixel7 emulator).
- Real data end-to-end: AuthGate signs in with the seed account (`dev@matome.test`)
  → Guardian JWT → `GET /api/recordings` → Home renders 5 seeded recordings with
  sections (Today / Earlier), filter chips (All/Today/Work/Ideas/Unresolved),
  status states (done / processing / failed-with-retry), search, and pull-to-refresh.
- Backend was NOT changed beyond CORS — Guardian auth and the recordings API served
  the Flutter client unchanged. This is the key signal: the decoupled backend already
  serves a new client cleanly.

## What was delivered (commits on `migration/flutter-lab`)

| Task | Commit | Summary |
|------|--------|---------|
| #762 backend prep | `5dcf0a7` | CORS (`cors_plug`) for the Flutter Web origin; API contract doc; seed confirmed |
| #763 scaffold | `58e0fc5` | `apps/flutter` (`matome_flutter`), web/linux/android, no iOS |
| #764 auth + client | `fa03ad8` | dio + secure storage + riverpod; Guardian login; `Recording` model; per-platform base URL |
| #765 Home UI | `9e93b02` | Responsive Home/Today: header, search, chips, sections, RecordingCard, pull-to-refresh |
| lab fix | `5a6fbee` | Unblock Linux build under clang 22 (`-Wno-deprecated-literal-operator`) |
| lab glue | `0165437` | AuthGate auto sign-in (seed) + `mise run flutter-{web,linux,android}` tasks |

Verification: `flutter analyze` clean; `flutter test` 22 passing; `flutter build`
green for web, linux, apk. Backend e2e confirmed via curl (health 200, login JWT,
recordings list, CORS preflight for :8080).

## Effort (this lab)

~5 delegated builder runs + orchestration, roughly **half a day of automated work**
(builder wall-clock ~30 min total + integration/fix time). A human team doing the
same first screen cold (incl. learning the toolchain) is realistically **2–3 days**.
This was ONE screen with the data layer; extrapolating to the full app is the open
question below, not a settled number.

## What was easy

- `flutter create` + three build targets working same-day (via mise, versioned).
- Talking to the existing Phoenix API — the OpenAPI/contract-first backend meant the
  Dart client was a thin, hand-written layer (no backend churn).
- Visual consistency across platforms — Flutter's own renderer delivered the same
  Home on web/desktop/mobile with one responsive layout (`width >= 1000` → max-width
  720 column; below → full-width single column).
- Riverpod state + tolerant JSON parsing made loading/empty/error/failed states cheap.

## What was hard / friction

- **Linux desktop + bleeding-edge clang.** `flutter_secure_storage_linux`'s vendored
  `json.hpp` is fatal under clang 22 + the scaffold's `-Werror`. Needed a one-line
  CMake suppression. Expect more of these papercuts on Arch/rolling toolchains.
- **No login UI seam.** The data layer (#764) and the screen (#765) each assumed a
  session existed; neither created one. Closed with a lab-only AuthGate. A real
  migration needs a proper auth flow (and the Supabase-auth decision below).
- **Seeding real data.** `POST /api/recordings` does a storage presign round-trip, so
  sample data was inserted directly via psql for the demo.

## Gaps NOT exercised by this lab (must-cover before a full migration)

1. **Supabase auth** — deferred by decision. The lab kept Guardian. The real target
   (Supabase auth) means either Phoenix validates Supabase JWTs or the client bridges
   Supabase→Guardian. Unproven here.
2. **Phoenix Channels / real-time** — the recording/streaming flow uses
   `matome_api_web/channels` + socket-token. `phoenix_socket` (Dart) was NOT tested.
   This is the highest-risk unknown for a migration, given recording is core.
3. **Audio recording + upload** — native record + storage presign upload not built in
   Flutter. Needs `record`/`just_audio` + the S3 presign dance. Significant.
4. **Storage / media playback** via `supabase_flutter` — untested.
5. **iOS** — out of scope (no macOS here); a real migration must cover it.
6. **The other screens** — Calendar, Details, Spaces, Settings, Login, Signup, Satori,
   Welcome, Inbox. Only Home was ported.
7. **Desktop story** — Flutter Linux desktop native vs keeping Tauri. Toolchain
   papercuts (above) are a cost to weigh.
8. **CI / build pipeline**, i18n (lab hardcoded English), full design-system parity,
   Flutter Web bundle size for the app origin.

## Recommendation — conditional GO for deeper evaluation (not yet a full GO)

The cross-platform UX consistency and the clean reuse of the decoupled backend are
strong positive signals: the thing Flutter promises (one UI, three platforms) held,
and the backend needed almost nothing. The migration is **viable**.

But the decision should NOT be made on Home alone. The two unknowns that can sink a
migration — **Phoenix Channels real-time** and **native audio record+upload** — were
not touched, and recording is the product's core. 

Proposed next step before committing: a **second, harder spike** covering (a) a live
recording → channel → upload flow in Flutter against the real backend, and (b) the
Supabase-auth path. If that spike is as clean as this one, it's a full GO. If the
real-time/recording path fights the framework, reconsider — possibly keep RN for
mobile and use Flutter only where it shines.

Backend stays Elixir either way. Landing page stays separate (own URL/SEO). This lab
changed nothing in the existing RN/Next/Tauri apps — it lives entirely under
`apps/flutter` on `migration/flutter-lab` and is fully reversible.
