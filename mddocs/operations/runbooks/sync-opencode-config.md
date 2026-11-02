# Runbook: Sync Agent Config (AGENT.md Archive ↔ On-Disk)

**Purpose:** Keep the committed AGENT.md recovery archive in `_config/` in sync
with the on-disk locations that live outside the git tree (e.g. org-level,
parent-directory, or user-level AGENT.md files).

**Script:** `mddocs/scripts/sync-agent-config.sh`

---

## Overview

`_config/` tracks copies of AGENT.md files whose authoritative on-disk location is
outside the repository. The script synchronises the pair in either direction and
can report drift without modifying anything.

## Modes

| Mode | Direction | Effect |
|---|---|---|
| `--deploy` | `_config/` → on-disk | Writes archive content to the on-disk target (repo → filesystem) |
| `--collect` | on-disk → `_config/` | Writes on-disk content back to the archive (filesystem → repo) |
| `--check` | both | Diff only; exits `1` if any pair is out of sync; never modifies files |

## Usage

```sh
# Deploy committed config to the filesystem
bash mddocs/scripts/sync-agent-config.sh --deploy

# Collect on-disk changes back into the archive
bash mddocs/scripts/sync-agent-config.sh --collect

# Verify the archive matches on-disk (CI / pre-session audit)
bash mddocs/scripts/sync-agent-config.sh --check
```

The script is idempotent and copies only when content differs.

## Registering a New Pair

To add a new AGENT.md pair, append a `sync_pair <archive> <target>` line in the
"Registered pairs" section of the script, following the commented example.

## Verification

- [ ] `--check` exits `0` (all pairs in sync)
- [ ] Deployed AGENT.md matches the archive
- [ ] Archive changes committed (`.gitattributes`-tracked)

## Related

- [Sync Agent Definitions](sync-agent-definitions.md)
- [Configure Agent Namespace](configure-agents.md)
