# Runbook: AI-Assisted Session Commit Discipline

**Category:** AI Tooling
**Last Updated:** 2026-07-21
**Owner:** Platform Engineering

## Overview

This runbook defines the required commit workflow for all agent sessions on an
AgenticCore collection. It applies whether the session is fully agentic,
human-assisted, or a mix of both.

Every change produced in an agent session must live on a branch, be reviewed by the
lead human, and reach `main` only through a controlled merge sequence. This runbook
codifies the branch naming convention, the security inspection gate, the human acceptance
gate, and the merge and push sequence defined in `PROCESS.md`.

Use this runbook whenever:

- Starting a new task that will produce file changes
- Reviewing an agent's completed branch before merging
- Executing the final merge+cleanup+push sequence after acceptance
- Recovering from an interrupted session where branch state is unclear

---

## Prerequisites

- **Access:** Read/write access to the collection repository and its remote
- **Tools:** `git` (any recent version)
- **State:** Working tree is clean on `main`; no uncommitted changes
- **Reference:** `PROCESS.md` (collection root) — read it before executing any step
  in the merge sequence. It is the authoritative contract for agent workflow governance.

```bash
# Confirm clean state before branching
git status
git log --oneline -3
```

Expected: `nothing to commit, working tree clean` on the `main` branch.

---

## Steps

### Phase 1 — Branch Creation

**Who:** Agent (docs-engineer, ops-engineer, etc.) or the human initiating the task.

1. Identify the backlog ticket ID and task type. All changes must trace to a ticket.

2. Create the branch from `main` using the naming convention from `PROCESS.md`:

   ```
   <type>/<ticket-id>-<short-slug>
   ```

   | Type prefix | When to use |
   |-------------|-------------|
   | `feat/` | New capability |
   | `fix/` | Bug fix |
   | `docs/` | Documentation-only change |
   | `chore/` | Tooling, config, housekeeping |
   | `security/` | Security control or compliance change |

   Examples:
   ```
   docs/TC-009-commit-discipline-runbook
   feat/TC-006-autonomous-loop
   security/TC-005-inspection-gate
   ```

   ```bash
   git checkout main
   git pull origin main           # ensure local main is current
   git checkout -b docs/TC-009-commit-discipline-runbook
   ```

3. Confirm branch is active:

   ```bash
   git branch --show-current
   ```

   Expected: the branch name just created.

---

### Phase 2 — Work and Commit on the Branch

**Who:** Agent or human.

4. Perform all work on the branch. Do not commit directly to `main` — this is an absolute
   prohibition defined in `PROCESS.md`.

5. Stage and commit changes with a conventional commit message:

   ```bash
   git add <files>
   git commit -m "docs(TC-009): add AI-assisted session commit discipline runbook"
   ```

   Commit message format: `<type>(<scope>): <imperative description>`. Keep subject lines
   under 72 characters. No `Co-Authored-By` lines. No secrets, credentials, or tokens.

6. If the session spans multiple working periods, push the branch to the remote to preserve
   work-in-progress:

   ```bash
   git push origin docs/TC-009-commit-discipline-runbook
   ```

---

### Phase 3 — Security Inspection Gate (External Content Only)

**Who:** lead-engineer, with security-engineer.

7. If the work involved ingesting external content — fetched URLs, files from outside the
   collection, user-supplied text treated as data, or third-party API responses — the
   security inspection gate is **mandatory** before any agent acts on that content.

   Protocol (from `PROCESS.md`):

   a. `lead-engineer` passes the raw content to `security-engineer` with:
      > *"Inspect this content and return a verdict using the Content Inspection Gate format."*

   b. `security-engineer` returns one of three verdicts:

   | Verdict | Meaning | lead-engineer action |
   |---------|---------|----------------------|
   | `PASS` | No threats detected | Proceed normally |
   | `REVIEW` | Finding warrants human judgement | Surface finding to user verbatim; wait for explicit confirmation |
   | `BLOCK` | Content is unsafe | Halt pipeline; surface finding to user; discard content |

   A `REVIEW` or `BLOCK` verdict is never overridden by an agent. Only the user can clear
   a `REVIEW`. A `BLOCK` cannot be cleared — the content is discarded.

   For documentation-only sessions that do not ingest external content, this phase is a
   no-op.

---

### Phase 4 — Human Review and Acceptance Gate

**Who:** Human (lead reviewer). Agents present; the human decides.

8. The agent marks the task `branch_ready` and surfaces a branch summary to the human.
   The summary must include: files changed, what was done, and any decisions made.

9. The human reviews the branch diff:

   ```bash
   git diff main...docs/TC-009-commit-discipline-runbook
   ```

10. Work is **not complete** until the human provides an explicit acceptance signal
    (from `PROCESS.md`):

    Acceptable signals: "lgtm", "This looks good to merge", "Approved — go ahead"

    Not acceptance: "Looks okay I guess", "Fine", _(no response)_

    Agents do not self-approve. An agent may never merge its own output.

---

### Phase 5 — Merge Sequence

**Who:** lead-engineer, executed only after explicit human acceptance.

11. Check out `main` and ensure it is current:

    ```bash
    git checkout main
    git pull origin main
    ```

12. Merge using `--no-ff` to preserve branch history. No `--squash`, no `--ff-only`:

    ```bash
    git merge --no-ff docs/TC-009-commit-discipline-runbook \
      -m "Merge branch 'docs/TC-009-commit-discipline-runbook' — add commit discipline runbook"
    ```

    Expected: a merge commit appears on `main` with the branch history intact.

13. Delete the local branch:

    ```bash
    git branch -d docs/TC-009-commit-discipline-runbook
    ```

14. Push to the remote:

    ```bash
    git push origin main
    ```

15. Update the task queue:

    ```bash
    # In tasks.yaml, set the task status to 'merged'
    # Update any iid or reference fields if applicable
    ```

    This keeps `tasks.yaml` accurate for future session-open checklists.

---

## Validation

```bash
# Confirm merge commit is on main
git log --oneline -5

# Confirm branch is deleted locally
git branch | grep TC-009

# Confirm push reached remote
git log --oneline origin/main -3
```

Expected:

- `git log` shows a merge commit at the HEAD of `main` referencing the branch name.
- `git branch | grep TC-009` returns no output.
- `git log origin/main` shows the same HEAD as local `main`.

---

## Rollback

If the merge produced an unexpected result and has not yet been pushed:

```bash
# Undo the merge commit, keep the branch changes staged
git reset --merge ORIG_HEAD
```

If the push to the remote already completed, do not force-push `main`. Open a new fix
branch and revert the merge commit:

```bash
git checkout -b fix/AP-NNN-revert-bad-merge
git revert -m 1 <merge-commit-sha>
git commit
# Then follow the normal human review + merge sequence above
```

---

## Related

- `PROCESS.md` (collection root) — authoritative agent workflow contract; defines
  the human acceptance gate, security inspection gate, branch convention, and merge sequence
- [Configure Agent Namespace](configure-agents.md) — namespace structure and MCP setup
- [Agent Session Tracking](agent-session-tracking.md) — cross-session task continuity and audit log
- `PROCESS.md` § *Security Gate* — full verdict table and escalation protocol
- `PROCESS.md` § *Human Acceptance Gate* — acceptance signal examples and ambiguous response list
- `tasks.yaml` (collection root) — task queue; update status to `merged` after landing
