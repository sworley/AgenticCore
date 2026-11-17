---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Harness management plane
---

# Management Plane

> **Plane purpose.** `Management/` documents **AgenticCore itself** — the
> harness's architecture, governance, security posture, operations, and
> adoption. It does not document customer work performed by adopted project
> benches (that is the `Projects/` plane).

## Categories

| Category | Scope | Present |
|---|---|---|
| [Architecture](Architecture/System/AgenticCore-Spec.md) | Harness design, planes, integration | ✓ |
| [Assurance](Assurance/Reviews/Ledger-Runbook/index.md) | Reviews, audits, evidence | ✓ |
| [Governance](Governance/Decisions/index.md) | ADRs, standards, policies, exceptions | ✓ |
| [Security](Security/Guardrails/Credential-Identity/index.md) | Trust boundaries, guardrails, access | ✓ |
| [Work](Work/Activities/ACT-DKT-0002-taxonomy-reconciliation/index.md) | Time-bounded harness improvement work | ✓ |

## Rules

- **Management-only.** Management-plane agents use the existing authorized
  ticket/HIL workflow for structural changes; project-scoped agents cannot
  create or modify management objects merely because paths are visible.
- **Metadata is authority.** Taxonomy frontmatter governs artefact identity;
  physical location is fixed by the forward-only coexistence model (ADR-0030);
  any relocation would be a separate decision.
