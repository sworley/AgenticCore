# __SLUG__ — Shared Agent Context

<!-- schema: agent-context/v1 -->
<!-- Required sections: Identity, Bench Model, Agent Roster, Environment -->
<!-- INSTRUCTIONS: fill in the Identity, Environment, and Key Paths sections -->
<!-- for your project. Remove these instruction comments once populated.    -->

**Read this file at the start of every session before taking any action.**

This is a vendor-neutral shared context file. It is read by all agents from all tools
(AI toolchain, opencode, and any future toolchain). It contains no tool-specific syntax.

---

## Session-Open Checklist

Every agent must complete these steps before starting any task:

1. Read this file (`.core/agents/_context.md`) — ✓ you are here
2. Run `git status` — confirm the worktree is on the correct branch and clean
3. Check `tasks.yaml` — identify any `in_progress` tasks that belong to you
4. If picking up an interrupted task, read the task's `steps` field for where it left off

---

## Identity

| Field | Value |
|-------|-------|
| **Collection name** | `__SLUG__` |
| **Purpose** | <!-- fill in: what this repo is for --> |
| **Git remote** | <!-- fill in: your git host/path --> |

---

## Bench Model

The project uses a numbered worktree convention. All benches are git worktrees of the same repo.

| Bench | Path | Role | Notes |
|-------|------|------|-------|
| `.00` | `__SLUG__.00` | Owner workspace | IDE work, R&D, scratch — never assign agent tasks here |
| `.01` | `__SLUG__.01` | Lead-engineer | Owns `main`, remote, task queue, bench lifecycle |
| `.02`+ | `__SLUG__.02`, `.03`, etc. | Worker benches | Execute assigned tasks; do not merge, do not push |

**Rule:** `.01` provisions and coordinates. Worker benches execute. Agent task work never
happens directly in `.01` — if a task requires building, running, or generating artifacts,
stop and assign to a worker bench.

Bench registry: `bench-registry.yaml`

---

## Task Queue

- **Location:** `tasks.yaml`
- **Human-readable backlog:** `mddocs/backlog.md`

### Task Lifecycle

```
backlog → ready → claimed → in_progress → branch_ready → awaiting_review → accepted → merged
```

Only `lead-engineer` writes to `tasks.yaml`, except the `backlog → ready` transition (user only).

### Current Task State

**Live source:** `tasks.yaml` — always authoritative. At session open, scan for
`in_progress` items and cross-reference against `bench-registry.yaml` to confirm
no bench is doing duplicate work.

---

## Environment

| Field | Value |
|---|---|
| **Hardware** | <!-- fill in --> |
| **OS** | <!-- fill in --> |
| **Shell** | <!-- fill in --> |
| **Primary AI tools** | AI toolchain, opencode |
| **Credential store** | <!-- fill in --> |

**Confirmed toolchain:** <!-- fill in, e.g. `git`, `gh`, `mdbook`, `cargo`/Rust, `uv`, `jq` -->

---

## Agent Tool Directories

This project may be used by **both AI toolchain and opencode**. Both toolchains are
first-class citizens. Each has its own agent directory with tool-specific frontmatter.
They must stay in sync via the `.agents/` canonical source layer.

| Directory | Tool | Format | Notes |
|-----------|------|--------|-------|
| `.agents/` | (canonical source) | Body only — no frontmatter | **Edit here first** — single source of truth |
| `.agents/_meta.yaml` | (canonical source) | YAML — per-agent frontmatter config | Drives sync script |
| `.agents/sync-agents.sh` | (sync script) | zsh | Run after any agent body or meta change |
| `.agentic/agents/` | AI toolchain | `name:` frontmatter | AUTO-GENERATED — do not hand-edit |
| `.opencode/agents/` | opencode | `description:` + `mode:` frontmatter | AUTO-GENERATED — do not hand-edit |

**Rule:** Never hand-edit `.agentic/agents/` or `.opencode/agents/` directly. All agent
changes go through `.agents/<name>.md` + `_meta.yaml`, then run `sync-agents.sh`.

---

## Agent Roster

