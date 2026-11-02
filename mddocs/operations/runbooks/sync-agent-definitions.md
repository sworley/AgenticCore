# Runbook: Sync Agent Definitions

**Purpose:** Propagate changes from the canonical `.agents/` source to tool-specific
agent directories (`.opencode/agents/`).

**Script:** `.agents/sync-agents.sh`
**When to run:** After any change to `.agents/<name>.md` or `.agents/_meta.yaml`

---

## Prerequisites

- Python 3 available (`python3 --version`)
- Changes committed to `.agents/` (or staged)

---

## Procedure

### Step 1 — Preview changes (dry run)

```sh
.agents/sync-agents.sh --dry-run
```

Review the output to confirm the expected files will be written.

### Step 2 — Run the sync

```sh
.agents/sync-agents.sh
```

### Step 3 — Review generated files

```sh
git diff .opencode/agents/
```

Confirm the diffs match your intent.

### Step 4 — Stage and commit

```sh
git add .agents/ .opencode/agents/
git status
# Present summary to HIL and wait for LGTM
git commit -m "feat: update agent definitions [AP-NNN]"
```

---

## Verification

- [ ] No errors during sync
- [ ] Generated files have correct frontmatter (description, mode, permission)
- [ ] Agent body is present and not truncated
- [ ] AUTO-GENERATED comment present at top of each generated file

---

## Rollback

If generated files are incorrect:
```sh
git checkout .opencode/agents/
```

Fix the canonical source and re-run the sync.

---

## Environment Validation

Run before starting any development session:

```sh
./mddocs/scripts/check-env.sh
```

Checks:
- `GIT_HOST` set
- `GIT_TOKEN` set
- `direnv` active (`DIRENV_DIR` set)
- `pass` store accessible
- `mdbook` available
