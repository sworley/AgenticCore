# ADR-0004: `main` Branch Protection and Immutability

**Date:** 2026-06-25
**Status:** accepted

## Context

`main` is the stable integration branch and the sole source of truth for released
artifacts. Without explicit rules governing what operations are permitted on `main`,
agentic actors or accidental human actions could corrupt history, roll back accepted
work, or introduce unreviewed changes directly.

Two categories of risk need to be addressed:

1. **Direct write risk** — commits, pushes, or force-pushes that bypass the branch →
   review → merge workflow.
2. **History mutation risk** — operations that rewrite or revert history on `main`
   after work has been accepted: `git revert`, `git reset --hard`, `git rebase`,
   cherry-picks that undo prior commits, or any other operation whose net effect is
   to remove or alter accepted work.

Server-side enforcement (Git branch protection) is the authoritative backstop, but
the rules must be stated as process constraints independent of any platform so they
apply to all agentic and human actors in all environments.

## Decision

`main` is a append-only, merge-only branch. The following rules apply:

**Permitted operations on `main`:**
- `git merge --no-ff <branch>` — after explicit HIL LGTM
- Annotated tag creation (`git tag -a`)

**Prohibited operations on `main`:**
- Direct commits (`git commit` while on `main`)
- Direct pushes that are not the result of an approved merge
- Force push (`git push --force` or `git push --force-with-lease`) — all roles, no exceptions
- `git reset --hard` or `git reset --mixed` targeting any commit on `main`
- `git rebase` of `main` against any other branch
- `git revert` used to undo a previously accepted commit on `main` — roll-forward
  via a new fix commit on a feature branch is the required pattern
- Cherry-picks onto `main` that skip or remove prior accepted commits
- Any operation whose net effect is to remove, alter, or reorder commits already
  present on `main`

**Roll-back policy:** There is no roll-back. If accepted work on `main` must be
undone, the correct pattern is a roll-forward: open a task, branch from `main`,
implement the reversal as a new commit, review, and merge normally. This preserves
audit trail and ensures HIL acceptance of every state `main` reaches.

**Server-side enforcement:** The above rules must be enforced at the Git project
level as a protected branch configuration (Maintainer-only push, force push disabled
for all roles). Configuration is in scope for TC-002 (CI pipeline task).

## Consequences

**Positive:**
- `main` history is auditable and append-only — every state is reachable and reviewable
- No accepted work can disappear without a new accepted commit explaining why
- Agentic actors cannot accidentally or maliciously rewrite shared history
- Roll-forward policy forces explicit task creation and HIL acceptance for any undo

**Negative / Trade-offs:**
- Roll-forward is more process overhead than `git revert` for simple undos
- Mistakes on `main` cannot be quietly fixed; they must be addressed transparently

**Neutral:**
- Server-side enforcement is a second layer — process rule is binding before TC-002 lands

## Implementation Notes

- PROCESS.md §4 states the merge strategy and references this ADR for branch protection rules
- Server-side configuration: Git project → Settings → Repository → Protected Branches
  - `main`: Allowed to push = Maintainer; Allowed to merge = Maintainer; Force push = disabled
- TC-002 is the task that implements server-side enforcement
