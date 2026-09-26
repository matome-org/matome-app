#!/usr/bin/env bash
# Bootstrap a local Core account. Idempotent.
#
# Core has no seed user. This posts register (or login when the email
# already exists) and makes sure the signed-in identity owns an
# organization named "matome".
set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

base="${MATOME_URL:-http://localhost:7001}"
base="${base%/}"
email="${MATOME_BOOTSTRAP_EMAIL:-matome-admin@localhost}"
password="${MATOME_BOOTSTRAP_PASSWORD:-Matome67!}"
org_name="${MATOME_BOOTSTRAP_ORG:-matome}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "first-login: python3 is required to talk JSON to Core" >&2
  exit 1
fi

if ! curl -fsS --max-time 3 "$base/health" >/dev/null 2>&1; then
  echo "first-login: Core is not up at $base" >&2
  echo "  start it from matome-core: mise run backend" >&2
  exit 1
fi

export MATOME_BOOTSTRAP_BASE="$base"
export MATOME_BOOTSTRAP_EMAIL="$email"
export MATOME_BOOTSTRAP_PASSWORD="$password"
export MATOME_BOOTSTRAP_ORG="$org_name"

python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

base = os.environ["MATOME_BOOTSTRAP_BASE"]
email = os.environ["MATOME_BOOTSTRAP_EMAIL"]
password = os.environ["MATOME_BOOTSTRAP_PASSWORD"]
org_name = os.environ["MATOME_BOOTSTRAP_ORG"]


def request(method, path, body=None, headers=None, expected=()):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base + path,
        data=data,
        method=method,
        headers={"content-type": "application/json", **(headers or {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read()
            payload = json.loads(raw.decode()) if raw else {}
            return resp.status, payload
    except urllib.error.HTTPError as err:
        raw = err.read()
        try:
            payload = json.loads(raw.decode()) if raw else {}
        except json.JSONDecodeError:
            payload = {"error": raw.decode(errors="replace")}
        if expected and err.code in expected:
            return err.code, payload
        print(f"first-login: {method} {path} -> {err.code}", file=sys.stderr)
        print(json.dumps(payload, indent=2), file=sys.stderr)
        sys.exit(1)


status, auth = request(
    "POST",
    "/api/auth/register",
    {"email": email, "password": password},
    expected=(201, 422),
)
created_user = status == 201
if status == 422:
    status, auth = request(
        "POST",
        "/api/auth/login",
        {"email": email, "password": password},
        expected=(200, 401),
    )
    if status != 200:
        print(
            "first-login: that email exists, but the password does not match.",
            file=sys.stderr,
        )
        sys.exit(1)

token = auth["access_token"]
bearer = {"authorization": f"Bearer {token}"}

status, listing = request("GET", "/api/v1/organizations", headers=bearer)
orgs = listing.get("organizations") or listing.get("data") or []


def name_of(org):
    return str(org.get("name") or "").strip()


wanted = next((org for org in orgs if name_of(org) == org_name), None)
if wanted is None:
    default_name = f"{email.split('@', 1)[0]} organization"
    auto = next((org for org in orgs if name_of(org) == default_name), None)
    if created_user and auto is not None:
        headers = {
            **bearer,
            "if-match": str(auto.get("revision") or 1),
        }
        _, updated = request(
            "PATCH",
            f"/api/v1/organizations/{auto['id']}",
            {"name": org_name},
            headers=headers,
        )
        wanted = updated.get("organization") or updated.get("data") or auto
        wanted["name"] = org_name
    else:
        key = str(
            uuid.uuid5(uuid.NAMESPACE_URL, f"{base}|{email}|org|{org_name}")
        )
        _, created = request(
            "POST",
            "/api/v1/organizations",
            {"name": org_name},
            headers={**bearer, "idempotency-key": key},
        )
        wanted = created.get("organization") or created.get("data") or created

print(f"email    {email}")
print(f"password {password}")
print(f"org      {wanted.get('name')} ({wanted.get('id')})")
print(f"url      {base}")
PY
