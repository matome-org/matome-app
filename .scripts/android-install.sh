#!/usr/bin/env bash
# Install the studio APK on a running emulator/device and launch it.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

apk="${1:-$root/build-android/bin/matome-studio.apk}"
if [ ! -f "$apk" ]; then
  "$root/.scripts/android-build.sh"
  apk="$root/build-android/bin/matome-studio.apk"
fi

android_env

adb wait-for-device
adb install -r -t "$apk"
adb shell am start -n org.matome.studio/org.qtproject.qt.android.bindings.QtActivity
echo "installed $apk"
