#!/usr/bin/env bash
set -euo pipefail

port="${usage_port:-8080}"
if [[ ! "$port" =~ ^[0-9]{1,5}$ ]] || (( 10#$port < 1 || 10#$port > 65535 )); then
    echo "web-container-run: expected a port between 1 and 65535" >&2
    exit 2
fi
image="$(docker image inspect --format '{{.Id}}' matome-web:local)"
if docker container inspect matome-web-local >/dev/null 2>&1; then
    expected="true $image 127.0.0.1:$port"
    actual="$(docker inspect --format '{{index .Config.Labels "org.matome.local-web"}} {{.Image}} {{range (index .HostConfig.PortBindings "80/tcp")}}{{.HostIp}}:{{.HostPort}}{{end}}' matome-web-local)"
    if [[ "$actual" != "$expected" ]]; then
        echo "web-container-run: existing container has a different image, port, or owner" >&2
        echo "Run mise run web:container:stop before starting a new configuration" >&2
        exit 1
    fi
    docker start matome-web-local >/dev/null
    echo "Web container is running with these port bindings:"
    exec docker port matome-web-local
fi
docker run --detach --name matome-web-local \
    --label org.matome.local-web=true \
    --publish "127.0.0.1:$port:80" matome-web:local >/dev/null
echo "Matome web: http://localhost:$port"
