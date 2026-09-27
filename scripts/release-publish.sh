#!/usr/bin/env bash
# Dispatch GitHub-hosted package builds for an existing release tag.
set -euo pipefail

tag="${1:-}"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: mise run release:publish -- vX.Y.Z" >&2
  exit 2
fi

gh release view "$tag" --json tagName --jq .tagName >/dev/null
gh workflow run package-release.yml --ref master -f tag="$tag"
echo "Dispatched GitHub package builds for $tag"
