---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Agentic
purpose: Home for agentic procedures executed by the harness
---

# Procedures

**Top:** [Agentic](../README.md)

**Purpose.** Canonical home for the AgenticCore management-plane (`.01`)
**agentic procedures** - deterministic, script/gate-backed harness machinery
executed by agents. Each procedure is `primary: true` and authoritative at this
path. The historical `operations/runbooks/` and `reference.architecture/`
locations are retained as `primary: false` redirect stubs so existing links
continue to resolve.

**Artifact class.** These are **agentic procedures**, not operational runbooks. No
operational runbook lives in the management plane; operational (human-facing,
manual-parity) runbooks are a project-plane artifact
(`projects/<context>/runbooks/<runbook-id>/`, ADR-0029 item #1). The harness
self-maintenance procedures below carry an inline manual fallback section.

## Contents

### Agent namespace and agent-domain procedures

| Procedure | Purpose |
|---|---|
| [Configure Agent Namespace](configure-agents.md) | Configure the agent namespace and MCP servers |
| [Agent Authoring Workflow](agent-authoring-workflow.md) | Author agent operation workflows |
| [Agent Session Tracking](agent-session-tracking.md) | Track agent session state |
| [Session Continuity](session-continuity.md) | Maintain session continuity and end-of-focus memory writes |
| [Session Reasoning Log](session-reasoning-log.md) | Record and maintain the session reasoning log |
| [AI-Assisted Session Commit Discipline](ai-doc-session-commit-discipline.md) | Enforce AI-assisted session commit discipline |
| [Sync Agent Definitions](sync-agent-definitions.md) | Sync agent definitions |
| [Sync Agent Config](sync-opencode-config.md) | Sync agent config between AGENT.md archive and on-disk |

### Harness self-maintenance procedures

| Procedure | Purpose |
|---|---|
| [Git Sync](git-sync-runbook.md) | Sync the git workspace |
| [Build and Publish mdBook](build-publish-mddocs.md) | Build and publish the mdBook documentation site |
| [check-links](check-links-runbook.md) | Run the internal link validator |
| [Set Up mddoc](setup-mddoc.md) | Set up a local mddoc documentation site |
| [Bench Recovery](bench-recovery.md) | Wipe and reprovision a bench on context loss |
| [Hook Rollback](hook-rollback.md) | Roll back git hooks |
| [Rotate Git PAT](rotate-git-pat.md) | Rotate the Git PAT |
| [Branch-Protection Rulesets](branch-protection-rulesets.md) | Configure GitHub branch-protection rulesets |

**Owner:** maintained by the harness. The procedures are part of the management
plane (ADR-0029) and are governed by the metadata-first authority of ADR-0029,
with physical location fixed by the additive conformance layer.
