# Scripts

- `gen-deploy-env.sh` — fills `.env.localserver` or `.env.production` (see below).
- `push-dokploy-env.sh` — pushes that environment into Dokploy (see below).
- `test-linux.sh` / `test-macos.sh` / `test-windows.ps1` — per-machine
  meeting-capture package tests (see below).

## Deploy environments

Both Compose stacks derive their URLs from a single value, which leaves that
one plus the secrets as the only manual input:

| Stack | File | Derived from | Reaches |
|---|---|---|---|
| `localserver` | `.env.localserver` | `HOST_IP` | `http://HOST_IP:<port>` |
| `production` | `.env.production` | `BASE_DOMAIN` | `https://api\|app\|media.<domain>` |

The generator seeds anything missing from the matching `*.example`, fills the
secrets with `openssl rand`, and never touches a value that is already set, so
it is safe to re-run:

```bash
mise run localserver:env                      # HOST_IP detected from this host
BASE_DOMAIN=example.com mise run production:env
./.scripts/gen-deploy-env.sh --print           # same, then dump it for Dokploy
```

`HOST_IP` detection uses `ip route get`, which resolves to *this* machine —
override it when generating for a different host:

```bash
HOST_IP=192.168.1.50 ./.scripts/gen-deploy-env.sh
```

`BASE_DOMAIN` has nothing to detect, so the first run needs it in the
environment. Whatever the generator cannot decide — the SMTP relay, the chat
model — stays `CHANGE_ME` and is listed at the end.

`--print` sends progress to stderr and the file to stdout, so the dump pipes
cleanly. The generated files hold real secrets: `chmod 600`, gitignored, and
they belong in the Dokploy environment panel, not in a commit.

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
the old address. `--no-deploy` defers that, and `--deploy-only` triggers the
rebuild on its own — which is how a run that stopped after storing the
environment is resumed.

It also refuses to ship a `CHANGE_ME` placeholder, since one reaching a
deployment only fails much later and far from here.

Note that a LAN-only Dokploy cannot receive GitHub webhooks, so `autoDeploy`
never fires there: pushing to `development` updates the branch, and the deploy
that picks it up is the one this script triggers. A public VPS does receive
them, so there the push script is only needed when the environment changes.

### A second target

Both file paths are parameters, so a VPS is the same workflow against another
connection file:

```bash
CONN_FILE=.env.dokploy.vps.local \
  ./.scripts/push-dokploy-env.sh --file=.env.production --dry-run
```

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
