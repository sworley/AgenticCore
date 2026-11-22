---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Home for harness agent model, bench context, and agent configuration
---

# Agentic

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for the harness's agent model and bench semantics:
the agent roster, the bench/worktree isolation model, the shared agent context,
the agentic workflow overview, and agent-namespace configuration. Each file
carries `primary: true` and is authoritative at this path; the historical
`onboarding/` and `reference.architecture/` locations are retained as
`primary: false` redirect stubs so existing links continue to resolve.

## Contents

| File | Purpose |
|---|---|
| [Agent Roster](roster/agent-roster.md) | The complete agentic team and model tiers |
| [Bench Model](context/bench-model.md) | Bench/worktree isolation and namespace hierarchy |
| [Shared Agent Context](context/shared-context.md) | Shared agent context file |
| [Agentic Workflow Overview](overview/agentic-workflow-overview.md) | Overview of the agentic workflow model |
| [Configure Agent Namespace](procedures/configure-agents.md) | Configure the agent namespace and MCP servers |

The agent-authoring playbook is maintained as a runbook at
[`../runbooks/agent-authoring-workflow.md`](../runbooks/agent-authoring-workflow.md).

**Owner:** maintained by the harness. The agent model is part of the management
plane (ADR-0029) and is governed by the metadata-first authority of ADR-0029,
with physical location fixed by the additive conformance layer.
