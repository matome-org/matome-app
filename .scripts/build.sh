#!/usr/bin/env bash
# Build matome-studio. Idempotent.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

desktop_env
qmake_build "$root/build" "$root/matome.pro"
echo "studio $root/build/bin/matome-studio"
