#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?source directory required}"
automation_dir="$(cd "$(dirname "$0")/.." && pwd)"
tag="${2:?release tag required}"
dist_dir="${3:?output directory required}"
[[ "$tag" == "v$(cat "$source_dir/version.txt")" ]] || {
  echo 'package-linux: tag does not match version.txt' >&2
  exit 1
}

mkdir -p "$dist_dir"
dist_dir="$(cd "$dist_dir" && pwd)"
build_dir="${RUNNER_TEMP:-/tmp}/matome-linux-build"
mkdir -p "$build_dir"
cd "$build_dir"
qmake "$source_dir/matome.pro" CONFIG+=release
make -j"$(nproc)"

appdir="$build_dir/AppDir"
mkdir -p "$appdir/usr/share/doc/matome/licenses"
cp "$source_dir/LICENSE" "$appdir/usr/share/doc/matome/licenses/LICENSE"
cp "$source_dir"/src/gui/fonts/OFL-*.txt "$appdir/usr/share/doc/matome/licenses/"
rsvg-convert -w 256 -h 256 "$source_dir/src/gui/icons/matome.svg" \
  -o "$build_dir/matome.png"
export QML_SOURCES_PATHS="$source_dir/src/gui/qml"
export QMAKE="$(command -v qmake)"
export APPIMAGE_EXTRACT_AND_RUN=1
export OUTPUT="$dist_dir/matome-linux-x86_64-$tag.AppImage"
"${LINUXDEPLOY:?linuxdeploy path required}" \
  --appdir "$appdir" \
  --executable "$build_dir/bin/matome-studio" \
  --desktop-file "$automation_dir/packaging/linux/matome.desktop" \
  --icon-file "$build_dir/matome.png" \
  --plugin qt \
  --output appimage
test -s "$OUTPUT"
