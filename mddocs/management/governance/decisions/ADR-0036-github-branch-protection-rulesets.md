# ADR-0036: GitHub Branch-Protection Rulesets

**Date:** 2026-11-20
**Status:** accepted
**Supersedes:** ADR-0004 (the process-level `main` append-only / merge-only rule; this ADR is its server-side enforcement and extension to the `dev` integration gate)
**Superseded by:** -
**Governed by:** ADR-0035 (forward-only supersede; this supersession is recorded in the supersession ledger)

## Context

ADR-0004 (accepted 2026-06-25) established `main` as an **append-only, merge-only**
branch with a roll-forward policy and no history rewrite. It made clear that
server-side enforcement (branch protection) is the authoritative backstop, and
scoped that configuration to TC-002 (the CI task).

Several things have since changed:

1. **The legacy protection on `main` and `dev` is too loose to be the backstop
   ADR-0004 describes.** Both branches have legacy branch protection that requires
   the `verify` CI check and a pull request, but it does **not** enforce on admins,
   does not require branches to be up to date before merge (`strict: false`), and
   `dev` does not even require signed commits. Neither enforces linear history or
   conversation resolution.

2. **AgenticCore is a single-operator harness.** The HIL is the sole human; every
   agentic session runs under the operator's own GitHub identity and PAT. That
   shapes which protections are even possible:

   - GitHub will not let a user approve their own pull request, so a rule that
     requires approving reviews would make `main` (or `dev`) **un-mergeable** for a
     single-operator repo. The merge gate therefore relies on the pull-request
     workflow plus CI (`verify`), branches up to date, and signed commits - not on
     a human reviewer.
   - Because the agentic sessions share the operator's identity, any bypass actor
     granted to the operator is (in effect) available to those sessions too. The
     operator account is therefore added as a **bypass actor** on both `main` and
     `dev` so that the operator is never locked out; this is a deliberate,
     documented trade-off and makes the rulesets a *process-level* backstop, with
     local pre-commit hooks (ADR-0022) and HIL discipline as the first line of
     defense.

3. **`dev` is the single integration branch and the promotion gate.** Per
   `PROCESS.md` §5, feature/task branches merge to `dev` and `main` is
   append-only / merge-only. A ruleset on `dev` enforces that everything merges
   there through a pull request (with CI and signatures), and a ruleset on `main`
   enforces the immutability and promotion rule. This is the process we want to
   follow, so it is worth backing with the server.

4. **GitHub has superseded legacy branch protection with branch-protection
   rulesets.** Rulesets are declarative, composable, auditable, and can target
   branch patterns (`main`, `dev`), which is exactly the shape needed to enforce
   both the `main` immutability rule and the PR-gated integration into `dev`.

## Decision

Adopt GitHub **branch-protection rulesets** as the server-side enforcement layer
for ADR-0004 and for the PR-gated integration into `dev`. Two active rulesets are
defined:

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

### Ruleset 2 - `dev-strict` (target `dev`)

| Rule | Setting | Rationale |
|---|---|---|
| Branch creation | block | `dev` already exists; prevent accidental re-creation |
| Deletion | block | prevent removing `dev` |
| Non-fast-forward | block | `dev` is shared and never rebased (PROCESS.md §5) |
| Pull request | required | no direct pushes to `dev`; everything lands via a PR |
| Pull request - status checks | require `verify`, strict (branches up to date) | merge gate on the CI green, no stale merges |
| Pull request - approving reviews | 0 (none) | single-operator: self-approval is impossible; gate is CI + workflow |
| Pull request - code-owner review | not required | single-operator: would block merges |
| Signed commits | require | auditable provenance |
| Conversation resolution | not required | single-operator; avoid locking merges on threads with no reviewer |
| Bypass actors | operator account | documented lock-out avoidance (does not weaken the process rule) |

Branch naming is a documented convention (`PROCESS.md` §5) enforced locally, not
via these rulesets. A ruleset cannot validate branch names, and a server-side
selection could risk locking out agentic sessions; the convention lives in the
documentation and the local hook suite (ADR-0022).

### Migration

- The legacy branch protection on `main` **and** `dev` is **removed** once
  `main-strict` and `dev-strict` are active, so there is a single source of truth
  (rulesets), not two competing enforcement layers.
- The exact ruleset definitions (and the commands to apply / verify them) are
  recorded as the authoritative source in the runbook
  `mddocs/operations/runbooks/branch-protection-rulesets.md`. The live GitHub
  configuration is the enforcement layer; the runbook is the source of truth for
  how it was intended to be configured.
- Any change to the ruleset policy requires a new superseding ADR (forward-only,
  ADR-0035). A ruleset edit is a data/schema change and is not an in-place
  amendment to this decision.

## Consequences

**Positive:**
- `main` append-only / merge-only is enforced at the server, not just by process.
- Force-push, rebase, and history rewrite on `main` (and `dev`) are blocked for
  everyone.
- Everything that reaches `dev` must land via a pull request with `verify` CI,
  up-to-date branches, and signed commits - the integration envelope.
- Promotion to `main` is a pull request with the same gate, so `main` stays
  append-only and the release path remains intact.
- Rulesets are auditable and versioned in the runbook.

**Negative / Trade-offs:**
- Single-operator means there is no human-approval gate on `main` or `dev`; the
  gate is the pull-request workflow plus CI and signatures.
- The operator account is a bypass actor on both `main` and `dev`, so an agentic
  session running under that identity could in principle bypass the server rule.
  This is the cost of never locking the operator out; the first line of defense is
  the local pre-commit hook suite (ADR-0022) and HIL discipline.
- GitHub-specific: the policy is only enforceable where rulesets exist.

**Neutral:**
- The process rules in `PROCESS.md` §5 and the roll-forward policy remain binding
  independent of the server configuration.
- The release model is unchanged: `release/vX.Y.Z-prep -> main` (PR) and the
  `main -> dev` merge-back (PR), both via pull requests, so they are not blocked
  by the PR-required rulesets.

## Implementation Notes

- Runbook: `mddocs/operations/runbooks/branch-protection-rulesets.md`.
- The `release/vX.Y.Z-prep -> main` merge and the `main -> dev` merge-back
  (PROCESS.md §5) continue to work because the operator is a bypass actor on both
  `main` and `dev`.
- Branch naming (PROCESS.md §5) remains a documented convention enforced locally;
  the rulesets do not validate branch names.
- Supersession recorded in `mddocs/management/governance/decisions/supersession-ledger.yaml`
  (ADR-0004 -> ADR-0036).
