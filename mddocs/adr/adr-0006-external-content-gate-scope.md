# ADR-0006: External Content Gate Scope and Plane Separation Model

**Date:** 2026-05-17
**Status:** accepted
**Supersedes:** —

## Prior Art

EXAMPLE-ADR-0019 (Security Gate Scope, Management/Customer Plane Model, and Agent-Level
Enforcement, 2026-05-17). Gate scope definitions and plane separation model carried
forward; customer-plane and IL2-specific enforcement details removed.

---

## Context

Three related problems were identified:

**Problem 1 — External content gate definition gap.**
The lead-engineer content inspection gate named WebFetch URLs, files ingested from outside
the collection, user-supplied data, and third-party API responses — but not `git clone`,
`git pull`, `git rebase`, or package dependency installation. An agent reading the
definition literally could skip inspection for any of those operations.

**Problem 2 — No explicit rule prohibiting git hook installation in external repos.**
No agent definition stated that git hooks must not be installed in repositories outside
the management plane without team and customer approval.

**Problem 3 — Plane model not formally recorded.**
The management/external plane separation was implemented in code but not documented as
a named architectural decision with explicit scope, enforcement mechanism, and
forward-looking notes.

## Decision Drivers

- Zero-trust posture: all external material must be inspected before agents act on it
- Security asymmetry: the management plane warrants maximum agentic control; the external
  plane requires explicit approval before infrastructure changes are made
- Incremental hardening: implement agent-level enforcement now; defer system-level git
  hooks until the model is validated

## The Management / External Plane Model

### Management Plane

| Property | Value |
|---|---|
| Git root | `<program>.01/.git` |
| Worktrees | `.00` (owner HIL), `.01` (lead-engineer), `.02`+ (workers) |
| Contents | Tickets, agent definitions, AGENT.md files, hooks, scripts, ADRs, runbooks |
| Security posture | Maximum — all agentic guardrails apply |

### External / Customer Plane

| Property | Value |
|---|---|
| Location | Subdirectories within bench worktrees |
| Contents | External code, IaC, pipeline configs |
| Security posture | Read/execute within bench sessions; no infrastructure changes without explicit approval |

### Hard Boundary

`.gitignore` in `.01` explicitly lists every external repo name. External code cannot
enter management git history by accident or agent error.

## Decisions

### Decision 1 — External Content Gate Scope

The following operations are explicitly classified as external content and require
security-engineer content inspection before any agent acts on the result:

| Operation | Risk |
|---|---|
| `git clone` of an external repository | Bulk ingestion of unreviewed code |
| `git pull` against an external upstream | Incremental commit ingestion; upstream poisoning |
| `git rebase` against an external upstream | Replay of external commits onto a clean branch |
| Package install (`cargo add`, `npm install`, `pip install`, or equivalent) | Third-party code introduction; supply chain risk |
| URL fetch via WebFetch | Arbitrary external content |
| File ingested from outside the collection | Arbitrary external file |
| User-supplied text acted on as data | Prompt injection surface |
| Third-party API response | Untrusted data |

### Decision 2 — No Git Hooks on External Repositories

No agent may install, configure, modify, or remove git hooks in any external or customer
repository without explicit written approval from both the delivery team and the customer.

### Decision 3 — Agent-Level Enforcement Only (for Now)

**Chosen approach:** Agent-level guardrails only. System-level git hooks are not
implemented at this time. The management plane is always operated under agentic control,
so agent-level rules cover the primary enforcement surface.

The decision is reversible — implementing system-level hooks later requires no
architectural change.

## Consequences

**Positive:**
- External content gate has no ambiguous cases — every common agentic operation that introduces external material is named explicitly
- The incremental approach (agent-level first) allows validation before committing to system-level changes

**Negative / Trade-offs:**
- Agent-level enforcement relies on the agent reading and following its definition
- System-level git hooks (backstop for human-in-terminal scenarios) remain unimplemented until a future decision
- `.gitignore` must be manually updated each time a new external repo is added

**Neutral:**
- The model accommodates future external planes with no structural changes

## Lessons Learned

Security boundaries that exist as convention need to be written as named rules to be
enforceable by agents. "Everybody knows" is not a guardrail.

Incremental hardening is a valid strategy when the enforcement surface is narrow and
well understood.

## Related

- [ADR-: Agentic Agent Enforcement Posture](adr-0022-git-pre-commit-permission-order-check.md)
- [ADR-0007: Bench Scope Isolation](adr-0007-bench-scope-isolation.md)
- `PROCESS.md` — human gate and security inspection gate contract
