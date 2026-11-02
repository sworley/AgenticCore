# ADR-0013: Pattern A — Two-Flavor Model

**Date:** 2026-06-29
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Context

Pattern A is the single management pattern used in both framework and project repos.
Both contexts require a long-lived `.01` management agent that owns the task queue,
bench lifecycle, and session discipline. However, the persona and scope language differ:

- **Framework context** — the agent is a baseline-steward; scope is the framework
  itself: versioning, scrubbing, and release lifecycle. No customer data.
- **Project context** — the agent is a lead-engineer; scope is an adopter project:
  task queue, bench coordination, and delivery.

Introducing a new pattern letter for the framework context would create guardrail
divergence risk and maintenance burden. Every guardrail update would need to be applied
to two pattern letters. Session model, standing rules, and LGTM gate are identical in
both contexts.

---

## Decision

Pattern A has two named flavors — `project` (lead-engineer) and `framework`
(baseline-steward). The template structure, guardrails, and session model are
identical across flavors. Only persona identity and scope language differ.

Flavors are selected at provision time via a `--flavor` argument in `provision-bench.sh`:

- `--flavor project` (default) → generates from `bench-AGENT.md.pattern-a-project`
- `--flavor framework` → generates from `bench-AGENT.md.pattern-a-framework`

The bench-registry.yaml `flavor` field records which flavor is active for each `.01`
entry, enabling operators to distinguish framework and project repos at a glance.

---

## Consequences

**Positive:**
- No guardrail divergence is possible. Both flavors share the same standing rules,
  session model, and behavioral constraints. A change to the guardrail block propagates
  to both templates in a single edit pass.
- The framework repo is self-hostable with full Pattern A discipline, including
  session-open/close checklists, LGTM gate, three-strikes, and bench lifecycle.
- Adding a third context in future requires only a new flavor file and a new `--flavor`
  case in `provision-bench.sh` — not a new pattern letter and not a new governance
  review.
- Consistent with ADR-0001 Decision 5: flavors are template variants, not separate
  patterns. The extension point is the generator, not new committed artifacts.

**Negative / Trade-offs:**
- Two template files must be kept in sync for any structural change to Pattern A.
  A diff tool or scripted check is recommended on any PR touching either template.
- The `--flavor` argument adds a decision point to bench provisioning. Operators must
  know which flavor is appropriate for the target repo. Default (`project`) preserves
  backward compatibility.

**Neutral:**
- The `bench-registry.yaml` schema gains an optional `flavor` field. Existing entries
  without the field are implicitly `project`.

---

## Implementation Notes

- Templates: `.agents/bootstrap/bench-AGENT.md.pattern-a-project`,
  `.agents/bootstrap/bench-AGENT.md.pattern-a-framework`
- Script: `mddocs/scripts/provision-bench.sh` — `--flavor project|framework` arg
- Registry: `bench-registry.yaml` — `flavor` field on `.01` entries
- PROCESS.md Roles table: `baseline-steward` row added

---

## Related

- [ADR-0001: Bootstrap Architecture](adr-0001-bootstrap-architecture.md) — Decision 5 (Agent Definition Propagation)
- [ADR-0009: Agent Portability Model](adr-0009-agent-portability-model.md) — D-3 (Projection Pattern), D-5 (Bench Identity)
- [ADR-0012: Bench Assignment — Canonical/Generated Split](adr-0012-bench-assignment-canonical-generated-split.md)
