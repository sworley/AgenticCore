# Runbook: git-sync — Git Workspace Sync

**Script:** `mddocs/scripts/git-sync.sh`
**Purpose:** Clone or update every project in a Git group into the current
directory, mirroring the group's namespace structure. Used by the HIL and
lead-engineer to populate and refresh bench worktrees.

---

## Prerequisites

| Tool | Install |
|---|---|
| `jq` | `brew install jq` |
| `curl` | system |
| `git` | system |
| `pass` | `brew install pass` (optional — needed for profile-based token retrieval) |
| `zsh` | system |

---

## Profiles File

Create `~/.config/git-sync/profiles` with one entry per Git instance:

```
# name     url                                    pass-path                    default-group
default    https://git.example.com   git/example.internal.com/pat  example-group
```

Format: `<name> <url> <pass-path> <default-group>` — whitespace separated.
Lines starting with `#` are comments.

---

## Usage

### Non-interactive (recommended for automation)

```zsh
# Use the default profile
./mddocs/scripts/git-sync.sh

# Explicit profile
./mddocs/scripts/git-sync.sh --profile default

# Override group
./mddocs/scripts/git-sync.sh --profile default --group my-other-group

# Dry run — shows what would change, no writes
./mddocs/scripts/git-sync.sh --dry-run

# Supply token directly (non-interactive scripts only)
GIT_SYNC_TOKEN="$(pass show git/example.internal.com/pat)" \
  ./mddocs/scripts/git-sync.sh --mode sync
```

### Interactive

```zsh
./mddocs/scripts/git-sync.sh
# Prompts for token (hidden), mode selection
```

### Local pull only (no token, no API)

```zsh
./mddocs/scripts/git-sync.sh --mode update
# or
GIT_SYNC_MODE=update ./mddocs/scripts/git-sync.sh
```

---

## Modes

### `sync` — Clone or update from Git API

- Queries the Git API for all projects in the target group (paginated)
- For each project:
  - **Does not exist locally** → `git clone`
  - **Exists locally** → update remote URL + `git pull --ff-only`
- Checks out the default branch (main or master) after clone/pull
- Requires a valid token with at least `read_api` scope

### `update` — Local pull only

- Traverses the current directory for `.git` repos (max depth 3)
- Skips directories whose name starts with `.` (bench worktrees)
- Runs `git pull` in each — no API calls, no token needed
- Use after a network-isolated session or to refresh without re-querying Git

---

## Security Notes

- Tokens are retrieved via `pass` — never embedded in URLs or `.git/config`
- A temporary `GIT_ASKPASS` script is created in `/tmp` and deleted on exit
- `GIT_SYNC_TOKEN` env var is available for CI use but should not be used
  interactively — prefer `pass`
- The token is never written to disk, logs, or git history

---

## .gitignore Requirement

Every top-level directory that `git-sync.sh` creates must be listed in `.gitignore`.
Synced repos that are not gitignored will appear as untracked files and pollute
`git status` across all worktrees.

Add new namespace directories to `.gitignore` **before** running the sync:

```sh
echo "my-new-subgroup/" >> .gitignore
git add .gitignore
git commit -m "chore: gitignore synced namespace my-new-subgroup"
```

---

## Environment Variables Reference

| Variable | Purpose | Default |
|---|---|---|
| `GIT_SYNC_PROFILE` | Profile name from profiles file | `default` |
| `GIT_SYNC_GROUP` | Override group/namespace path | Profile default or `pwd` basename |
| `GIT_SYNC_URL` | Override Git base URL | Profile value |
| `GIT_SYNC_PASS_PATH` | Override pass store path | Profile value |
| `GIT_SYNC_TOKEN` | Supply token directly | *(from pass)* |
| `GIT_SYNC_MODE` | `sync` or `update` | Interactive prompt |

---

## Troubleshooting

**`Error: could not find Git group`**
- Verify the group path: `curl -s --header "PRIVATE-TOKEN: $GIT_TOKEN" "$GIT_HOST/api/v4/groups?search=<name>" | jq '.[].full_path'`
- Confirm PAT has `read_api` or `api` scope

**`Pass unlock prompt not appearing`**
- Ensure `GPG_TTY` is set: `export GPG_TTY=$(tty)`
- Run `gpg --card-status` to wake the agent

**`Pull failed (local changes?)`**
- The repo has uncommitted changes — resolve before re-running
- Or use `--mode update` to skip repos with conflicts

**Token retrieved but API returns 401**
- Token may be expired — rotate via Git UI and update pass store
- See runbook: [Rotate Git PAT](rotate-git-pat.md)

---

## Related

- [Provision Worker Bench](../../reference.architecture/provision-worker-bench.md)
- [Rotate Git PAT](rotate-git-pat.md)
