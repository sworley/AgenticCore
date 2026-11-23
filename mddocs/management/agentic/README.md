---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Home for the harness agent model, agent namespace, and agentic procedures
---

# Agentic

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for the harness agent model and agent namespace: the
agent roster, the shared agent context, and the agentic procedures the harness
executes. The bench/worktree isolation model and the agentic workflow overview
are structural, so they live in the
[Architecture](../architecture/README.md) home
(`management/architecture/bench/` and `management/architecture/workflow/`). Each
file here carries `primary: true` and is authoritative at this path; the
historical `onboarding/` and `reference.architecture/` locations are retained as
`primary: false` redirect stubs so existing links continue to resolve.

## Contents

| File | Purpose |
|---|---|
| [Agent Roster](roster/agent-roster.md) | The complete agentic team and model tiers |
| [Shared Agent Context](context/shared-context.md) | Shared agent context file |
| [Procedures](procedures/README.md) | Agentic procedures executed by the harness (agent namespace and harness self-maintenance) |

The structural benches model and workflow overview live in the architecture home:

- [Bench Model](../architecture/bench/bench-model.md) - bench/worktree isolation and namespace hierarchy
- [Agentic Workflow Overview](../architecture/workflow/agentic-workflow-overview.md) - overview of the agentic workflow model

**Owner:** maintained by the harness. The agent model is part of the management
plane (ADR-0029) and is governed by the metadata-first authority of ADR-0029,
with physical location fixed by the additive conformance layer.
