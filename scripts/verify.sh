#!/usr/bin/env bash
# Local gate shared by `mise run verify` and the pre-push hook.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

"$root/.scripts/qml-check.sh"
"$root/.scripts/i18n.sh" --check
exec "$root/.scripts/test.sh"
