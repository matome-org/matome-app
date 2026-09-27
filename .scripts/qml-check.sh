#!/usr/bin/env bash
# Lint all QML recursively, with every warning fatal.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

lint="/usr/lib/qt6/bin/qmllint"
if [ ! -x "$lint" ]; then
    lint="$(command -v qmllint || true)"
fi
if [ -z "$lint" ]; then
    echo "qml-check: no qmllint found (qt6-declarative ships it)" >&2
    exit 1
fi

"$root/.scripts/build.sh" >/dev/null

types="$root/build/src/gui/matome-studio.qmltypes"
if [ ! -f "$types" ]; then
    echo "qml-check: $types is missing; the build should have written it" >&2
    exit 1
fi

imports="$(mktemp -d)"
trap 'rm -rf "$imports"' EXIT
mkdir -p "$imports/matome"
cp "$types" "$imports/matome/"
cat > "$imports/matome/qmldir" <<EOF
module matome
typeinfo $(basename "$types")
depends QtQuick
depends QtCore
depends QtQml.Models
EOF

mapfile -t qml_files < <(find "$root/src/gui/qml" -name '*.qml' | sort)
if [ "${#qml_files[@]}" -eq 0 ]; then
    echo "qml-check: no QML files found under src/gui/qml" >&2
    exit 1
fi

exec "$lint" --max-warnings 0 -I "$imports" -I "$root/src/gui/qml" "${qml_files[@]}"
