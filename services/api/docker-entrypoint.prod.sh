#!/usr/bin/env bash
# Production Core entrypoint (OTP release). Migrate, then start with PHX_SERVER.
# Used by services/api/Dockerfile (Dockploy). Compose local stack uses Dockerfile.dev.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# In the image the release lives at /app; entrypoint is copied next to bin/.
if [ -x /app/bin/matome_api ]; then
  BIN=/app/bin/matome_api
elif [ -x "$ROOT/bin/matome_api" ]; then
  BIN="$ROOT/bin/matome_api"
else
  echo "✗ matome_api release binary not found" >&2
  exit 1
fi

if [ -n "${DATABASE_URL:-}" ]; then
  echo "→ waiting for Postgres..."
  # pg_isready may be absent in slim runner — best-effort TCP wait via bash.
  host_port="$(python3 - <<'PY' 2>/dev/null || true
import os, urllib.parse
u = urllib.parse.urlparse(os.environ["DATABASE_URL"])
print(f"{u.hostname}:{u.port or 5432}")
PY
)"
  if [ -n "$host_port" ] && command -v pg_isready >/dev/null 2>&1; then
    until pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; do sleep 1; done
  else
    sleep 2
  fi
fi

echo "→ MatomeApi.Release.migrate"
"$BIN" eval "MatomeApi.Release.migrate()"

echo "→ starting release (PHX_SERVER=true)"
export PHX_SERVER=true
exec "$BIN" start
