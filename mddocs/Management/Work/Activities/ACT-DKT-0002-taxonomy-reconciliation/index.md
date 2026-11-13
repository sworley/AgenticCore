---
id: ACT-DKT-0002
title: Taxonomy Reconciliation — Current mddocs/ Inventory vs. Proposed Management Tree
document_type: analysis
status: approved
version: "0.1"
date: 2026-11-12
scope: management-and-adopted-projects
intended_audience:
  - baseline-steward
  - lead-engineer
  - docs-engineer
  - human-approver
activity_of: ACT-DKT-0001
purpose: Reconcile every existing mddocs/ artefact against the proposed taxonomy structure; identify clean mappings, structural gaps, and decision points required before HIL submission.
lifecycle: approved
approved_by: HIL
adopted_date: 2026-11-12
related:
  paths:
    - "../ACT-DKT-0001-taxonomy-proposal/v4"
    - "../../../../adr/adr-0026-release-branch-curation-model.md"
    - "../../../../adr/adr-0015-framework-distribution-adoption-model.md"
---

# ACT-DKT-0002: Taxonomy Reconciliation

> **Status:** Draft — not circulated for review. Input into the HIL submission package for PROPOSAL-DKT-0001.

## 1. Purpose

This activity reconciles the complete current `mddocs/` inventory against the proposed `Management/` tree and reports where the structure absorbs existing artefacts cleanly, where it does not, and what decisions must be resolved before the proposal can advance to HIL approval.

The reconciliation is scoped strictly to the proposal in `ACT-DKT-0001`. Issues around future knowledge-management tooling (Obsidian, graph-backed memory) are noted only as downstream considerations and do not drive this analysis.

## 2. Methodology

1. Enumerated every tracked file under `mddocs/`, excluding `book/` build artefacts.
2. Classified each artefact by **purpose** using the proposal's four-dimensional model (context / purpose / format / lifecycle).
3. Mapped each to its proposed destination folder.
4. Flagged clean fits, ambiguous mappings, and hard mismatches.
5. Called out decision points and open questions.

## 3. Inventory Summary

| Artefact class | Count | Current location |
|---|---|---|
| ADR decisions (including template + index) | 29 | `mddocs/adr/` |
| Operational runbooks | 18 | `mddocs/operations/runbooks/` |
| Reference architecture docs | 15 | `mddocs/reference.architecture/` |
| Script documentation sidecars | 26 | `mddocs/scripts/` |
| Executable scripts / assets | 30 | `mddocs/scripts/` (.sh, .py, .yaml, etc.) |
| Onboarding docs | 6 | `mddocs/onboarding/` |
| FAQ entries | 6 | `mddocs/faq/` |
| Example walkthroughs | 5 | `mddocs/examples/` |
| MCP service artefacts | 3 | `mddocs/mcp/mcp-rag-docs/` |
| Release notes | 3 | `mddocs/release-notes/` |
| Root-level navigation / config | ~8 | `mddocs/` root |

**Total tracked artefacts (excluding build output): ~150 files**

## 4. Reconciliation Table

Legend: **C** = clean fit, **A** = ambiguity / decision required, **M** = mismatch / gap

