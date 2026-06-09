# matome_flutter

Flutter client for matome — the migration target replacing the RN/Expo app
(`apps/mobile`). Flutter **3.44.1** (stable), managed via `mise`.

See the cutover report at `.docs/flutter-migration-report.md` for per-platform
status, the full parity audit, and remaining gaps.

## Prerequisites

```bash
eval "$(mise activate bash)"   # provides the pinned Flutter 3.44.1 toolchain
flutter pub get
```

Enable the platforms once per machine (no-op if already enabled):

```bash
flutter config --enable-web --enable-linux-desktop \
  --enable-macos-desktop --enable-windows-desktop --enable-android --enable-ios
```

The API base URL is resolved per-platform (web/linux → `http://localhost:4000`,
Android emulator → `http://10.0.2.2:4000`). Override with
`--dart-define=API_BASE_URL=...`.

## Native config (versioned — important)

The native projects under `android/`, `ios/`, `macos/`, `windows/`, `linux/` are
**committed**. The repo root `.gitignore`'s legacy "# Native" rules are scoped to
`apps/mobile/` so they no longer swallow this app's native folders. Two Android
overrides and the Apple mic config live in these tracked files and **must not be
regenerated/overwritten** by a bare `flutter create`:

- `android/app/build.gradle.kts` → `compileSdk = 36` (required by `file_picker`'s
  AAR metadata check).
- `android/app/src/main/AndroidManifest.xml` → `RECORD_AUDIO` permission (mic).
- `ios/Runner/Info.plist` → `NSMicrophoneUsageDescription` (mic).
- `macos/Runner/{DebugProfile,Release}.entitlements` →
  `com.apple.security.device.audio-input` (sandbox mic).

A fresh checkout is buildable with **no extra setup** — these files are tracked.
If you ever re-run `flutter create` to repair a platform folder, re-apply the four
overrides above (build artifacts stay ignored via each platform's own `.gitignore`).

## Build

| Target | Command | Notes |
|--------|---------|-------|
| web | `CHROME_EXECUTABLE=/usr/bin/chromium flutter build web` | CanvasKit. |
| linux | `flutter build linux` | Desktop. Audio capture needs the external `fmedia` binary (else recording is unsupported; view/play still work). |
| android | `flutter build apk` | Uses the versioned `compileSdk 36` + `RECORD_AUDIO`. |
| ios | `flutter build ios` | **macOS host only** (Xcode, CocoaPods, signing). Not verified on Linux. |
| macos | `flutter build macos` | **macOS host only.** |
| windows | `flutter build windows` | **Windows host only** (Visual Studio C++ workload). |

## Quality gates

```bash
flutter analyze
flutter test --concurrency=1   # NOTE: --concurrency=1 — inbox_controller_test has a parallel-only flake
```

Suite: **247 passing, 1 skipped**.
