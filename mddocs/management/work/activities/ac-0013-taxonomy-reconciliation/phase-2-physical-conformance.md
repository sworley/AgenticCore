---
document_type: analysis
title: Phase 2 - Physical Conformance Mapping and Link-Rewrite Budget
status: in-review
lifecycle: in-review
version: "0.1"
date: 2026-11-21
related:
  paths:
    - "./index.md"
    - "../../../governance/decisions/ADR-0029-documentation-taxonomy-adoption.md"
    - "../../../governance/decisions/ADR-0035-adr-evolution-forward-only-supersede.md"
    - "../../../governance/decisions/ADR-0032-classification-metadata-id-contracts.md"
---

# Phase 2 - Physical Conformance Mapping and Link-Rewrite Budget

> Status: **in-review**. This is the mapping and cost budget for the physical
> conformance layer introduced by the additive revision to ADR-0029. No file
> moves are performed from this document. The mapping is reviewed before any
> move is staged.

## 1. Purpose and scope

This document records the mapping of the management-plane corpus into the
added homes, and the link-rewrite budget for that migration. It extends
AC-0013, which reconciled the original `mddocs/` inventory against the proposed
management tree.

Scope: the physical conformance of the management-plane content into the added
homes (`agentic/`, `delivery/`, `runbooks/`, `tooling/mcp/`, plus the security and
assurance reroutes and the seeding of `audits/evidence/` and
`governance/exceptions/`).

Out of scope (deferred to a separate top-level taxonomy decision): adopter-facing
content in `reference.architecture/`, `onboarding/`, `faq/`, `examples/`, the
root anchors, the `scripts/` subtree, the historical `adr/` records (ADR-0035),
and the unseeded `projects/` tree. The tooling-home relocation of the `scripts/`
subtree remains a separate decision (ADR-0032 Amendment 2026-11-20).

## 2. Migration pattern

Each move uses the metadata-first `primary` / `redirect` contract already
established in ADR-0029 (D2/D5/D6):

- The new home file carries the full content and is `primary: true`.
- The old path is replaced by a thin stub that is `primary: false` with a
  `redirect` to the new path, so every existing link continues to resolve and
  `check-links` / `mdbook build` stay green.
- Cross-references are additionally rewritten where the canonical tree should
  point at the primary home (the link-rewrite budget below).

This means the migration is additive and reversible at each step, and the build
never breaks even before links are rewritten.

## 3. Move mapping

