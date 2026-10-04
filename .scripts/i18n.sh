#!/usr/bin/env bash
# Refresh the translation sources from every C++ and QML string; English, the
# source language, keeps only plural forms. With --check, refresh copies
# instead and fail while any string is untranslated.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

lupdate="$("$root/.scripts/linguist.sh")/lupdate"
sources=("$root"/src/gui/i18n/*.ts)
targets=("${sources[@]}")
english="$root/src/gui/i18n/matome_en.ts"

if [ "${1:-}" = "--check" ]; then
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT
  cp "${sources[@]}" "$scratch/"
  targets=("$scratch"/*.ts)
  english="$scratch/matome_en.ts"
fi

translated=()
for ts in "${targets[@]}"; do [ "$ts" = "$english" ] || translated+=("$ts"); done
options=(-silent -extensions cpp,h,qml,js -locations relative -no-obsolete "$root/src/gui")
"$lupdate" "${options[@]}" -ts "${translated[@]}"
"$lupdate" "${options[@]}" -pluralonly -source-language en -target-language en -ts "$english"

status=0
for ts in "${targets[@]}"; do
  unfinished="$(grep -c 'type="unfinished"' "$ts" || true)"
  total="$(grep -c '<message' "$ts" || true)"
  echo "$(basename "$ts"): $total strings, $unfinished unfinished"
  [ "$unfinished" -eq 0 ] || status=1
done
exit "$status"
