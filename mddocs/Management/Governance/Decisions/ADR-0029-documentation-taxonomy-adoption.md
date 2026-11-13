# ADR-0029: Documentation and Knowledge Taxonomy Adoption

**Date:** 2026-11-12
**Adopted:** 2026-11-12
**Status:** accepted
**Supersedes:** — (defers ADR migration to a future ADR)
**Superseded by:** —

## Context

AgenticCore's `mddocs/` directory is the harness's primary documentation surface. It currently contains approximately 150 tracked artefacts across ADRs, runbooks, reference architecture, onboarding content, release notes, scripts, MCP services, and seed data. The structure is flat or loosely grouped — there is no consistent hierarchy, no metadata contract, and no governed classification model.

As the corpus grows (28 ADRs, 18 runbooks, 15 reference documents, a growing script set, and increasing project activity), three problems are becoming visible:

1. **Discoverability.** Agents and humans navigating `mddocs/` have no predictable structure. An artefact's location tells you its format (runbook, ADR, script) but not its purpose or governance role.

2. **Classification discipline.** New artefacts are placed by convention rather than by rule. Cross-domain artefacts (a guardrail that is runbook-shaped, a project script that is harness-owned) are placed by local judgment with no governing principle, leading to inconsistent placement over time.

3. **Lifecycle management.** There is no standard mechanism for retiring obsolete content, promoting activity-local results to durable project artefacts, or tracking the lifecycle state of documentation. Git retains history, but there is no taxonomy-level contract for what "superseded" or "retired" means at the artefact level.

These problems are not urgent today — the corpus is still small enough that humans can navigate it. But they are structural, and they compound. The absence of a metadata contract means every new artefact is a fresh classification decision made without a reference framework. The absence of a lifecycle model means obsolete content accumulates without a defined retirement path.

A separate concern — knowledge-management tooling (Obsidian, graph-backed memory), reduced churn of `.md` files, efficient memory management backends — is noted as future value but is **not** the motivation for this ADR. It is downstream of the metadata contract, not the reason to adopt it.

## Decision

### Guiding principle

The taxonomy governs **documentation and metadata contracts**. The metadata on a tool is the contractual record of its owner, its domain, and the governance it enforces or participates in. **Physical file location is downstream of both.** Where a file sits today is not what governs it — the frontmatter contract is. Physical location is an execution detail to be resolved by a future migration ADR, not a prerequisite for adoption.

This means:
- A tool's *governance identity* is defined by its frontmatter (`enforces: ADR-XXXX`, `owner`, `lifecycle`, `domain`), not by its directory path.
- A tool's *discoverability* is defined by the metadata query surface, not by human directory navigation.
- A tool's *accountability* — who owns it, what policy it enforces, what process it participates in — is visible without reading its content.
- Relocating a file does not change its governance identity; relocating a file does change its governance identity if the frontmatter is not updated alongside it.

### Sub-decisions

Adopt the proposed documentation and knowledge taxonomy (`PROPOSAL-DKT-0001`, v0.4) as the governance framework for all current and future `mddocs/` artefacts, with the following resolved sub-decisions:

| Decision | Resolution |
|---|---|
| D1 — ADR migration scope | Forward-only. New ADRs use the new structure from approval onward. Existing 28 ADRs remain in `mddocs/adr/`. A future migration ADR governs the physical `git mv`. |
| D2 — ADR canonicity during transition | Directed coexistence. Both `mddocs/adr/index.md` and `mddocs/Management/Governance/Decisions/index.md` are live, each using the metadata contract with `primary: true/false` and `redirect`. ADR numbering is a flat global sequence independent of physical location. |
| D3 — Cross-domain resolution | No automatic primary-destination rule. Each cross-domain artefact is reviewed case-by-case. Resolution rationale is recorded in the activity file before the location is committed. The `primary: true/false` pattern (from D2) is the general-purpose resolution tool. |
| D4 — Script classification | Annotate-first, restructure-later. All executables and sidecars receive frontmatter (or `.meta.yaml` companion) encoding `domain`, `category`, `process`, `owner`, `lifecycle`, and where applicable `enforces: ADR-XXXX`, `allowed_in_adopter_repos`, `source_activity`, `migrated_from`. Physical restructuring to `Management/Tools/` or `Projects/<context>/Tools/` happens under a future migration ADR. |
| D5 — `AGENTICCORE_SPEC.md` | Directed coexistence. Stays at `mddocs/AGENTICCORE_SPEC.md` as `primary: true`. Companion stub at `mddocs/Management/Architecture/System/AgenticCore-Spec.md` as `primary: false` with `redirect`. No physical move. |
| D6 — Seed backlog | Directed coexistence. `mddocs/backlog.md` (live, `lifecycle: active`, `primary: true`) and `mddocs/scripts/seed/mddocs/backlog.md` (template, `lifecycle: template`, `primary: false`) carry mutual `redirect` frontmatter. Distinct lifecycles; distinct roles. |
| D7 — Guardrail runbooks | Directed coexistence. `credential-identity-guard.md` and `secret-guard.md` stay at current paths as `primary: true`. Frontmatter adds `security_category: guardrail` and `governance_context` to make their security purpose machine-readable. No physical move. |
| D8 — Review ledger runbook | Directed coexistence. `review-ledger-runbook.md` stays at current path as `primary: true`. Frontmatter adds `assurance_category: review-governance` and `governance_context`. No physical move. |

