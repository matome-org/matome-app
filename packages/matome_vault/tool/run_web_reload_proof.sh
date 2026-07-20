#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${TMPDIR:-/tmp}/matome-vault-2146-web-proof"
SERVER_LOG="${TMPDIR:-/tmp}/matome-vault-2146-server.log"
DRIVER_LOG="${TMPDIR:-/tmp}/matome-vault-2146-driver.log"
SERVER_PID=""
DRIVER_PID=""
SESSION_ID=""

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
      "http://127.0.0.1:9516/session/$SESSION_ID" >/dev/null 2>&1 || true
  fi
  stop_process "$DRIVER_PID"
  stop_process "$SERVER_PID"
}
trap cleanup EXIT

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
timeout 3m dart compile js "$ROOT/tool/web_reload_proof.dart" \
  -o "$BUILD_DIR/main.dart.js"
cp "$ROOT/tool/web_reload_proof.html" "$BUILD_DIR/index.html"

python -m http.server 7358 --bind 127.0.0.1 --directory "$BUILD_DIR" \
  >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
chromedriver --port=9516 --allowed-ips=127.0.0.1 >"$DRIVER_LOG" 2>&1 &
DRIVER_PID=$!

for _ in {1..100}; do
  if curl --max-time 1 -fsS http://127.0.0.1:9516/status >/dev/null 2>&1 && \
      curl --max-time 1 -fsS http://127.0.0.1:7358/ >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

SESSION_RESPONSE="$(curl --max-time 15 -fsS \
  -H 'Content-Type: application/json' \
  -d '{"capabilities":{"alwaysMatch":{"browserName":"chrome","goog:chromeOptions":{"binary":"/usr/bin/chromium","args":["--headless=new","--no-sandbox","--disable-dev-shm-usage"]}}}}' \
  http://127.0.0.1:9516/session)"
SESSION_ID="$(jq -r '.value.sessionId' <<<"$SESSION_RESPONSE")"
[[ -n "$SESSION_ID" && "$SESSION_ID" != "null" ]]

curl --max-time 10 -fsS -H 'Content-Type: application/json' \
  -d '{"url":"http://127.0.0.1:7358/"}' \
  "http://127.0.0.1:9516/session/$SESSION_ID/url" >/dev/null

RESULT=""
DEADLINE=$((SECONDS + 120))
while (( SECONDS < DEADLINE )); do
  RESPONSE="$(curl --max-time 2 -fsS -H 'Content-Type: application/json' \
    -d '{"script":"return document.getElementById(\"result\")?.textContent ?? \"\";","args":[]}' \
    "http://127.0.0.1:9516/session/$SESSION_ID/execute/sync" || true)"
  if [[ -n "$RESPONSE" ]]; then
    RESULT="$(jq -r '.value // ""' <<<"$RESPONSE")"
  else
    RESULT=""
  fi
  [[ -n "$RESULT" ]] && break
  sleep 0.25
done

[[ -n "$RESULT" ]]
jq . <<<"$RESULT"
jq -e '.status == "pass" and .reload == true and .authenticatedRead == true and .preservedUntilExplicitDelete == true and .audioUrlRevoked == true and .imageUrlRevoked == true and .documentUrlRevoked == true and .deleteReconciled == true and .cleanup == true' \
  <<<"$RESULT" >/dev/null
chromium --version
