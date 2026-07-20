#!/usr/bin/env bash
set -euo pipefail

device="${1:-emulator-5554}"
package="com.matome.matome_flutter"
activity="$package/.MainActivity"
result_path="files/sqlcipher_android_restart/restart-result.json"
apk="build/app/outputs/flutter-apk/app-debug.apk"

adb -s "$device" get-state >/dev/null
flutter build apk --debug \
  --target=integration_test/sqlcipher_android_restart_harness.dart \
  --dart-define=MATOME_SQLCIPHER=true \
  --dart-define=MATOME_SQLCIPHER_RESTART_GATE=true
adb -s "$device" install -r "$apk" >/dev/null
adb -s "$device" shell pm clear "$package" >/dev/null
adb -s "$device" shell am start -n "$activity" >/dev/null

write_result=""
for _ in {1..60}; do
  write_result="$(adb -s "$device" shell run-as "$package" cat "$result_path" 2>/dev/null | tr -d '\r' || true)"
  if [[ "$write_result" == *'"phase":"failed"'* ]]; then
    printf 'write phase failed: %s\n' "$write_result" >&2
    exit 1
  fi
  if [[ "$write_result" == *'"phase":"write"'* && "$write_result" == *'"status":"ok"'* ]]; then
    break
  fi
  sleep 1
done
if [[ ! "$write_result" =~ \"pid\":([0-9]+) ]]; then
  printf 'write phase timed out or returned invalid evidence: %s\n' "$write_result" >&2
  exit 1
fi
writer_pid="${BASH_REMATCH[1]}"
if [[ "$write_result" =~ \"marker\":\"([^\"]+)\" ]]; then
  marker="${BASH_REMATCH[1]}"
else
  printf 'write phase omitted package marker\n' >&2
  exit 1
fi
live_pid="$(adb -s "$device" shell pidof "$package" | tr -d '\r')"
if [[ "$live_pid" != "$writer_pid" ]]; then
  printf 'writer PID mismatch: result=%s live=%s\n' "$writer_pid" "$live_pid" >&2
  exit 1
fi

adb -s "$device" shell am force-stop "$package"
if [[ -n "$(adb -s "$device" shell pidof "$package" | tr -d '\r')" ]]; then
  printf 'writer process survived am force-stop\n' >&2
  exit 1
fi
adb -s "$device" shell am start -n "$activity" >/dev/null

read_result=""
for _ in {1..60}; do
  read_result="$(adb -s "$device" shell run-as "$package" cat "$result_path" 2>/dev/null | tr -d '\r' || true)"
  if [[ "$read_result" == *'"phase":"failed"'* ]]; then
    printf 'read phase failed: %s\n' "$read_result" >&2
    exit 1
  fi
  if [[ "$read_result" == *'"phase":"read"'* && "$read_result" == *'"status":"ok"'* ]]; then
    break
  fi
  if [[ "$read_result" == *'"phase":"write"'* && "$read_result" =~ \"pid\":([0-9]+) && "${BASH_REMATCH[1]}" != "$writer_pid" ]]; then
    printf 'package data was recreated before read phase: %s\n' "$read_result" >&2
    exit 1
  fi
  sleep 1
done
if [[ ! "$read_result" =~ \"pid\":([0-9]+) ]]; then
  printf 'read phase timed out or returned invalid evidence: %s\n' "$read_result" >&2
  exit 1
fi
reader_pid="${BASH_REMATCH[1]}"
if [[ "$reader_pid" == "$writer_pid" || "$read_result" != *"\"writerPid\":$writer_pid"* || "$read_result" != *"\"marker\":\"$marker\""* ]]; then
  printf 'restart evidence mismatch: write=%s read=%s\n' "$write_result" "$read_result" >&2
  exit 1
fi

printf 'SQLCipher restart gate passed\nwrite=%s\nread=%s\n' "$write_result" "$read_result"
