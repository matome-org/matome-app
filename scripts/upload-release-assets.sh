#!/usr/bin/env bash
set -euo pipefail

tag="${1:?release tag required}"
dist_dir="${2:?package directory required}"
repo="${GITHUB_REPOSITORY:?GitHub repository required}"
cd "$dist_dir"

for pattern in \
  "matome-web-$tag.tar.gz" \
  "matome-macos-universal-$tag.dmg" \
  "matome-windows-x86_64-$tag.exe" \
  "matome-linux-x86_64-$tag.AppImage" \
  "matome-android-arm64-$tag.apk"; do
  test -s "$pattern" || { echo "upload-release-assets: missing $pattern" >&2; exit 1; }
done

sha256sum matome-* > SHA256SUMS
gh release upload "$tag" matome-* SHA256SUMS --repo "$repo" --clobber

for old_name in \
  "matome-desktop-linux-x86_64-$tag.tar.gz" \
  "matome-android-emulator-x86_64-$tag.apk"; do
  if gh release view "$tag" --repo "$repo" --json assets \
      --jq '.assets[].name' | grep -Fxq "$old_name"; then
    gh release delete-asset "$tag" "$old_name" --repo "$repo" --yes
  fi
done
