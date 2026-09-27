#!/usr/bin/env bash
# Browser e2e for the WASM studio against FakeCore, in Chromium.
# Usage: e2e.sh [--profile desktop|mobile] [--grep <regex>] [--repeat <n>]
#   --profile  desktop 1280×800 (mouse, keyboard) or mobile (Pixel 7
#              viewport, touch); repeatable, both by default
#   --grep     only scenarios whose "<id> <title>" matches
#   --repeat   run each scenario n times
# Builds the e2e WASM variant (the studio plus the test-only
# probe in tests/e2e/web/probe, in build-tests/web-e2e/); needs the shipped
# build from `mise run wasm` for the boot check. Runs FakeCore and the page
# server on free ports and stops them when done.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

test_env
export MATOME_TEST_BUILD=1
product="$root/build-wasm/bin"
if [ ! -f "$product/matome-studio.wasm" ]; then
  echo "e2e: missing $product/matome-studio.wasm — run mise run wasm first" >&2
  exit 1
fi
for tool in node playwright python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "e2e: $tool is required (playwright: mise tool npm:playwright)" >&2
    exit 1
  fi
done

# The e2e variant: the same sources as the shipped build, with the probe
# linked whole so its window.matomeE2E hook registers.
e2e="$root/build-tests/web-e2e"
mkdir -p "$e2e"
(
  wasm_env
  qmake_build "$e2e/probe" "$root/tests/e2e/web/probe/probe.pro"
  "$root/.scripts/wasm-build.sh" "$e2e/app" \
    CONFIG+=matome_test \
    "LIBS+=-Wl,--whole-archive,$e2e/probe/libwebprobe.a,--no-whole-archive" \
    "PRE_TARGETDEPS+=$e2e/probe/libwebprobe.a"
) >"$e2e/build.log" 2>&1 || {
  echo "e2e: building the e2e WASM variant failed; see $e2e/build.log" >&2
  exit 1
}

node_path="$(cd "$(dirname "$(command -v playwright)")/.." && pwd)"
export NODE_PATH="$node_path${NODE_PATH:+:$NODE_PATH}"
export MATOME_E2E_SITE="$e2e/app/bin"
export MATOME_E2E_PRODUCT="$product"
# fakecore.sh builds FakeCore, then execs it: the suite starts (and, for
# 7.1, restarts) it through this.
export MATOME_E2E_FAKECORE="$root/.scripts/fakecore.sh"
export MATOME_E2E_LOGS="$e2e/logs"
rm -rf "$MATOME_E2E_LOGS"

exec node "$root/tests/e2e/web/run.cjs" "$@"
