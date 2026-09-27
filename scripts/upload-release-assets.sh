#!/usr/bin/env bash
set -euo pipefail

tag="${1:?release tag required}"
dist_dir="${2:?package directory required}"
repo="${GITHUB_REPOSITORY:?GitHub repository required}"
cd "$dist_dir"

for asset in \
  "matome-web-$tag.tar.gz:matome-web.tar.gz" \
  "matome-macos-universal-$tag.dmg:matome-macos-universal.dmg" \
  "matome-windows-x86_64-$tag.exe:matome-windows-x86_64.exe" \
  "matome-linux-x86_64-$tag.AppImage:matome-linux-x86_64.AppImage" \
  "matome-android-arm64-$tag.apk:matome-android-arm64.apk"; do
  versioned="${asset%%:*}"
  stable="${asset#*:}"
  test -s "$versioned" || { echo "upload-release-assets: missing $versioned" >&2; exit 1; }
  rm -f "$stable"
  ln "$versioned" "$stable"
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
