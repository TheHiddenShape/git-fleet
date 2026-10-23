# git-fleet

Keep a local copy of all your GitHub repositories in sync with a single command.

## How it works

`git_fleet_sync.sh` detects your GitHub username from the `gh` login, lists your repositories, then processes them in parallel in the script's own directory:

- **Missing repo** → cloned.
- **Uncommitted local changes** (including untracked files) → skipped, so no work is lost.
- **Empty repo on GitHub** → reported and left alone.
- **Existing repo** → fetched, then the current branch is compared with its upstream:

| Status       | Meaning                                         | Action                    |
|--------------|-------------------------------------------------|---------------------------|
| `[ok]`       | Already up to date                              | none                      |
| `[updated]`  | New commits on GitHub only                      | fast-forward              |
| `[ahead]`    | Local commits not pushed yet                    | none (push them yourself) |
| `[diverged]` | Commits on both sides                           | none (rebase or merge yourself) |
| `[ERROR]`    | Detached HEAD, no upstream branch, fetch failed | none                      |

Only the checked-out branch is compared and updated. Local work is never modified: the script only fast-forwards.

Each repo gets one status line, and the output is grouped by status.

## Requirements

- `git`
- [`gh`](https://cli.github.com/), logged in (`gh auth login`)

## Usage

```bash
./git_fleet_sync.sh [--forks] [--archived] [-j N]
```

| Option       | Description                                    |
|--------------|------------------------------------------------|
| `--forks`    | Include forked repositories (excluded by default) |
| `--archived` | Include archived repositories (excluded by default) |
| `-j N`       | Number of parallel jobs (default: 8)           |

To sync another user or organization, set `OWNER`:

```bash
OWNER=some-org ./git_fleet_sync.sh
```
