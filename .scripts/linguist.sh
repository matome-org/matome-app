#!/usr/bin/env bash
# Print the directory that holds lupdate and lrelease: the system Qt's, else
# the host Qt the WASM and Android builds use. Fails loudly without them.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
for dir in "$(qmake6 -query QT_HOST_BINS)" "$qt_host/bin"; do
  if [ -x "$dir/lupdate" ] && [ -x "$dir/lrelease" ]; then
    echo "$dir"
    exit 0
  fi
done

echo "missing: lupdate lrelease (Qt Linguist tools)" >&2
echo >&2
echo "on Arch / Omarchy:" >&2
echo "  sudo pacman -S --needed qt6-tools" >&2
exit 1
