#!/usr/bin/env sh
set -eu

tag="${1:?release tag required}"
output="${2:?output directory required}"
if ! printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "fetch-web-release: expected a vX.Y.Z release tag" >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
base="https://github.com/matome-org/matome-app/releases/download/$tag"
cd "$work"
wget -q -O matome-web.tar.gz "$base/matome-web.tar.gz"
wget -q -O SHA256SUMS "$base/SHA256SUMS"
awk '$2 == "matome-web.tar.gz" { print; found++ }
     END { if (found != 1) exit 1 }' SHA256SUMS > web.sha256
sha256sum -c web.sha256
mkdir -p "$output"
tar -xzf matome-web.tar.gz -C "$output"
for asset in matome-studio.html matome-studio.js matome-studio.wasm qtloader.js; do
    test -s "$output/$asset"
done
