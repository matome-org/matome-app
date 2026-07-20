#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build/web_opfs_proof"
SERVER_LOG="${TMPDIR:-/tmp}/matome-opfs-proof-server.log"
DRIVER_LOG="${TMPDIR:-/tmp}/matome-opfs-proof-chromedriver.log"
BROWSER_LOG="${TMPDIR:-/tmp}/matome-opfs-proof-browser.json"
SERVER_PID=""
DRIVER_PID=""
SESSION_ID=""
EXIT_STATUS=0

tail_logs() {
  printf '%s\n' '--- last browser diagnostics ---' >&2
  printf '%s\n' "${LAST_DIAGNOSTICS:-not captured}" >&2
  printf '%s\n' '--- browser console/exceptions ---' >&2
  jq . "$BROWSER_LOG" >&2 2>/dev/null || true
  printf '%s\n' '--- web proof server log (tail) ---' >&2
  tail -n 80 "$SERVER_LOG" >&2 2>/dev/null || true
  printf '%s\n' '--- chromedriver log (tail) ---' >&2
  tail -n 120 "$DRIVER_LOG" >&2 2>/dev/null || true
}

stop_process() {
  local pid="$1"
  [[ -z "$pid" ]] && return
  kill "$pid" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    kill -0 "$pid" >/dev/null 2>&1 || {
      wait "$pid" >/dev/null 2>&1 || true
      return
    }
    sleep 0.1
  done
  kill -KILL "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
}

cleanup() {
  if [[ -n "$SESSION_ID" ]]; then
    curl --max-time 5 -fsS -X DELETE \
      "http://127.0.0.1:9515/session/$SESSION_ID" >/dev/null 2>&1 || true
  fi
  stop_process "$DRIVER_PID"
  stop_process "$SERVER_PID"
  if (( EXIT_STATUS != 0 )); then
    tail_logs
  fi
}
trap 'EXIT_STATUS=$?; cleanup; exit "$EXIT_STATUS"' EXIT

timeout 10m flutter build web \
  --target=tool/web_opfs_proof.dart \
  --no-web-resources-cdn \
  --output="$BUILD_DIR"

python -m http.server 7357 --bind 127.0.0.1 --directory "$BUILD_DIR" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
chromedriver --port=9515 --allowed-ips=127.0.0.1 >"$DRIVER_LOG" 2>&1 &
DRIVER_PID=$!

READY=false
for _ in {1..100}; do
  if curl --max-time 1 -fsS http://127.0.0.1:9515/status >/dev/null 2>&1 && \
      curl --max-time 1 -fsS http://127.0.0.1:7357/ >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 0.1
done
if [[ "$READY" != true ]]; then
  printf '%s\n' 'Server or chromedriver did not become ready' >&2
  exit 1
fi

SESSION_RESPONSE="$(curl --max-time 15 -fsS \
  -H 'Content-Type: application/json' \
  -d '{"capabilities":{"alwaysMatch":{"browserName":"chrome","goog:loggingPrefs":{"browser":"ALL"},"goog:chromeOptions":{"binary":"/usr/bin/chromium","args":["--headless=new","--no-sandbox","--disable-dev-shm-usage"]}}}}' \
  http://127.0.0.1:9515/session)"
SESSION_ID="$(jq -r '.value.sessionId' <<<"$SESSION_RESPONSE")"
if [[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]]; then
  jq . <<<"$SESSION_RESPONSE"
  exit 1
fi

curl --max-time 10 -fsS \
  -H 'Content-Type: application/json' \
  -d '{"url":"http://127.0.0.1:7357/"}' \
  "http://127.0.0.1:9515/session/$SESSION_ID/url" >/dev/null

RESULT=""
LAST_DIAGNOSTICS='{"phase":null,"readyState":null,"url":null}'
DEADLINE=$((SECONDS + 180))
while (( SECONDS < DEADLINE )); do
  if ! RESPONSE="$(curl --max-time 2 -fsS \
    -H 'Content-Type: application/json' \
    -d '{"script":"return {result: document.getElementById(\"result\")?.textContent ?? \"\", phase: document.getElementById(\"phase\")?.textContent ?? null, readyState: document.readyState, url: location.href};","args":[]}' \
    "http://127.0.0.1:9515/session/$SESSION_ID/execute/sync")"; then
    sleep 0.25
    continue
  fi
  LAST_DIAGNOSTICS="$(jq -c '.value' <<<"$RESPONSE")"
  RESULT="$(jq -r '.value.result' <<<"$RESPONSE")"
  if [[ -n "$RESULT" ]]; then
    break
  fi
  sleep 0.25
done

curl --max-time 5 -fsS \
  -H 'Content-Type: application/json' \
  -d '{"type":"browser"}' \
  "http://127.0.0.1:9515/session/$SESSION_ID/log" >"$BROWSER_LOG" || true

if [[ -z "$RESULT" ]]; then
  printf '%s\n' 'Timed out waiting for browser proof result' >&2
  exit 1
fi

jq . <<<"$RESULT"
jq -e '.status == "pass" and .reload == true and .secureContext == true' <<<"$RESULT" >/dev/null
chromium --version
