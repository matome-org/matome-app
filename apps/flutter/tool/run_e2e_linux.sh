#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

tests=(
  integration_test/e2e_smoke_test.dart
  integration_test/e2e_auth_guard_test.dart
  integration_test/e2e_recording_flows_test.dart
  integration_test/e2e_notes_transcript_test.dart
  integration_test/e2e_matome_overflow_sheet_test.dart
  integration_test/e2e_matome_image_open_test.dart
  integration_test/e2e_image_detail_desktop_test.dart
  integration_test/e2e_use_case_surfaces_test.dart
)

flutter pub get
for test_file in "${tests[@]}"; do
  printf '\n==> Linux E2E: %s\n' "$test_file"
  flutter test "$test_file" -d linux --no-pub
done
