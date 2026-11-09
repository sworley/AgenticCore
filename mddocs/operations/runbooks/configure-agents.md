# Runbook: Configure Agent Namespace

**Agent:** ops-engineer
**Triggered by:** New clone, membership change, or an agent-definition change that
affects the namespace layout.

---

## Overview

The agent namespace is the set of directories that define, generate, and share the
agents used by the runtime. It has three layers:

1. **Canonical source** — `.agents/` is the single source of truth for agent
   definitions, plus the shared agent context.
2. **Generated tool-specific directories** — `.opencode/agents/` (and equivalents for
   other runtimes) are produced from the canonical source and must never be hand-edited.
3. **Shared context** — `.core/agents/_context.md` carries the context that every agent
   inherits.

## Namespace Layout

| Path | Role |
|---|---|
| `.agents/` | Canonical agent definitions (`_meta.yaml`, `<name>.md`) |
| `.agents/sync-agents.sh` | Generates tool-specific files from `.agents/` |
| `.opencode/agents/` | OpenCode agents — auto-generated, do not hand-edit |
| `.core/agents/_context.md` | Shared context inherited by all agents |
| `_config/` | AGENT.md recovery archive (see the sync runbook) |

## Procedure

### Step 1 — Sync the canonical source to tool directories

```sh
bash .agents/sync-agents.sh
```

### Step 2 — Review the generated files

```sh
git diff .opencode/agents/
```

Confirm frontmatter (description, mode, permission) is correct and the generated
files carry the AUTO-GENERATED comment.

### Step 3 — Configure MCP servers

Wire the MCP servers the agents rely on. See
[Configure MCP Servers](../../reference.architecture/configure-mcp.md).

### Step 4 — Stage and commit

```sh
git add .agents/ .opencode/agents/
git status
# Present to HIL and wait for LGTM
git commit -m "feat: configure agent namespace [AC-NNNN]"
```

---

## Verification

- [ ] `sync-agents.sh --dry-run` shows the expected files
- [ ] Generated files have valid frontmatter and body
- [ ] MCP servers wired and verified
- [ ] Commit reviewed and approved by HIL

## Related

- [Agent Authoring Workflow](agent-authoring-workflow.md)
- [Sync Agent Definitions](sync-agent-definitions.md)
- [Shared Agent Context](../../reference.architecture/shared-context.md)
- [Configure MCP Servers](../../reference.architecture/configure-mcp.md)
