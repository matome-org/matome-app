#!/usr/bin/env bash
set -euo pipefail

if ! docker info >/dev/null; then
    exit 1
fi
if ! docker container inspect matome-web-local >/dev/null 2>&1; then
    exit 0
fi
owner="$(docker inspect --format '{{index .Config.Labels "org.matome.local-web"}}' matome-web-local)"
if [[ "$owner" != true ]]; then
    echo "web-container-stop: container is not owned by the local web tasks" >&2
    exit 1
fi
exec docker rm --force matome-web-local
