#!/usr/bin/env bash
# Build all release assets from a tag locally and attach them to GitHub.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

tag="${1:-}"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: mise run release:publish -- vX.Y.Z" >&2
  exit 2
fi

if ! git diff --quiet HEAD --; then
  echo "release-publish: the working tree must be clean" >&2
  exit 1
fi

tag_sha="$(git rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null || true)"
if [[ -z "$tag_sha" || "$tag_sha" != "$(git rev-parse HEAD)" ]]; then
  echo "release-publish: check out the release tag $tag before building" >&2
  exit 1
fi

version="$(cat version.txt)"
if [[ "$tag" != "v$version" ]]; then
  echo "release-publish: version.txt ($version) does not match $tag" >&2
  exit 1
fi

gh release view "$tag" --json tagName --jq .tagName >/dev/null
mise run verify
mise run build
mise run wasm
mise run android

mkdir -p dist
web="matome-web-$tag.tar.gz"
desktop="matome-desktop-linux-x86_64-$tag.tar.gz"
android="matome-android-emulator-x86_64-$tag.apk"
license_files=(LICENSE src/gui/fonts/OFL-*.txt)

tar --dereference -czf "dist/$web" -C build-wasm/bin . -C "$root" "${license_files[@]}"
tar -czf "dist/$desktop" -C build/bin matome-studio -C "$root" "${license_files[@]}"
cp build-android/bin/matome-studio.apk "dist/$android"
(cd dist && sha256sum "$web" "$desktop" "$android" > SHA256SUMS)

gh release upload "$tag" "dist/$web" "dist/$desktop" "dist/$android" dist/SHA256SUMS --clobber
echo "Published web, Linux desktop, and Android emulator assets to $tag"
