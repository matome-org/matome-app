# Scripts

- `gen-localserver-env.sh` — fills `.env.localserver` for the Dokploy
  local-server stack (see below).
- `push-dokploy-env.sh` — pushes that environment into Dokploy (see below).
- `test-linux.sh` / `test-macos.sh` / `test-windows.ps1` — per-machine
  meeting-capture package tests (see below).

## Local-server deploy environment

`docker-compose.localserver.yml` derives every browser-reachable URL from
`HOST_IP`, which leaves the LAN address plus six secrets as the only manual
input. The script generates them and never touches a value that is already
set, so it is safe to re-run:

```bash
mise run localserver:env               # writes/completes .env.localserver
./.scripts/gen-localserver-env.sh --print   # same, then dump it for Dokploy
```

`--print` sends progress to stderr and the file to stdout, so the dump pipes
cleanly. The generated file holds real secrets: it is `chmod 600`, gitignored,
and belongs in the Dokploy environment panel, not in a commit.

Detection uses `ip route get`, which resolves to this machine's LAN address —
override it when generating for a different host:

```bash
HOST_IP=192.168.1.50 ./.scripts/gen-localserver-env.sh
```

## Pushing the environment to Dokploy

Dokploy stores the environment in its own database, so `git push` rebuilds the
code and leaves the variables untouched. `push-dokploy-env.sh` closes that gap.
Copy `.env.dokploy.example` to `.env.dokploy.local` and fill in the URL, API
token and compose id first.

```bash
./.scripts/push-dokploy-env.sh --pull      # seed .env.localserver from Dokploy
mise run localserver:env                   # fill whatever is still missing
./.scripts/push-dokploy-env.sh --dry-run   # review the diff
./.scripts/push-dokploy-env.sh             # update, then rebuild
```

`--pull` first is what keeps an already-running stack safe: Postgres and MinIO
were initialized with the secrets currently in Dokploy, so generating fresh
ones locally and pushing them would lock the services out of their own volumes.
The script refuses to change a secret that is already set unless
`--rotate-secrets` says so explicitly.

`compose.update` replaces the whole environment field, so the script merges:
remote-only keys are carried over, local keys win, and `--prune=KEY` (or
`--prune-derived` for the four values `HOST_IP` now derives) removes stale
ones. Run it only when the environment changes — code still ships by pushing to
`development`.

It ends with `compose.deploy` rather than a redeploy because `API_BASE_URL` is
a build arg for the Flutter web bundle: reusing the image would keep serving
the old address. `--no-deploy` defers that.

## Per-machine meeting-capture package tests

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
