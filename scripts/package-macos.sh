#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?source directory required}"
tag="${2:?release tag required}"
dist_dir="${3:?output directory required}"
[[ "$tag" == "v$(cat "$source_dir/version.txt")" ]] || {
  echo 'package-macos: tag does not match version.txt' >&2
  exit 1
}

mkdir -p "$dist_dir"
dist_dir="$(cd "$dist_dir" && pwd)"
build_dir="${RUNNER_TEMP:-/tmp}/matome-macos-build"
mkdir -p "$build_dir"
cd "$build_dir"
qmake "$source_dir/matome.pro" CONFIG+=release \
  'QMAKE_APPLE_DEVICE_ARCHS=x86_64 arm64'
make -j"$(sysctl -n hw.ncpu)"

bundle="$build_dir/bin/Matome.app"
test -d "$bundle"
architectures="$(lipo -archs "$bundle/Contents/MacOS/Matome")"
[[ " $architectures " == *' x86_64 '* && " $architectures " == *' arm64 '* ]] || {
  echo "package-macos: expected universal app, got $architectures" >&2
  exit 1
}
mkdir -p "$bundle/Contents/Resources/licenses"
cp "$source_dir/LICENSE" "$bundle/Contents/Resources/licenses/LICENSE"
cp "$source_dir"/src/gui/fonts/OFL-*.txt "$bundle/Contents/Resources/licenses/"
cd "$build_dir/bin"
macdeployqt Matome.app -qmldir="$source_dir/src/gui/qml" -dmg
mv Matome.dmg "$dist_dir/matome-macos-universal-$tag.dmg"
