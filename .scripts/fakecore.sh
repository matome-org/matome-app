#!/usr/bin/env bash
# Build FakeCore quietly and run it in the foreground: the e2e backend.
# Args pass through (--port N; 0 takes any free port; default 7011). The
# first stdout line is the readiness signal: "fakecore
# http://127.0.0.1:<port>". Control API under /__e2e/ (see tests/FakeCore.h).
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

qmake_build "$root/build-tests/fakecore" "$root/tests/fakecore.pro" >&2
exec "$root/build-tests/fakecore/fakecore" "$@"