### 4.1 Governance / Decisions

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/adr/adr-0000-template.md` | `Governance/Decisions/Templates/adr-template.md` | C | Existing ADR template maps directly; proposal's frontmatter contract needs validation against this template. |
| `mddocs/adr/adr-0001` through `adr-0028` | `Governance/Decisions/<adr-id>/index.md` | **A** | Each ADR becomes a self-contained package folder. Proposal explicitly defers ADR migration to a separate ADR — this table is evidence for that migration plan. The existing `adr/` flat path is the canonical path until the migration ADR is approved. |
| `mddocs/adr/index.md` | `Governance/Decisions/index.md` | C | Direct mapping; index moves with the ADR set upon migration. |

**Decision point:** Will ADR migration be a one-time archival move (preserving Git history via `git mv`) or a forward-only split (new ADRs use new structure; historical ones remain)? This affects the scope of the migration ADR.

### 4.2 Operations

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/operations/runbooks/bench-recovery.md` | `Operations/Runbooks/Bench-Recovery/` | C | Clear runbook; moves cleanly into the Operations category. |
| `mddocs/operations/runbooks/build-publish-mddocs.md` | `Operations/Runbooks/Build-Publish-MdBook/` | C | Technical runbook; clean fit. |
| `mddocs/operations/runbooks/credential-identity-guard.md` | `Security/Guardrails/Credential-Identity/` | **A** | **Cross-domain:** this is a runbook (Operations) that enforces a security policy. Proposal's P10 says existing authority prevails; the placement is ambiguous until the security/operations boundary is decided. Strong argument for `Security/Guardrails/` because the artefact *is* a guardrail specification, not just an operational how-to. |
| `mddocs/operations/runbooks/secret-guard.md` | `Security/Guardrails/Secret-Management/` | **A** | Same cross-domain tension as credential-identity-guard. |
| `mddocs/operations/runbooks/hook-rollback.md` | `Operations/Runbooks/Hook-Rollback/` | C | Operational procedure; no security-governance ambiguity. |
| `mddocs/operations/runbooks/setup-mddoc.md` | `Operations/Runbooks/Setup-Mddocs/` | C | Pure operational setup procedure. |
| `mddocs/operations/runbooks/sync-*.md` (3 files) | `Operations/Runbooks/` | C | Sync runbooks are operational procedure. |
| `mddocs/operations/runbooks/git-sync-runbook.md` | `Operations/Runbooks/Git-Sync/` | C | |
| `mddocs/operations/runbooks/session-continuity.md` | `Operations/Procedures/Session-Management/` | C | |
| `mddocs/operations/runbooks/session-reasoning-log.md` | `Operations/Procedures/Session-Logging/` | C | |
| `mddocs/operations/runbooks/configure-agents.md` | `Agentic/Procedures/Configure-Agents/` | **A** | Cross-domain: configuring agents is operational, but it is also agent-definition governance. Either placement is defensible; whichever wins, the cross-reference must exist. |
| `mddocs/operations/runbooks/check-links-runbook.md` | `Operations/Runbooks/Quality-Checks/` | C | |
| `mddocs/operations/runbooks/rotate-git-pat.md` | `Security/Procedures/Credential-Rotation/` | **A** | Cross-domain: credential rotation is a security procedure that happens operationally. |
| `mddocs/operations/runbooks/ai-doc-session-commit-discipline.md` | `Governance/Procedures/Commit-Discipline/` | **A** | This document defines process discipline for how AI agents commit — it is governance, not a runbook. Current placement in `operations/` is the current naming artefact. |
| `mddocs/operations/runbooks/agent-session-tracking.md` | `Operations/Observability/Session-Tracking/` | C | |
| `mddocs/operations/runbooks/agent-authoring-workflow.md` | `Agentic/Procedures/Authoring-Workflow/` | **A** | Cross-domain: references ADR-0027; the workflow is agentic but the governance context is strong. |
| `mddocs/operations/runbooks/review-ledger-runbook.md` | `Assurance/Reviews/Ledger-Runbook/` | **A** | This is a review/assurance procedure, not operations. Its current name ("runbook") reflects current flat structure. |
| `mddocs/operations/index.md` | `Operations/index.md` | C | |

**Decision point:** When an artefact spans two categories (e.g., it is both a security guardrail and an operational runbook), does the taxonomy define a resolution rule (primary context wins, secondary is cross-referenced) or is it case-by-case? The proposal is silent on cross-domain resolution mechanics.

