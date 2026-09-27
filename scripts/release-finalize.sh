#!/usr/bin/env bash
# Tag and publish a merged Release Please pull request from the local machine.
set -euo pipefail

# shellcheck source=release-lib.sh
source "$(dirname "$0")/release-lib.sh"
release_preflight
release-please github-release \
  --token="$token" \
  --repo-url="$repo" \
  --target-branch=master \
  --config-file=release-please-config.json \
  --manifest-file=.release-please-manifest.json \
  "$@"
