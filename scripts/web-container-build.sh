#!/usr/bin/env bash
set -euo pipefail

cd "${MISE_PROJECT_ROOT:?}"
args=()
if [[ "${usage_no_cache:-false}" == true ]]; then
    args+=(--no-cache)
fi
if [[ -n "${usage_release:-}" ]]; then
    if [[ ! "$usage_release" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "web-container-build: expected --release vX.Y.Z" >&2
        exit 2
    fi
    args+=(--build-arg "WEB_RELEASE=$usage_release")
fi
exec docker build "${args[@]}" --tag matome-web:local .