### 4.3 Security

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/faq/web-access-guardrails.md` | `Security/Trust-Boundaries/Web-Access-Restriction/` | C | Pure security documentation; its current placement in `faq/` is a current-structure artefact, not a purpose indicator. |
| `mddocs/mcp/mcp-rag-docs/cve-scan.txt` | `Security/Trust-Boundaries/CVE-Scan-Data/` | C | Supporting asset for the security content-gate documented in ADR-0006. |

**Note:** ADR-0006, ADR-0016, ADR-0018, and ADR-0019 are already classified above under `Governance/Decisions/`. They document security decisions but their *artefact type* is ADR, so `Governance/` remains their primary home. `Security/` would contain *implemented* guardrail specifications and threat models that are not captured as ADRs.

### 4.4 Agentic

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/onboarding/agent-roster.md` | `Agentic/Roles/Roster/` | C | Document about agent roles; direct mapping. |
| `mddocs/reference.architecture/agent-authoring-workflow.md` | `Agentic/Procedures/Authoring-Workflow/` | **A** | See cross-domain note above; this document sits at the boundary of `Agentic/` and `Architecture/Patterns/`. |
| `mddocs/reference.architecture/shared-context.md` | `Agentic/Context/Shared-Context/` | C | Documents the shared context pattern for agent teams; clear `Agentic/` placement. |
| `mddocs/onboarding/bench-model.md` | `Agentic/Context/Bench-Model/` | C | Bench model is the core agentic execution topology. |
| `mddocs/onboarding/agentic-workflow-overview.md` | `Agentic/Overview/` | C | Narrative overview of the agentic workflow; direct mapping. |

### 4.5 Architecture

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/mcp/mcp-rag-docs/server.py` | *Stays in place*; referenced from `Architecture/Interfaces/MCP-RAG-Docs/` | C | Native implementation code stays where it is (proposal P10 / out-of-scope boundary). A governance doc in `Architecture/Interfaces/MCP-RAG-Docs/` describes it; the .py is a referenced asset, not a moved one. |
| `mddocs/mcp/mcp-rag-docs/README.md` | `Architecture/Interfaces/MCP-RAG-Docs/README.md` | C | The README is the interface documentation — this is the kind of doc that moves. |
| `mddocs/reference.architecture/tooling-contract.md` | `Architecture/Interfaces/Tooling-Contract/` | C | Explicitly about the adapter interface; clean fit. |
| `mddocs/reference.architecture/configure-mcp.md` | `Architecture/Interfaces/MCP-Configuration/` | C | Interface configuration; direct mapping. |
| `mddocs/reference.architecture/bench-registry.md` | `Architecture/System/Bench-Registry/` | C | Describes a harness subsystem; clean fit. |
| `mddocs/reference.architecture/provision-worker-bench.md` | `Architecture/System/Bench-Provisioning/` | **A** | Cross-domain: describes how benches are provisioned (system design) but also *operational mechanics*. Both `Architecture/` and `Operations/` are defensible. |
| `mddocs/reference.architecture/bootstrap-new-project.md` | `Reference/Adoption/Bootstrap/` | **A** | This is an adopter-facing walkthrough, not internal architecture. Its current placement in `reference.architecture/` reflects the current flat structure, not its purpose. |
| `mddocs/reference.architecture/release-process.md` | `Delivery/Procedures/Release-Cut/` | C | Operational procedure governing the release cut; `Delivery/` is the clearer home. |
| `mddocs/mcp/mcp-rag-docs/cve-scan` | `Security/Trust-Boundaries/` (supporting asset) | C | See Security section above. |

### 4.6 Delivery

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/release-notes/v0.6.0.md` | `Delivery/Releases/v0.6.0.md` | C | Time-bound release record; clean fit. |
| `mddocs/release-notes/v0.7.0.md` | `Delivery/Releases/v0.7.0.md` | C | |
| `mddocs/release-notes/UNRELEASED.md` | `Delivery/Releases/UNRELEASED.md` | C | |
| `mddocs/reference.architecture/release-notes-template.md` | `Delivery/Resources/Release-Notes-Template/` | C | |

