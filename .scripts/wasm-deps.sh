#!/usr/bin/env bash
# Check the WebAssembly toolchain. Idempotent.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

missing=""
[ -x "$emsdk/upstream/emscripten/emcc" ] || missing="$missing emcc"
[ -x "$qt_wasm/bin/qmake" ] || missing="$missing qt-wasm-qmake"
[ -x "$qt_host/bin/qmake6" ] || missing="$missing qt-host-qmake"

if [ -z "$missing" ]; then
  # shellcheck disable=SC1091
  source "$emsdk/emsdk_env.sh" >/dev/null
  echo "all present — qt-wasm $($qt_wasm/bin/qmake -query QT_VERSION), emcc $(emcc --version | head -1)"
  exit 0
fi

echo "missing:$missing" >&2
echo >&2
echo "expected:" >&2
echo "  emsdk 4.0.7 at $emsdk (Qt 6.11.2 WASM ABI)" >&2
echo "  Qt wasm_singlethread + gcc_64 host at $qt_home" >&2
echo >&2
echo "install:" >&2
echo "  git clone https://github.com/emscripten-core/emsdk.git \$HOME/.local/emsdk" >&2
echo "  \$HOME/.local/emsdk/emsdk install 4.0.7 && \$HOME/.local/emsdk/emsdk activate 4.0.7" >&2
echo "  uv tool install aqtinstall" >&2
echo "  aqt install-qt all_os wasm 6.11.2 wasm_singlethread --outputdir \$HOME/.local/Qt" >&2
echo "  aqt install-qt linux desktop 6.11.2 linux_gcc_64 --outputdir \$HOME/.local/Qt" >&2
echo "  then set HostSpec=linux-g++ in wasm_singlethread/bin/target_qt.conf" >&2
exit 1
