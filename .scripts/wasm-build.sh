#!/usr/bin/env bash
# Build matome-studio.wasm. Idempotent.
# Usage: wasm-build.sh [<build dir> [qmake args...]]  (default build-wasm)
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

wasm_env
build_dir="${1:-$root/build-wasm}"
[ "$#" -eq 0 ] || shift
qmake_build "$build_dir" "$root/matome.pro" "$@"

bin="$build_dir/bin"
if [ ! -f "$bin/matome-studio.html" ]; then
  echo "wasm build did not produce $bin/matome-studio.html" >&2
  ls -la "$bin" >&2 || true
  exit 1
fi
cp -f "$root/packaging/wasm/matome-studio.html" "$bin/matome-studio.html"
# The splash's face, from the studio's own fonts.
cp -f "$root/src/gui/fonts/CormorantGaramond-Light.ttf" "$bin/"
gzip -kf "$bin/matome-studio.js" "$bin/qtloader.js" "$bin/matome-studio.html"
ln -sfn matome-studio.html "$bin/index.html"
echo "wasm $bin/matome-studio.html"