### 4.7 Reference (Adoption and Orientation)

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/onboarding/getting-started.md` | `Reference/Adoption/Getting-Started/` | C | Adopter-facing content; directly maps. |
| `mddocs/onboarding/repository-structure.md` | `Reference/Adoption/Repository-Structure/` | C | |
| `mddocs/reference.architecture/adopter-reconciliation.md` | `Reference/Adoption/Reconciliation/` | C | |
| `mddocs/faq/orientation.md` | `Reference/Adoption/Orientation/` | C | |
| `mddocs/examples/ticket-lifecycle.md` | `Governance/Procedures/Ticket-Lifecycle/` | **A** | This is a governance/ticketing walkthrough, not an adoption reference. Its `examples/` placement is current-structure artefactual. |

### 4.8 Reference (Execution and Operations)

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/examples/release-process.md` | `Delivery/Procedures/Release-Walkthrough/` or `Operations/Procedures/Release-Cut/` | **A** | See Architecture/release-process.md note — both the spec and the walkthrough target the same operational concept but at different levels of detail. They should live near each other. |
| `mddocs/examples/bench-session-walkthrough.md` | `Operations/Procedures/Bench-Session-Walkthrough/` | C | Operational walkthrough; clean fit. |
| `mddocs/examples/adr-decision-process.md` | `Governance/Procedures/ADR-Walkthrough/` | C | Governance walkthrough; clean fit. |
| `mddocs/examples/index.md` | `Reference/Examples/index.md` | C | |

