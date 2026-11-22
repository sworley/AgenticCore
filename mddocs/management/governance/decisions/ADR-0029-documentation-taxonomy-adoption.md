# ADR-0029: Documentation and Knowledge Taxonomy Adoption

**Date:** 2026-11-12
**Adopted:** 2026-11-12
**Revised:** 2026-11-21 (additive revision: physical conformance layer)
**Status:** accepted
**Supersedes:** - (additive revision only; this ADR is not superseded and does not supersede)
**Superseded by:** -

## Context

AgenticCore's `mddocs/` directory is the harness's primary documentation surface. It currently contains approximately 150 tracked artefacts across ADRs, runbooks, reference architecture, onboarding content, release notes, scripts, MCP services, and seed data. The structure is flat or loosely grouped - there is no consistent hierarchy, no metadata contract, and no governed classification model.

As the corpus grows, three problems are structural and compound:

1. **Discoverability.** Agents and humans navigating `mddocs/` have no predictable structure. An artefact's location tells you its format (runbook, ADR, script) but not its purpose or governance role.

2. **Classification discipline.** New artefacts are placed by convention rather than by rule. Cross-domain artefacts (a guardrail that is runbook-shaped, a project script that is harness-owned) are placed by local judgment with no governing principle, leading to inconsistent placement over time.

3. **Lifecycle management.** There is no standard mechanism for retiring obsolete content, promoting activity-local results to durable project artefacts, or tracking the lifecycle state of documentation. Git retains history, but there is no taxonomy-level contract for what "superseded" or "retired" means at the artefact level.

The harness is also moving toward a knowledge management graph (Obsidian, Neo4j). That future needs two complementary things: a typed metadata contract that gives every artefact stable identity, category, lifecycle, and relationships, and an intuitive physical structure that makes those categories legible as a browsable tree and gate-checkable by the harness. This ADR adopts both as a single, coherent model.

## Decision

### Guiding principle

The taxonomy governs **documentation and metadata contracts**. Metadata is first. The frontmatter contract is the sole authority for an artefact's identity, its category, its lifecycle, and its relationships. **The physical taxonomy is an additive conformance layer**: it brings the on-disk tree into conformance with the metadata categories so the structure is intuitive and navigable, while never overriding the contract.

This means:

- A tool's *governance identity* is defined by its frontmatter (`enforces: ADR-XXXX`, `owner`, `lifecycle`, `domain`), not by its directory path.
- A tool's *discoverability* is defined by the metadata query surface first; the taxonomy makes that same discoverability available to human navigation.
- A tool's *accountability* - who owns it, what policy it enforces, what process it participates in - is visible without reading its content.
- Relocating a file does not change its governance identity, provided the frontmatter is updated alongside it. The taxonomy never overrides the frontmatter contract.

### The two-layer model

The taxonomy is built on two reinforcing layers:

1. **The metadata contract (authoritative).** Every artefact carries frontmatter (or a `.meta.yaml` companion for executables) recording `id`, `document_type`, `category`, `lifecycle`, `owner`, `related.paths`, `governance_context`, and where applicable `primary`/`redirect`, `enforces`, `allowed_in_adopter_repos`, `source_ticket`, `migrated_from`. The classification-ID kinds (`SH-`, `SDX-`, `REF-`, `STD-`, `SEED-`) and the governance IDs (`ADR-`, `AC-`, ledger IDs) are governed by ADR-0032.

2. **The physical taxonomy (additive conformance).** The on-disk tree is brought into conformance with these categories. Each home is a first-class, contract-backed category with a README index, a distinct `document_type`/`category` identity, lifecycle semantics, and registration in the reconcile mapping. The physical tree makes the graph manifest; the metadata contract is its canonical form.

The two layers are not in tension. The metadata contract provides the typed nodes and edges. The taxonomy provides the intuitive grouping that makes the graph legible as physical structure.

### The physical conformance layer

Adopt the following management homes as first-class, contract-backed, populated homes. Each is supported by a metadata contract and registered in the reconcile mapping:

- `agentic/`. Agent roster, bench model, overview, shared context, and agent procedures (configure-agents, authoring-workflow, agent-session-tracking).
- `delivery/`. Release management, release notes, branch/PR flow, CI-CD controls, deployment provenance, environment promotion, rollback and recovery, configuration management, artifact management, customer project onboarding, template creation.
- `audits/` with `audits/evidence/`. Gate outputs produced by the harness (reconcile-metadata-registry, check-links, mdbook build, coverage) as managed, provenance-carrying evidence bundles.
- `governance/exceptions/`. Waivers (`WAV-XXXX`) and the waiver log, governed by the ADR-0032 contract.
- `runbooks/`. Operational runbooks, promoted to a single home.
- `tooling/mcp/`. MCP documentation home under the tooling category, one section per MCP server (`tooling/mcp/<mcp-name>/`, e.g. `mcp-rag-docs/`, `review-ledger/`) so each is identifiable by purpose. Native runtime code (`server.py`, and `mcp/review-ledger/` at the harness root) stays in place as an established runtime anchor and is referenced, not moved.

Existing homes remain and are retained as-is: `governance/decisions/`, `security/guardrails/`, `assurance/reviews/`, `architecture/system/`, `tooling/`, `work/activities/`.

Deferred homes (documented, not yet added): `telemetry/`, `reports/`, `activity/daily`, `governance/controls/`, `governance/policies/`, `governance/ownership/`. These are recorded here so the model knows they were considered; they are added only when they become populated and contract-backed.

### Sub-decisions

The eight original sub-decisions are restated against the two-layer model. Those that deferred physical restructuring are revised to add conformance; the metadata contract decisions are unchanged.

