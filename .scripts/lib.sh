# Sourced by the other scripts, never run on its own: the repo root (the
# working directory from here on), the toolchain paths, and the build steps
# they share.
# shellcheck shell=bash

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
jobs="$(nproc 2>/dev/null || echo 1)"

qt_home="$HOME/.local/Qt/6.11.2"
qt_host="${QT_HOST:-$qt_home/gcc_64}"
qt_wasm="${QT_WASM:-$qt_home/wasm_singlethread}"
qt_android="${QT_ANDROID:-$qt_home/android_x86_64}"
emsdk="${EMSDK:-$HOME/.local/emsdk}"
sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/.local/android-sdk}}"
ndk="${ANDROID_NDK_ROOT:-$sdk/ndk/27.2.12479018}"
java_home="${JAVA_HOME:-$HOME/.local/share/mise/installs/java/openjdk-17.0.2}"

# The qmake qmake_build runs: the system Qt's unless wasm_env picks another.
qmake="qmake6"

# qmake_build <dir> <project.pro> [qmake args...]: configures and makes <dir>.
qmake_build() {
  local dir="$1"
  shift
  mkdir -p "$dir"
  (cd "$dir" && "$qmake" "$@" && make -j"$jobs")
}

# run_suite <tests project.pro> <binary> <build-tests subdir>: builds a test
# suite and runs it offscreen.
run_suite() {
  local dir="$root/build-tests/$3"
  qmake_build "$dir" "$root/tests/$1"
  (cd "$dir" && QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= "./$2")
}

# The system Qt, with Linguist's lrelease for the translations.
desktop_env() {
  "$root/.scripts/deps.sh" >/dev/null
  MATOME_LRELEASE="$("$root/.scripts/linguist.sh")/lrelease"
  export MATOME_LRELEASE
}

# Emscripten, and the WASM Qt's qmake for qmake_build.
wasm_env() {
  "$root/.scripts/wasm-deps.sh" >/dev/null
  # shellcheck disable=SC1091
  source "$emsdk/emsdk_env.sh"
  qmake="$qt_wasm/bin/qmake"
}

# The Android SDK, NDK, JDK, and AVDs, exported with adb and java on PATH.
android_env() {
  export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk" ANDROID_NDK_ROOT="$ndk" JAVA_HOME="$java_home"
  export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.config/.android/avd}"
  export PATH="$java_home/bin:$sdk/platform-tools:$PATH"
}

test_env() {
  local file="$root/tests/.env"
  [ -f "$file" ] || file="$root/tests/.env.example"
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
  case "${MATOME_TEST_DEFAULT_SERVER:-}" in
    http://localhost:*|http://127.0.0.1:*|http://10.0.2.2:*) ;;
    *) echo "test_env: MATOME_TEST_DEFAULT_SERVER must use a local test host" >&2; return 1 ;;
  esac
}
