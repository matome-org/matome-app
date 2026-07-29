#!/usr/bin/env bash
# Fill in a deploy environment from its *.example scaffold.
#   ./.scripts/gen-deploy-env.sh                      # .env.localserver
#   ./.scripts/gen-deploy-env.sh --stack=production   # .env.production
#   ./.scripts/gen-deploy-env.sh --print              # also dump it for Dokploy
#
# Idempotent: an existing real value is never touched, so re-running only fills
# what is missing or still holds a CHANGE_ME placeholder. Keys absent from the
# file are seeded from the scaffold, comments and ordering included.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK=localserver
ENV_FILE="${ENV_FILE:-}"
PRINT=0

usage() {
  sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Progress goes to stderr so `--print` leaves stdout as a clean env dump that
# can be piped straight into the Dokploy API.
report() {
  echo "$1" >&2
}

for arg in "$@"; do
  case "$arg" in
    --print) PRINT=1 ;;
    --stack=*) STACK="${arg#--stack=}" ;;
    --file=*) ENV_FILE="${arg#--file=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# The generated secrets are hex, so they stay safe inside DATABASE_URL without
# any percent-encoding. SECRET_KEY_BASE is the one that needs 64 bytes.
case "$STACK" in
  localserver)
    DEFAULT_FILE="$ROOT/.env.localserver"
    EXAMPLE_FILE="$ROOT/.env.localserver.example"
    COMPOSE_FILE="$ROOT/docker-compose.localserver.yml"
    HOST_KEY=HOST_IP
    SECRET_KEYS=(
      POSTGRES_PASSWORD
      GUARDIAN_SECRET_KEY
      ADMIN_OTP_PEPPER
      STORAGE_S3_SECRET_ACCESS_KEY
      AI_ENGINE_DISPATCH_TOKEN
      AI_ENGINE_CALLBACK_SIGNING_SECRET
    )
    ;;
  production)
    DEFAULT_FILE="$ROOT/.env.production"
    EXAMPLE_FILE="$ROOT/.env.production.example"
    COMPOSE_FILE="$ROOT/docker-compose.production.yml"
    HOST_KEY=BASE_DOMAIN
    SECRET_KEYS=(
      POSTGRES_PASSWORD
      SECRET_KEY_BASE
      GUARDIAN_SECRET_KEY
      ADMIN_OTP_PEPPER
      STORAGE_S3_SECRET_ACCESS_KEY
      AI_ENGINE_DISPATCH_TOKEN
      AI_ENGINE_CALLBACK_SIGNING_SECRET
    )
    ;;
  *)
    echo "unknown stack: $STACK (expected localserver or production)" >&2
    exit 2
    ;;
esac
ENV_FILE="${ENV_FILE:-$DEFAULT_FILE}"

command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to generate secrets" >&2
  exit 1
}

current_value() {
  KEY="$1" awk -F= '
    BEGIN { key = ENVIRON["KEY"] }
    index($0, key "=") == 1 { sub("^" key "=", ""); print; exit }
  ' "$ENV_FILE"
}

# A CHANGE_ME placeholder counts as missing, so a file copied straight from the
# scaffold is completed rather than rejected.
has_value() {
  local value
  value="$(current_value "$1")"
  [ -n "$value" ] && [ "${value#CHANGE_ME}" = "$value" ]
}

set_key() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp "$ENV_FILE.XXXXXX")"
  chmod 600 "$tmp"
  KEY="$key" VALUE="$value" awk '
    BEGIN { key = ENVIRON["KEY"]; value = ENVIRON["VALUE"]; written = 0 }
    index($0, key "=") == 1 && !written { print key "=" value; written = 1; next }
    { print }
    END { if (!written) print key "=" value }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

detect_host_ip() {
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null |
      awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')"
  fi
  if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
  fi
  printf '%s' "$ip"
}

mask() {
  local value="$1"
  if [ "${#value}" -le 8 ]; then
    printf '%s' "$value"
  else
    printf '%s…' "${value:0:6}"
  fi
}

[ -f "$EXAMPLE_FILE" ] || { echo "missing $EXAMPLE_FILE" >&2; exit 1; }

if [ ! -f "$ENV_FILE" ]; then
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  report "created $ENV_FILE from $(basename "$EXAMPLE_FILE")"
fi
chmod 600 "$ENV_FILE"

# A file pulled from a running deployment predates whatever the scaffold gained
# since, so anything it lacks is copied over before the secrets are filled.
while IFS= read -r line; do
  [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]] || continue
  key="${BASH_REMATCH[1]}"
  grep -q "^$key=" "$ENV_FILE" && continue
  printf '%s\n' "$line" >> "$ENV_FILE"
  report "+ seeded    $key"
done < "$EXAMPLE_FILE"

# The local stack can find its own LAN address; a public domain has to be told.
if has_value "$HOST_KEY"; then
  report "= kept      $HOST_KEY=$(current_value "$HOST_KEY")"
else
  host_value="${!HOST_KEY:-}"
  if [ -z "$host_value" ] && [ "$HOST_KEY" = HOST_IP ]; then
    host_value="$(detect_host_ip)"
  fi
  if [ -z "$host_value" ] || [ "$host_value" = "127.0.0.1" ]; then
    echo "$HOST_KEY has no usable value" >&2
    echo "re-run with it set explicitly: $HOST_KEY=... $0 --stack=$STACK" >&2
    exit 1
  fi
  set_key "$HOST_KEY" "$host_value"
  report "+ generated $HOST_KEY=$host_value"
fi

for key in "${SECRET_KEYS[@]}"; do
  if has_value "$key"; then
    report "= kept      $key=$(mask "$(current_value "$key")")"
  else
    case "$key" in
      SECRET_KEY_BASE) bytes=64 ;;
      *) bytes=32 ;;
    esac
    set_key "$key" "$(openssl rand -hex "$bytes")"
    report "+ generated $key=$(mask "$(current_value "$key")")"
  fi
done

# Core signs callbacks with one secret and authenticates dispatch with the
# other, so a shared value would let either side forge the opposite direction.
if [ "$(current_value AI_ENGINE_DISPATCH_TOKEN)" = "$(current_value AI_ENGINE_CALLBACK_SIGNING_SECRET)" ]; then
  echo "AI_ENGINE_DISPATCH_TOKEN and AI_ENGINE_CALLBACK_SIGNING_SECRET must differ" >&2
  echo "clear one of them in $ENV_FILE and re-run" >&2
  exit 1
fi

# Whatever is left is a human decision — an SMTP relay, a chat model. Compose
# still renders with the placeholders, so this warns instead of failing, and
# push-dokploy-env.sh refuses to ship them.
leftover="$(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=CHANGE_ME/ { print $1 }' "$ENV_FILE")"
if [ -n "$leftover" ]; then
  report ""
  report "still needs a real value in $ENV_FILE:"
  while IFS= read -r key; do report "  $key"; done <<< "$leftover"
  report ""
fi

if command -v docker >/dev/null 2>&1 && [ -f "$COMPOSE_FILE" ]; then
  if docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config -q 2>/dev/null; then
    report "compose renders with this environment"
  else
    echo "compose could not render — run for the full error:" >&2
    echo "  docker compose --env-file $ENV_FILE -f $COMPOSE_FILE config" >&2
    exit 1
  fi
fi

if [ "$PRINT" -eq 1 ]; then
  report "--- $ENV_FILE (contains secrets) ---"
  cat "$ENV_FILE"
fi
