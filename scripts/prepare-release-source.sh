#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?source directory required}"
tag="${2:?release tag required}"
automation_dir="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$tag" == v0.1.0 ]]; then
  cp "$automation_dir/qmake/layout.pri" "$source_dir/qmake/layout.pri"
  cp "$automation_dir/src/gui/gui.pro" "$source_dir/src/gui/gui.pro"
  cp "$automation_dir/src/gui/i18n/i18n.pri" "$source_dir/src/gui/i18n/i18n.pri"
fi
