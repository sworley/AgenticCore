# Reference Architecture Index

This section contains runbooks, implementation guides, and operational patterns
for the AgenticCore framework.

## Runbooks

| Runbook | Purpose |
|---|---|
| [Session Open Checklist](session-open-checklist.md) | Steps to run at every session start |
| [Session Close Checklist](session-close-checklist.md) | Steps to run before ending a session |
| [Provision Worker Bench](provision-worker-bench.md) | Provision a `.02`+ ephemeral worktree |
| [Bootstrap New Project](bootstrap-new-project.md) | Use this framework for a new project |
| [Task Queue Operations](task-queue-operations.md) | Working with `tasks.yaml` |
| [Bench Registry](bench-registry.md) | Track and manage open benches |
| [Agent Authoring Workflow](agent-authoring-workflow.md) | Create or modify agent definitions |
| [Release Process](release-process.md) | Full release lifecycle with HIL gates |
| [Release Notes Template](release-notes-template.md) | Template for `mddocs/release-notes/vX.Y.Z.md` |
| [Configure MCP Servers](configure-mcp.md) | One-time MCP setup — cache warm, config, verify |
| [Sign-Off Package](sign-off-package.md) | HIL approval gate — diff, verdicts, open findings, blockers |
| [Adopter Reconciliation Model](adopter-reconciliation.md) | Change propagation, ADR namespace, upgrade cadence |

## Guide: Scripts

All scripts live in `mddocs/scripts/` and have companion runbooks here.

| Script | Runbook | Purpose |
|---|---|---|
| `mddocs/scripts/git-sync.sh` | [git-sync runbook](../operations/runbooks/git-sync-runbook.md) | Clone/update all repos in a Git group |
| `mddocs/scripts/check-env.sh` | [Sync Agent Definitions](../operations/runbooks/sync-agent-definitions.md) | Validate developer environment |
| `mddocs/scripts/bench-status.sh` | (inline) | Show all worktree states |
| `mddocs/scripts/provision-bench.sh` | [Provision Worker Bench](provision-worker-bench.md) | Provision a worker bench |
| `mddocs/scripts/check-worktree-hygiene.sh` | (inline) | Verify all worktrees are clean |
