#!/usr/bin/env bash
# Push the local-server environment into the Dokploy compose service.
#   ./.scripts/push-dokploy-env.sh --dry-run   # show what would change
#   ./.scripts/push-dokploy-env.sh             # update, then rebuild
#   ./.scripts/push-dokploy-env.sh --pull      # seed the local file from Dokploy
#
# Dokploy keeps the environment in its own database, so `git push` rebuilds the
# code but never touches the variables. This closes that gap.
#
# Connection settings come from .env.dokploy.local (DOKPLOY_URL, DOKPLOY_TOKEN,
# DOKPLOY_COMPOSE_ID). The app environment comes from .env.localserver.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${CONN_FILE:-$ROOT/.env.dokploy.local}"
ENV_FILE="${ENV_FILE:-$ROOT/.env.localserver}"
DRY_RUN=0
PULL=0
DEPLOY=1
ROTATE=0
PRUNE_LIST=""

# HOST_IP now drives these in docker-compose.localserver.yml. A stale copy left
# in Dokploy would silently win over the derived value and pin the old address.
DERIVED_KEYS="API_BASE_URL,CORS_ORIGINS,STORAGE_S3_ENDPOINT,DATABASE_URL"

usage() {
  sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --pull) PULL=1 ;;
    --no-deploy) DEPLOY=0 ;;
    --rotate-secrets) ROTATE=1 ;;
    --prune-derived) PRUNE_LIST="${PRUNE_LIST:+$PRUNE_LIST,}$DERIVED_KEYS" ;;
    --prune=*) PRUNE_LIST="${PRUNE_LIST:+$PRUNE_LIST,}${arg#--prune=}" ;;
    --file=*) ENV_FILE="${arg#--file=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required" >&2; exit 1; }
done

[ -f "$CONN_FILE" ] || { echo "missing $CONN_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
set -a; . "$CONN_FILE"; set +a
for var in DOKPLOY_URL DOKPLOY_TOKEN DOKPLOY_COMPOSE_ID; do
  [ -n "${!var:-}" ] || { echo "$var is empty in $CONN_FILE" >&2; exit 1; }
done
DOKPLOY_URL="${DOKPLOY_URL%/}"

api_get() {
  curl -sS -f -m 30 -H "x-api-key: $DOKPLOY_TOKEN" "$DOKPLOY_URL/api/$1"
}

api_post() {
  curl -sS -f -m 300 -X POST \
    -H "x-api-key: $DOKPLOY_TOKEN" \
    -H 'Content-Type: application/json' \
    --data-binary @- \
    "$DOKPLOY_URL/api/$1"
}

remote_env() {
  api_get "compose.one?composeId=$DOKPLOY_COMPOSE_ID" | jq -r '.env // ""'
}

# Anything credential-shaped is never printed and never overwritten silently.
is_secret() {
  case "$1" in
    *PASSWORD*|*SECRET*|*TOKEN*|*PEPPER*|*_KEY|*_KEY_ID) return 0 ;;
    *) return 1 ;;
  esac
}

REMOTE="$(remote_env)"

if [ "$PULL" -eq 1 ]; then
  if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$ENV_FILE.bak"
    echo "backed up $ENV_FILE -> $ENV_FILE.bak" >&2
  fi
  printf '%s\n' "$REMOTE" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "pulled $(printf '%s\n' "$REMOTE" | grep -cE '^[A-Za-z_][A-Za-z0-9_]*=') keys into $ENV_FILE" >&2
  exit 0
fi

[ -f "$ENV_FILE" ] || {
  echo "missing $ENV_FILE — run: mise run localserver:env" >&2
  exit 1
}

declare -A LOCAL_VAL=() REMOTE_VAL=() PRUNED=() EMITTED=()
LOCAL_ORDER=()

