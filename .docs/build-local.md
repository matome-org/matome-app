# Local build + test per platform — the parity gate

> Plan `flutter-consolidation` (#82), ADR-0001 #4: **a green local build+test per platform is
> the gate** that proves a capability before any legacy client is deleted. No cloud CI is
> required. This doc is the canonical list of "green-build" commands the [parity matrix](parity-matrix.md)
> cells cite as evidence. Run from `apps/flutter/`.

## Prerequisites

- Flutter `3.44.x` stable (Dart `3.12.x`). Verify: `flutter --version`.
- `flutter pub get` clean.
- Codegen current: `dart run build_runner build --delete-conflicting-outputs` (slang i18n + drift).

## Test suite (platform-agnostic Dart/widget tests)

```bash
flutter test --concurrency=1
```

> `--concurrency=1` is REQUIRED — the suite is not safe under the default parallelism (known
> process debt). Expected tail: `All tests passed!`.

## Per-platform build + integration

| Target | Build command | Integration / run | Notes |
|---|---|---|---|
| **linux** | `flutter build linux` | `flutter run -d linux` | Host-verified. Meeting capture needs `ffmpeg` + PulseAudio/PipeWire; mic via `record` (needs `fmedia` or degrades). media_kit needs `mpv` (Arch: `pacman -S mpv`). |
| **web** | `flutter build web` | `flutter run -d chrome` | Needs `CHROME_EXECUTABLE` set for headless/integration. Online-only per ADR-0001 #2 (Drift disabled on web). Ships `sqlite3.wasm` + drift worker + CanvasKit — watch cold-start payload. |
| **android** | `flutter build apk` (or `appbundle`) | `flutter test integration_test/ -d <emulator>` | Host-verifiable with an emulator/device. Port RN Maestro flows here (task 1275). |
| **ios** | `flutter build ios --no-codesign` | `flutter test integration_test/ -d <device>` | ⚠️ **configured, NOT build-verified** — needs a macOS host. |
| **macos** | `flutter build macos` | `flutter run -d macos` | ⚠️ **configured, NOT build-verified** — needs a macOS host. System-audio capture = ScreenCaptureKit/virtual driver (task 1280). |
| **windows** | `flutter build windows` | `flutter run -d windows` | ⚠️ **configured, NOT build-verified** — needs a Windows host. System-audio capture = WASAPI loopback (task 1279). |

## What "green" means for a matrix cell

A platform column counts toward a retirement gate only when, on that platform:
1. `flutter build <target>` completes without error, AND
2. `flutter test --concurrency=1` passes, AND
3. the capability's integration test / screenshot evidence (traceable to a commit sha) is recorded
   in the [parity matrix](parity-matrix.md) evidence log.

## Honest gaps (recorded)

- **ios / macos / windows are unverified on this Linux dev host.** Their columns cannot go green
  without access to a macOS host (ios/macos) and a Windows host (windows). This is the real
  constraint on the desktop (W4) and mobile-ios retirement gates — not a code gap, an
  environment gap.
- No automated CI exists (`.github/` empty); deleting clients breaks no pipeline, but it also
  means these local commands ARE the proof — run them, capture the tail, cite it.
