# Per-machine meeting-capture package tests

The meeting-capture feature is a federated Flutter plugin split by OS so per-OS
native code never enters foreign bundles:

- `apps/flutter/packages/meeting_capture` — facade: contract, shared bounded
  process runner, MethodChannel/EventChannel backend, `MeetingCapturePlatform`.
- `apps/flutter/packages/meeting_capture_linux` — Dart-only ffmpeg/pactl impl.
- `apps/flutter/packages/meeting_capture_windows` — native WASAPI impl (C++).
- `apps/flutter/packages/meeting_capture_macos` — native ScreenCaptureKit impl (Swift).

Because native code only builds on its own OS, clone the repo on each machine and
run that OS's script. Each script does, per package: `flutter pub get`, `flutter
analyze`, `flutter test`, then (Windows/macOS) a native build of the package
example plus the on-device integration test.

## Run

Linux:
```bash
git clone <repo> && cd matome-app
./.scripts/test-linux.sh
```

macOS 15+ (Xcode + CocoaPods; grant Screen Recording + Microphone to the example app):
```bash
git clone <repo> && cd matome-app
./.scripts/test-macos.sh
```

Windows (Visual Studio with the Desktop C++ workload):
```powershell
git clone <repo>; cd matome-app
.\.scripts\test-windows.ps1
```

## What passes vs. what is red

- **Dart unit tests** (facade channel backend, each impl's registrant) run on any
  host and should pass.
- **`probe` + `requestPermission`** integration tests should pass once the native
  plugin compiles.
- **The capture round-trip** integration test is the on-device TDD target and is
  **expected to fail** until the native DSP lands:
  - Windows WASAPI loopback+mic → AAC/M4A (Media Foundation) — task **#1279**.
  - macOS ScreenCaptureKit system audio + mic → AAC/M4A (AVAssetWriter) — task **#1280**.
  The native capture in these packages is a first attempt, marked
  `NEEDS-DEVICE-VALIDATION` in the C++/Swift sources.

## Toolchain

Flutter 3.44 / Dart 3.12 (see `mise.toml` and `apps/flutter/pubspec.yaml`). The
scripts do not install the toolchain — install Flutter first (mise or the Flutter
SDK) so `flutter --version` works.
