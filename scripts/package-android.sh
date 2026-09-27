#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?source directory required}"
tag="${2:?release tag required}"
dist_dir="${3:?output directory required}"
version="${tag#v}"
[[ "$tag" == "v$(cat "$source_dir/version.txt")" ]] || {
  echo 'package-android: tag does not match version.txt' >&2
  exit 1
}
for name in QT_ANDROID QT_HOST ANDROID_SDK_ROOT ANDROID_NDK_ROOT JAVA_HOME \
    QT_ANDROID_KEYSTORE_PATH QT_ANDROID_KEYSTORE_ALIAS \
    QT_ANDROID_KEYSTORE_STORE_PASS QT_ANDROID_KEYSTORE_KEY_PASS; do
  [[ -n "${!name:-}" ]] || { echo "package-android: missing $name" >&2; exit 1; }
done

mkdir -p "$dist_dir"
dist_dir="$(cd "$dist_dir" && pwd)"
build_dir="${RUNNER_TEMP:-/tmp}/matome-android-arm64-build"
mkdir -p "$build_dir"
cd "$build_dir"
if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo 'package-android: version must be numeric SemVer' >&2
  exit 1
fi
version_code=$((6 + 1000000 * 10#${BASH_REMATCH[1]} + 1000 * 10#${BASH_REMATCH[2]} + 10#${BASH_REMATCH[3]}))
"$QT_ANDROID/bin/qmake" "$source_dir/matome.pro" -spec android-clang \
  CONFIG+=qtquickcompiler CONFIG+=release \
  MATOME_ANDROID_ABI=arm64-v8a MATOME_ANDROID_VERSION_CODE="$version_code"
make qmake_all
make -j"$(nproc)"

settings="$build_dir/src/gui/android-matome-studio-deployment-settings.json"
test -f "$settings"
android_out="$build_dir/src/gui/android-build"
mkdir -p "$android_out/libs/arm64-v8a"
so="$build_dir/src/gui/libmatome-studio_arm64-v8a.so"
test -f "$so"
cp "$so" "$android_out/libs/arm64-v8a/"
"$QT_HOST/bin/androiddeployqt" \
  --input "$settings" \
  --output "$android_out" \
  --android-platform android-36 \
  --jdk "$JAVA_HOME" \
  --gradle \
  --release \
  --sign "$QT_ANDROID_KEYSTORE_PATH" "$QT_ANDROID_KEYSTORE_ALIAS" \
  --storetype PKCS12

apk="$(find "$android_out" -name '*-release-signed.apk' -print -quit)"
test -n "$apk"
"$ANDROID_SDK_ROOT/build-tools/36.0.0/apksigner" verify --verbose "$apk"
cp "$apk" "$dist_dir/matome-android-arm64-$tag.apk"
