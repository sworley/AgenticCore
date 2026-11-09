# Bench Model

## Overview

The bench model uses **git worktrees** to provide isolated, parallel workspaces for
different roles and tasks. Each bench is a checked-out worktree on a named branch.

## Namespace Hierarchy

| Namespace | Role | Lifecycle | Owner |
|---|---|---|---|
| `.00` | HIL / customer-project workspace | Long-living | Human (owner) |
| `.01` | Lead-engineer (management repo) | Long-living | lead-engineer agent |
| `.02`+ | Worker benches (management/framework) | Ephemeral (per-ticket) | bench-lead agents |

## Bench Patterns

| Pattern | Namespace | Purpose | Bench-Lead Agent |
|---|---|---|---|
| Pattern H | `.00` | HIL management plane — scratch, oversight, coordination | `hil-assistant` |
| Pattern A | `.02`+ | Framework management work (scripts, config, docs) | lead-engineer |
| Pattern W | `.00` | Customer/project work — repos cloned into `.00`, gitignored by `.01` | attendant |

## Customer / Project Plane (`.00`)

Customer/project work is performed in the **long-standing `.00` worktree** (the
HIL/client plane). A git worktree materializes only **tracked** files, and customer
repositories are listed in the management repo's `.gitignore` (the ADR-0006 hard
boundary), so a fresh `.02+` worktree never contains customer code. Therefore:

1. The HIL (with the `attendant`, relaxed model) clones the customer/project
   repositories it needs **into `.00`**.
2. `.01` adds each customer repo to the **management `.gitignore`** so customer code
   never enters management history.
3. Because `.00` is long-standing (never torn down), the cloned repositories persist
   there.
4. Work intentionally left out of the customer repo is captured on a
   **management-repo branch (`.01`)** for review, test, and merge to `main`.

Consequently, `.02+` worktrees are reserved for **management/framework work (Pattern A)**
on tracked content. See [ADR-0028](../adr/adr-0028-customer-plane-provisioning.md).

## Bench Files — Disk-Local vs. Generated vs. Registry

Each bench has a disk-local convenience file and a tool-specific generated file. Durable
bench provenance lives in `bench-registry.yaml`, not in either of these:

| File | Type | Committed | Purpose |
|---|---|---|---|
| `.bench/assignment.md` | Disk-local, tool-agnostic | No — gitignored, regenerable | TICKET, BRANCH, PATTERN, TASK. A convenience file read by the attendant/tools inside this live worktree. Not the durable record — see `bench-registry.yaml`. |
| `AGENT.md` | Tool-specific, generated | Pattern-dependent (see below) | AI toolchain instructions generated at provision time from the pattern template. Pattern A and Pattern H: not committed (skip-worktree applied). Pattern W: committed to bench branch. |

`provision-bench.sh` creates both files automatically. `.bench/assignment.md` is written
to disk only — it is gitignored, so it is never staged or committed by any pattern. For
Pattern A and Pattern H benches, AGENT.md is also written to disk only — skip-worktree
is applied at provision time so it cannot be accidentally staged or committed. For
Pattern W benches, AGENT.md is committed to the bench branch immediately after
generation. If the bench worktree is rebuilt, regenerate AGENT.md from
`.bench/assignment.md` and the appropriate pattern template.

Pattern H additionally overlays `opencode.json` in the `.00` worktree — the canonical file piped
through `jq '.default_agent = "hil-assistant"'`, written to disk with skip-worktree applied, never
committed. No other pattern touches `opencode.json`. See
[Provision Worker Bench — Pattern H](../reference.architecture/provision-worker-bench.md#pattern-h--provisioning-the-00-hil-worktree)
for the in-place refresh and adopter-repair procedures.

## Rules

- `.00` and `.01` are **never torn down**
- `.02`+ benches are provisioned by the lead-engineer for each ticket
- Bench teardown requires **HIL authorization** — check `locked` field before `git worktree remove`
- `AGENT.md` is generated at provision time; Pattern A and Pattern H apply skip-worktree (not committed); Pattern W commits it to the bench branch
- Pattern H additionally overlays `opencode.json` with skip-worktree applied (not committed)
- `.bench/assignment.md` is gitignored and disk-local — never committed to any bench branch; `bench-registry.yaml` is the canonical, durable, queryable per-bench provenance record (ADR-0012 amendment, TC-056)
- Bench leads may not write to `.01` namespace or `tasks.yaml`

## Worktree Layout (Example)

The layout below illustrates **this framework's own** repository — the branch names
shown (`main`, `feat/...`, `docs/...`) are the framework's own convention, not a
requirement. An adopter maps `.01` to whichever integration branch their own project
uses.

```
~/dev/
├── AgenticCore.01/       ← .01 — lead-engineer (framework's own: dev branch; main at release cutover only)
├── AgenticCore.00/       ← .00 — HIL (workspace/owner branch)
├── AgenticCore.02/       ← .02 — worker (feat/TC-004-some-task)
└── AgenticCore.03/       ← .03 — worker (docs/TC-005-another-task)
```

`provision-bench.sh` creates worker benches by branching from the current `.01`
branch (HEAD) — see the comment above `git worktree add` in the script — so bench
provisioning works correctly under any adopter branch strategy; the framework does
not require `main`/`dev`.

## Provisioning a Worker Bench

See the runbook: [Provision Worker Bench](../reference.architecture/provision-worker-bench.md)

Quick reference:
```sh
# From .01 (main):
./mddocs/scripts/provision-bench.sh \
  --bench 02 --ticket AC-NNNN --type feat --slug short-slug \
  --task "Brief description of the task"
# provision-bench.sh creates .bench/assignment.md (gitignored, disk-local, not committed) and AGENT.md (generated; Pattern A: not committed; Pattern W: committed)
# Register in bench-registry.yaml
# Update tasks.yaml with bench assignment
```

Pattern H (`.00`) uses a separate, argument-light invocation — see
[Pattern H — provisioning the .00 HIL worktree](../reference.architecture/provision-worker-bench.md#pattern-h--provisioning-the-00-hil-worktree):
```sh
./mddocs/scripts/provision-bench.sh --pattern h
```

## Teardown

```sh
# 1. Verify all artifacts committed
git -C "$BENCH_DIR" status

# 2. Get HIL authorization ("tear down .02")

# 3. Remove worktree
git worktree remove "$BENCH_DIR"

# 4. Delete branch (after merge)
git branch -d "$BRANCH"

# 5. Update bench-registry.yaml status to torn_down
```
