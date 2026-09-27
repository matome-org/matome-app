#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?source directory required}"
tag="${2:?release tag required}"
automation_dir="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$tag" == v0.1.0 ]]; then
  cp "$automation_dir/src/gui/gui.pro" "$source_dir/src/gui/gui.pro"
fi
