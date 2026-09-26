#!/usr/bin/env bash
# Check system build deps. Idempotent.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

missing=""
for tool in qmake6 g++ make; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
linguist="$("$root/.scripts/linguist.sh" 2>/dev/null)" || missing="$missing lupdate lrelease"
for header in QtCore/QCoreApplication QtQuick/QQuickWindow QtNetwork/QNetworkAccessManager QtTest/QTest; do
  ls /usr/include/qt6/$header >/dev/null 2>&1 || missing="$missing $header"
done

if [ -z "$missing" ]; then
  echo "all present — qt $(qmake6 -query QT_VERSION), $(g++ --version | head -1), linguist $linguist"
  exit 0
fi

echo "missing:$missing" >&2
echo >&2
echo "on Arch / Omarchy:" >&2
echo "  sudo pacman -S --needed qt6-base qt6-declarative qt6-tools gcc make" >&2
exit 1
