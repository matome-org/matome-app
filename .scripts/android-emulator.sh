#!/usr/bin/env bash
# Boot Pixel_7_API_34 with host GPU. SwiftShader paints Qt Quick
# Rectangles as one triangle of two.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

android_env

emu="$sdk/emulator/emulator"
if [ ! -x "$emu" ]; then
  echo "android-emulator: missing $emu" >&2
  exit 1
fi

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "android-emulator: -gpu host needs a display; set DISPLAY or WAYLAND_DISPLAY" >&2
  exit 1
fi

exec "$emu" -avd Pixel_7_API_34 -gpu host -netdelay none -netspeed full
