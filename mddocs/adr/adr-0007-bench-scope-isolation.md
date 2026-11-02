# ADR-0007: Agent Bench Scope Isolation — Current Controls, Bash Tool Gap, and Options

**Date:** 2026-05-19
**Status:** proposed
**Supersedes:** —

## Prior Art

EXAMPLE-ADR-0021 (Agent Bench Scope Isolation — Current Controls, Bash Tool Gap, and
Options, 2026-05-19). Bench isolation controls, Bash tool gap analysis, and options
taxonomy carried forward; EXAMPLE-specific bench naming replaced with generic placeholders.

---

## Context

The numbered-bench model isolates agent work into discrete git worktrees
(`<program>.NN`). Each bench has a defined scope: `.00` is the owner's
protected workspace; `.01` is the lead-engineer and the sole holder of git history,
the task queue, and remote push rights; `.02`+ are worker benches executing assigned
tasks.

An agent session opened in `.02` should logically be confined to `.02`. In practice,
three enforcement layers exist — but they do not all cover the same tools.

## Current Controls

| Control | Tool(s) covered | Scope boundary | How enforced |
|---------|----------------|---------------|--------------|
| `read-scope-guard.py` PreToolUse hook | `Read` tool | `git rev-parse --show-toplevel` → worktree root | Exits 2 (block) if resolved path is outside collection root or `~/.agentic/projects/` |
| `.mcp.json` path restriction | `mcp__filesystem__*` tools | Single bench directory (`--allow-write {{BENCH_DIR}}`) | MCP server rejects requests outside its allowed paths |
| `AGENT.md` / bench AGENT.md instruction | All tools (process) | Bench-scoped work; do not access sibling benches | Model instruction; no technical enforcement |

In a git worktree, `git rev-parse --show-toplevel` returns the worktree path, not `.01`.
So `read-scope-guard.py` is already correctly bench-scoped when running from a worker bench.

## The Gap

The `Bash` tool has no path guard. An agent in `.02` can freely:

```bash
cat /path/to/<program>.01/.agentic/work/tasks.yaml
git -C /path/to/<program>.01 log
ls /path/to/<program>.00/
```

No hook, no MCP restriction, and no permission setting blocks these. The only gate
is the AI toolchain UI permission prompt.

## Decision Drivers

- `.00` is the owner's protected workspace; no agent should read or write it without explicit per-action owner approval
- `.01` holds the task queue, git history, and all management state
- The UI permission prompt is a real gate, but it requires the owner to recognize the cross-bench path

## Considered Options

### Option 1 — Bash scope guard hook (`bench-scope-guard.py`)

New PreToolUse hook on `Bash`. Uses `git rev-parse --show-toplevel` to determine the
bench root, then scans the command string for absolute paths that fall under the program
namespace but outside the current bench. Blocks on match; allows system paths, user home,
and `~/.agentic/`.

### Option 2 — `permissions.deny` additions

Add explicit deny entries to `settings.local.json.template` for each protected bench path.
No new code; uses the built-in deny mechanism. Must enumerate each protected path by name.

### Option 3 — Accept UI permission prompt as sufficient gate

No technical change. Document the gap in this ADR and in the bench AGENT.md convention.
Owner is the gate; the permission prompt already fires for out-of-scope Bash reads.

## Decision

**Pending.** Owner is evaluating whether the UI permission prompt provides sufficient
protection or whether a technical control is warranted.

Until a decision is recorded here, Option 3 is the de facto state: the UI gate is
active, and bench AGENT.md files instruct agents not to access sibling bench directories.

## Consequences

**Positive (if a technical control is chosen):**
- Cross-bench Bash access is blocked at the tool layer, not just the UI layer
- Owner does not need to recognize a cross-bench path in a permission prompt

**Negative / Trade-offs:**
- Option 1 is heuristic: shell variable substitution (`$BENCH_DIR/file`) bypasses it
- Option 2 requires manual maintenance as bench slots change
- Either option adds hook execution overhead to every Bash call

**Neutral:**
- Decision is reversible — adding a hook later requires no architectural change

## Lessons Learned

An agent in a worker bench can construct absolute paths into sibling bench directories
that are functionally identical to the path it should use. The gap is not exotic — it
occurs naturally when an agent has seen a cross-bench path in session context. The Read
guard handles the `Read` tool correctly; the same protection does not automatically
extend to Bash.

## Related

- [ADR-: Agentic Agent Enforcement Posture](adr-0022-git-pre-commit-permission-order-check.md)
- [ADR-0006: External Content Gate Scope](adr-0006-external-content-gate-scope.md)
- [ADR-0008: Orchestrator Subagent Routing Layer](adr-0008-orchestrator-subagent-routing-layer.md)