> **Revision 2026-11-22.** The five taxonomy dispositions (items #1-#5,
> recorded after section 6) revise the destinations below. Notably, the
> `runbooks/` home dissolves (item #1) and `bench-model` + `agentic-workflow-overview`
> move to `management/architecture/` (item #5). The tables here are the baseline;
> the dispositions govern the final destination.

### 3.1 `management/agentic/`

| Current path | New path |
|---|---|
| `onboarding/agent-roster.md` | `management/agentic/roster/agent-roster.md` |
| `onboarding/bench-model.md` | `management/architecture/bench/bench-model.md` (rev, item #5) |
| `onboarding/agentic-workflow-overview.md` | `management/architecture/workflow/agentic-workflow-overview.md` (rev, item #5) |
| `reference.architecture/shared-context.md` | `management/agentic/context/shared-context.md` |
| `reference.architecture/agent-authoring-workflow.md` | `management/agentic/procedures/authoring-workflow.md` (rev, item #1) |
| `operations/runbooks/configure-agents.md` | `management/agentic/procedures/configure-agents.md` |

### 3.2 `management/delivery/`

| Current path | New path |
|---|---|
| `release-notes/v0.6.0.md` | `management/delivery/releases/v0.6.0.md` |
| `release-notes/v0.7.0.md` | `management/delivery/releases/v0.7.0.md` |
| `release-notes/UNRELEASED.md` | `management/delivery/releases/UNRELEASED.md` |
| `reference.architecture/release-process.md` | `management/delivery/release-process.md` |
| `reference.architecture/release-notes-template.md` | `management/delivery/release-notes-template.md` |
| `reference.architecture/sign-off-package.md` | `management/delivery/sign-off-package.md` |

### 3.3 `management/tooling/mcp/`

MCP documentation content moves under the tooling category, one section per MCP
server so each is identifiable by purpose. Native runtime code stays in place as
an established runtime anchor and is referenced, not moved.

| Current path | New path |
|---|---|
| `mcp/index.md` | `management/tooling/mcp/README.md` |
| `mcp/mcp-rag-docs/README.md` | `management/tooling/mcp/mcp-rag-docs/README.md` |
| `mcp/mcp-rag-docs/cve-scan.txt` | `management/tooling/mcp/mcp-rag-docs/cve-scan.txt` |

The `review-ledger` server gets its own section under
`management/tooling/mcp/review-ledger/`, seeded with a home index; its primary
operations content is the review-ledger runbook, which moves to
`management/assurance/reviews/ledger-runbook/` (D8), and is cross-referenced here.

Native runtime code stays in place and is referenced, not moved (AC-0013 D4 / P10):

- `mddocs/mcp/mcp-rag-docs/server.py` - rag-docs server.
- `mcp/review-ledger/server.py` (harness root, with `pyproject.toml`) - the
  review-ledger server, an established runtime anchor. The prior taxonomy
  proposal (`.tmp/AgenticCore-Documentation-Knowledge-Taxonomy-Proposal.v4.md`)
  explicitly required that `mcp/review-ledger/` not be moved or redefined by
  implication, so it is not in the move set.

`cve-scan.txt` is flagged as a cross-domain security asset (see section 6).

### 3.4 `management/security/guardrails/` (reroute from runbooks, D7)

| Current path | New path |
|---|---|
| `operations/runbooks/credential-identity-guard.md` | `management/security/guardrails/credential-identity/credential-identity-guard.md` |
| `operations/runbooks/secret-guard.md` | `management/security/guardrails/secret-management/secret-guard.md` |

The existing `index.md` stubs in those two directories become the home index, with
the moved document `primary: true`.

### 3.5 `management/assurance/reviews/` (reroute from runbooks, D8)

| Current path | New path |
|---|---|
| `operations/runbooks/review-ledger-runbook.md` | `management/assurance/reviews/ledger-runbook/review-ledger-runbook.md` |

The existing `index.md` stub becomes the home index.

### 3.6 `management/runbooks/` (dissolves, item #1)

The `management/runbooks/` home dissolves. All residents re-parent to the single
procedures home `management/agentic/procedures/`, as agentic procedures. The
harness self-maintenance items carry an inline manual fallback section.

| Current path | New path |
|---|---|
| `operations/runbooks/agent-authoring-workflow.md` | `management/agentic/procedures/agent-authoring-workflow.md` |
| `operations/runbooks/agent-session-tracking.md` | `management/agentic/procedures/agent-session-tracking.md` |
| `operations/runbooks/ai-doc-session-commit-discipline.md` | `management/agentic/procedures/ai-doc-session-commit-discipline.md` |
| `operations/runbooks/bench-recovery.md` | `management/agentic/procedures/bench-recovery.md` |
| `operations/runbooks/branch-protection-rulesets.md` | `management/agentic/procedures/branch-protection-rulesets.md` |
| `operations/runbooks/build-publish-mddocs.md` | `management/agentic/procedures/build-publish-mddocs.md` |
| `operations/runbooks/check-links-runbook.md` | `management/agentic/procedures/check-links-runbook.md` |
| `operations/runbooks/git-sync-runbook.md` | `management/agentic/procedures/git-sync-runbook.md` |
| `operations/runbooks/hook-rollback.md` | `management/agentic/procedures/hook-rollback.md` |
| `operations/runbooks/rotate-git-pat.md` | `management/agentic/procedures/rotate-git-pat.md` |
| `operations/runbooks/session-continuity.md` | `management/agentic/procedures/session-continuity.md` |
| `operations/runbooks/session-reasoning-log.md` | `management/agentic/procedures/session-reasoning-log.md` |
| `operations/runbooks/setup-mddoc.md` | `management/agentic/procedures/setup-mddoc.md` |
| `operations/runbooks/sync-agent-definitions.md` | `management/agentic/procedures/sync-agent-definitions.md` |
| `operations/runbooks/sync-opencode-config.md` | `management/agentic/procedures/sync-opencode-config.md` |

The `management/runbooks/README.md` index is removed (no operational runbook
home in the management plane; its index role is superseded by the
`management/agentic/procedures/` home index).

## 4. New homes seeded without content move

| Home | Content |
|---|---|
| `management/audits/` + `management/audits/evidence/` | Seeded with a home index. Populated on first gate run (reconcile, check-links, mdbook build, coverage). |
| `management/governance/exceptions/` | Seeded with a home index and the waiver-log contract. Populated on first waiver (WAV-XXXX). |

## 5. Home indices

Each added or relocated home gets a `README.md` or home `index.md` carrying the
metadata contract (document_type, category identity, lifecycle semantics) and
registering its residents. The moved documents retain their frontmatter and gain
`primary: true`; the old paths keep a `primary: false` redirect stub.

## 6. Cross-domain items (D3)

| Item | Primary home | Secondary reference |
|---|---|---|
| `mcp/mcp-rag-docs/cve-scan.txt` | `management/tooling/mcp/mcp-rag-docs/` | security (cve-scan data feed) |
| `operations/runbooks/rotate-git-pat.md` | `management/runbooks/` | security (credential rotation) |
| `operations/runbooks/ai-doc-session-commit-discipline.md` | `management/runbooks/` | governance (commit discipline) |
| `reference.architecture/agent-authoring-workflow.md` vs `operations/runbooks/agent-authoring-workflow.md` | `management/agentic/procedures/` and `management/runbooks/` | consolidate the two, decide primary |

Each is reviewed in HIL before the move is staged (D3), and the disposition is
recorded here.

**Dispositions (stage 1 `runbooks/`, 2026-11-21):**

- `operations/runbooks/rotate-git-pat.md` -> primary `management/runbooks/rotate-git-pat.md`.
  Secondary reference: security (credential rotation); the operational cross-reference
  is retained in the runbooks home.
- `operations/runbooks/ai-doc-session-commit-discipline.md` -> primary
  `management/runbooks/ai-doc-session-commit-discipline.md`. Secondary reference:
  governance (commit discipline); the operational cross-reference is retained in
  the runbooks home.
- `operations/runbooks/agent-authoring-workflow.md` -> primary
  `management/runbooks/agent-authoring-workflow.md`. The
  `reference.architecture/agent-authoring-workflow.md` copy is NOT consolidated in
  this stage; it is deferred to stage 2 (`agentic/`), where the two copies are
  reconciled and the primary decided (pending HIL review).
- `mcp/mcp-rag-docs/cve-scan.txt` -> not touched in this stage; deferred to stage 4
  (`tooling/mcp/`), where it moves with the MCP docs home.

**Dispositions (stage 2 `agentic/`, 2026-11-21):**

- `onboarding/agent-roster.md` -> primary `management/agentic/roster/agent-roster.md`.
  Harness-internal agent model; not adopter-facing onboarding, so in scope.
- `onboarding/bench-model.md` -> primary `management/agentic/context/bench-model.md`.
  Harness-internal bench/worktree model; not adopter-facing onboarding, so in scope.
- `onboarding/agentic-workflow-overview.md` -> primary
  `management/agentic/overview/agentic-workflow-overview.md`. Harness-internal
  workflow description, not adopter-facing onboarding, so in scope.
- `reference.architecture/shared-context.md` -> primary
  `management/agentic/context/shared-context.md`. Harness-internal shared agent
  context; in scope.
- `reference.architecture/agent-authoring-workflow.md` -> PRIMARY resolved to
  `management/runbooks/agent-authoring-workflow.md` (runbook form). The two unique
  blocks (hook authoring procedure + authoring-agent execution model) were folded
  into the runbook primary; the `reference.architecture/` path becomes a
  `primary: false` redirect stub. This deviates from the section 3.1 target
  `management/agentic/procedures/authoring-workflow.md` per HIL decision (2026-11-21)
  to keep a single authoring-workflow authority.
- `operations/runbooks/configure-agents.md` -> primary
  `management/agentic/procedures/configure-agents.md`. Previously a reroute file
  kept in `operations/runbooks/`; moved in this stage with the agentic set.

**Dispositions (taxonomy decision 2026-11-22: artifact-class split, dissolves
`management/runbooks/`):**

Item #1 of the conformance review is resolved by separating runbooks from
procedures by **artifact class**, not by domain:

- **Agentic procedure** (management plane, `.01`): deterministic, script / gate
  backed harness machinery, executed by agents. Includes harness self-maintenance
  (`git-sync`, `check-links`, `build-publish-mddocs`, `bench-recovery`,
  `rotate-git-pat`, `hook-rollback`, `branch-protection-rulesets`,
  `setup-mddoc`). The manual-parity fallback for these becomes an inline "manual
  fallback" section inside the procedure. **No operational runbook lives in
  management.**
- **Operational runbook** (project plane, `.00`): human-facing manual-parity for
  adopted work; agentically authored and agentically validated (the agent writes
  it and runs it to prove a human can follow it), then HIL-executed. Packaged as
  a directory per runbook: `projects/<ctx>/runbooks/<runbook-id>/` with
  `index.md` plus `scripts/` (per-step supports and a combined `run-all` script).

Consequences recorded for implementation (not yet staged):

1. `management/runbooks/` dissolves. Both the agentic-domain items and the
   harness self-maintenance items re-parent to a single procedures home,
   `management/agentic/procedures/` (clear, concise, hard to mis-read). The
   harness self-maintenance items are re-borne as agentic procedures with an
   inline manual fallback.
2. `projects/<context>/runbooks/` is added to the project-plane context grammar
   with the runbook package shape.
3. The management plane gains a runbook contract (frontmatter, structure,
   validation gate) so project runbooks follow the same metadata-first
   discipline (same structure, different focus).

**Disposition (2026-11-22, item #2: spec is a root anchor, option A):**

The authoritative harness spec is recognized as a **cross-plane governing-body
anchor**, not management-plane content. Resolution: option A.

- `mddocs/AGENTICCORE_SPEC.md` stays at the corpus root as `primary: true`,
  `document_type: spec`. It is the harness-wide governing body covering both the
  management (`.01`) and project (`.00`) planes.
- `mddocs/management/architecture/system/AgenticCore-Spec.md` is rewritten as a
  clearly-labeled cross-plane anchor pointer: it states the spec is harness-wide,
  covers both planes, and lives at the corpus root by design. `primary: false` +
  `redirect` retained.
- `management/architecture/` is a real home reserved for management-plane
  structural content (not pointer-only). It holds real content when such content
  exists; the spec pointer is its governing anchor entry.

Three-level model recorded:
- Harness (governing body): the root spec, covering both planes.
- Management plane (`.01`): supervisor over the harness, adaptive, adjustable as
  projects evolve; owns the harness's own rules and structure.
- Project plane (`.00`): separate; manages projects and sub-activities; governed
  by (not governing) the harness; improvement goes via management promotion.

Two distinct architectures, both governed by the top-level harness:
- Management architecture (`.01`): governance, security guardrails, assurance,
  agentic machinery, delivery, tooling.
- Project architecture (`.00`): context grammar, activities/artifacts/evidence,
  operational runbooks, plus the adopter-facing `reference.architecture/`.

**Disposition (2026-11-22, item #3: self-gating discipline, stages 3-6 proceed):**

The four self-gating homes are the physical expression of the harness governing
itself (item #2 model), not optional polish. Stages 3-6 proceed as staged.

- `delivery/` and `tooling/mcp/` are straightforward moves (native MCP runtime
  stays in place; native `mcp/review-ledger/server.py` and
  `mddocs/mcp/mcp-rag-docs/server.py` remain referenced, not moved).
- `audits/evidence/` is **boundary-captured gate provenance** (reading i): gate
  results (reconcile CLEAN, check-links, mdbook build) are captured as evidence
  at **governance boundaries** (release, supersession, waiver, activity close),
  not per-commit, to avoid churn.
- `governance/exceptions/` uses the `WAV-XXXX` waiver-log contract (ADR-0035);
  the home + contract are seeded at stage 6 and populated on first waiver.

**Disposition (2026-11-22, item #4: transitional top-level, target shape recorded):**

The top-level `mddocs/` is accepted as **transitional by design** (staged,
per-domain, gated migration plus adopter-facing deferral). No top-level reorg is
performed now. The target top-level shape is recorded so the migration has a
terminus:

```
mddocs/
├── AGENTICCORE_SPEC.md      corpus anchor (governing body)
├── SUMMARY.md  index.md  configuration.md   corpus anchors / config
├── management/              .01  supervisor plane  (load-bearing)
├── projects/                .00  governed plane   (adopted work + operational runbooks)
├── reference.architecture/  adopter-facing  (how to adopt)
├── onboarding/ faq/ examples/   adopter-facing
└── book/                       build output (excluded)
```

The remainder is deliberately deferred (adopter-facing: `reference.architecture/`,
`onboarding/`, `faq/`, `examples/`) or governed by its own ADRs (`adr/` via
ADR-0035, `scripts/` via ADR-0032), not an oversight. `operations/`, `mcp/`,
`release-notes/` resolve into `management/`/`projects/` as stages 3-6 and the
item-#1 project runbooks land.

**Disposition (2026-11-22, item #5: split structural docs into `architecture/`):**

The `agentic/` home is split by nature (option 2):

- **Move to `management/architecture/`** (structural / how the harness runs agents):
  - `bench-model.md` - the git worktree isolation / execution environment model
    (ADR-0007 isolation boundary).
  - `agentic-workflow-overview.md` - the orchestration / workflow model.
- **Stay in `agentic/`** (agent-namespace + procedures):
  - `agent-roster.md`, `shared-context.md` (agent namespace).
  - `procedures/` (configure-agents, authoring-workflow, and the re-parented
    session / sync / commit procedures from item #1).

This deviates from ADR-0029 exact wording (which lists bench-model and
shared-context under `agentic/`); recorded as a disposition, not an ADR bump.
`management/architecture/` gains its first real load-bearing content (item #2).

## 7. Link-rewrite budget

Counted against the tracked corpus (excluding `book/` build output).

- **126** internal links reference the moved source paths.
- These come from **42** distinct referencing files.
- Of the 33 source paths in the move set, 32 have at least one inward reference.
  The single exception is `mcp/mcp-rag-docs/cve-scan.txt`, a cross-domain data
  asset with no internal link; it moves with the MCP docs home and needs no link
  rewrite. The high-count paths are `sync-agent-definitions.md` (10),
  `git-sync-runbook.md` (9), `review-ledger-runbook.md` (9), `bench-model.md` (9),
  the runbook set, and `configure-agents.md` (6).

Because the migration uses `primary` / `redirect` stubs, the build stays green
before any link is rewritten. The 126 figure is the budget for pointing the
canonical tree at the primary homes and removing the redirect stubs. A
non-stub migration (remove old paths, no redirect) would require all 126 links to
be rewritten in the same change.

## 8. Staging order

Migration is staged by domain, each in its own gated change (reconcile CLEAN,
check-links green, mdbook build green):

1. `runbooks/` (largest population, self-contained).
2. `agentic/` (cross-domain review for the authoring-workflow consolidation).
3. `delivery/` (release records, low risk).
4. `tooling/mcp/` (docs move per server; native code stays in place).
5. `security/guardrails/` and `assurance/reviews/` reroutes (D7, D8).
6. Seed `audits/evidence/` and `governance/exceptions/` home indices.

Each step is independently reviewable and reversible.
