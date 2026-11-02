# FAQ: How is the project workspace managed?

**Question (2026-11-02 session):** "Please elaborate on how the project workspace
is managed."

## Answer

The workspace is one git repository governed by a **git-worktree bench hierarchy**.
It is managed at three layers:

1. **Physical layout** — the repo is split into long-living namespaces and ephemeral
   worker benches, each a checked-out worktree on its own branch.
   - `.00` — HIL management plane (long-living, never torn down)
   - `.01` — lead-engineer management plane (long-living, never torn down)
   - `.02`+ — worker benches (ephemeral, per-ticket)

2. **Provenance** — durable, queryable per-bench state lives in
   [`bench-registry.yaml`](../reference.architecture/bench-registry.md) (branch, task, pattern, `locked`
   flag, status). The disk-local `.bench/assignment.md` is regenerable and gitignored;
   it is *not* the durable record.

3. **Operational tooling** — a small set of scripts drives the lifecycle:
   - [`provision-bench.sh`](../scripts/operations/provision-bench.md) creates benches
     from the current `.01` HEAD and generates per-bench files.
   - [`git-sync.sh`](../scripts/operations/git-sync.md) clones/updates every project
     in a Git group, mirroring the namespace structure (`sync` mode) or pulling
     locally without the API (`update` mode).
   - Session-open/close checklists enforce workspace hygiene before and after each
     working session (environment checks, hook wiring, clean `dev`/`main` tree,
     bench status, task-queue scan).

Because the model is documentation-first and HIL-gated, every structural change —
provisioning a bench, merging to `dev`, or tearing one down — is preceded by a
runbook step and requires explicit human authorization.

## Key Rules

- `.00` and `.01` are never torn down.
- `.02`+ benches are provisioned by the lead-engineer per ticket.
- Teardown requires **HIL authorization**; check the `locked` field before
  `git worktree remove`.
- The lead-engineer (`.01`) is the sole writer of `tasks.yaml`; bench leads cannot
  write to `.01` or `tasks.yaml`.
- Synced top-level directories must be in `.gitignore` (see
  [`git-sync-runbook.md`](../operations/runbooks/git-sync-runbook.md#gitignore-requirement)).

## Canonical References

- [Bench Model](../onboarding/bench-model.md)
- [Repository Structure](../onboarding/repository-structure.md)
- [Provision Worker Bench](../reference.architecture/provision-worker-bench.md)
- [Bench Registry](../reference.architecture/bench-registry.md)
- [Task Queue Operations](../reference.architecture/task-queue-operations.md)
- [Session Open Checklist](../reference.architecture/session-open-checklist.md)
- [Session Close Checklist](../reference.architecture/session-close-checklist.md)
- [git-sync Runbook](../operations/runbooks/git-sync-runbook.md)
- [Session Continuity Runbook](../operations/runbooks/session-continuity.md)

## Provenance

- **Session:** 2026-11-02 — "project workspace management" Q&A (AgenticCore v0.5.0).
- **Related ADRs:** ADR-0001 (bootstrap architecture), ADR-0007 (bench scope
  isolation), ADR-0015 (distribution & adoption), ADR-0026 (release-branch curation).