| Decision | Resolution |
|---|---|
| D1 - ADR migration scope | Forward-only. New ADRs use `management/governance/decisions/` from approval onward. The historical ADRs remain in `mddocs/adr/` as the canonical historical record; no physical migration of historical ADRs. Placement and evolution are governed by ADR-0035. |
| D2 - ADR canonicity during transition | Directed coexistence. Both indexes are live, each using the metadata contract with `primary: true/false` and `redirect`. ADR numbering is a flat global sequence independent of physical location. |
| D3 - Cross-domain resolution | No automatic primary-destination rule. Each cross-domain artefact is reviewed case-by-case; resolution rationale is recorded in the activity file before the location is committed. The `primary: true/false` pattern is the general-purpose resolution tool. |
| D4 - Script/tooling classification | The annotation contract is authoritative and is carried in frontmatter / `.meta.yaml`. Physical placement is brought into conformance with the artefact's domain home (harness tooling under `tooling/`, project-activity scripts under their project). Graduation from activity-scoped to shared remains a metadata `lifecycle` change with `migrated_from` provenance. |
| D5 - `AGENTICCORE_SPEC.md` | Directed coexistence. Stays at `mddocs/AGENTICCORE_SPEC.md` as `primary: true`. Companion at `management/architecture/system/AgenticCore-Spec.md` as `primary: false` with `redirect`. No physical move. |
| D6 - Seed backlog | Directed coexistence. `mddocs/backlog.md` (live, `lifecycle: active`, `primary: true`) and `mddocs/scripts/seed/mddocs/backlog.md` (template, `lifecycle: template`, `primary: false`) carry mutual `redirect` frontmatter. Distinct lifecycles; distinct roles. |
| D7 - Guardrail runbooks | Physical conformance. `credential-identity-guard.md` and `secret-guard.md` move into `security/guardrails/{credential-identity, secret-management}/` as the primary home, with `security_category: guardrail` and `governance_context` retained. The operational cross-reference is maintained in the runbooks home. |
| D8 - Review ledger runbook | Physical conformance. `review-ledger-runbook.md` moves into `assurance/reviews/ledger-runbook/` as the primary home, with `assurance_category: review-governance` and `governance_context` retained. The operational cross-reference is maintained in the runbooks home. |

Each conformance change is staged by domain and gated. No single bulk move is carried out; each domain moves in its own reviewed, gate-passing change with the mapping and link-rewrite budget tracked in the reconciliation record (AC-0013).

**Governing principle (restated):** Metadata is first and authoritative. The physical taxonomy is an additive conformance layer that makes the metadata categories manifest on disk. No home placement overrides the frontmatter contract, and no frontmatter contract is deferred to the physical tree. Physical restructuring in this ADR is additive to metadata-first, not a replacement of it.

## Consequences

**Positive:**

- Every `mddocs/` artefact has a machine-readable metadata contract, and the physical tree now conforms to those categories, so discoverability works through both metadata query and directory navigation.
- The taxonomy is a first-class, gate-checked artifact. The harness can verify that physical placement conforms to the declared category, so the structure stays coherent as the corpus grows.
- The two-layer model is directly compatible with a future knowledge management graph. The metadata contract supplies typed nodes and edges; the taxonomy supplies the intuitive grouping.
- Cross-domain artefacts have a governed home plus a maintained cross-reference, so the ambiguity that motivated D7/D8 is resolved without losing the operational view.
- Conformance is staged by domain and gated, so each change is small, reviewable, and independently reversible.

**Negative / Trade-offs:**

- The conformance layer requires a one-time migration of the affected corpus into the new homes, including link rewriting. This is more work than a pure metadata-only adoption, and it is the cost of an intuitive, gate-checked structure.
- Two index files coexist for ADRs during the historical-transition period; readers must understand `primary`/`redirect` to find the active index.
- The `projects/` tree remains unseeded until the first adopted project context is live (ADR-0033).
- Relocation must keep frontmatter and cross-references in sync. A move without updating frontmatter would break the very contract the taxonomy depends on.

**Neutral:**

- ADR-0015 (framework distribution and adoption model) is not affected. The adoption contract for adopter projects is unchanged.
- No new classification-ID kind is introduced. The added homes reuse the existing kinds governed by ADR-0032.

## Implementation Notes

**Supporting evidence:** `AC-0013` (Taxonomy Reconciliation - `mddocs/management/work/activities/ac-0013-taxonomy-reconciliation/index.md`) holds the artefact inventory and reconciliation; it is extended with the current-to-new mapping and link-rewrite budget for the conformance migration.

**Governed by:** `ADR-0032` (classification metadata and standard ID contracts), `ADR-0035` (ADR evolution - forward-only supersede and historical coexistence).

**Immediate actions upon HIL approval:**
1. Register the added homes (`agentic/`, `delivery/`, `audits/` + `evidence/`, `governance/exceptions/`, `runbooks/`, `tooling/mcp/`) in the metadata contract and the reconcile mapping.
2. Produce the full current-to-new mapping and link-rewrite budget as an extension of AC-0013, and review it before any file move.
3. Stage the conformance migration by domain (governance/decisions, security/assurance, delivery/reference, tooling, agentic, mcp, runbooks), each in its own gated change: reconcile CLEAN, check-links green, mdbook build green.
4. Update the tooling home to the retained subset per ADR-0032 Amendment 2026-11-20.

**Out of scope for this ADR:** migration of the historical `mddocs/adr/` records, project context seeding, and any change to ADR-0015 or the adopter contract. The physical conformance layer applies to the management homes and the artefacts that populate them; historical ADR placement is governed by ADR-0035.
