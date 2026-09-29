#!/usr/bin/env bash
set -euo pipefail

root="${MISE_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
exec python3 "$root/tests/test_wasm_proxy.py"
