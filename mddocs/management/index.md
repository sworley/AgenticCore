---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Harness management plane
---

# Management Plane

> **Plane purpose.** `management/` documents **AgenticCore itself** - the
> harness's architecture, governance, security posture, operations, and
> adoption. It does not document customer work performed by adopted project
> benches (that is the `projects/` plane).

## Categories

| Category | Scope | Present |
|---|---|---|
| [Architecture](architecture/system/AgenticCore-Spec.md) | Harness design, planes, integration | ✓ |
| [Assurance](assurance/reviews/ledger-runbook/index.md) | Reviews, audits, evidence | ✓ |
| [Governance](governance/decisions/index.md) | ADRs, standards, policies, exceptions | ✓ |
| [Security](security/guardrails/credential-identity/index.md) · [Secret](security/guardrails/secret-management/index.md) | Trust boundaries, guardrails, access | ✓ |
| [Runbooks](runbooks/README.md) | Operational and harness procedures | ✓ |
| [Tooling](tooling/README.md) | Reusable framework tooling, schemas, assets | ✓ |
| [Work](work/activities/ac-0013-taxonomy-reconciliation/index.md) | Time-bounded harness improvement work | ✓ |

## Rules

- **Management-only.** Management-plane agents use the existing authorized
  ticket/HIL workflow for structural changes; project-scoped agents cannot
  create or modify management objects merely because paths are visible.
- **Metadata is authority.** Taxonomy frontmatter governs artefact identity;
  physical location is fixed by the forward-only coexistence model (ADR-0035);
  any relocation would be a separate decision.
