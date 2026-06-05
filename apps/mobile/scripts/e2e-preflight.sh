#!/usr/bin/env sh
set -eu

mode="${1:-all}"

fail() {
  printf '%s\n' "x $*" >&2
  exit 1
}

is_local_url() {
  case "${1:-}" in
    http://localhost:*|http://localhost/*|http://localhost|\
    http://127.0.0.1:*|http://127.0.0.1/*|http://127.0.0.1|\
    http://0.0.0.0:*|http://0.0.0.0/*|http://0.0.0.0|\
    http://10.0.2.2:*|http://10.0.2.2/*|http://10.0.2.2|\
    http://*.local:*|http://*.local/*|http://*.local)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if ! command -v maestro >/dev/null 2>&1; then
  fail 'maestro not found. Install it before claiming E2E device validation.'
fi

case "$mode" in
  smoke)
    exit 0
    ;;
  all|recording)
    ;;
  *)
    fail "unknown e2e preflight mode: $mode"
    ;;
esac

if [ -f .env.local ]; then
  # shellcheck disable=SC1091
  . ./.env.local
fi

supabase_url="${EXPO_PUBLIC_SUPABASE_URL:-}"
transcribe_url="${EXPO_PUBLIC_TRANSCRIBE_API_URL:-}"

if ! is_local_url "$supabase_url"; then
  fail "EXPO_PUBLIC_SUPABASE_URL must point at local Supabase before recording E2E, got '${supabase_url:-unset}'."
fi

if ! is_local_url "$transcribe_url"; then
  fail "EXPO_PUBLIC_TRANSCRIBE_API_URL must point at a local transcription stub before recording E2E, got '${transcribe_url:-unset}'."
fi

if [ "${MATOME_E2E_AUTH_READY:-}" != "local-seeded" ]; then
  fail "deterministic local auth is not confirmed. Seed/login a local test user, then rerun with MATOME_E2E_AUTH_READY=local-seeded."
fi

printf '%s\n' 'E2E preflight passed: Maestro present, local Supabase/stub URLs configured, local auth confirmed.'
