#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../.scripts/lib.sh"

test_env
desktop_env
run_suite core.pro tst_core core
