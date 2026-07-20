#!/usr/bin/env bash
# Local DEV Core entrypoint (docker-compose). Wait for Postgres, create +
# migrate the dev DB, then start Phoenix with `mix phx.server`. The prod
# release uses docker-entrypoint.prod.sh instead.
set -euo pipefail

if [ -n "${DATABASE_URL:-}" ]; then
  echo "→ waiting for Postgres..."
  until pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; do sleep 1; done
fi

echo "→ mix ecto.create (idempotent)"
mix ecto.create --quiet || true

echo "→ mix ecto.migrate"
mix ecto.migrate

echo "→ starting Core API (mix phx.server)"
exec mix phx.server
