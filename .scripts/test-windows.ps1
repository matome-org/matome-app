# Test the meeting-capture Windows (WASAPI) package on a real Windows host.
#   git clone <repo>; cd matome-app; .\.scripts\test-windows.ps1
#
# Runs: facade unit tests, the Windows package Dart unit tests, a native
# `flutter build windows` of the package example, and the on-device integration
# test. Requires Visual Studio (Desktop C++ workload).
#
# The capture round-trip integration test is the TDD target for #1279 and is
# EXPECTED TO FAIL until the WASAPI + Media Foundation DSP is implemented.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Pkgs = Join-Path $Root "apps\flutter\packages"

Write-Host "== flutter version =="
flutter --version

function Test-Package {
  param([string]$Dir, [string[]]$TestArgs = @())
  Write-Host ""
  Write-Host "== package: $(Split-Path $Dir -Leaf) =="
  Push-Location $Dir
  try {
    flutter pub get
    flutter analyze
    flutter test @TestArgs
  } finally {
    Pop-Location
  }
}

# Facade (pure Dart) + Windows impl Dart unit tests (MethodChannel mocks).
Test-Package (Join-Path $Pkgs "meeting_capture")
Test-Package (Join-Path $Pkgs "meeting_capture_windows")

# Native build + on-device integration test via the example app.
$Ex = Join-Path $Pkgs "meeting_capture_windows\example"
Write-Host ""
Write-Host "== example: native build + integration test (windows) =="
Push-Location $Ex
try {
  flutter pub get
  # Generate the windows runner once (idempotent; leaves lib/ intact).
  if (-not (Test-Path "windows")) { flutter create --platforms=windows . }
  flutter build windows --debug
  flutter test integration_test\capture_test.dart -d windows
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "OK - Windows package tests + native build passed."
Write-Host "The capture round-trip test is expected red until #1279 DSP lands."
