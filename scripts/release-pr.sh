#!/usr/bin/env bash
# Create or update the Release Please pull request from the local machine.
set -euo pipefail

# shellcheck source=release-lib.sh
source "$(dirname "$0")/release-lib.sh"
release_preflight
release-please release-pr \
  --token="$token" \
  --repo-url="$repo" \
  --target-branch=master \
  --config-file=release-please-config.json \
  --manifest-file=.release-please-manifest.json \
  "$@"
