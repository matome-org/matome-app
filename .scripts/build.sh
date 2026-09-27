#!/usr/bin/env bash
# Build matome-studio. Idempotent.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

desktop_env
if [ "${1:-}" = --test ]; then
  test_env
  export MATOME_TEST_BUILD=1
  qmake_build "$root/build-tests/desktop-app" "$root/matome.pro" CONFIG+=matome_test
  echo "studio $root/build-tests/desktop-app/bin/matome-studio"
else
  qmake_build "$root/build" "$root/matome.pro"
  echo "studio $root/build/bin/matome-studio"
fi
