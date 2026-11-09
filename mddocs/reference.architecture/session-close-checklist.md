# Session Close Checklist

**Trigger:** End of every agentic session, or before switching focus to a different task.

**Agent:** lead-engineer (`.01`)
**Estimated time:** 5-10 minutes

---

## Procedure

### Step 1 — Verify all benches are clean

```sh
./mddocs/scripts/check-worktree-hygiene.sh
```

Or manually:
```sh
git worktree list --porcelain | grep "worktree" | awk '{print $2}' | \
  while read p; do
    status=$(git -C "$p" status --short 2>/dev/null)
    [ -n "$status" ] && echo "DIRTY: $p" && echo "$status"
  done
```

**All benches must be clean before proceeding.**

### Step 2 — Land bench artifacts to dev (for benches being torn down)

`dev` is the integration + durability surface (ADR-0026) — bench artifacts land
there, not on `main`. `main` is touched only at a curated release cutover.

For each bench being decommissioned this session:

```sh
# a. Checkout session-state and mddocs files to dev
git checkout dev
git checkout <bench-branch> -- .core/work/session-state-$(date +%Y-%m-%d).md
git checkout <bench-branch> -- mddocs/   # if any doc updates

# b. Commit
git add -A
git commit -m "docs: land session artifacts from <branch> [AC-NNNN]"
```

### Step 3 — Update running release notes draft

Append notable changes this session to `.core/work/next-release-notes.md` (create if absent).
Use plain bullet entries grouped by tier:

```markdown
## YYYY-MM-DD

- [significant] short description (ADR-NNNN / AC-NNNN)
- [routine] short description (AC-NNNN)
- [patch] short description
```

Significant = new agent, new invariant, changed guardrail, new ADR.
Routine = doc fix, runbook update, checklist addition, gap closure.
Patch = typo, broken link, formatting — include only if worth noting.

### Step 4 — Update tasks.yaml

- Mark completed tasks as `merged` or `closed`
- Update `updated` fields
- Add `completed_at` for finished tasks

### Step 5 — Sweep open out-of-scope reviewer notes

Review open note-severity findings in the review and security ledgers. Each note
either:
- becomes a backlog ticket in `tasks.yaml` — the finding cites the new ticket's
  AC-ID, and the ticket cites the finding's SF-/RF-ID (cross-referenced both ways), or
- is consciously accepted (rationale recorded on the finding).

Do not let out-of-scope reviewer observations leak past session close unresolved.

### Step 6 — Write session memory note

Create `.core/work/session-state-$(date +%Y-%m-%d).md` if it doesn't exist:

```markdown
# Session State — YYYY-MM-DD

**Branch:** dev
**Active tasks:** AC-NNNN (status)
**Work done this session:** ...
**Blockers:** ...
**Next step:** ...
```

Stage and commit:
```sh
git add .core/work/session-state-$(date +%Y-%m-%d).md tasks.yaml
git commit -m "chore: session close state [YYYY-MM-DD]"
```

### Step 7 — Push to remote

```sh
git push origin dev
```

Requires HIL explicit approval before running.

### Step 8 — Clean build artifacts

```sh
rm -rf mddocs/book/
```

---

## Verification

Session close is complete when:
- [ ] All bench `git status` outputs are clean
- [ ] `.core/work/next-release-notes.md` updated with notable changes this session
- [ ] `tasks.yaml` reflects end-of-session state
- [ ] Open out-of-scope reviewer notes swept into tickets or consciously accepted
- [ ] Session memory note committed
- [ ] All merged work pushed to `origin/dev`
- [ ] `mddocs/book/` removed

---

## Escalation

If any bench has uncommitted changes that cannot be cleanly committed:
1. Stage and commit what is complete
2. Move incomplete work to a new task in `tasks.yaml` with `status: in_progress`
3. Document the partial state in the session note
