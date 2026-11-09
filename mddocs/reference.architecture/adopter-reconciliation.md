# Adopter Reconciliation Model

**Defined by:** ADR-0014 (slug and namespace), ADR-0015 (distribution and propagation)
**Audience:** AgenticCore baseline-steward; adopter project stewards

---

## Overview

AgenticCore is distributed as versioned release exports (ADR-0015 D-1). Adopter
repos start from a clean `git init` with no AP history or remote. The relationship
between framework and adopter is baseline-versioned, not continuously coupled.

This document defines:
- How framework ADRs and adopter ADRs are distinguished
- How framework changes reach adopters
- The recommended reconciliation cadence
- The pattern promotion path from adopter to framework

---

## ADR Namespace Model

### Framework ADRs

Framework ADRs live in the AgenticCore repo and carry the `AP ADR-NNNN` identifier.
They govern decisions that apply to all adopters — agent patterns, MCP architecture,
bench model, hook contracts, release lifecycle.

### Adopter ADRs

Each adopter declares a project slug at initialization (ADR-0014 D-1). All adopter
ADRs use that slug: `<PROJECT> ADR-NNNN`. Example: `ACME ADR-0001`.

The ADR number space is independent. `AP ADR-0015` and `ACME ADR-0015` are unrelated
decisions in separate repos with separate governance. Cross-project references use the
full prefixed form — `AP ADR-0015`, never bare `ADR-0015` in a context where both
namespaces are in scope.

### Decision boundary

| Decision type | Belongs in |
|---|---|
| Agent definitions, bench model, hook contracts, MCP server design | AP (framework) |
| Project task governance, customer delivery patterns, team-specific guardrails | Adopter project |
| A pattern that originated in an adopter but is portable and stable | AP (via promotion — see below) |

When in doubt: if the decision requires no reference to a specific customer,
environment, or team structure to be stated, it belongs in the framework.

---

## Change Propagation

### How framework improvements reach adopters

Framework improvements are released as AP version tags. Adopters receive improvements
by running `export-framework.sh` against a newer AP release tag into a new working
copy, then manually reconciling the delta against their project's customizations.

There is no automatic pull. Upgrade is an explicit, adopter-scheduled decision.

### Upgrade signal

AP releases include an adopter impact classification in the release notes (see
[Release Process](release-process.md), Step 3.5). Each change is classified:

| Class | Meaning | Adopter action |
|---|---|---|
| **Transparent** | Internal framework improvement; no adopter-visible interface changed | None required |
| **Optional** | New capability the adopter can adopt; existing behavior unchanged | Evaluate and adopt at adopter's discretion |
| **Required** | Breaking change or security fix; adopters on prior release are affected | Must reconcile before next release upgrade |

AP does not support more than one `Required` class item per minor version without a
documented migration path in the release notes.

### Framework version record

On initialization, `export-framework.sh` writes the AP release version to
`framework-version.txt` at the repo root. This is the permanent baseline reference.
Adopters update this file when they upgrade.

---

## Reconciliation Cadence

No cadence is mandated. Government programs follow their own configuration management
discipline. The recommended model is:

1. **At each AP minor release** — review the release notes for `Required` class items.
   Plan reconciliation work as a task in the adopter's task queue.
2. **At each AP major release** — full reconciliation review; treat as a deliberate
   upgrade decision with HIL sign-off.
3. **On security findings** — if AP publishes a `Required` security fix, reconcile
   within the adopter's next sprint regardless of cadence.

Adopters do not need to track every AP patch release. Versioned baseline discipline
means: know what version you are on, review the delta when you choose to upgrade.

---

## Pattern Promotion

When an adopter develops a pattern that is portable and stable, it can be promoted to
the framework (ADR-0015 D-4). The promotion path:

1. The adopter's steward abstracts the pattern — strips project-specific content,
   states the requirement without reference to customer or environment.
2. Steward opens an `AC-NNNN` task in the AgenticCore issue tracker, describing the
   portable pattern and citing the source artifact (`<PROJECT> ADR-NNNN` or
   `<PROJECT>-NNNN`) using the cross-project citation format (ADR-0014 D-6).
3. AP baseline-steward evaluates the abstraction — not the raw source artifact — and
   assigns a disposition: ADR, runbook, script, or decline with rationale.
4. If accepted, the pattern enters AP's normal development lifecycle — bench,
   review (including security-reviewer pass per AP standing rules), and release.

A pattern is ready for promotion when (ADR-0015 D-6):
- The portable shape is clear — statable without project-specific reference
- Customer-specific content is fully stripped
- Guardrails are understood from experience, not hypothesized

Submitting a raw project artifact with customer references intact is not a valid
promotion submission.

---

## Verification

This model is correctly implemented when:
- [ ] Adopter repo has `framework-version.txt` recording the AP release it initialized from
- [ ] All adopter ADRs use `<PROJECT> ADR-NNNN` format, not bare `ADR-NNNN`
- [ ] AP release notes include adopter impact classifications (Transparent / Optional / Required)
- [ ] Adopter task queue tracks any `Required` class items from AP releases in scope

---

## Related

- [ADR-0014: Project Task Slug and ADR Ticket Governance](../adr/adr-0014-project-slug-adr-ticket-governance.md)
- [ADR-0015: Framework Distribution and Adoption Model](../adr/adr-0015-framework-distribution-adoption-model.md)
- [Release Process](release-process.md) — Step 3.5: adopter impact classification
- [Bootstrap New Project](bootstrap-new-project.md) — initialization procedure
