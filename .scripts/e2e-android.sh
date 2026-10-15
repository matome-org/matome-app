#!/usr/bin/env bash
# Mobile e2e: the native APK on Pixel_7_API_34, every Android scenario, each
# against a freshly seeded FakeCore that tests/e2e/android/run.py starts on a
# free port (the emulator reaches it as 10.0.2.2). The user's Core (7001) is
# never touched. Args filter scenarios: a cell (3.1), a section (3.), or a
# title word. Boots the emulator if none is running and shuts down only one
# it booted; the runner restores the device settings it changes.
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

test_env
android_env

# First, so its toolchain check runs before anything needs adb.
"$root/.scripts/android-build.sh" --test

emulator_pid=""
cleanup() {
  if [ -n "$emulator_pid" ]; then
    adb emu kill >/dev/null 2>&1 || true
    wait "$emulator_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! adb devices | grep -E 'emulator-[0-9]+[[:space:]]+device' >/dev/null; then
  echo "e2e-android: starting Pixel_7_API_34 (-gpu host)"
  "$root/.scripts/android-emulator.sh" >/tmp/matome-emulator.log 2>&1 &
  emulator_pid=$!
fi

# Up to three minutes for Android to finish booting; an emulator this script
# started that exits first fails the run with the end of its log.
deadline=$((SECONDS + 180))
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  if [ -n "$emulator_pid" ] && ! kill -0 "$emulator_pid" 2>/dev/null; then
    echo "e2e-android: the emulator exited; end of /tmp/matome-emulator.log:" >&2
    tail -n 5 /tmp/matome-emulator.log >&2
    exit 1
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "e2e-android: emulator did not finish booting" >&2
    exit 1
  fi
  sleep 2
done

"$root/.scripts/android-install.sh" "$root/build-tests/android-app/bin/matome-studio.apk"

# The runner imports FakeCore's driver from tests/e2e (fakecore.py).
PYTHONPATH="$root/tests/e2e${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$root/tests/e2e/android/run.py" "$root/.scripts/fakecore.sh" "$@"
echo "e2e-android ok"
