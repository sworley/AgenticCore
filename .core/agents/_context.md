# AgenticCore.000 — Shared Agent Context

<!-- schema: agent-context/v1 -->
<!-- Required sections: Identity, Bench Model, Agent Roster, Environment -->
<!-- Decision basis: ADR- (Agent Portability Model) -->

**Read this file at the start of every session before taking any action.**

This is a vendor-neutral shared context file. It is read by all agents from all toolchains
(opencode, Codex CLI, and any future runtime). It contains no tool-specific syntax.

---

## Identity

| Field | Value |
|---|---|
| **Project name** | `AgenticCore` |
| **Purpose** | Reference harness for orchestrating tool-use LLM agents |
| **Git remote** | `<Git hosting-host>/<org>/<repo>` |
| **License** | MIT |

This is a **harness repo**. It contains agent definitions, tooling, process documentation,
ADRs, and bootstrap templates for projects that adopt the AgenticCore pattern.

---

## Bench Model

The project uses a numbered worktree convention. All benches are git worktrees of the
same repo, sharing `.git/` at the repo root.

| Bench | Path | Role | Notes |
|---|---|---|---|
| `.00` | `AgenticCore.00` | Owner workspace | IDE work, R&D, scratch — never assign agent tasks here |
| `.01` | `AgenticCore.01` | Lead-engineer | Owns `main`, remote, task queue, bench lifecycle |
| `.02`+ | `AgenticCore.02`, `.03` | Worker benches | Execute assigned tasks; do not merge, do not push |

**Rule:** `.01` provisions and coordinates. Worker benches execute. Agent task work never
happens directly in `.01` — if a task requires building, running, or generating artifacts,
stop and assign to a worker bench.

Bench registry: `bench-registry.yaml`

---

## Agent Roster

| Agent | Role | Mode |
|---|---|---|
| `lead-engineer` | Orchestrates routing; owns task queue and bench lifecycle; primary entry point | primary |
| `orchestrator` | Routing planning agent — produces ROUTING_PLAN blocks, applies invariants, signals fallback | subagent |
| `docs-engineer` | Documentation — mddocs, ADRs, runbooks | subagent |
| `docs-reviewer` | Documentation quality gate — evaluative only | subagent |
| `ops-engineer` | Operational scripts, automation, developer environment tooling | subagent |
| `ai-engineer` | AI agent config, MCP servers, workflow integration | subagent |
| `attendant` | Pattern W bench-lead for project-scoped work | primary |
| `baseline-steward` | Framework improvement lifecycle — governance, versioning, release | subagent |
| `release-engineer` | Tactical release execution — CI/CD, branch/tag workflow | subagent |
| `security-engineer` | Security controls, hook logic, content inspection gate | subagent |
| `security-reviewer` | Adversarial security review — verdict-only, never modifies files | subagent |
| `ux-engineer` | UI/UX, information architecture, accessibility, developer experience | subagent |
| `hil-assistant` | HIL-proximate collaborator in `.00`; personal management plane | primary |
| `code-reviewer` | Semantic code review — evaluates before commits; never modifies files | subagent |
| `azure-cloud-engineer` | Cloud architecture specialist — IaC, Well-Architected, region/compliance | subagent |
| `infra-engineer` | Infrastructure engineer — IaC, networking, deployment lifecycle | subagent |

### Two-Role Documentation Model

| Role | `docs-engineer` | `docs-reviewer` |
|---|---|---|
| **Purpose** | Author and maintain documentation | Evaluate documentation quality before acceptance |
| **Gate type** | Implementation (writes and edits) | Quality gate (evaluates before branch_ready) |
| **Produces** | ADRs, runbooks, SUMMARY.md updates | Verdict: APPROVED / APPROVED WITH NOTES / BLOCKED |
| **Can fix findings?** | Yes | No — escalates to docs-engineer |

### Two-Role Security Model

| Role | `security-engineer` | `security-reviewer` |
|---|---|---|
| **Purpose** | Build and operate security controls | Evaluate architecture decisions before acceptance |
| **Gate type** | Content inspection (pre-action) | Architecture sign-off (pre-acceptance) |
| **Produces** | Working changes, runbooks, hook logic | Verdict: APPROVED / APPROVED WITH NOTES / BLOCKED |
| **Can implement remediations?** | Yes | No — escalates to security-engineer |

---

## Environment

| Field | Value |
|---|---|
| **Primary AI toolchain** | opencode (primary); Codex CLI (deferred) |
| **LLM endpoint** | `http://llm-inference-service:8000/v1` (K8s ExternalName service) |
| **Credential store** | Environment variables (pass + direnv optional) |
| **Confirmed toolchain** | `git`, `python3`, `mdbook`, `yq`/`jq` |

## Key Paths

| Path | Purpose |
|---|---|
| `.core/Core.md` | Instruction contract — session checklist, standing rules |
| `.core/invariants.md` | Absolute prohibitions — loaded by every agent |
| `tasks.yaml` | Agent-facing task queue |
| `bench-registry.yaml` | Bench state registry |
| `.core/hooks/` | Enforcement scripts (secret-guard, scope-guard, install-guard) |
| `mddocs/` | Documentation hub (mdbook site) |
| `mddocs/adr/` | Architecture Decision Records |

## Multi-Tool Note

This project is **opencode-first**. opencode agent definitions are the primary output.
Compatible toolchain support is available via the `.agents/_meta.yaml` + `sync-agents.sh`
layer if needed. Codex CLI support is a placeholder, deferred to backlog.

**Branch naming:** `<type>/<ticket-id>-<short-slug>`
Prefixes: `feat/`, `fix/`, `docs/`, `chore/`, `security/`

**Commit discipline:** Commit after each discrete unit of work. Do not accumulate changes
across multiple subtasks before committing.