while IFS= read -r line; do
  [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
  key="${BASH_REMATCH[1]}"
  [ -n "${LOCAL_VAL[$key]+x}" ] || LOCAL_ORDER+=("$key")
  LOCAL_VAL[$key]="${BASH_REMATCH[2]}"
done < "$ENV_FILE"

while IFS= read -r line; do
  [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
  REMOTE_VAL[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
done <<< "$REMOTE"

IFS=',' read -r -a prune_keys <<< "$PRUNE_LIST"
for key in "${prune_keys[@]}"; do
  [ -n "$key" ] && PRUNED[$key]=1
done

# compose.update replaces the whole env field, so the remote body is rebuilt
# line by line — comments and key order survive, and keys that only exist in
# Dokploy are carried over instead of being wiped.
MERGED=""
while IFS= read -r line; do
  if [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
    key="${BASH_REMATCH[1]}"
    [ -n "${PRUNED[$key]+x}" ] && continue
    if [ -n "${LOCAL_VAL[$key]+x}" ]; then
      MERGED+="$key=${LOCAL_VAL[$key]}"$'\n'
      EMITTED[$key]=1
      continue
    fi
  fi
  MERGED+="$line"$'\n'
done <<< "$REMOTE"

for key in "${LOCAL_ORDER[@]}"; do
  [ -n "${EMITTED[$key]+x}" ] && continue
  [ -n "${PRUNED[$key]+x}" ] && continue
  MERGED+="$key=${LOCAL_VAL[$key]}"$'\n'
done

changed_secrets=()
changes=0
for key in "${LOCAL_ORDER[@]}"; do
  [ -n "${PRUNED[$key]+x}" ] && continue
  if [ -z "${REMOTE_VAL[$key]+x}" ]; then
    changes=$((changes + 1))
    if is_secret "$key"; then
      echo "+ add     $key"
    else
      echo "+ add     $key=${LOCAL_VAL[$key]}"
    fi
  elif [ "${REMOTE_VAL[$key]}" != "${LOCAL_VAL[$key]}" ]; then
    changes=$((changes + 1))
    if is_secret "$key"; then
      echo "~ change  $key (secret)"
      changed_secrets+=("$key")
    else
      echo "~ change  $key: ${REMOTE_VAL[$key]} -> ${LOCAL_VAL[$key]}"
    fi
  fi
done

for key in "${!PRUNED[@]}"; do
  if [ -n "${REMOTE_VAL[$key]+x}" ]; then
    changes=$((changes + 1))
    echo "- prune   $key"
  fi
done

if [ "$changes" -eq 0 ]; then
  echo "Dokploy already matches $ENV_FILE — nothing to push"
  exit 0
fi

# Rotating a secret against a live stack is destructive: Postgres keeps the
# password baked into its initialized data volume, and MinIO keeps its root
# credentials, so a new value locks the running services out of their data.
if [ "${#changed_secrets[@]}" -gt 0 ] && [ "$ROTATE" -eq 0 ]; then
  echo "" >&2
  echo "refusing to change ${#changed_secrets[@]} secret(s) already set in Dokploy:" >&2
  printf '  %s\n' "${changed_secrets[@]}" >&2
  echo "the running Postgres/MinIO volumes were initialized with the old values." >&2
  echo "keep them: ./.scripts/push-dokploy-env.sh --pull   (then re-run)" >&2
  echo "rotate anyway (wipes access to existing data): --rotate-secrets" >&2
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "dry run — nothing sent"
  exit 0
fi

echo ""
echo "→ compose.update"
jq -n --arg id "$DOKPLOY_COMPOSE_ID" --arg env "$MERGED" '{composeId: $id, env: $env}' |
  api_post compose.update > /dev/null

if [ "$(remote_env)" != "$MERGED" ]; then
  echo "compose.update did not persist the expected environment" >&2
  exit 1
fi
echo "✓ environment stored"

if [ "$DEPLOY" -eq 0 ]; then
  echo "skipped deploy — the new values apply on the next one"
  exit 0
fi

# API_BASE_URL is a build arg for the Flutter web bundle, so a redeploy of the
# existing image would keep serving the old address. Always rebuild.
echo "→ compose.deploy (rebuild)"
jq -n --arg id "$DOKPLOY_COMPOSE_ID" '{composeId: $id}' |
  api_post compose.deploy > /dev/null
echo "✓ deploy triggered — follow it in the Dokploy dashboard"
