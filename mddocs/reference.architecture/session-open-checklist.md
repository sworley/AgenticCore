# Session Open Checklist

**Trigger:** Start of every agentic session. Canonical phrase: "Lead-engineer, session open"

**Agent:** lead-engineer (`.01`)
**Estimated time:** 2-3 minutes

---

## Procedure

### Step 0 — Validate environment

```sh
./mddocs/scripts/check-env.sh
python3 .core/scripts/check-hook-wiring.py
```

`check-env.sh` verifies required env vars and tool availability. Exits non-zero on
failure — resolve before proceeding. Required env vars are declared in `.env-required`
(project-specific, committed to git). Values are injected by direnv, `.envrc`, or shell
profile — never stored in `.env-required` itself.

`check-hook-wiring.py` verifies every **AI-tool hook** in `.core/hooks/` is wired in
`settings.json.template`. Exits non-zero if any are unwired — add the missing entries
before proceeding. Git hooks (installed into `.git/hooks/` via `install-git-hooks.sh`,
e.g. `pre-commit-permission-order-check.py`) are a separate class and are excluded from
this check; see `agent-authoring-workflow.md` for the two-class distinction.

**First-time setup:** Copy `.env-required.example` to `.env-required` and uncomment
the vars your project needs. See the example file for common variables.

### Step 1 — Sync Git workspace

```sh
./mddocs/scripts/git-sync.sh --profile <name>
```

Pulls latest changes for all repos in the configured Git group into the
current bench. Skip if running in `update`-only mode or offline.

### Step 2 — Confirm workspace state

```sh
git status
```

Expected: on `dev` (staging branch for day-to-day work) or `main` (release cutover
only) with a clean working tree. If dirty, investigate before proceeding.

### Step 3 — Review open benches

```sh
git worktree list
```

Note any benches not in the expected state. Cross-reference with `bench-registry.yaml`.

Run the bench status script for more detail:
```sh
./mddocs/scripts/bench-status.sh
```

Run with `--stale` to cross-reference open worktrees against `tasks.yaml` and flag
any bench whose task is already `merged` or `cancelled`:
```sh
./mddocs/scripts/bench-status.sh --stale
```

Stale benches should be torn down via the session-close checklist before proceeding.

`bench-status.sh` also flags a missing `.00` HIL worktree with an advisory NOTICE
(on both the normal run and `--stale`) and prints the exact command to provision
one — `./mddocs/scripts/provision-bench.sh --pattern h`. **On first startup** (no
`.00` yet) the lead-engineer provisions `.00` itself rather than deferring to the
operator: run `provision-bench.sh --pattern h`, register `.00` in `bench-registry.yaml`
with `locked: true`, and confirm the new `.00` opens as `hil-assistant`. After `.00`
exists it is HIL-owned — never torn down, never reprovisioned. The script itself never
creates or modifies `.00`; the lead-engineer runs the command. See
[Pattern H — provisioning the `.00` HIL worktree](provision-worker-bench.md#pattern-h--provisioning-the-00-hil-worktree).

### Step 4 — Scan task queue

Open `tasks.yaml`. Look for:
- Items with `status: in_progress` — surface to HIL as "current work"
- Items with `status: branch_ready` — surface as "awaiting your review"
- Items with `blocked_by` that are now unblocked — surface as "now unblocked"
- Items with `labels: [gap]` and status not `merged` — surface count and titles as "open gaps"

See `task-queue-operations.md` for the gap label convention and a ready-to-run scan snippet.

### Step 4.5 — Surface open review findings

Query both review ledger paths via MCP:

```
review-ledger-security: list_findings(status=open)
review-ledger-reviews:  list_findings(status=open)
```

Present: finding ID, severity, file, one-line description, age in days.

**Escalation rule:** any finding older than 7 days must be surfaced explicitly as a
HIL escalation item — present these first, before the full findings list.

If the MCP servers are unavailable, note this in the session-open report and proceed.

### Step 5 — Clean build artifacts

```sh
cd mddocs && mdbook clean
```

This prevents stale build output from polluting the workspace.

### Step 6 — Report to HIL

Provide a concise summary:
1. Workspace is clean / issues found
2. Top in-progress or branch-ready item with next step
3. Any blockers or relay items from `relay-pending.md`
4. Close by asking the HIL: **"What would you like to work on?"**

---

## Verification

Session open is complete when:
- [ ] `check-env.sh` passed (or failures acknowledged and noted)
- [ ] `check-hook-wiring.py` passed — all hooks wired
- [ ] `git-sync.sh` completed (or skipped with reason)
- [ ] `git status` shows clean `dev` (or `main` at release cutover)
- [ ] All open benches are accounted for; no stale benches flagged
- [ ] `.00` HIL worktree present (provisioned automatically on first startup if absent); the provision command ran if it was missing
- [ ] Top task surfaced to HIL
- [ ] Both review ledger paths queried; escalations (>7 days) surfaced to HIL
- [ ] `mddocs/book/` removed

---

## Escalation

If `.01` is not on `dev` (or `main` at release cutover) and clean, stop and investigate
before proceeding. Do not proceed with task work until workspace state is known.
