# AgenticCore — Portable Agentic Framework

**AgenticCore** is a portable, documentation-first, open-source harness for
orchestrating tool-use AI agents in a team-based architecture. It is designed
for developers, DevOps, and Site Reliability Engineers building agentic workflows.

## Purpose

This repository provides:

- A **reusable agentic workflow model** based on a git-worktree bench hierarchy
- A **documentation-first discipline** maintained entirely through mdBook
- **Sanitized, portable patterns** for project onboarding, initialization, and agentic operation
- **Automation scripts** with companion runbooks for every operational procedure

## Core Principles

| Principle | Implementation |
|---|---|
| Documentation-first | All decisions, workflows, and procedures live in `mddocs/` |
| Agentic portability | Agent definitions in `.opencode/agents/` — tool-agnostic source in `.agents/` |
| Namespace separation | `.00` (HIL) / `.01` (lead-engineer) / `.02`+ (ephemeral workers) |
| HIL acceptance gate | No merge, push, or external action without explicit human approval |
| Minimal viable config | Lean, auditable, no project-specific bleed |

## Quick Start

```sh
# Clone and enter the repository
git clone https://git.example.com/example-group/AgenticCore.git
cd AgenticCore

# Copy and configure credential injection
cp .envrc.template .envrc
# Edit .envrc to wire your credential store

# Allow direnv
direnv allow

# Build the documentation
mdbook build mddocs/
mdbook serve mddocs/
```

## Repository Map

```
AgenticCore/
├── AGENT.md                  # Root instruction — session rules and persona
├── PROCESS.md                # Canonical workflow, roles, and governance
├── opencode.json             # AI toolchain configuration
├── tasks.yaml                # Task queue (lead-engineer only writes here)
├── bench-registry.yaml       # Bench state registry
├── .agents/                  # Canonical agent definition source
├── .core/                    # Governance + enforcement layer
│   ├── Core.md               # Instruction contract (session checklists, standing rules)
│   ├── invariants.md         # Absolute prohibitions — loaded by every agent
│   ├── hooks/                # Enforcement scripts
│   ├── scripts/              # Environment + hook tooling
│   ├── bootstrap/            # Bench/project bootstrap templates
│   ├── agents/               # Shared agent context
│   └── work/                 # Task queue and session state
├── .opencode/                # AI-toolchain-specific config (auto-generated)
├── mddocs/                   # All documentation (mdBook site)
│   ├── adr/                  # Architectural Decision Records
│   └── scripts/              # POSIX-compliant automation scripts
└── mcp/                      # MCP server implementations
```

## Navigation

- New to the project? Start with [Getting Started](onboarding/getting-started.md)
- Understanding the workflow? See [Agentic Workflow Overview](onboarding/agentic-workflow-overview.md)
- Architecture decisions: [ADR Index](adr/index.md)
- Operational procedures: [Runbook Index](reference.architecture/index.md)
