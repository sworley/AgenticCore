---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
purpose: Runbook home for operational and harness procedures
---

# Runbooks

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for the harness operational runbooks. Each runbook
carries `document_type: runbook` and `primary: true` and is authoritative at
this path; the historical `operations/runbooks/` location is retained as a
`primary: false` redirect stub so existing links continue to resolve.

## Contents

| Runbook | Purpose |
|---|---|
| [Agent Authoring Workflow](agent-authoring-workflow.md) | Author agent operation workflows |
| [Agent Session Tracking](agent-session-tracking.md) | Track agent session state |
| [AI-Assisted Session Commit Discipline](ai-doc-session-commit-discipline.md) | Enforce AI-assisted session commit discipline |
| [Bench Recovery](bench-recovery.md) | Wipe and reprovision a bench on context loss |
| [Branch-Protection Rulesets](branch-protection-rulesets.md) | Configure GitHub branch-protection rulesets |
| [Build and Publish mdBook](build-publish-mddocs.md) | Build and publish the mdBook documentation site |
| [check-links - Internal Link Validator](check-links-runbook.md) | Run the internal link validator |
| [git-sync - Git Workspace Sync](git-sync-runbook.md) | Sync the git workspace |
| [Hook Rollback](hook-rollback.md) | Roll back git hooks |
| [Rotate Git PAT](rotate-git-pat.md) | Rotate the Git PAT |
| [Session Continuity](session-continuity.md) | Maintain session continuity and end-of-focus memory writes |
| [Session Reasoning Log](session-reasoning-log.md) | Record and maintain the session reasoning log |
| [Set Up mddoc Local Documentation Site](setup-mddoc.md) | Set up a local mddoc documentation site |
| [Sync Agent Definitions](sync-agent-definitions.md) | Sync agent definitions |
| [Sync Agent Config](sync-opencode-config.md) | Sync agent config between AGENT.md archive and on-disk |

**Owner:** maintained by the harness. The runbook set is part of the management
plane (ADR-0029) and is governed by the metadata-first authority of ADR-0029,
with physical location fixed by the additive conformance layer.
