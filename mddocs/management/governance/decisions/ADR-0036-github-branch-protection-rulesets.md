# ADR-0036: GitHub Branch-Protection Rulesets

**Date:** 2026-11-20
**Status:** accepted
**Supersedes:** ADR-0004 (the process-level `main` append-only / merge-only rule; this ADR is its server-side enforcement and extension)
**Superseded by:** -
**Governed by:** ADR-0035 (forward-only supersede; this supersession is recorded in the supersession ledger)

## Context

ADR-0004 (accepted 2026-06-25) established `main` as an **append-only, merge-only**
branch with a roll-forward policy and no history rewrite. It made clear that
server-side enforcement (branch protection) is the authoritative backstop, and
scoped that configuration to TC-002 (the CI task).

Two things have since changed:

1. **The legacy protection on `main` is too loose to be the backstop ADR-0004
   describes.** The current GitHub branch protection requires the `verify` CI
   check and signed commits, but it sets `required_approving_review_count: 0`,
   does **not** enforce on admins, does not require branches to be up to date
   before merge, and does not require linear history or conversation resolution.
   It also does nothing to constrain who may create feature branches.

2. **AgenticCore is a single-operator harness.** The HIL is the sole human; every
   agentic session runs under the operator's own GitHub identity and PAT. That
   shapes which protections are even possible:

   - GitHub will not let a user approve their own pull request, so a rule that
     requires approving reviews would make `main` **un-mergeable** for a
     single-operator repo. The merge gate therefore relies on the pull-request
     workflow plus CI (`verify`), branches up to date, and signed commits - not on
     a human reviewer.
   - Because the agentic sessions share the operator's identity, any bypass actor
     granted to the operator is (in effect) available to those sessions too. The
     operator account is therefore added as a **bypass actor** on `main` only so
     that the operator is never locked out; this is a deliberate, documented
     trade-off and makes the ruleset a *process-level* backstop, with local
     pre-commit hooks (ADR-0022) and HIL discipline as the first line of defense.

3. **GitHub has superseded legacy branch protection with branch-protection
   rulesets.** Rulesets are declarative, composable, auditable, and can target
   branch patterns (`main`, `feat/*`, `release/*`), which is exactly the shape
   needed to enforce both the `main` append-only rule and a feature-branch
   creation gate.

## Decision

Adopt GitHub **branch-protection rulesets** as the server-side enforcement layer
for ADR-0004 and for feature-branch creation. Two active rulesets are defined:

### Ruleset 1 - `main-strict` (target `main`)

| Rule | Setting | Rationale |
|---|---|---|
| Branch creation | block | `main` already exists; prevent accidental re-creation |
| Deletion | block | prevent removing `main` |
| Non-fast-forward | block | no force-push / rebase - the ADR-0004 "no exceptions" rule |
| Pull request | required | no direct pushes to `main` |
| Pull request - status checks | require `verify`, strict (branches up to date) | merge gate on the CI green, no stale merges |
| Pull request - approving reviews | 0 (none) | single-operator: self-approval is impossible; gate is CI + workflow |
| Pull request - code-owner review | not required | single-operator: would block merges |
| Signed commits | require | auditable provenance |
| Conversation resolution | not required | single-operator; avoid locking merges on threads with no reviewer |
| Bypass actors | operator account | documented lock-out avoidance (does not weaken the process rule) |

### Ruleset 2 - `feat-restrict-creation` (target `feat/*`)

| Rule | Setting | Rationale |
|---|---|---|
| Branch creation | block (default) | only authorized actors may create feature branches |
| Bypass actors | operator, `malachid` | the two existing collaborators who create feature branches |

### Migration

- The legacy branch protection on `main` is **removed** once `main-strict` is
  active, so there is a single source of truth (rulesets), not two competing
  enforcement layers.
- The exact ruleset definitions (and the commands to apply / verify them) are
  recorded as the authoritative source in the runbook
  `mddocs/operations/runbooks/branch-protection-rulesets.md`. The live GitHub
  configuration is the enforcement layer; the runbook is the source of truth for
  how it was intended to be configured.
- Any change to the ruleset policy requires a new superseding ADR (forward-only,
  ADR-0035). A ruleset edit is data/schema change and is not an in-place
  amendment to this decision.

## Consequences

**Positive:**
- `main` append-only / merge-only is enforced at the server, not just by process.
- Force-push, rebase, and history rewrite on `main` are blocked for everyone.
- Only authorized collaborators can create `feat/*` branches.
- The merge gate on `main` enforces CI (`verify`), up-to-date branches, and signed
  commits.
- Rulesets are auditable and versioned in the runbook.

**Negative / Trade-offs:**
- Single-operator means there is no human-approval gate on `main`; the gate is the
  pull-request workflow plus CI and signatures.
- The operator account is a bypass actor on `main`, so an agentic session running
  under that identity could in principle bypass the server rule. This is the cost
  of never locking the operator out; the first line of defense is the local
  pre-commit hook suite (ADR-0022) and HIL discipline.
- GitHub-specific: the policy is only enforceable where rulesets exist.

**Neutral:**
- The process rules in `PROCESS.md` §5 and the roll-forward policy remain binding
  independent of the server configuration.

## Implementation Notes

- Runbook: `mddocs/operations/runbooks/branch-protection-rulesets.md`.
- The `release/vX.Y.Z-prep -> main` merge and the `main -> dev` merge-back
  (PROCESS.md §5) continue to work because the operator is a bypass actor on
  `main`.
- Supersession recorded in `mddocs/management/governance/decisions/supersession-ledger.yaml`
  (ADR-0004 -> ADR-0036).
