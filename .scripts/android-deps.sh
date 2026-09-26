#!/usr/bin/env bash
# Check the Android APK toolchain. Idempotent.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

missing=""
[ -x "$java_home/bin/java" ] || missing="$missing jdk17"
[ -x "$sdk/platform-tools/adb" ] || missing="$missing adb"
[ -d "$sdk/platforms/android-36" ] || missing="$missing android-36"
[ -x "$sdk/build-tools/36.0.0/aapt" ] || missing="$missing build-tools-36"
[ -d "$ndk" ] || missing="$missing ndk-27.2"
[ -x "$qt_android/bin/qmake" ] || missing="$missing qt-android-qmake"
[ -x "$qt_host/bin/androiddeployqt" ] || missing="$missing androiddeployqt"

if [ -z "$missing" ]; then
  echo "all present — qt-android $($qt_android/bin/qmake -query QT_VERSION), adb $($sdk/platform-tools/adb version | head -1)"
  exit 0
fi

echo "missing:$missing" >&2
echo >&2
echo "expected:" >&2
echo "  JDK 17 at $java_home" >&2
echo "  Android SDK at $sdk (platform 36, build-tools 36.0.0, ndk 27.2.12479018)" >&2
echo "  Qt android_x86_64 + gcc_64 host at $qt_home" >&2
echo >&2
echo "install:" >&2
echo "  mise use -g java@openjdk-17.0.2" >&2
echo "  export ANDROID_HOME=\$HOME/.local/android-sdk" >&2
echo "  sdkmanager platform-tools \"platforms;android-36\" \"build-tools;36.0.0\" \"ndk;27.2.12479018\"" >&2
echo "  aqt install-qt all_os android 6.11.2 android_x86_64 --outputdir \$HOME/.local/Qt --modules qtshadertools qtimageformats" >&2
exit 1
