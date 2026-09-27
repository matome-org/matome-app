#!/usr/bin/env bash
# Shared preflight for local Release Please commands.
release_preflight() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  cd "$root"

  if [[ "$(git branch --show-current)" != master ]] || ! git diff --quiet HEAD --; then
    echo "release: use a clean master checkout" >&2
    exit 1
  fi

  git fetch origin master
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/master)" ]]; then
    echo "release: pull the latest master before continuing" >&2
    exit 1
  fi

  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  token="$(gh auth token)"
}
