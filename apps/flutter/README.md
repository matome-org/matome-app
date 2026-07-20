# matome_flutter

Flutter client for matome — the migration target replacing the RN/Expo app
(`apps/mobile`). Flutter **3.44.1** (stable), managed via `mise`.

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

The API base URL is resolved per-platform (web/linux → `http://localhost:7001`,
Android emulator → `http://10.0.2.2:7001`). Override with
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

Suite after the Vault upload migration: **1099 passing, 34 skipped**.

The Android W5 restart gate uses one installed package across a real
`am force-stop`, then proves that three distinct Vault-backed media rows reopen
under a new PID without plaintext, partial Items, or ready-blob orphans:

```bash
bash tool/run_native_vault_android_restart_gate.sh emulator-5554
```

The script builds a compile-time-enabled test harness, installs once, verifies
the package PID and sandbox token on both launches, and clears package data from
its exit trap.

Vault upload gates stream authenticated plaintext without materializing a local
plaintext upload file:

```bash
flutter test test/recordings/vault_upload_queue_test.dart test/upload_pipeline_test.dart
bash tool/run_web_upload_stream_gate.sh
flutter test --run-skipped --tags live \
  --dart-define=LIVE_CORE_URL=http://127.0.0.1:7001 \
  test/recordings/live_vault_audio_processing_e2e_test.dart
```

The Chromium gate verifies the fail-closed signed-length case, then rebuilds
Core with a local HTTPS/HTTP2 test gateway and streams Core-issued
`browser_stream` single and multipart descriptors into MinIO. The gateway adds
the known length only on its HTTP/1.1 MinIO hop; the browser request remains
lengthless and bounded. There is deliberately no XHR/full-buffer fallback.

## Destructive local reset

Schema v30 intentionally has no migration or compatibility path because the app
has not shipped. Account boot closes prior resources, removes the account's v1
SQLCipher directory (including `matome.sqlite-wal` and `matome.sqlite-shm`), the
v1 Native Vault namespace, and legacy `Documents/Matome` recorder/import staging,
then creates a fresh encrypted v2 database and encrypted Vault. Web deletes the
v1 encrypted OPFS database checkpoint before creating v2. No old local media or
draft is preserved.

`file_blobs` stores `blob_id`, logical plaintext size/SHA-256,
`cipher_format`, `cipher_version`, `blob_state`, upload state, and user metadata.
It never stores a filesystem path, FEK, or physical nonce. `recording_drafts`
stores opaque segment/staging handles resolved only inside private recorder
staging.

`vault_retention_policies` defaults to `keep_forever`. The opt-in expiry policy
collects only expired, unreferenced Vault blobs with provider-verified Core
upload facts and no active work or lease. `blob_gc_decisions` records each
redaction-safe preserve/collect decision without a physical path. Unknown and
local-only blobs are always preserved.
