# ADR-0025: Framework Write-Protection Model — Layered Newcomer-Write Control

**Date:** 2026-08-18
**Status:** proposed
**Supersedes:** —
**Superseded by:** —

## Context

Field feedback from the first fresh v1.1.0 deployment (TC-050) raised a distinct
concern from the adopter-direction confidentiality control that TC-050 addressed:
**a person new to the framework who clones AgenticCore should not be able to
commit or merge to the framework's `main` branch.** This is a concern about the
framework repository protecting itself from newcomer writes — the mirror image of
TC-050's concern, which was about customer code leaking *into* the framework during
adoption. The two concerns were tracked together under a single TC-051 ticket and
then split: TC-051 retains the Flow B `.gitignore` reconciliation gap; this ADR
documents the decision record for the newcomer write-protection half, tracked as
TC-059.

`TC-002` was the historical task that was expected to own "server-side branch
protection" (see [ADR-0004](adr-0004-main-branch-protection.md), which named TC-002
as the scope for server-side enforcement). TC-002 instead became the mdBook CI
pipeline task and merged with Git runner execution deferred. No live ticket has
owned the documented server-side branch-protection posture since. This ADR closes
that orphaned governance-documentation gap.

This ADR does not introduce a new control. It verifies and documents an existing,
already-effective layered control, and records the HIL decisions that shape how the
framework project manages the residual risk in that control.

### Verified as-is state (2026-08-18)

The following was confirmed by a read-only query against the framework's Git
project protected-branch configuration. These are facts, not proposals:

| Branch | Push access | Merge access | Force-push | Code-owner approval required |
|---|---|---|---|---|
| `main` | Maintainers only | Maintainers only | disabled (`allow_force_push: false`) | `false` |
| `dev` | not protected — any Developer-or-above member may push directly | not protected | n/a | n/a |

`main` is the only protected branch on the framework remote. Project membership at
the time of verification (roles only — no usernames are recorded in this document
per the framework's no-PII rule): 1 Owner, 1 Maintainer, 1 Developer.

**Conclusion of verification:** the core concern raised by TC-059 — "a newcomer with
a clone cannot commit or merge to framework `main`" — is already enforced server-side.
No live remote reconfiguration is performed by this ADR; it is a documentation and
verification artifact. Any future change to the live protected-branch configuration
is HIL-gated and out of scope here.

## Decision

Adopt and document a three-layer write-protection model for the framework
repository, and record two governance stances the HIL has settled regarding it.

### 1. Layer 1 — Adoption posture: the severed-remote model already excludes adopters

[ADR-0015](adr-0015-framework-distribution-adoption-model.md) D-1 and D-3 establish
that adopters do not obtain the framework via a live remote at all. Adopters run
`export-framework.sh` against a versioned release, which severs any framework
remote, upstream reference, and commit history from the resulting adopter repository
(D-1; hardened further by the D-7.3 verified-severance assertion and D-7.5
history-scrub verification added under TC-050). An adopter optionally adds the
framework back as a named, pull-only upstream (D-3) — this is supported but never
required, and grants no push path back to the framework.

Consequence: "newcomer as adopter" cannot write to the framework by construction.
There is no remote to push to. This layer requires no further action — it is a
byproduct of the adoption model already decided in ADR-0015.

### 2. Layer 2 — Server-side branch protection on `main` (verified, not newly introduced)

For "newcomer as direct contributor with a clone of the framework repository itself"
(distinct from an adopter), the enforced control is the Git protected-branch
configuration verified above: `main` push and merge are both restricted to the
Maintainer role, and force-push is disabled for all roles. This matches the process
rule already stated in [ADR-0004](adr-0004-main-branch-protection.md) and
[ADR-0001](adr-0001-bootstrap-architecture.md) Decision 7 (branch protection and
merge strategy) — ADR-0004 named TC-002 as the scope for this server-side
enforcement; this ADR records that the enforcement is in place and reassigns
ownership of the documentation/verification scope to TC-059, since TC-002 no longer
carries it (see Context).

**`dev` is intentionally left unprotected.** This is a deliberate choice, not an
oversight: the framework's development model is open at the `dev` and feature-branch
level — any Developer-or-above member may push directly to `dev` or open a feature
branch — while the release branch (`main`) remains gated. The real control on `main`
is not merely the server-side rule in isolation; it is that rule combined with the
[PROCESS.md](../../PROCESS.md) review process — the LGTM acceptance gate, the
security-reviewer and docs-reviewer gates, and the `--no-ff` merge convention that
preserves review history (PROCESS.md §5; ADR-0001 Decision 7). If the framework
extends its open-development posture further, openness belongs at the development
layer (`dev`, feature branches); the release layer (`main`) stays gated regardless.

**CODEOWNERS approval on `main`: recommended, not required.** Git's
`code_owner_approval_required` setting is currently `false` on `main`. Given that
`main` is already Maintainer-only for both push and merge, and that the PROCESS.md
review gate (§7, §8) provides the substantive review layer, Maintainer-only-merge
plus the existing review process is judged sufficient today. Enabling
`code_owner_approval_required` is recorded here as an available future hardening
step — not a mandate — should the Maintainer pool grow beyond a size where informal
review coordination remains reliable.

### 3. Layer 3 — Role management is the real residual risk

The HIL's assessment, recorded here as the governing view: the branch-protection
rule on `main` is only as strong as who holds the Maintainer and Owner roles. The
rule itself (Layer 2) is sound and verified; the place governance attention belongs
is **who is granted those roles and when**. The guardrail:

- Newcomers are onboarded at the **Developer role or below**. Developer grants push
  access to `dev` and the ability to open branches and merge requests — sufficient
  to contribute through the full PROCESS.md task/branch/review flow — but not push
  or merge access to `main`.
- Maintainer and Owner roles are granted **deliberately and sparingly**, as an
  explicit decision distinct from onboarding. Role elevation is not a default or
  automatic outcome of tenure or contribution volume.
- Project membership and role assignments are **reviewed periodically** (at minimum,
  at each framework release cutover) to confirm the Maintainer/Owner pool still
  reflects an intentional, minimal set.

This is a role-management practice, not a new server-side mechanism. It has no
schedule-enforcing tooling as of this ADR; the practice is the guardrail.

### 4. Governance gap closure

`TC-002` no longer owns the server-side branch-protection scope it was originally
assigned under ADR-0004 (it completed as the mdBook CI pipeline task with runner
execution deferred). This ADR is the record that closes that orphaned scope: the
documentation and verification of the framework's write-protection posture is owned
by TC-059 going forward. No further ticket is spawned to "re-verify" the server-side
setting on a schedule; role-review cadence (Layer 3) is the mechanism that keeps the
posture current.

## Consequences

**Positive:**

- The framework's core write-protection concern (newcomer cannot commit/merge to
  `main`) is confirmed already enforced — no urgent remediation is required.
