#!/usr/bin/env bash
# Test the meeting-capture packages on a real Linux host.
#   git clone <repo> && cd matome-app && ./.scripts/test-linux.sh
#
# Runs: facade (channel + contract) unit tests, the Linux impl host-gated tests
# (real ffmpeg/pactl), and a native `flutter build linux` of the app to prove the
# endorsed Linux plugin links. The live upload->Core e2e is separate (needs the
# backend up: `mise run backend`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/flutter"
PKGS="$APP/packages"

echo "== flutter version =="
flutter --version

run_pkg() {
  local dir="$1"; shift
  echo ""
  echo "== package: $(basename "$dir") =="
  (cd "$dir" && flutter pub get && flutter analyze && flutter test "$@")
}

# Facade — MethodChannel backend + contract (pure Dart, runs anywhere).
run_pkg "$PKGS/meeting_capture"

# Linux implementation — host-gated tests shell out to real ffmpeg/ffprobe/pactl.
run_pkg "$PKGS/meeting_capture_linux" --run-skipped --tags linux_host

# Native build proof: the app links the endorsed linux plugin.
echo ""
echo "== flutter build linux (app) =="
(cd "$APP" && flutter pub get && flutter build linux --debug)

echo ""
echo "OK — Linux package tests + native build passed."
echo "Note: the live meeting round-trip e2e needs the backend running:"
echo "  mise run backend"
echo "  (cd apps/flutter && flutter test test/recordings/live_meeting_processing_e2e_test.dart \\"
echo "     --dart-define=LIVE_CORE_URL=http://localhost:7001 --tags live)"
