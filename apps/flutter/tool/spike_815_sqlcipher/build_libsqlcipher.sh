#!/usr/bin/env bash
# Spike #815 / task #1847 — reproducible build of a throwaway SQLCipher
# shared library for the Linux-desktop raw-DEK round-trip PoC
# (test/db/sqlcipher_native_spike_test.dart).
#
# This is NOT a production build recipe. It exists only to answer the go/no-go
# question for #815: "can a hand-rolled native connection actually key a real
# SQLCipher build with a raw DEK and round-trip data on this distro?"
#
# Why not just add `sqlcipher_flutter_libs` and build?
#   Its linux/CMakeLists.txt sets `OPENSSL_USE_STATIC_LIBS ON` by default and
#   `find_package(OpenSSL REQUIRED)`. Distros that ship OpenSSL as
#   shared-only (Arch: `pacman -Ql openssl` has no `.a` archives, only
#   libssl.so/libcrypto.so) fail that `find_package` call — this is the
#   collision documented in pubspec.yaml next to the (commented out)
#   `sqlcipher_flutter_libs` dependency. We deliberately build WITHOUT forcing
#   static OpenSSL to prove the hand-rolled path sidesteps that failure mode.
#
# Source: rather than downloading the SQLCipher amalgamation from network
# (blocked in this sandbox / not something to fetch from an unofficial host
# without the human's say-so), this script reuses the SQLCipher 4.7.0
# community amalgamation ALREADY VENDORED in this repo's own dependency tree:
# `node_modules/expo-sqlite/vendor/sqlcipher/sqlite3.c` (Expo's RN SQLite
# plugin ships it under an `exsqlite3_*` symbol prefix to avoid clashing with
# the system libsqlite3 inside a React Native app's process). We rename that
# prefix back to the standard `sqlite3_*` names so package:sqlite3's ffi
# bindings (which dlsym for `sqlite3_open`, `sqlite3_key`, etc.) can load it
# as a drop-in.
#
# Usage:
#   ./build_libsqlcipher.sh [output_dir]
#   MATOME_SQLCIPHER_POC_LIB="$(./build_libsqlcipher.sh)/libsqlcipher_poc.so" \
#     flutter test --tags native_spike --run-skipped \
#       test/db/sqlcipher_native_spike_test.dart
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VENDOR_SRC="$REPO_ROOT/node_modules/expo-sqlite/vendor/sqlcipher/sqlite3.c"
VENDOR_HDR="$REPO_ROOT/node_modules/expo-sqlite/vendor/sqlcipher/sqlite3.h"
OUT_DIR="${1:-$(mktemp -d /tmp/matome_sqlcipher_poc.XXXXXX)}"

if [[ ! -f "$VENDOR_SRC" ]]; then
  echo "error: vendored SQLCipher amalgamation not found at $VENDOR_SRC" >&2
  echo "       (run 'npm install' / 'bun install' at repo root first — this" >&2
  echo "       script does not fetch source over the network)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
sed 's/exsqlite3_/sqlite3_/g' "$VENDOR_SRC" > "$OUT_DIR/sqlite3.c"
sed 's/exsqlite3_/sqlite3_/g' "$VENDOR_HDR" > "$OUT_DIR/sqlite3.h"

gcc -shared -fPIC -O2 \
  -DSQLITE_HAS_CODEC \
  -DSQLITE_EXTRA_INIT=sqlcipher_extra_init \
  -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown \
  -DSQLITE_THREADSAFE=1 \
  -DSQLITE_TEMP_STORE=2 \
  -DHAVE_STDINT_H \
  -DSQLITE_ENABLE_FTS5 \
  "$OUT_DIR/sqlite3.c" -o "$OUT_DIR/libsqlcipher_poc.so" \
  -lcrypto

echo "built: $OUT_DIR/libsqlcipher_poc.so" >&2
echo "$OUT_DIR"
