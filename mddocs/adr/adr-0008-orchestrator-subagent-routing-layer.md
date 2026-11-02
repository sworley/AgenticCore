# ADR-0008: Orchestrator Subagent — Dedicated Routing Planning Layer

**Date:** 2026-05-22
**Status:** accepted
**Supersedes:** —

## Prior Art

EXAMPLE-ADR-0022 (Orchestrator Subagent — Dedicated Routing Planning Layer, 2026-05-22).
Routing layer separation rationale and orchestrator responsibility model carried forward
unchanged.

---

## Context

`lead-engineer` is the sole primary agent and HIL entry point. An audit of its
definition identified four distinct responsibility clusters:

| Cluster | ~% of definition |
|---|---|
| Gate enforcement | 34% |
| Program/delivery management | 21% |
| Technical orchestration | 14% |
| Execution guardrails | 13% |

The orchestration cluster — the routing function — was the thinnest and most
under-specified. No guidance existed for parallel vs. sequential invocation,
specialist conflict resolution, escalation criteria, routing disambiguation, or
agent roster evolution.

## Decision Drivers

- Routing decisions required the same judgment as specialist execution — lead-engineer
  was silently making architectural calls with no documented criteria
- Specialist boundary overlaps had no documented disambiguation rules
- The orchestration function needed to grow without polluting program management and
  gate enforcement context
- HIL interaction surface must remain at one agent — adding a co-primary entry point
  was explicitly rejected

## Considered Options

**COA A — Extract PM work into `delivery-coordinator` subagent**
Lead-engineer retains gates, orchestration, guardrails. Gates (34% of file) stay in
lead-engineer — conceptual muddle persists.

**COA B — Refocus lead-engineer as program manager; new `engineering-lead` for orchestration**
Creates HIL interaction surface problem: either engineering-lead is a subagent (relay
noise, fidelity risk) or co-primary (user carries routing burden).

**COA B — Configuration 1 analysis (subagent):**
Every technical question becomes a visible three-party relay: HIL → PM → engineering-lead
→ PM → HIL. Four fidelity failure modes: omission, reframing, false reconciliation,
confidence laundering.

**COA C — Three-way split; gates fold into security layer**
Maximum specialization; highest coordination complexity; lead-engineer retired. Rejected:
gates are not purely security concerns.

**Selected: Orchestrator as subagent below lead-engineer**
Keep lead-engineer as sole primary. Build orchestrator as a dedicated routing planning
subagent that lead-engineer delegates to silently.

## Decision

**Orchestrator as a read-only planning subagent.**

### Architecture

```
HIL → lead-engineer (primary — sole entry point)
           ↓ multi-specialist routing decisions
      orchestrator (subagent — planning only, read-only tools)
           ↓ ROUTING_PLAN block
      lead-engineer validates and executes
           ↓
      specialist agents (security-engineer, docs-engineer, etc.)
```

Orchestrator produces `ROUTING_PLAN` blocks only. It does not invoke specialists,
synthesize outputs, or take any action beyond producing a plan.

### Three-layer fidelity protection

**Layer 1 — Invariant rules (preventive)**

| Invariant | Trigger | Rule |
|---|---|---|
| `content-inspection` | External content | `security-engineer` must be step 1 |
| `credential-secrets` | Credentials / secrets | `security-engineer` in plan |
| `adr-coa-poc-sequence` | ADR/COA/POC decision | docs-engineer → security-reviewer → lead advances |
| `merge-push` | Merge/push in plan | HIL confirmation request |

**Layer 2 — Structured output with pre-execution assertions**
Orchestrator emits a `ROUTING_PLAN` schema. Lead-engineer runs assertions before
executing: invariants present, sequencing consistent, reasons map to recognized
triggers, sensitivity classification correct.

**Layer 3 — Selective HIL visibility**
Requests above sensitivity threshold surface a one-line routing confirmation before
execution. Threshold triggers: external content, credentials, ADR/COA/POC, 3+
specialists, destructive operations.

### Silent fallback and behavior-based deprecation

When lead-engineer's assertions fail or orchestrator sets `fallback_recommended: true`:
1. Lead-engineer routes using its own inline routing
2. Lead-engineer auto-creates a gap ticket in `tasks.yaml` with label taxonomy
3. Gap tickets surface at next session-open

Deprecation of inline routing is **behavior-based**: when gap ticket rate reaches zero
across sustained sessions, lead-engineer retires its inline routing table.

## Consequences

**Positive:**
- HIL interaction surface unchanged — sole primary entry point preserved
- Routing decisions are now documented, auditable, and improvement-trackable
- Fidelity risks addressed at three independent layers
- Deprecation gate is evidence-based

**Negative / Trade-offs:**
- Soak phase adds a routing hop for multi-specialist requests
- Lead-engineer must maintain both orchestrator delegation logic and inline routing
  fallback during soak

**Neutral:**
- Gap ticket taxonomy provides reporting signal on orchestrator maturation over time

## Related

- [ADR-0007: Bench Scope Isolation](adr-0007-bench-scope-isolation.md)
- `.agentic/agents/orchestrator.md` — full orchestrator spec
- `.agentic/agents/lead-engineer.md` — Orchestrator Delegation section
