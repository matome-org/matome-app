#!/usr/bin/env bash
# Test the meeting-capture macOS (ScreenCaptureKit) package on a real macOS 15+ host.
#   git clone <repo> && cd matome-app && ./.scripts/test-macos.sh
#
# Runs: facade unit tests, the macOS package Dart unit tests, a native
# `flutter build macos` of the package example, and the on-device integration
# test. Requires Xcode + CocoaPods, and Screen Recording + Microphone permission
# for the example app (System Settings -> Privacy & Security).
#
# The capture round-trip integration test is the TDD target for #1280 and is
# EXPECTED TO FAIL until the SCStream + AVAssetWriter DSP is implemented.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGS="$ROOT/apps/flutter/packages"

echo "== flutter version =="
flutter --version

run_pkg() {
  local dir="$1"; shift
  echo ""
  echo "== package: $(basename "$dir") =="
  (cd "$dir" && flutter pub get && flutter analyze && flutter test "$@")
}

# Facade (pure Dart) + macOS impl Dart unit tests (MethodChannel mocks).
run_pkg "$PKGS/meeting_capture"
run_pkg "$PKGS/meeting_capture_macos"

# Native build + on-device integration test via the example app.
EX="$PKGS/meeting_capture_macos/example"
echo ""
echo "== example: native build + integration test (macos) =="
cd "$EX"
flutter pub get
# Generate the macOS runner once (idempotent; leaves lib/ intact).
[ -d macos ] || flutter create --platforms=macos .
flutter build macos --debug
flutter test integration_test/capture_test.dart -d macos

echo ""
echo "OK — macOS package tests + native build passed."
echo "The capture round-trip test is expected red until #1280 DSP lands."
