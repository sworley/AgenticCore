# ADR-0028: Customer/Project Plane Provisioning — Clone into `.00`, Gitignore in `.01`

**Date:** 2026-11-02
**Status:** accepted
**Supersedes:** —

## Context

The bench model's worktrees (`.00` / `.01` / `.02+`) are all worktrees off a single
`.01` git root (see ADR-0006 and the baseline Plane Separation model). A git worktree
materializes only **tracked** files. Customer/project repositories are cloned into the
management area and listed in the management repo's `.gitignore` — the ADR-0006 hard
boundary — so they never enter management git history.

Because a fresh `.02+` worktree contains only tracked management content, **it cannot
see customer code**. The framework's portable Pattern W (attendant,
`provision-bench.sh --pattern w`) deliberately omitted the customer-repo provisioning
specifics (the legacy gap analysis records the original `EXAMPLE` ADR's customer-repo
provisioning as "not ported").

## Decision

Customer/project work is performed in the **long-standing `.00` worktree**, the
HIL/client plane:

- The HIL (with the `attendant`, relaxed model) clones the customer/project
  repositories it needs **into `.00`**.
- `.01` adds each customer repository to the **management `.gitignore`** (ADR-0006
  hard boundary), so customer code can never enter management git history.
- Because `.00` is long-standing (never torn down), the cloned customer repositories
  persist there — unlike a fresh `.02+` worktree, which only carries tracked content.
- Anything intentionally left out of the customer repository (documented decisions,
  derived configuration, notes) is captured on a **management-repo branch** (`.01`), so
  `.01` can review, test, and merge to `main`.

`.02+` worktrees are reserved for **management/framework work (Pattern A)** on tracked
content — they scale well and never carry customer code.

## Consequences

**Positive:**
- Customer code stays out of management history (ADR-0006 boundary).
- Customer work is reproducible in a long-standing plane; fresh `.02+` worktrees are
  never polluted by customer code.
- `.01` retains a clean review/test/merge path for management branches.

**Negative / Trade-offs:**
- Customer work is tied to the long-lived `.00` worktree — the clone + `.gitignore`
  step is a manual, deliberate operation.
- Fresh `.02+` worktrees cannot be used for customer code without first cloning the
  repository into `.00`.

## Lessons Learned

"Everybody knows" is not a guardrail. The mechanism that makes customer work possible in
a worktree (clone into the long-standing plane, then gitignore it in the management repo)
was implicit; it needs to be a written rule to be reproducible.

## Related

- [ADR-0006: External Content Gate Scope](adr-0006-external-content-gate-scope.md)
- [Bench Model](../onboarding/bench-model.md)
- [Visual Overview](../onboarding/visual-overview.md)
