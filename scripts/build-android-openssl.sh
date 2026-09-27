#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
abi="${MATOME_ANDROID_ABI:-x86_64}"
case "$abi" in
  x86_64) target=android-x86_64 ;;
  arm64-v8a) target=android-arm64 ;;
  *) echo "android-openssl: unsupported ABI: $abi" >&2; exit 1 ;;
esac

ndk="${ANDROID_NDK_ROOT:-${ANDROID_SDK_ROOT:-$HOME/.local/android-sdk}/ndk/27.2.12479018}"
toolchain="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
test -x "$toolchain/clang" || { echo "android-openssl: missing Android NDK" >&2; exit 1; }
export ANDROID_NDK_ROOT="$ndk" PATH="$toolchain:$PATH"

output="${MATOME_ANDROID_OPENSSL_DIR:-$root/build-android/openssl/$abi}"
crypto="$output/libcrypto_3.so"
ssl="$output/libssl_3.so"
stamp="$output/openssl-3.5.8.ready"
if [[ -f "$stamp" && -s "$crypto" && -s "$ssl" ]]; then
  echo "android-openssl: $output"
  exit 0
fi

version=3.5.8
checksum=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
archive="$output/openssl-$version.tar.gz"
source="$output/openssl-$version"
mkdir -p "$output"
if [[ ! -f "$archive" ]]; then
  curl -fsSL --retry 3 \
    "https://github.com/openssl/openssl/releases/download/openssl-$version/openssl-$version.tar.gz" \
    -o "$archive.tmp"
  mv "$archive.tmp" "$archive"
fi
if ! printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -; then
  rm -f "$archive"
  exit 1
fi
if [[ ! -f "$source/Configure" ]]; then
  tar -xf "$archive" -C "$output"
fi

cd "$source"
./Configure "$target" shared no-apps no-tests -D__ANDROID_API__=28
if ! make -s -j"$(nproc)" SHLIB_VERSION_NUMBER= build_libs >"$output/build.log" 2>&1; then
  tail -n 80 "$output/build.log" >&2
  exit 1
fi
cp libcrypto.so "$crypto"
cp libssl.so "$ssl"
mise -C "$root" exec -- patchelf --set-soname libcrypto_3.so "$crypto"
mise -C "$root" exec -- patchelf --set-soname libssl_3.so "$ssl"
mise -C "$root" exec -- patchelf --replace-needed libcrypto.so libcrypto_3.so "$ssl"
touch "$stamp"
echo "android-openssl: $output"
