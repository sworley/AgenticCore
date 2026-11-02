# Runbook: Bench Recovery (Wipe and Reprovision)

**Category:** Platform & Developer Tooling
**Last Updated:** 2026-07-21
**Owner:** Platform Engineering

## Overview

Use this runbook when a bench's session context has been wiped, the bench worktree path
no longer exists, or the bench needs to be fully reprovisioned from scratch. The bench
registry (`bench-registry.yaml` in the collection root) and `tasks.yaml` are the recovery
specifications — they record bench assignments, roles, and task state.

This runbook covers four scenarios:

- **Scenario A** — session context was cleared but the worktree filesystem is intact
- **Scenario B** — both session context and the worktree were lost; full reprovision needed
- **Scenario C** — untracked files regenerating after deletion (active session write loop)
- **Scenario D** — dirty bench with merge conflicts or diverged branch

---

## Prerequisites

- Access to `<program>.01` (the lead bench)
- `git` available on the target machine
- opencode CLI installed
- `provision-bench.sh` available at `mddocs/scripts/provision-bench.sh`
- Recovery source: `_config/` directory in the repo, or a prior `.opencode/` backup

---

## Scenario A — Session Context Cleared, Filesystem Intact

The worktree directory exists but session memory for the bench is gone.

### Steps

**1 — Identify the bench**

```bash
# From inside the bench worktree
git rev-parse --show-toplevel   # confirms the bench path
git branch --show-current       # confirms the branch
```

**2 — Re-register the ours merge driver**

The `merge.ours.driver` registration lives in `.git/config` and is lost when a new
worktree is created. Re-register before resuming work:

```bash
git config merge.ours.driver true
```

Without this, `.gitattributes` `merge=ours` entries are inactive and bench merges can
clobber `.01`'s files.

**3 — Restore settings from template**

```bash
# From the bench worktree
cp .mcp.json.template .mcp.json
# Substitute the bench absolute path placeholder
BENCH_ABS="$(git rev-parse --show-toplevel)"
sed -i '' "s|{{BENCH_DIR}}|${BENCH_ABS}|g" .mcp.json
```

**4 — Update bench registry in .01**

Open a lead-engineer session in `.01` and confirm the bench entry in `bench-registry.yaml`
reflects the current role, branch, and assigned tasks.

**5 — Open a fresh session**

```bash
opencode
```

Verify the session picks up the correct project context.

---

## Scenario B — Full Reprovision (Worktree Lost)

Both the worktree and session context are gone. Reprovision from `.01`.

### Steps

**1 — Ensure .01 is clean and on main**

```bash
# From <program>.01
git checkout main && git pull origin main
git status   # must be clean
```

**2 — Confirm the bench number**

```bash
git worktree list
```

Choose the next available `NN` (e.g., `.02`, `.03`) not currently in use.

**3 — Create the worktree**

```bash
# NN = next available bench number
# Run from the parent directory containing the .01 worktree
git -C <program>.01 worktree add \
    ../<program>.NN \
    -b feat/AP-NNN-<slug>
```

**4 — Bootstrap worker files**

```bash
# From the new bench worktree
BENCH_ABS="$(git rev-parse --show-toplevel)"

# Generate .mcp.json from template
sed "s|{{BENCH_DIR}}|${BENCH_ABS}|g" .mcp.json.template > .mcp.json
```

If `provision-bench.sh` is present, use it instead:

```bash
bash mddocs/scripts/provision-bench.sh --bench <program>.NN
```

**5 — Re-register the merge driver**

```bash
git config merge.ours.driver true
```

**6 — Update tasks.yaml in .01**

Open a lead-engineer session in `.01` and update any in-progress tasks that were
assigned to the lost bench. Either re-assign them to the new bench number or reset
them to `ready` if they need to restart.

**7 — Update bench-registry.yaml in .01**

Add or update the entry for the new bench number, recording role, branch, and tasks.

