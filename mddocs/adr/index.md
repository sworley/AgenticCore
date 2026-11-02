# ADR Index

This index tracks all Architectural Decision Records for AgenticCore.
ADRs are forward-only — once accepted, a record is never edited. Superseded
decisions get a new ADR that references the one it replaces.

| ID | Title | Status | Date |
|---|---|---|---|
| [ADR-0001](adr-0001-bootstrap-architecture.md) | Bootstrap Architecture | accepted | 2026-06-22 |
| [ADR-0002](adr-0002-mcp-rag-docs.md) | mcp-rag-docs — Local BM25 Search MCP Server | accepted | 2026-06-22 |
| [ADR-0003](adr-0003-mcp-stdio-architecture.md) | Local stdio MCP Architecture | accepted | 2026-06-22 |
| [ADR-0004](adr-0004-main-branch-protection.md) | `main` Branch Protection and Immutability | accepted | 2026-06-25 |
| [ADR-0005](adr-0005-prompt-traceability-session-logging.md) | Prompt Traceability and Session Logging | accepted | 2026-05-08 |

> **Note — retired vendor-specific records.** Three ADRs originally authored as
> vendor-specific enforcement, profile-inheritance, and config-versioning records
> are **not carried forward as files** in this harness (their numbers were retired
> and are not part of the sequential set below). Their intent is modelled and
> supported by the following (see also `AGENTICCORE_SPEC.md` §4.4):
>
> - **Agentic Agent Enforcement Posture** → `.core/invariants.md`,
>   `.core/hooks/*`, `mddocs/adr/adr-0022-git-pre-commit-permission-order-check.md`.
> - **Profile/Context Inheritance Across Projects** → `.core/agents/_context.md`,
>   `.agents/bootstrap/*`, `mddocs/adr/adr-0009-agent-portability-model.md`.
> - **Config Versioning and Bench Manifest** → `bench-registry.yaml`,
>   `.core/work/README.md`, `mddocs/adr/adr-0011-lead-engineer-identity-anchoring.md`.
| [ADR-0006](adr-0006-external-content-gate-scope.md) | External Content Gate Scope | accepted | 2026-05-17 |
| [ADR-0007](adr-0007-bench-scope-isolation.md) | Bench Scope Isolation | proposed | 2026-05-19 |
| [ADR-0008](adr-0008-orchestrator-subagent-routing-layer.md) | Orchestrator Subagent Routing Layer | accepted | 2026-05-22 |
| [ADR-0009](adr-0009-agent-portability-model.md) | Agent Portability Model | proposed | 2026-05-27 |
| [ADR-0010](adr-0010-hook-rollback-strategy.md) | Hook Rollback Strategy | accepted | 2026-06-06 |
| [ADR-0011](adr-0011-lead-engineer-identity-anchoring.md) | Lead-Engineer Identity Anchoring | proposed | 2026-06-08 |
| [ADR-0012](adr-0012-bench-assignment-canonical-generated-split.md) | Bench Assignment — Canonical/Generated Split | accepted | 2026-06-29 |
| [ADR-0013](adr-0013-pattern-a-two-flavor-model.md) | Pattern A — Two-Flavor Model | accepted | 2026-06-29 |
| [ADR-0014](adr-0014-project-slug-adr-ticket-governance.md) | Project Task Slug and ADR Ticket Governance | accepted | 2026-07-02 |
| [ADR-0015](adr-0015-framework-distribution-adoption-model.md) | Framework Distribution and Adoption Model | accepted | 2026-07-02 |
| [ADR-0016](adr-0016-agentic-toolchain-secret-management.md) | Agentic Toolchain Secret Management | accepted | 2026-07-02 |
| [ADR-0017](adr-0017-outer-dependencies-and-portability.md) | Outer Dependencies and Portable Configuration | accepted | 2026-07-02 |
| [ADR-0018](adr-0018-credential-injection-pattern.md) | Credential Injection Pattern | accepted | 2026-07-02 |
| [ADR-0019](adr-0019-role-hierarchy-persona-convention-security-audit-contract.md) | Role Hierarchy, Persona Convention, Bounded-Context Worker Axiom, Reviewer Ledger as Framework Primitive, and Delegation Autonomy Boundary | accepted | 2026-07-10 |
| [ADR-0020](adr-0020-default-model-selection.md) | Default Model Selection for opencode Sessions | accepted | 2026-07-21 |
| [ADR-0021](adr-0021-per-agent-model-tiering.md) | Per-Agent Model Tiering (Opt-In Overrides on Top of the Default) | accepted | 2026-07-29 |
| [ADR-0022](adr-0022-git-pre-commit-permission-order-check.md) | Git-Native Pre-Commit Permission-Order Check and Install-Only Hook Installer | proposed | 2026-07-30 |
| [ADR-0023](adr-0023-opencode-mcp-tool-restriction.md) | Config-Enforced opencode MCP Tool Restriction for approve_finding_update | proposed | 2026-07-31 |
| [ADR-0024](adr-0024-informed-hil-override.md) | Informed HIL Override — Documented Risk-Acceptance Valve | proposed | 2026-08-07 |
| [ADR-0025](adr-0025-framework-write-protection-model.md) | Framework Write-Protection Model — Layered Newcomer-Write Control | proposed | 2026-08-18 |
| [ADR-0026](adr-0026-release-branch-curation-model.md) | Release-Branch Curation Model (git-flow-style) | accepted | 2026-08-20 |
| [ADR-0027](adr-0027-authoring-agent-execution-model.md) | Authoring-Agent Execution Model — Execution-Light Workers, Lead-Run Gates | accepted | 2026-08-21 |

**Adding a new ADR**

Copy [ADR-0000 Template](adr-0000-template.md) to `adr-NNNN-short-title.md`,
fill in the fields, and add a row to this index. Update `SUMMARY.md` to include
the new file. Set status to `proposed` until accepted by HIL.

**Status values**

- `proposed` — under discussion; not yet binding
- `accepted` — active decision; in effect
- `superseded` — replaced by a newer ADR (link provided in the file)
- `deprecated` — no longer applicable