### 4.9 FAQs — Purpose-First Classification

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/faq/docs-build.md` | `Operations/Procedures/Docs-Build/` | C | Procedural Q&A about building docs. |
| `mddocs/faq/git-sync-hosts.md` | `Operations/Procedures/Git-Sync-Hosts/` | C | |
| `mddocs/faq/web-access-guardrails.md` | `Security/Trust-Boundaries/Web-Access/` | C | See Security section above. |
| `mddocs/faq/workspace-management.md` | `Operations/Procedures/Workspace-Management/` | C | |
| `mddocs/faq/index.md` | `Reference/Q&A/index.md` | C | FAQ is a Q&A format; lives in Reference/ as a format bucket. |
| `mddocs/faq/_template.md` | `Reference/Q&A/_template.md` | C | |

### 4.10 Scripts — Three-Domain Classification

Scripts are not a documentation taxonomy problem to be solved by directory placement. They are governance artefacts whose ownership, domain, and lifecycle are encoded in metadata. Physical restructuring is deferred to a future migration ADR (D4 approved: annotate now, restructure later).

| Class | Current path | Proposed destination | Frontmatter fields (distinctive) |
|---|---|---|---|
| **Harness-owned tooling** | `mddocs/scripts/*.sh` (18), `*.py` (3) | `Management/Tools/` (future) | `domain: Management`, `allowed_in_adopter_repos: false` |
| **Harness-provided general-use** | Same as above; classified by purpose | `Management/Tools/` (future); referenced from `Projects/` | `domain: Management`, `allowed_in_adopter_repos: true` |
| **Project-activity script** | Created during `Projects/<context>/Activities/` work | `Projects/<context>/Tools/` or shared pool (future) | `domain: Projects/<context>`, `source_activity: ACT-XXXX`, `source_context: <context>`, `lifecycle: activity-scoped` or `shared` |
| **Governance enforcement** | Git hooks, pre-commit gates | Governed by the ADR that mandates them | `enforces: ADR-XXXX`; primary identity is the policy artefact, not a tool category |
| **Script documentation sidecars** (26 `.md` files) | Alongside each executable | Move with their artefact's primary domain | Inherit domain from parent artefact; `document_type: script-docs` |
| **MCP runtime code** | `mddocs/mcp/mcp-rag-docs/server.py` | *Stays in place* — executable implementation | Documented by companion `README.md`; primary governed by ADR (ADR-0002) |
| **Seed / data files** | `mddocs/scripts/seed/tasks.yaml`, `seed/mddocs/backlog.md` | `mddocs/scripts/seed/` (data), `Management/Work/Backlog.md` (live canonical) | Seed data is regenerable; live backlog is a governance artefact (D6) |

**Shared pool mechanics:** A project-activity script with `lifecycle: shared` is physically relocated to `Projects/Tools/` (or `Management/Tools/Shared/`) under a migration ADR. Its frontmatter records `migrated_from: Projects/<context>/Activities/ACT-XXXX/<path>` and `source_activity: ACT-XXXX`. The shared pool's index tracks origin and provenance. This is a metadata state change, not a new file creation.

**Executive governance scripts** (git hooks, pre-commit gates, CI enforcement): These are not tools. They are executable governance artefacts. Their frontmatter contract uses `enforces: ADR-XXXX` as the primary identity field. Physical placement is governed by the enforcement scope (harness-local, per-branch, etc.) as defined in the mandating ADR. The taxonomy does not relocate enforcement scripts; it documents them.

### 4.11 Root-Level Navigation and Configuration

| Current path | Proposed destination | Fit | Notes |
|---|---|---|---|
| `mddocs/index.md` | `mddocs/index.md` (root) | C | Serves as the root navigation for the entire `mddocs/` tree; stays at root. |
| `mddocs/SUMMARY.md` | `mddocs/SUMMARY.md` (root) | C | mdBook navigation spine; stays at root. |
| `mddocs/AGENTICCORE_SPEC.md` | `Architecture/System/AgenticCore-Spec.md` | **A** | This file defines the harness specification itself. It is both architecture and governance authority. Moving it into `Architecture/System/` is logical, but its current root location reflects its authoritative status. If it moves, the root `index.md` cross-reference must be maintained. |
| `mddocs/configuration.md` | `Reference/Configuration/` | C | Configuration reference; direct mapping. |
| `mddocs/backlog.md` | `Management/Work/Backlog.md` | **A** | See seed/backlog note above. Duplicate risk if both exist. |
| `mddocs/mermaid-init.js`, `mermaid.min.js` | Stay at `mddocs/` root | C | Build assets for mdBook; stay at root alongside `book.toml`. |
| `mddocs/book.toml`, `mddocs/.gitignore` | Stay at root | C | Configuration files; stay at root. |

## 5. Cross-Domain Tension Summary

The reconciliation surfaced a recurring cross-domain pattern: several artifacts legitimately belong to two categories. The specific hotspots are:

| Domain tension | Count | Disposition |
|---|---|---|
| Security guardrails that live as operational runbooks | 2 | `Security/Guardrails/` preferred primary (D7 approved) |
| Agentic procedures that are also architecture pattern docs | 2 | `Agentic/` preferred primary; cross-reference to `Architecture/Patterns/` |
| Adoption walkthroughs currently in `reference.architecture/` | 2 | `Reference/Adoption/` preferred primary |
| Review/assurance procedures filed as runbooks | 1 | `Assurance/Reviews/` preferred primary (D8 approved) |
| Executable artefact sidecar docs | 26 | Classified by artefact's primary purpose (D4); one-time migration discipline |

**Resolution approach:** No automatic taxonomy rule. Each cross-domain artefact is reviewed case-by-case (D3 approved). The `primary: true/false` frontmatter pattern from D2 is available as a general-purpose resolution tool. Disposition of all known hotspots is recorded in D7 and D8.

## 6. Decision Points for HIL Submission

These must be resolved — either in the ADR or in the migration plan — before the taxonomy is approved for implementation.

### D1 — ADR Migration Scope ✅ HIL-approved: Option B (forward-only)

**Decision:** New ADRs use the new `Management/Governance/Decisions/` structure from the point of approval onward. The existing 28 ADRs in `mddocs/adr/` remain in their current path as the canonical historical record. A separate, future migration ADR governs the eventual physical move.

**Rationale:** Minimizes adoption scope; allows soak time with the taxonomy in production use before incurring migration risk; consistent with the process requirement that ADR migration itself requires its own ADR.

---

### D2 — ADR Canonicity During Transition ✅ HIL-approved: Directed Coexistence

**Decision:** Both index files are live simultaneously, each using the proposal's frontmatter contract as machine-readable metadata about its scope. ADR numbering is a flat global sequence (ADR-0000 … ADR-NNNN) independent of physical location. Numbering does not restart or change at migration time.

**Index frontmatter contract:**

`mddocs/adr/index.md` (historical):
```yaml
document_type: index
status: superseded-by-taxonomy
lifecycle: superseded
records: ADR-0000 through ADR-0028
redirect: Management/Governance/Decisions/
primary: false
```

`mddocs/Management/Governance/Decisions/index.md` (active):
```yaml
document_type: index
status: active
lifecycle: active
records: ADR-0029 onward
redirect: ../../adr/
primary: true
```

**Cutover trigger:** A future migration ADR (created through the standard HIL process) defines the `git mv` operations. When approved, execution is a mechanical commit: physical paths change, logical sequence does not. Both index files remain valid throughout; the historical redirect is retired after validation.

---

### D3 — Cross-Domain Resolution Rule ✅ HIL-approved: Case-by-case, reviewed together

**Decision:** No automatic primary-destination rule is codified in the taxonomy. Each cross-domain artefact is reviewed individually by the team. The `primary: true/false` pattern established for index files (see D2) is available as a general-purpose resolution tool for any taxonomy split that arises.

**Process:** Cross-domain artefacts are flagged in activity records (this document, ACT-DKT-0002) and resolved in HIL review sessions before the proposed location is committed to `dev`. Resolution decision and rationale are recorded in the activity file alongside the artefact's mapping row.

---

### D4 — Script Classification: Annotate First, Restructure Later ✅ HIL-approved

**Decision:** No bulk relocation script at adoption time. A one-time frontmatter annotation pass across all executables (`.sh`, `.py`, `.yaml`) and documentation sidecars (`.md`) is performed as the classification exercise. Physical restructuring to a `Tools/` location happens under a future migration ADR, after the taxonomy has soak time and the annotation contract is validated in practice.

#### Distinction that drives the annotation

Three classes of script require distinct frontmatter:

| Class | Examples | Domain | Annotation focus |
|---|---|---|---|
| **Harness-owned tooling** | `provision-bench.sh`, `adopt.sh`, `setup-mddoc.sh`, `sync-agents.sh` | `Management` | Owned by harness; operational infrastructure |
| **Harness-provided general-use** | `git-sync.sh`, `check-env.sh` | `Management` (primary), referenced from `Projects/` | `allowed_in_adopter_repos: true`; logically available to projects without being project-owned |
| **Project-activity script** | Any script created in the course of `Projects/<context>/Activities/ACT-XXXX/` work | `Projects/<context>` | `source_activity`, `source_context`, `lifecycle: activity-scoped`; may graduate to a shared pool |

**Shared pool:** When a project-activity script proves generally useful, it migrates to a shared `Projects/Tools/` area (or `Management/Tools/Shared/`). The migration is governed by a metadata `lifecycle` state change — `activity-scoped` → `shared` — with `migrated_from: Projects/<context>/Activities/ACT-XXXX/<path>` recorded in frontmatter. The shared pool's own index tracks origin and provenance.

**Governance enforcement scripts** (e.g., git hooks, pre-commit gates) are a distinct class. They are not "tools for humans to run." Their primary identity comes from the governance artefact they enforce (`enforces: ADR-0022`), not from a tool or operations category. Frontmatter reflects this with an `enforces` field rather than (or in addition to) a `category` field. Physical placement of enforcement scripts is governed by the ADR that mandates them, not by the documentation taxonomy.

#### Proposed frontmatter contract for scripts

```yaml
---
id: SH-<IDENTIFIER>          # Stable script ID (parallel to ADR-XXXX / ACT-XXXX)
title: <human-readable name>
document_type: script
status: active
lifecycle: active            # active | shared | superseded | retired
domain: Management           # Management | Projects/<context>
category: Operations         # taxonomy bucket it serves (or: enforcement)
process: bench-provisioning  # which workflow it participates in
owner: lead-engineer
allowed_in_adopter_repos: false   # true for harness-provided general-use
enforces: ADR-0022              # only for governance enforcement scripts
source_activity: ACT-XXXX      # only for project-activity scripts; empty if Management-owned
migrated_from:                 # populated if lifecycle=shared; empty otherwise
related:
  paths:
    - ../operations/runbooks/provision-bench.md
---
```

For executable files (`.sh`, `.py`) that cannot carry YAML frontmatter natively, a `.meta.yaml` companion file sits alongside the executable using the same frontmatter contract.

#### Why annotate-first, restructure-later

The classification decisions don't change whether you move files today or next quarter. Annotation work is the same in either case. Moving files first and annotating later means the work is done twice if the taxonomy or the physical layout shifts. Frontmatter on the artefact survives any physical restructure — it is not dependent on a directory tree being authoritative.

The soak-time argument from D1 applies here as well: annotate, use the metadata contract in practice, observe where the three classes (harness-owned, harness-provided, project-activity) create friction or ambiguity, then define the physical `Tools/` layout with evidence rather than prediction.

---

### D5 — `AGENTICCORE_SPEC.md` Authoritative Location ✅ HIL-approved: Directed Coexistence

**Decision:** No physical relocation at adoption time. The file remains at `mddocs/AGENTICCORE_SPEC.md` as the `primary: true` authoritative location. A companion stub is created at `mddocs/Management/Architecture/System/AgenticCore-Spec.md` registered as `primary: false` with `redirect` back to the root. Both files carry frontmatter per the proposal's metadata contract. The `mddocs/index.md` root navigation continues to reference it. Any future physical move is governed by a separate migration ADR and retains the same frontmatter contract.

**Rationale:** The spec's root location reflects its status as a governance anchor for the entire harness — not a content-type artefact to be filed by purpose. The dual-frontmatter approach makes its authoritative location machine-readable, provides discoverability through the `Management/Architecture/System/` category, and is fully reversible without any file move. This is the D1/D2 pattern applied to a single governance anchor file.

---

### D6 — Seed Backlog Duplication ✅ HIL-approved: Directed Coexistence

**Decision:** The live canonical backlog remains at `mddocs/backlog.md` (already populated, referenced by the provisioning template's `_context.md`). The seed template at `mddocs/scripts/seed/mddocs/backlog.md` stays where it is — provisioning scripts depend on it and it cannot move. Both files carry frontmatter per the D5 dual-frontmatter-with-redirect pattern:

`mddocs/backlog.md` (live canonical):
```yaml
document_type: backlog
status: active
lifecycle: active
primary: true
redirect: scripts/seed/mddocs/backlog.md
```

`mddocs/scripts/seed/mddocs/backlog.md` (template):
```yaml
document_type: backlog
status: template
lifecycle: template
primary: false
redirect: ../../../backlog.md
```

The two files share the same `document_type` and metadata contract but have distinct lifecycles (`active` vs `template`). Any agent discovering either file can find the live view via `redirect`. The seed template's `__SLUG__` placeholder is preserved — it is not a duplication problem, it is the template contract.

**Rationale:** Seed data is parameterized and regenerable by design; the live backlog is the management artefact that mirrors `tasks.yaml`. Merging them would conflate two different lifecycles and break provisioning. The dual-frontmatter approach makes the distinction machine-readable without requiring two different `document_type` values or any physical relocation.

---

### D7 — `credential-identity-guard.md` and `secret-guard.md` ✅ HIL-approved: Directed Coexistence

**Decision:** No physical relocation. Both files remain at their current locations under `mddocs/operations/runbooks/` as the `primary: true` locations. Their security purpose is encoded in frontmatter so they are discoverable in the `Security/` category via metadata query, without disrupting the operational workflow that reads them from their current paths.

**Frontmatter added to both files (example for `credential-identity-guard.md`):**
```yaml
document_type: runbook
status: active
lifecycle: active
primary: true
redirect: Security/Guardrails/Credential-Identity/
security_category: guardrail
governance_context:
  - ADR-0016
  - ADR-0018
domain: Management
purpose: Enforce credential identity boundaries during bench operations
```

`secret-guard.md` follows the same pattern with `security_category: guardrail` and appropriate `governance_context` references.

Companion stubs at `mddocs/Management/Security/Guardrails/Credential-Identity/` and `mddocs/Management/Security/Guardrails/Secret-Management/` can be created as `primary: false` redirect indices if discoverability through the Security/ category tree is needed before physical relocation occurs.

**Rationale:** There is no operational reason to displace files that are working correctly in their current locations. The metadata contract makes their security purpose machine-readable without requiring a file move. Relocation can be revisited when the taxonomy has soak time and a specific operational need for the new physical path emerges. This minimizes scope and movement while preserving discoverability for both security and operational audiences.

---

### D8 — `review-ledger-runbook.md` ✅ HIL-approved: Directed Coexistence

**Decision:** No physical relocation. The file remains at `mddocs/operations/runbooks/review-ledger-runbook.md` as the `primary: true` location. Its assurance purpose is registered in frontmatter so it is discoverable in the `Assurance/` category via metadata query, without disrupting the operational workflow that reads it from its current path.

**Frontmatter added:**
```yaml
document_type: runbook
status: active
lifecycle: active
primary: true
redirect: Assurance/Reviews/Ledger-Runbook/
assurance_category: review-governance
governance_context:
  - ADR-0019-D7
purpose: Implements the sign-off package assembly procedure before HIL approval
domain: Management
```

A companion stub at `mddocs/Management/Assurance/Reviews/Ledger-Runbook/` can be created as `primary: false` with `redirect` back to the runbook path if discoverability through the Assurance/ category tree is needed before physical relocation.

**Rationale:** Consistent with D7's scope-minimization principle. The artefact's current name "runbook" reflects the flat structure, not its purpose — but the metadata contract resolves that without moving the file. Its assurance role is now machine-readable. Relocation can be revisited when there is a specific operational need for the Assurance/ physical path.

## 7. Resolved Open Questions

These items from the initial analysis have been resolved by the decisions above:

**Q3 (seed data) → resolved by D6.** Seed data stays in `mddocs/scripts/seed/`. Live backlog lives under `Management/Work/`. No duplication, no sync risk.

**Q4 (adoption-contract impact) → scoped out.** The proposal's out-of-scope boundary explicitly excludes changes to the adoption model or adopter workspace structure. ADR-0015 is not affected. If `Projects/<context>/` naming conventions ever need to be imposed on adopter workspaces, that is a separate ADR scoped to ADR-0015 amendment.

## 8. Remaining Open Questions (Post-Adoption)

These require further investigation but are **not blockers** to HIL approval of the taxonomy. They are follow-on work to be scoped when the time is right:

**Q1 — Existing ADR path references.** ADR-0026 and other existing ADRs may contain filesystem path references that break under the proposed structure. This must be audited as part of the migration ADR (D1), not as a prerequisite.

**Q2 — Link integrity baseline.** How many internal links in the current `mddocs/` corpus reference paths that would change under the new structure? A link-check audit is a prerequisite for the execution plan, not for taxonomy approval.

**Q5 — Projects/ context seeding.** No `Projects/<context>/` directories exist today. The first adopted customer context will seed the first project tree. The proposal's Projects/ structure is first exercised in production only when an adopted project is live, which is outside the current scope.

## 9. Overall Assessment

The proposed taxonomy **absorbs the current `mddocs/` corpus cleanly** for the majority of artefacts. The clean-fit rate is approximately 70–75% of the inventory; the remaining 25–30% falls into two buckets:

1. **Cross-domain artefacts** (operations that are also security, agentic that are also architecture) — ~8–10 files, all resolved in D3 through case-by-case review with recorded rationale.
2. **Structural classification problems** (sidecar scripts, seed data, ADR migration mechanics) — all resolved: scripts annotated by domain (D4), three-domain classification enum approved (harness-owned / harness-provided / project-activity / governance-enforcement), seed backlog directed coexistence approved (D6), ADR migration deferred (D1), shared pool lifecycle pattern approved.

The taxonomy does **not** introduce any contradictions with the existing ADR set. All eight decision points have been resolved and are recorded in this document. No outstanding structural objections remain.

### Remaining open items (post-adoption)

These are not blockers to taxonomy approval; they are follow-on work to be scoped when the time is right:

- **ADR migration ADR** (triggered by D1): the actual `git mv` operations, link audits, and build-config updates for moving the 28 existing ADRs into the new structure.
- **Link integrity audit** (flagged in Q2): all internal links in the corpus must be re-validated after any ADR migration, regardless of how it is done.
- **Projects/ context seeding** (deferred): no current `Projects/<context>/` directories exist. The first adopted customer context will seed the first project tree, at which point the proposal's Projects/ structure is first exercised in production.
