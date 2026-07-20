#!/usr/bin/env bash
set -euo pipefail

device="${1:-emulator-5554}"
package="com.matome.matome_flutter"
activity="$package/.MainActivity"
result_path="files/w5_android_restart/result.json"
apk="build/app/outputs/flutter-apk/app-debug.apk"

adb -s "$device" get-state >/dev/null
cleanup() {
  adb -s "$device" shell am force-stop "$package" >/dev/null 2>&1 || true
  adb -s "$device" shell pm clear "$package" >/dev/null 2>&1 || true
}
trap cleanup EXIT

timeout 300 flutter build apk --debug \
  --target=integration_test/native_vault_android_restart_harness.dart \
  --dart-define=MATOME_NATIVE_VAULT_RESTART_GATE=true
timeout 30 adb -s "$device" install -r "$apk" >/dev/null
adb -s "$device" shell pm clear "$package" >/dev/null
adb -s "$device" shell am start -W -n "$activity" >/dev/null

write_result=""
for _ in {1..90}; do
  write_result="$(adb -s "$device" shell run-as "$package" cat "$result_path" 2>/dev/null | tr -d '\r' || true)"
  if [[ "$write_result" == *'"phase":"failed"'* ]]; then
    printf 'write phase failed: %s\n' "$write_result" >&2
    exit 1
  fi
  if [[ "$write_result" == *'"phase":"write"'* && "$write_result" == *'"privateRoot":true'* ]]; then
    break
  fi
  sleep 1
done
if [[ ! $write_result =~ \"pid\":([0-9]+) ]]; then
  printf 'write phase timed out: %s\n' "$write_result" >&2
  exit 1
fi
writer_pid="${BASH_REMATCH[1]}"
live_writer_pid="$(adb -s "$device" shell pidof "$package" | tr -d '\r')"
if [[ "$live_writer_pid" != "$writer_pid" ]]; then
  printf 'writer PID mismatch: evidence=%s live=%s\n' "$writer_pid" "$live_writer_pid" >&2
  exit 1
fi
if [[ $write_result =~ \"sandboxToken\":\"([^\"]+)\" ]]; then
  sandbox_token="${BASH_REMATCH[1]}"
else
  printf 'write phase lacks sandbox token: %s\n' "$write_result" >&2
  exit 1
fi

adb -s "$device" shell am force-stop "$package"
for _ in {1..20}; do
  if [[ -z "$(adb -s "$device" shell pidof "$package" | tr -d '\r')" ]]; then
    break
  fi
  sleep 0.25
done
if [[ -n "$(adb -s "$device" shell pidof "$package" | tr -d '\r')" ]]; then
  printf 'writer process survived force-stop: %s\n' "$writer_pid" >&2
  exit 1
fi

adb -s "$device" shell am start -W -n "$activity" >/dev/null
read_result=""
for _ in {1..90}; do
  read_result="$(adb -s "$device" shell run-as "$package" cat "$result_path" 2>/dev/null | tr -d '\r' || true)"
  if [[ "$read_result" == *'"phase":"failed"'* ]]; then
    printf 'read phase failed: %s\n' "$read_result" >&2
    exit 1
  fi
  if [[ "$read_result" == *'"phase":"read"'* && "$read_result" == *'"reconciled":true'* ]]; then
    break
  fi
  sleep 1
done
if [[ ! $read_result =~ \"pid\":([0-9]+) ]]; then
  printf 'read phase timed out: %s\n' "$read_result" >&2
  exit 1
fi
reader_pid="${BASH_REMATCH[1]}"
live_reader_pid="$(adb -s "$device" shell pidof "$package" | tr -d '\r')"
if [[ "$reader_pid" == "$writer_pid" || "$live_reader_pid" != "$reader_pid" ]]; then
  printf 'reader PID mismatch: writer=%s evidence=%s live=%s\n' "$writer_pid" "$reader_pid" "$live_reader_pid" >&2
  exit 1
fi
if [[ "$read_result" != *"\"writerPid\":$writer_pid"* ||
      "$read_result" != *"\"sandboxToken\":\"$sandbox_token\""* ||
      "$read_result" != *'"orphanCount":0'* ||
      "$read_result" != *'"partialItemCount":0'* ||
      "$read_result" != *'"authenticatedKinds":["audio","image","document"]'* ||
      "$read_result" != *'"keepForeverPreserved":true'* ||
      "$read_result" != *'"deleteReconciled":true'* ||
      "$read_result" != *'"deleteIdempotent":true'* ]]; then
  printf 'restart evidence mismatch: write=%s read=%s\n' "$write_result" "$read_result" >&2
  exit 1
fi

printf 'Native Vault Android W6 restart gate passed\n'
printf 'writer_pid=%s reader_pid=%s\n' "$writer_pid" "$reader_pid"
printf 'write=%s\nread=%s\n' "$write_result" "$read_result"
