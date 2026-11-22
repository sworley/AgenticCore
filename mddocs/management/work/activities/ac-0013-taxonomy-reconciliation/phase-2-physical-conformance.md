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

### 3.1 `management/agentic/`

| Current path | New path |
|---|---|
| `onboarding/agent-roster.md` | `management/agentic/roster/agent-roster.md` |
| `onboarding/bench-model.md` | `management/agentic/context/bench-model.md` |
| `onboarding/agentic-workflow-overview.md` | `management/agentic/overview/agentic-workflow-overview.md` |
| `reference.architecture/shared-context.md` | `management/agentic/context/shared-context.md` |
| `reference.architecture/agent-authoring-workflow.md` | `management/agentic/procedures/authoring-workflow.md` |
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

### 3.6 `management/runbooks/`

| Current path | New path |
|---|---|
| `operations/runbooks/agent-authoring-workflow.md` | `management/runbooks/agent-authoring-workflow.md` |
| `operations/runbooks/agent-session-tracking.md` | `management/runbooks/agent-session-tracking.md` |
| `operations/runbooks/ai-doc-session-commit-discipline.md` | `management/runbooks/ai-doc-session-commit-discipline.md` |
| `operations/runbooks/bench-recovery.md` | `management/runbooks/bench-recovery.md` |
| `operations/runbooks/branch-protection-rulesets.md` | `management/runbooks/branch-protection-rulesets.md` |
| `operations/runbooks/build-publish-mddocs.md` | `management/runbooks/build-publish-mddocs.md` |
| `operations/runbooks/check-links-runbook.md` | `management/runbooks/check-links-runbook.md` |
| `operations/runbooks/git-sync-runbook.md` | `management/runbooks/git-sync-runbook.md` |
| `operations/runbooks/hook-rollback.md` | `management/runbooks/hook-rollback.md` |
| `operations/runbooks/rotate-git-pat.md` | `management/runbooks/rotate-git-pat.md` |
| `operations/runbooks/session-continuity.md` | `management/runbooks/session-continuity.md` |
| `operations/runbooks/session-reasoning-log.md` | `management/runbooks/session-reasoning-log.md` |
| `operations/runbooks/setup-mddoc.md` | `management/runbooks/setup-mddoc.md` |
| `operations/runbooks/sync-agent-definitions.md` | `management/runbooks/sync-agent-definitions.md` |
| `operations/runbooks/sync-opencode-config.md` | `management/runbooks/sync-opencode-config.md` |

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
