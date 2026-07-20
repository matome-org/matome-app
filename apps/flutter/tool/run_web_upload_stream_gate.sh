#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp="$(mktemp -d)"
server_pid=""
core_reconfigured=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
  fi
  if [[ -n "$core_reconfigured" ]]; then
    docker compose -f "$workspace_root/docker-compose.yml" \
      --project-directory "$workspace_root" up -d core >/dev/null 2>&1 || true
  fi
  rm -rf "$temp"
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$temp/key.pem" -out "$temp/cert.pem" -days 1 \
  -subj "/CN=127.0.0.1" >/dev/null 2>&1
fixture="$temp/live-fixture.json"
result="$temp/live-result.json"
WEB_UPLOAD_TEST_CERT="$temp/cert.pem" WEB_UPLOAD_TEST_KEY="$temp/key.pem" \
  WEB_UPLOAD_LIVE_FIXTURE="$fixture" WEB_UPLOAD_LIVE_RESULT="$result" \
  node "$root/tool/web_upload_stream_server.mjs" &
server_pid=$!
sleep 0.5

workspace_root="$(cd "$root/../.." && pwd)"
core_build=()
if [[ "${WEB_UPLOAD_SKIP_CORE_BUILD:-0}" != "1" ]]; then
  core_build=(--build)
fi
STORAGE_S3_ENDPOINT=https://127.0.0.1:17777 \
  docker compose -f "$workspace_root/docker-compose.yml" \
  --project-directory "$workspace_root" up -d "${core_build[@]}" core >/dev/null
core_reconfigured=1
until curl --fail --silent http://127.0.0.1:7001/health >/dev/null; do sleep 1; done

email="web-upload-$(date +%s)-$$@example.com"
auth="$(curl --fail --silent -H 'content-type: application/json' \
  -d "{\"email\":\"$email\",\"password\":\"correct horse battery staple\"}" \
  http://127.0.0.1:7001/api/auth/register)"
token="$(jq -r '.access_token' <<<"$auth")"
authorization="authorization: Bearer $token"
matome="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d '{"title":"Chromium Core MinIO gate"}' http://127.0.0.1:7001/api/matomes)"
matome_id="$(jq -r '.matome.id' <<<"$matome")"

checksum() {
  dd if=/dev/zero bs="$1" count=1 2>/dev/null | sha256sum | cut -d ' ' -f1
}
single_length=$((1024 * 1024))
whole_length=$((30 * 1024 * 1024))
part_one_length=$((16 * 1024 * 1024))
part_two_length=$((14 * 1024 * 1024))
single_checksum="$(checksum "$single_length")"
whole_checksum="$(checksum "$whole_length")"
part_one_checksum="$(checksum "$part_one_length")"
part_two_checksum="$(checksum "$part_two_length")"

single_created="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"client_id\":\"web-single-$$\",\"item_type\":\"file\",\"byte_size\":$single_length,\"media_type\":\"audio\",\"checksum_sha256\":\"$single_checksum\"}" \
  "http://127.0.0.1:7001/api/matomes/$matome_id/items")"
single_item_id="$(jq -r '.item.id' <<<"$single_created")"
single_upload="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"mode\":\"auto\",\"transport\":\"browser_stream\",\"checksum_sha256\":\"$single_checksum\"}" \
  "http://127.0.0.1:7001/api/v1/items/$single_item_id/uploads")"

multipart_created="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"client_id\":\"web-multipart-$$\",\"item_type\":\"file\",\"byte_size\":$whole_length,\"media_type\":\"audio\",\"checksum_sha256\":\"$whole_checksum\",\"transport\":\"browser_stream\"}" \
  "http://127.0.0.1:7001/api/matomes/$matome_id/items")"
multipart_upload_id="$(jq -r '.upload.upload_id' <<<"$multipart_created")"
part_one="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"checksum_sha256\":\"$part_one_checksum\"}" \
  "http://127.0.0.1:7001/api/v1/uploads/$multipart_upload_id/parts/1/presign")"
part_two="$(curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"checksum_sha256\":\"$part_two_checksum\"}" \
  "http://127.0.0.1:7001/api/v1/uploads/$multipart_upload_id/parts/2/presign")"

jq -n --argjson single "$single_upload" --argjson part_one "$part_one" \
  --argjson part_two "$part_two" --argjson single_length "$single_length" \
  --argjson part_one_length "$part_one_length" --argjson part_two_length "$part_two_length" \
  '{single: {request: $single.upload.request, length: $single_length}, parts: [{request: $part_one.part.request, length: $part_one_length}, {request: $part_two.part.request, length: $part_two_length}]}' \
  >"$fixture"

CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-$root/tool/chromium_upload_test.sh}" \
  dart test -p chrome --chain-stack-traces \
  "$root/tool/web_upload_stream_test.dart"

single_etag="$(jq -r '.single_etag' "$result")"
curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "{\"upload_generation\":1,\"etag\":\"$single_etag\",\"checksum_sha256\":\"$single_checksum\"}" \
  "http://127.0.0.1:7001/api/v1/uploads/item-$single_item_id-upload-1/complete" \
  | jq -e '.upload.state == "uploaded" and .upload.transport == "browser_stream"' >/dev/null

multipart_state="$(curl --fail --silent -H "$authorization" \
  "http://127.0.0.1:7001/api/v1/uploads/$multipart_upload_id")"
parts="$(jq '.upload.accepted_parts | map({part_number, etag, checksum_sha256})' <<<"$multipart_state")"
curl --fail --silent -H "$authorization" -H 'content-type: application/json' \
  -d "$(jq -n --arg checksum "$whole_checksum" --argjson parts "$parts" '{upload_generation: 1, checksum_sha256: $checksum, parts: $parts}')" \
  "http://127.0.0.1:7001/api/v1/uploads/$multipart_upload_id/complete" \
  | jq -e '.upload.state == "uploaded" and .upload.transport == "browser_stream"' >/dev/null
