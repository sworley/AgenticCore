# Shared Agent Context

**Category:** Reference Architecture
**Last Updated:** 2026-07-21

## Overview

The shared context file is a vendor-neutral markdown document that every agent reads at
the start of a session. It provides authoritative facts about the project — identity,
bench model, agent roster, key paths, and environment — without duplicating that
information across individual agent definitions.

The pattern is described in ADR-0009 (Agent Portability Model). All toolchains —
AI toolchain, opencode, and any future tool — read the same file.

---

## Files

| Path | Purpose |
|------|---------|
| `.core/agents/_context.md` | AC framework's own populated shared context — the reference example |
| `.agents/bootstrap/project-context.md.template` | Blank template — copy and fill in for a new project |

---

## What the Context File Contains

| Section | Purpose |
|---------|---------|
| **Session-Open Checklist** | Steps every agent runs before taking action |
| **Identity** | Collection name, purpose, git remote |
| **Bench Model** | Worktree layout, roles, bench registry reference |
| **Task Queue** | Location of `tasks.yaml`, task lifecycle states |
| **Environment** | Hardware, OS, shell, toolchain, credential store |
| **Agent Tool Directories** | `.agents/` canonical source, sync contract, tool-specific output dirs |
| **Agent Roster** | All 10 AC agents — role, mode, invoked-by |
| **Key Paths** | Canonical paths for all significant directories and files |
| **Multi-Tool Note** | How AI toolchain and opencode share state; branch naming; commit discipline |

---

## Setting Up the Shared Context for a New Project

1. Copy the template to your project's context directory:

   ```bash
   cp .agents/bootstrap/project-context.md.template \
      agents/<your-project-name>/_context.md
   ```

2. Fill in the `{{PLACEHOLDER}}` fields:
   - `{{PROJECT_NAME}}` — collection name (e.g. `my-project.01`)
   - `{{PROJECT_PURPOSE}}` — one sentence describing the project
   - `{{GIT_REMOTE}}` — remote URL
   - `{{HARDWARE}}` — developer workstation description
   - `{{OS}}` — operating system
   - `{{SHELL}}` — shell (zsh, bash, etc.)
   - `{{TOOLCHAIN}}` — comma-separated list of confirmed tools
   - `{{CREDENTIAL_STORE}}` — how credentials are managed

3. Update the Key Paths section if your project layout differs from the AC defaults.

4. Commit the populated file to `main` before the first agentic session.

5. Agents configured to read the context file will load it automatically at session open.

**The Agent Roster section requires no changes** — the 10 AC agents are pre-populated.
Add project-specific specialist agents below the roster table if your project introduces new roles.

---

## How Agents Read the Context File

Agents are wired to read the context file via their session-open steps in `.agents/`:

| Agent | Session-open instruction |
|-------|--------------------------|
| `lead-engineer` | Step 0: Read `.core/agents/_context.md` |
| `docs-engineer` | Context line at top of agent definition |
| `ops-engineer` | Context line at top of agent definition |

The `orchestrator` and `security-reviewer` agents do not have session-open steps — they
are narrow-scope plan-only / verdict-only agents invoked mid-session.

---

## AC Framework Reference Context

The populated context for the AC framework itself lives at:

```
.core/agents/_context.md
```

This file serves dual purpose:
1. The AC framework's own populated shared context, used when agents work on the framework
2. The reference example that adopters inspect when filling in their own context file

---

## Related

- [Runbook: Configure Agent Namespace](../operations/runbooks/configure-agents.md) — full agent namespace setup including shared context
- [Runbook: Agent Authoring Workflow](../operations/runbooks/agent-authoring-workflow.md) — adding agents and keeping rosters in sync
- [ADR-0009: Agent Portability Model](../adr/adr-0009-agent-portability-model.md)
- `.agents/bootstrap/project-context.md.template` — blank template
- `.core/agents/_context.md` — populated AC framework context
