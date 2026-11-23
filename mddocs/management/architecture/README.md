---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Home for management-plane architectural and structural content
---

# Architecture

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for the AgenticCore management-plane (`.01`)
architecture: the harness-wide structural models (bench/worktree isolation,
agentic workflow orchestration) and the harness specification anchor. This is
management-plane structural content, distinct from project-plane (`.00`)
architecture, which lives in the adopter-facing `reference.architecture/` tree.

## Contents

| File | Purpose |
|---|---|
| [Bench Model](bench/bench-model.md) | Git worktree isolation / execution environment model (ADR-0007) |
| [Agentic Workflow Overview](workflow/agentic-workflow-overview.md) | Orchestration / workflow model |
| [AgenticCore Specification (pointer)](system/AgenticCore-Spec.md) | Cross-plane governing-body anchor |

The authoritative harness specification is a **corpus-root anchor**
(`mddocs/AGENTICCORE_SPEC.md`, `primary: true`, `document_type: spec`). It is the
harness-wide governing body covering both the management plane (`.01`) and the
project plane (`.00`), so it is not management-plane content. The
[`system/AgenticCore-Spec.md`](system/AgenticCore-Spec.md) page is a clearly
labeled cross-plane pointer to it; the spec is not duplicated here.

**Owner:** maintained by the harness. `management/architecture/` holds real
management-plane structural content; the spec pointer is its governing anchor
entry (ADR-0029 D5, item #2).