**Governing principle (restated from Decision section):** Artefacts are governed by their frontmatter contract, not by their directory path. Physical file location is an execution detail; the metadata contract is the authority. All eight sub-decisions are consistent with this principle. No sub-decision defers the metadata contract to a future step; all sub-decisions defer only physical restructuring.

## Consequences

**Positive:**
- Every `mddocs/` artefact has a machine-readable metadata contract from the point of adoption. Agents and tools can discover and classify content by purpose and lifecycle, not by path convention.
- The reconciliation exercise (see `ACT-DKT-0002`) confirmed that the proposed structure absorbs the current 150-file corpus with no structural contradictions and no requirement to move files at adoption.
- All eight decision points resolved. No outstanding structural objections remain.
- The D1/D2 pattern (adopt metadata now, defer physical restructuring) is a repeatable template for future corpus changes. Adoption risk is minimized; rollback is a metadata change only.
- Governance enforcement scripts (git hooks, pre-commit gates) gain a standard `enforces: ADR-XXXX` field, making the policy-to-implementation chain traceable without reading file content.
- Project-activity scripts gain a graduation path to a shared pool (`lifecycle: shared` with `migrated_from` provenance), supporting the "reduced churn" goal by providing a defined retirement and promotion mechanism for activity-local artefacts.

**Negative / Trade-offs:**
- Two index files coexist for ADRs (`mddocs/adr/` and `Management/Governance/Decisions/`) during the transition period. Agents must understand the `primary: true/false` contract to find the active index. This is a temporary state; the migration ADR will collapse to one canonical path.
- The script annotation pass (D4) requires one-time human effort to classify approximately 50 executables and sidecars. This effort is front-loaded but produces durable metadata that travels with the files through any future restructuring.
- Seven of eight guardrail and assurance runbooks remain in their current `operations/runbooks/` paths with frontmatter registering their security and assurance purpose. They are discoverable by metadata query but not by directory navigation until a future migration ADR physically relocates them.
- The taxonomy's `Projects/` tree is unseeded. No `Projects/<context>/` directories exist today. The structure is defined and ready for first use, but it is not exercised in production until an adopted project context is live.

**Neutral:**
- The Obsidian/graph-backed memory and knowledge-management tooling direction is noted as future value. It does not change this adoption decision and is not in scope for the implementation of the taxonomy itself. The metadata contract produced by this ADR is a prerequisite for any future tooling integration; the ADR does not depend on that tooling being in place.
- ADR-0015 (framework distribution and adoption model) is not affected by this ADR. The adoption contract for adopter projects remains unchanged. If `Projects/<context>/` naming conventions ever need to be imposed on adopter workspaces, that is a separate ADR scoped to ADR-0015 amendment.

## Implementation Notes

**Supporting evidence:** `ACT-DKT-0002` (Taxonomy Reconciliation — `mddocs/Management/Work/Activities/ACT-DKT-0002-taxonomy-reconciliation/index.md`) contains the full artefact inventory, reconciliation table, cross-domain tension analysis, and the rationale for each of the eight sub-decisions.

**Immediate actions upon HIL approval (this ADR):**
1. Establish `mddocs/Management/Work/Activities/ACT-DKT-0002` as an approved management-plane activity record.
2. Begin the one-time frontmatter annotation pass for all executables and sidecars (D4). Assign `id`, `document_type`, `domain`, `category`, `owner`, `lifecycle`, and `related.paths`. Use `.meta.yaml` companion files for `.sh` and `.py` executables.
3. Add `primary`, `redirect`, and domain-specific fields (`security_category`, `assurance_category`, `process`) to the seven artefact frontmatter sets identified in D5, D6, D7, and D8.
4. Create companion stubs at `Management/Architecture/System/AgenticCore-Spec.md`, `Management/Security/Guardrails/Credential-Identity/`, `Management/Security/Guardrails/Secret-Management/`, and `Management/Assurance/Reviews/Ledger-Runbook/` as `primary: false` with `redirect` back to the live files.

**Future actions (governed by separate tickets / ADRs):**
1. **Migration ADR** (D1/D2): governs the `git mv` operations for the 28 existing ADRs from `mddocs/adr/` to `Management/Governance/Decisions/` and collapses the dual-index redirect.
2. **Script physical restructuring** (D4): governs the move of annotated executables and sidecars to `Management/Tools/` and `Projects/<context>/Tools/`.
3. **Link integrity audit** (Q2): validates all internal links in the corpus against the post-migration structure before the migration ADR is submitted.
4. **Projects/ seeding** (Q5): first `Projects/<context>/` directory is created when the first adopted customer context is live.

**Out of scope for this ADR:** Physical directory restructuring, ADR migration, project context seeding, and any change to ADR-0015 or the adopter contract. None of those are prerequisites for taxonomy adoption; all are follow-on work to be scoped when the metadata contract has soak time.
