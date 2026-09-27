#!/usr/bin/env bash
# Desktop e2e: the real QML window, offscreen, with keyboard and mouse; then
# the built matome-studio binary itself against FakeCore.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

desktop_env
run_suite studio.pro tst_studio studio

"$root/.scripts/build.sh" >/dev/null
qmake_build "$root/build-tests/probe" "$root/tests/probe/probe.pro" >/dev/null
python3 "$root/tests/e2e/smoke.py" "$root/build/bin/matome-studio" \
    "$root/.scripts/fakecore.sh" "$root/build-tests/probe/plugins"
