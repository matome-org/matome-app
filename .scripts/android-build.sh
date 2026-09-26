#!/usr/bin/env bash
# Build an x86_64 APK for the Android emulator. Idempotent.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

"$root/.scripts/android-deps.sh" >/dev/null
android_env

build_dir="$root/build-android"
mkdir -p "$build_dir"
cd "$build_dir"
"$qt_android/bin/qmake" "$root/matome.pro" -spec android-clang CONFIG+=qtquickcompiler
make qmake_all
make -j"$jobs"

settings="$build_dir/src/gui/android-matome-studio-deployment-settings.json"
if [ ! -f "$settings" ]; then
  echo "android-build: missing $settings" >&2
  find "$build_dir" -name '*deployment-settings.json' >&2 || true
  exit 1
fi

android_out="$build_dir/src/gui/android-build"
mkdir -p "$android_out/libs/x86_64"
dest="$android_out/libs/x86_64/libmatome-studio_x86_64.so"
so="$(find "$build_dir/src/gui" -maxdepth 1 -name 'libmatome-studio_x86_64.so' | head -1)"
if [ -z "$so" ]; then
  so="$(find "$build_dir" -name 'libmatome-studio_x86_64.so' ! -path '*/android-build/*' | head -1)"
fi
if [ -z "$so" ]; then
  echo "android-build: missing libmatome-studio_x86_64.so" >&2
  exit 1
fi
if [ "$so" != "$dest" ]; then
  cp -f "$so" "$dest"
fi
"$qt_host/bin/androiddeployqt" \
  --input "$settings" \
  --output "$android_out" \
  --android-platform android-36 \
  --jdk "$JAVA_HOME" \
  --gradle \
  --debug

apk="$(find "$android_out" -name '*-debug.apk' | head -1)"
if [ -z "$apk" ]; then
  echo "android-build: no debug apk under $android_out" >&2
  find "$android_out" -name '*.apk' >&2 || true
  exit 1
fi
mkdir -p "$build_dir/bin"
cp -f "$apk" "$build_dir/bin/matome-studio.apk"
echo "apk $build_dir/bin/matome-studio.apk"