- The layered model (adoption posture, server-side rule, role management) is written
  down in one place, closing the ambiguity left by TC-002's scope drift.
- The `dev`-open stance is now a documented, deliberate decision rather than an
  unexplained gap a future audit might flag as an oversight.
- CODEOWNERS is recorded as an available hardening lever without adding process
  weight the current Maintainer pool size does not need.
- The orphaned TC-002 governance-documentation gap is closed by explicit
  reassignment to TC-059, so no control silently loses an owning ticket again.

**Negative / Trade-offs:**

- `dev` remains a soft target: any Developer-or-above member can push directly to
  `dev` without review. This is accepted risk under the open-development stance, not
  an oversight — but it means bad commits can land on `dev` without a gate until the
  `dev` → `main` merge review.
- CODEOWNERS not being required means `main` merge review currently relies on the
  Maintainer role and PROCESS.md discipline rather than a file-path-scoped
  server-enforced reviewer requirement. If the Maintainer pool grows, this
  trade-off should be revisited (see Layer 2).
- Role-review cadence (Layer 3) is a documented practice with no automated
  enforcement or reminder mechanism as of this ADR. Drift is possible if the
  practice is not actively followed.

**Neutral:**

- No live Git configuration is changed by this ADR. It is a documentation and
  verification artifact only; any future change to `main` or `dev` protection is a
  separate, HIL-gated decision.

## Related

- [ADR-0015: Framework Distribution and Adoption Model](adr-0015-framework-distribution-adoption-model.md) — D-1 (export-and-init, no framework remote in the adopter repo) and D-3 (optional, pull-only versioned-baseline upstream) establish Layer 1
- [ADR-0001: Bootstrap Architecture](adr-0001-bootstrap-architecture.md) — Decision 7 (branch protection and merge strategy) establishes the `main`/`dev`/`release` tier model this ADR verifies against
- [ADR-0004: `main` Branch Protection and Immutability](adr-0004-main-branch-protection.md) — the process-level append-only/merge-only rule for `main`, and the original TC-002 server-side-enforcement scope this ADR reassigns
- [PROCESS.md](../../PROCESS.md) — §5 (branch and merge convention), §7 (human acceptance gate), §8 (security gate) — the review-process component of Layer 2
