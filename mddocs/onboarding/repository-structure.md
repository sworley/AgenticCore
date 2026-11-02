# Repository Structure

```
AgenticCore/
│
├── AGENT.md                        Lead-engineer persona (AI toolchain)
├── PROCESS.md                       Canonical workflow, roles, governance
├── opencode.json                    OpenCode tool configuration
├── tasks.yaml                       Task queue — lead-engineer is sole writer
├── .gitignore
├── .envrc.template                  Credential injection template
│
├── .agents/                         Canonical agent source definitions
│   ├── _meta.yaml                   Agent registry metadata
│   ├── ai-engineer.md
│   ├── attendant.md
│   ├── baseline-steward.md
│   ├── docs-engineer.md
│   ├── lead-engineer.md
│   ├── ops-engineer.md
│   ├── orchestrator.md
│   ├── release-engineer.md
│   ├── security-engineer.md
│   ├── security-reviewer.md
│   └── sync-agents.sh               Generates tool-specific agent files
│
├── .opencode/                       OpenCode-specific configuration
│   ├── commit-push-gate.md          Commit/push acceptance gate instructions
│   ├── agents/                      Auto-generated from .agents/
│   └── plugins/
│       └── session-close-reminder.ts
│
├── .core/work/                           Session state and relay notes (tracked)
│   ├── README.md                    Task queue schema reference
│   ├── relay-pending.md             Cross-bench relay queue
│   └── session-state-<date>.md     Session memory files
│
├── mddocs/scripts/                  Automation scripts (collocated with docs)
│   ├── bench-status.sh              Show all worktree states
│   ├── check-env.sh                 Validate developer environment
│   ├── provision-bench.sh           Provision an ephemeral worker bench
│   └── check-worktree-hygiene.sh   Verify all worktrees are clean
│
├── mddocs/                          All documentation (mdBook source)
│   ├── book.toml                    mdBook configuration
│   ├── SUMMARY.md                   Table of contents
│   ├── index.md                     Home page
│   ├── backlog.md                   Human-readable task backlog mirror
│   ├── mermaid.min.js               Mermaid diagram support
│   ├── mermaid-init.js
│   ├── adr/                         Architectural Decision Records
│   ├── reference.architecture/      Runbooks and implementation guides
│   ├── onboarding/                  Getting started documentation
│   └── operations/runbooks/         Operational procedures
│
├── _config/                         Tracked AGENT.md recovery archive
│   ├── README.md
│   └── repos-AGENT.md
│
└── _oob/                            Out-of-band scratch (tracked for audit)
```

## Key Conventions

- `mddocs/` is the single source of truth for all documentation
- `.agents/` is the canonical source for agent definitions — never hand-edit `.opencode/agents/` directly
- `tasks.yaml` is owned exclusively by the lead-engineer (`.01`)
- `.core/work/` tracks session state — commit at every session close
- `_oob/` captures orphaned artifacts — never silently ignore untracked files
