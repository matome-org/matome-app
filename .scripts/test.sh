#!/usr/bin/env bash
# Build and run the unit tests and the offscreen studio suite (keyboard, mouse,
# touch, and drag), then hold the sources to the coverage gate.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

test_env
desktop_env
run_suite core.pro tst_core core
run_suite studio.pro tst_studio studio
python3 "$root/.scripts/coverage.py" --min 90