| Agent | Role | Mode | Invoked By |
|-------|------|------|-----------|
| `lead-engineer` | Orchestrator — routes work to specialists; owns task queue and bench lifecycle | primary | User |
| `orchestrator` | Routing planning agent — produces ROUTING_PLAN blocks, applies invariants, signals fallback | subagent | lead-engineer |
| `docs-engineer` | Documentation — mddocs, ADRs, runbooks, mdbook site | subagent | lead-engineer |
| `docs-reviewer` | Documentation quality gate — typos check, link check, style review; evaluative only | subagent | lead-engineer |
| `ops-engineer` | Operational scripts, automation, developer environment tooling | subagent | lead-engineer |
| `release-engineer` | CI/CD pipeline, branch/tag workflow, README as-built updates | subagent | lead-engineer |
| `security-engineer` | Security controls, hook logic, content inspection gate | subagent | lead-engineer |
| `security-reviewer` | Adversarial security review — verdict-only, never modifies files | subagent | lead-engineer |
| `ai-engineer` | AI agent configuration, MCP server development, AI-assisted workflow integration | subagent | lead-engineer |

<!-- Add project-specific agents here if your project introduces new specialist roles. -->

### Two-Role Documentation Model

| Role | `docs-engineer` | `docs-reviewer` |
|------|-----------------|-----------------|
| **Purpose** | Author and maintain documentation | Evaluate documentation quality before acceptance |
| **Gate type** | Implementation (writes and edits) | Quality gate (evaluates before branch_ready) |
| **Produces** | ADRs, runbooks, SUMMARY.md updates | Verdict: `APPROVED` / `APPROVED WITH NOTES` / `BLOCKED` |
| **Can fix findings?** | Yes | No — escalates to docs-engineer |

### Two-Role Security Model

| Role | `security-engineer` | `security-reviewer` |
|------|---------------------|---------------------|
| **Purpose** | Build and operate security controls | Evaluate architecture decisions before acceptance |
| **Gate type** | Content inspection (pre-action) | Architecture sign-off (pre-acceptance) |
| **Produces** | Working changes, runbooks, hook logic | Verdict: `APPROVED` / `APPROVED WITH NOTES` / `BLOCKED` |
| **Can implement remediations?** | Yes | No — escalates to security-engineer |

---

## Key Paths

| Path | Purpose |
|------|---------|
| `.agents/` | Canonical agent definitions (single source of truth) |
| `.agents/_meta.yaml` | Per-agent frontmatter config for AI toolchain and opencode |
| `.agents/sync-agents.sh` | Generates `.agentic/agents/` and `.opencode/agents/` |
| `.agents/bootstrap/` | Provision templates (bench assignment, AGENT.md patterns, context template) |
| `.agentic/agents/` | AI toolchain agent definitions (AUTO-GENERATED — do not hand-edit) |
| `.opencode/agents/` | opencode agent definitions (AUTO-GENERATED — do not hand-edit) |
| `tasks.yaml` | Agent-facing task queue |
| `bench-registry.yaml` | Bench state registry |
| `.agentic/hooks/` | AI toolchain hooks (Stop, PreToolUse, PostToolUse) |
| `.opencode/plugins/` | opencode plugins (TypeScript) |
| `.core/agents/` | Shared agent context (this directory) |
| `mddocs/` | Documentation hub (mdbook site) |
| `mddocs/adr/` | Architecture Decision Records |
| `mddocs/operations/runbooks/` | Operational runbooks |
| `mddocs/scripts/` | Automation scripts |
| `mddocs/SUMMARY.md` | mdbook table of contents |

---

## Multi-Tool Note

This project may be **shared between AI toolchain and opencode**. Both are first-class
development tools used in active sessions:

- **AI toolchain** — reads `.agentic/agents/`, `AGENT.md`, hooks
- **opencode** — reads `.opencode/agents/`, `opencode.json`, plugins

Both toolchains read `AGENT.md`, `PROCESS.md`, and this context file. Both must be kept
in sync when agent definitions change. The `.agents/` canonical source layer and
`sync-agents.sh` are the mechanism for keeping them in sync.

**Branch naming:** `<type>/<ticket-id>-<short-slug>`
Prefixes: `feat/`, `fix/`, `docs/`, `chore/`, `security/`

**Commit discipline:** Commit after each discrete unit of work. Do not accumulate changes
across multiple subtasks before committing. See the session-continuity runbook:
`mddocs/operations/runbooks/session-continuity.md`
