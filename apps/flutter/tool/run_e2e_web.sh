#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

chrome_binary="${CHROME_EXECUTABLE:-/usr/bin/chromium}"
driver_log="${TMPDIR:-/tmp}/matome-chromedriver.log"
tests=(
  integration_test/e2e_smoke_test.dart
  integration_test/e2e_auth_guard_test.dart
  integration_test/e2e_recording_flows_web_test.dart
  integration_test/e2e_notes_transcript_test.dart
  integration_test/e2e_matome_overflow_sheet_test.dart
  integration_test/e2e_matome_image_open_test.dart
  integration_test/e2e_image_detail_desktop_test.dart
  integration_test/e2e_use_case_surfaces_test.dart
)

command -v chromedriver >/dev/null
test -x "$chrome_binary"

chromedriver --port=4444 >"$driver_log" 2>&1 &
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true' EXIT
sleep 1

flutter pub get
for test_file in "${tests[@]}"; do
  printf '\n==> Web E2E: %s\n' "$test_file"
  CHROME_EXECUTABLE="$chrome_binary" flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$test_file" \
    -d web-server \
    --browser-name=chrome \
    --chrome-binary="$chrome_binary" \
    --no-start-paused \
    --no-web-resources-cdn \
    --timeout=300 \
    --no-pub
done
