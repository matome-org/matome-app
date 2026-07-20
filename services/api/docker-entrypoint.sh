#!/usr/bin/env bash
# Core API container entrypoint: wait for Postgres, create+migrate the DB, then
# boot Phoenix. Idempotent — safe on every `docker compose up`.
set -euo pipefail

echo "→ waiting for Postgres (${DATABASE_URL})..."
until pg_isready -d "${DATABASE_URL}" >/dev/null 2>&1; do
  sleep 1
done

echo "→ ecto.create + ecto.migrate"
mix ecto.create --quiet || true
mix ecto.migrate

echo "→ starting Phoenix on :4000 (ip ${PHX_HTTP_IP:-127.0.0.1})"
exec mix phx.server
