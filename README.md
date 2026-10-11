# git-fleet

Keep a local copy of all your GitHub repositories in sync with a single command.

## How it works

`sync-all.sh` detects your GitHub username from the `gh` login, lists your repositories, then processes them in parallel in the script's own directory:

- **Missing repo** → cloned.
- **Existing repo** → updated with `git pull --ff-only`.
- **Uncommitted local changes** → skipped, so no work is lost.
- **Empty repo on GitHub** → reported and left alone.

Each repo gets one status line (`[cloned]`, `[ok]`, `[skipped]`, `[empty]` or `[ERROR]`), and the output is grouped by status.

## Requirements

- `git`
- [`gh`](https://cli.github.com/), logged in (`gh auth login`)

## Usage

```bash
./sync-all.sh [--forks] [--archived] [-j N]
```

| Option       | Description                                    |
|--------------|------------------------------------------------|
| `--forks`    | Include forked repositories (excluded by default) |
| `--archived` | Include archived repositories (excluded by default) |
| `-j N`       | Number of parallel jobs (default: 8)           |

To sync another user or organization, set `OWNER`:

```bash
OWNER=some-org ./sync-all.sh
```