**8 — Verify**

```bash
git worktree list
opencode   # open a session and verify MCP servers connect
```

---

## Scenario C — Untracked Files Regenerating After Deletion

Untracked files in a bench worktree are deleted but reappear moments later with a
single-line stub header (e.g. `# Runbook: Some Title`).

### Symptoms

- `rm <file>` reports success but the file reappears within seconds
- The regenerated file contains only a 1-line stub header — not real content
- The file was never committed on any branch (`git ls-files` returns nothing)
- `git log --all -- <path>` shows no history

### Root Cause

An active session in the same bench is mid-loop and recreating the file via Write tool
calls. The session wrote the stub as a placeholder, was interrupted or the file was
deleted externally, and continues recreating it on each tool call. The file is not
coming from git — it has no tracked state.

### Resolution

1. **Stop the active bench session** — close or interrupt the opencode session running
   in the affected bench (Ctrl+C or close the window)
2. **Delete the files** — with the session stopped, `rm` will stick:
   ```bash
   rm /absolute/path/to/bench/stubfile.md
   ```
3. **Verify** — confirm the file is gone and does not regenerate after 30 seconds

If stopping the session is not possible, worktree teardown and recreate is the definitive
fix. Since the files were never committed, a clean worktree will not contain them. See
Scenario B for the full reprovision sequence.

**mdbook serve as alternate cause:** If `mdbook serve` is running and `SUMMARY.md`
references files absent from disk, mdbook auto-creates 1-line stubs. Stop `mdbook serve`
before any git clean or branch operation. Never run `mdbook serve` while performing branch
switches.

---

## Scenario D — Dirty Bench (Merge Conflicts or Diverged Branch)

The bench branch has diverged from main or has merge conflicts blocking progress.

### Steps

**1 — Assess the state**

```bash
git status
git log --oneline main..HEAD    # commits ahead of main
git log --oneline HEAD..main    # commits on main not in branch
```

**2 — Save work-in-progress**

```bash
git stash push -m "WIP before recovery $(date +%Y-%m-%d)"
```

**3 — Rebase or reset**

If the branch can be rebased cleanly:
```bash
git fetch origin main
git rebase origin/main
```

If the branch needs to restart from main (all work already merged or abandoned):
```bash
git checkout main
git pull origin main
git branch -D feat/AP-NNN-<slug>
git checkout -b feat/AP-NNN-<slug>
```

**4 — Restore stashed work if needed**

```bash
git stash pop
```

**5 — Update tasks.yaml** to reflect the branch reset if applicable.

---

## Validation

```bash
# Confirm worktree list is accurate
git worktree list

# Confirm branch is on the expected feature branch
git branch --show-current

# Confirm .mcp.json is present (gitignored — must exist on disk)
test -f .mcp.json && echo "present" || echo "MISSING"

# Confirm merge driver is registered
git config merge.ours.driver
```

---

## Rollback

This runbook creates new files and worktrees; it does not modify existing state in `.01`.
If the reprovision is incorrect:

1. Remove the incorrect worktree (requires HIL authorization per PROCESS.md §5):
   ```bash
   git worktree remove ../<program>.NN
   ```
2. Delete the branch:
   ```bash
   git branch -d feat/AP-NNN-<slug>
   ```
3. Re-run from Step 3 with corrected parameters.

---

## Related

- [ADR-: AI toolchain Config Versioning and Bench Manifest](../../adr/adr--opencode-config-versioning-bench-manifest.md)
- [Provision Worker Bench](../../reference.architecture/provision-worker-bench.md) — first-time bench creation
- [Configure Agent Namespace](configure-agents.md) — agent namespace setup
- [Bench Registry](../../reference.architecture/bench-registry.md) — bench tracking and registration
- `bench-registry.yaml` (collection root) — live bench state
- `tasks.yaml` (collection root) — task queue and bench assignments
