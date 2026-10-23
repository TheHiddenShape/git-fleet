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

# Most relevant line of a git error output: the first fatal/error line, else the first line.
git_error() {
  grep -m1 -E '^(fatal|error|ERROR):' <<<"$1" || head -n1 <<<"$1"
}

sync_repo() {
  local repo="$1" owner="$2" out
  if [[ ! -d "$repo/.git" ]]; then
    if out=$(gh repo clone "$owner/$repo" "$repo" -- --quiet 2>&1); then
      echo "[cloned]   $repo"
    else
      echo "[ERROR]    $repo: clone failed: $(git_error "$out")"
    fi
    return
  fi
  if ! git -C "$repo" rev-parse -q --verify HEAD >/dev/null \
     && [[ -z "$(git -C "$repo" ls-remote --heads origin)" ]]; then
    echo "[empty]    $repo: no commits on GitHub yet"
    return
  fi
  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    echo "[skipped]  $repo: uncommitted changes"
    return
  fi
  if ! git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
    echo "[ERROR]    $repo: detached HEAD"
    return
  fi
  if ! out=$(git -C "$repo" fetch --prune --quiet 2>&1); then
    echo "[ERROR]    $repo: fetch failed: $(git_error "$out")"
    return
  fi
  if ! git -C "$repo" rev-parse -q --verify '@{u}' >/dev/null; then
    echo "[ERROR]    $repo: branch $(git -C "$repo" branch --show-current) has no upstream on GitHub"
    return
  fi
  # Commits only on the local branch / only on its upstream.
  local local_only=0 remote_only=1
  if git -C "$repo" rev-parse -q --verify HEAD >/dev/null; then
    read -r local_only remote_only < <(git -C "$repo" rev-list --left-right --count 'HEAD...@{u}')
  fi
  if (( local_only > 0 && remote_only > 0 )); then
    echo "[diverged] $repo: $local_only local, $remote_only remote commit(s)"
  elif (( local_only > 0 )); then
    echo "[ahead]    $repo: $local_only unpushed commit(s)"
  elif (( remote_only == 0 )); then
    echo "[ok]       $repo"
  elif out=$(git -C "$repo" merge --ff-only --quiet '@{u}' 2>&1); then
    echo "[updated]  $repo: $remote_only new commit(s)"
  else
    echo "[ERROR]    $repo: $(git_error "$out")"
  fi
}
export -f git_error sync_repo

gh repo list "$OWNER" --limit 1000 ${FLAGS[@]+"${FLAGS[@]}"} --json name -q '.[].name' \
  | xargs -P "$JOBS" -I{} bash -c 'sync_repo "$1" "$2"' _ {} "$OWNER" \
  | sort -k1,1 -s
