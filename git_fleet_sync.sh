#!/usr/bin/env bash
# Clone missing repos and fast-forward existing ones for the authenticated GitHub user.
# Usage: ./git_fleet_sync.sh [--forks] [--archived] [-j N]
set -euo pipefail

JOBS=8
FORKS=0
ARCHIVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --forks)    FORKS=1 ;;
    --archived) ARCHIVED=1 ;;
    -j)         JOBS="$2"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

OWNER="${OWNER:-$(gh api user -q .login)}"

FLAGS=()
(( FORKS ))    || FLAGS+=(--source)
(( ARCHIVED )) || FLAGS+=(--no-archived)

cd "$(dirname "$(readlink -f "$0")")"

sync_repo() {
  local repo="$1" owner="$2"
  if [[ ! -d "$repo/.git" ]]; then
    if gh repo clone "$owner/$repo" "$repo" -- --quiet 2>/dev/null; then
      echo "[cloned]  $repo"
    else
      echo "[ERROR]   $repo: clone failed"
    fi
    return
  fi
  if ! git -C "$repo" rev-parse -q --verify HEAD >/dev/null \
     && [[ -z "$(git -C "$repo" ls-remote --heads origin)" ]]; then
    echo "[empty]   $repo: no commits on GitHub yet"
    return
  fi
  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    echo "[skipped] $repo: uncommitted changes"
    return
  fi
  local before
  before=$(git -C "$repo" rev-parse -q --verify HEAD || true)
  if out=$(git -C "$repo" pull --ff-only --quiet 2>&1); then
    local ahead
    ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    if (( ahead > 0 )); then
      echo "[ahead]   $repo: $ahead unpushed commit(s)"
    elif [[ "$(git -C "$repo" rev-parse -q --verify HEAD || true)" != "$before" ]]; then
      echo "[updated] $repo"
    else
      echo "[ok]      $repo"
    fi
  else
    echo "[ERROR]   $repo: ${out%%$'\n'*}"
  fi
}
export -f sync_repo

gh repo list "$OWNER" --limit 1000 ${FLAGS[@]+"${FLAGS[@]}"} --json name -q '.[].name' \
  | xargs -P "$JOBS" -I{} bash -c 'sync_repo "$1" "$2"' _ {} "$OWNER" \
  | sort -k1,1 -s
