#!/usr/bin/env bash
# Build the WASM studio and serve it on :7002. Proxies Core on :7001.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

"$root/.scripts/wasm-build.sh"

# Core and the port default in wasm-serve.py (MATOME_CORE, MATOME_WASM_PORT).
export MATOME_WASM_ROOT="${MATOME_WASM_ROOT:-$root/build-wasm/bin}"

exec python3 "$root/.scripts/wasm-serve.py"
