#!/usr/bin/env sh
set -eu

ENV_FILE="${AI_LIVE_ENV_FILE:-.env.live.local}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE; copy .env.live.example to .env.live.local." >&2
  exit 1
fi

set -a
. "./$ENV_FILE"
set +a

exec .venv/bin/pytest -m live_ai -q
