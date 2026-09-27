#!/usr/bin/env bash
# local-check - run the local gate and tell GitHub it passed.
#
# The gate needs the local Qt toolchain. A pre-push hook runs it and the Commit
# Statuses API records the result on the exact commit that was checked.
#
#   scripts/local-check.sh                    gate HEAD, then post (HEAD must be pushed)
#   scripts/local-check.sh --pre-push         gate, and post once the push lands
#   scripts/local-check.sh --dry-run [...]    print the API calls instead
#
# Env:
#   MATOME_LOCAL_CHECK_SHA=<s>  same as --sha=
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

DRY_RUN=0
PRE_PUSH=0
SHA="${MATOME_LOCAL_CHECK_SHA:-}"
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --pre-push)  PRE_PUSH=1 ;;
    --sha=*)     SHA="${arg#--sha=}" ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      printf 'local-check: unknown arg: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$SHA" ]]; then
  SHA="$(git rev-parse HEAD)"
fi

CONTEXT="local-check"

post_status_now() {
  local state="$1" desc="$2"
  if (( DRY_RUN )); then
    printf '[dry-run] POST /repos/%s/statuses/%s state=%s context=%s desc=%q\n' \
      "$REPO_SLUG" "$SHA" "$state" "$CONTEXT" "$desc"
    return 0
  fi
  gh api --silent -X POST "repos/$REPO_SLUG/statuses/$SHA" \
    -f "state=$state" -f "context=$CONTEXT" -f "description=$desc"
}

# The hook runs before the push, so the commit is not on GitHub yet and a
# status posted now would be refused. A detached poller posts it once the
# commit can be read there, and gives up after a minute.
post_status_when_reachable() {
  local state="$1" desc="$2"
  if (( DRY_RUN )); then
    printf '[dry-run] background-poll until SHA reachable, then POST /repos/%s/statuses/%s state=%s\n' \
      "$REPO_SLUG" "$SHA" "$state"
    return 0
  fi
  setsid nohup bash -c '
    slug="$1"; sha="$2"; state="$3"; ctx="$4"; desc="$5"
    for _ in $(seq 1 60); do
      if gh api -X GET "repos/$slug/commits/$sha" --silent >/dev/null 2>&1; then
        gh api --silent -X POST "repos/$slug/statuses/$sha" \
          -f "state=$state" -f "context=$ctx" -f "description=$desc"
        exit 0
      fi
      sleep 1
    done
  ' bash "$REPO_SLUG" "$SHA" "$state" "$CONTEXT" "$desc" \
    </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

if ! REPO_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"; then
  printf 'local-check: gh authentication and a reachable GitHub repository are required\n' >&2
  exit 1
fi

# The gate runs on the working tree, so the status is only true of the commit
# being pushed when the two are the same tree.
if [[ "$(git rev-parse HEAD)" != "$SHA" ]] || ! git diff --quiet HEAD --; then
  printf 'local-check: %s is not the clean HEAD, and the gate can only vouch for the\n' "${SHA:0:7}" >&2
  printf '             tree it runs on. Check it out with nothing changed.\n' >&2
  exit 1
fi

if (( ! PRE_PUSH )); then
  post_status_now pending "scripts/verify.sh - running locally"
fi

start="$(date +%s)"
rc=0
if (( DRY_RUN )); then
  printf '[dry-run] would run: scripts/verify.sh\n'
else
  scripts/verify.sh || rc=$?
fi
elapsed=$(( $(date +%s) - start ))

if (( rc == 0 )); then
  state=success
  desc="scripts/verify.sh - passed in ${elapsed}s"
else
  state=failure
  desc="scripts/verify.sh - failed (rc=$rc) after ${elapsed}s"
fi

if (( PRE_PUSH )); then
  if (( rc != 0 )); then
    printf 'local-check: %s - the push is refused.\n' "$desc" >&2
    exit "$rc"
  fi
  post_status_when_reachable "$state" "$desc"
  exit 0
fi

post_status_now "$state" "$desc"
exit "$rc"
