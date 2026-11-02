# ADR-0001: Bootstrap Architecture

**Date:** 2026-06-22
**Status:** accepted
**Scope:** v0.0.1 initial release — all foundational structural decisions
**Partially superseded by:** ADR-0026 (the branch-flow model below — `feat/* → dev → main → tag → release/*` and the branch-tier purpose table — is replaced by the curated release-branch model; the rest of this ADR remains authoritative)

---

## Overview

This ADR records the seven foundational architectural decisions made during the
initial bootstrap of the AgenticCore framework. These decisions were made as
a unit in a single design session and collectively define the structural,
operational, and governance foundation of the framework.

Each decision is recorded as a named section below. Future ADRs that supersede
any individual decision will reference this document and the specific section.

---

## Decision 1 — Repository Structure and Namespace

### Context

A portable agentic framework requires a clear, opinionated repository layout that:
- Separates agentic configuration from project artifacts
- Is self-documenting and navigable by both humans and agents
- Avoids project-specific bleed that reduces portability

Options considered:
1. Flat structure — simple but does not scale to multi-agent coordination
2. Monorepo with subdirectories per concern — chosen
3. Separate repos per concern — too much overhead for a framework repo

### Decision

The repository uses a monorepo layout with dedicated top-level directories per
concern. All documentation lives in `mddocs/`. All agent configuration lives in
`.agents/` (canonical source) with tool-specific outputs generated to `.opencode/agents/`
and `.agentic/agents/`. Operational scripts live in `mddocs/scripts/`. Session state
and task queue live in `.core/work/` and `tasks.yaml` at root.

The `.01` namespace (git worktree) is the lead-engineer's home. `.00` is the HIL
workspace. `.02`+ are ephemeral per-ticket worker benches.

### Consequences

**Positive:**
- Clear ownership — every file belongs to a known layer
- Portable — no project-specific paths or references at structural level
- Navigable — agents and humans can orient from the root

**Negative / Trade-offs:**
- More initial setup than a flat layout
- Requires discipline to keep layers separated

### See also

`mddocs/onboarding/repository-structure.md`

---

## Decision 2 — Credential Injection via direnv

### Context

Agentic workflows require access to Git tokens and other credentials at runtime.
Options:
1. Hardcode in config files — security violation; rejected
2. Environment variables set manually — fragile; error-prone
3. direnv with pass store integration — chosen
4. Vault/secrets manager — overkill for this framework tier

### Decision

All credentials are injected via `direnv` using `.envrc`. The `.envrc` reads from
a `pass` credential store using `$(pass show <path>)`. The `.envrc` is not committed.
A `.envrc.template` is committed as the reference. The `.gitignore` excludes both
`.envrc` and `.envrc.local` so that neither the working credential-injection file nor
its machine-local override is ever committed.

Remote-aware injection: the `.envrc` detects the git remote URL and selects the
appropriate credential path automatically.

### Consequences

**Positive:**
- Credentials never appear in git history
- Remote-aware selection eliminates manual credential switching
- `pass` provides GPG-backed encryption at rest
- Template provides clear onboarding path

**Negative / Trade-offs:**
- Requires `direnv` and `pass` installed
- GPG key must be unlocked for credential access
- Windows/non-POSIX environments need adaptation

**Neutral:**
- `.envrc` is per-checkout — each worktree has its own credential injection

### See also

`.envrc.template`, `mddocs/onboarding/getting-started.md`

---

## Decision 3 — Documentation-First Workflow with mdBook

### Context

The framework must maintain comprehensive, searchable, and versioned documentation
that supports agentic RAG (Retrieval-Augmented Generation) access patterns.

Options evaluated:
1. Zola (Rust SSG) — good performance; tabi theme supply chain concern; disqualified
2. MkDocs — Python dependency; not aligned with Rust toolchain preference
3. mdBook (Rust/Cargo) — chosen; native Rust, mdbook-mermaid available, Git Pages compatible
4. Custom Rust SSG — maximum control; eliminated on onboarding friction

### Decision

All documentation lives in `mddocs/` and is built with mdBook. Mermaid diagrams
are supported via `mdbook-mermaid` preprocessor. Diagrams are used only where they
genuinely clarify complex workflows — not decoratively.

`mddocs/` is the single source of truth. Every ADR, runbook, and procedure must be
in `mddocs/` and linked in `SUMMARY.md`.

### Consequences

**Positive:**
- Rust toolchain alignment — `cargo install mdbook` is one command
- Git Pages compatible — CI pipeline publishes on push to main
- Mermaid support without external dependencies
- Flat Markdown files — fully RAG-indexable

**Negative / Trade-offs:**
- No live search without additional plugin
- Contributors must keep `SUMMARY.md` current manually
- `mdbook-mermaid` adds a preprocessor dependency

### See also

Build: `mdbook build mddocs/` — Serve: `mdbook serve mddocs/`
CI pipeline: `.git-ci.yml`

---

## Decision 4 — Agentic Bench Model and Namespace Hierarchy

### Context

Running multiple AI agent sessions concurrently against the same repository risks
conflicting writes, loss of context isolation, and unclear ownership of in-progress
work. A structured isolation model mapped to git's native primitives is required.

### Decision

Workspaces are organized as **git worktrees** in a numbered namespace hierarchy:

- `.00` — HIL (human) workspace. Long-living. Owner-controlled.
- `.01` — Lead-engineer. Long-living. Owns task queue and bench lifecycle.
- `.02`+ — Worker benches. Ephemeral. Provisioned per ticket by lead-engineer.

Each namespace suffix corresponds to a git worktree checked out to a specific branch.
Context isolation is enforced by worktree scope — each agent session opens in its
assigned worktree.

Lead-engineer (`.01`) is the sole orchestrator. It never executes task work directly.
Bench leads (`.02`+) may not write to `.01` namespace.

### Consequences

**Positive:**
- Native git primitive — no external tooling required
- Clear ownership — each worktree is a named, trackable workspace
- Parallel execution — multiple tasks can run concurrently without conflicts
- Recoverable — any bench can be rebuilt from its branch

**Negative / Trade-offs:**
- Requires discipline at teardown — orphaned worktrees accumulate if not cleaned
- Context does not cross worktrees — relay protocol required for cross-bench work

### See also

`mddocs/reference.architecture/provision-worker-bench.md`
`mddocs/reference.architecture/bench-registry.md`

---

## Decision 5 — Agent Definition Propagation

### Context

AI tools (OpenCode, AI toolchain, and future tools) each have their own agent
definition format and location. Maintaining separate definitions per tool creates
drift and makes updates expensive.

### Decision

Agent definitions are maintained in `.agents/` as the canonical source:
- `<name>.md` — the agent body (tool-agnostic persona and instructions)
- `_meta.yaml` — per-agent metadata (mode, permissions, description, tool-specific frontmatter)
- `sync-agents.sh` — generates tool-specific outputs from the canonical source

Tool-specific directories (`.opencode/agents/`, `.agentic/agents/`) are **auto-generated**
outputs. They must not be hand-edited. All changes go to `.agents/` first.

### Consequences

**Positive:**
- Single source of truth for all agent logic
- Adding a new AI tool only requires a new generator block in `sync-agents.sh`
- Clean diffs — canonical source changes are meaningful

**Negative / Trade-offs:**
- Requires running `sync-agents.sh` after every agent body change
- Auto-generated files in the repo may confuse contributors unfamiliar with the pattern

### See also

`.agents/sync-agents.sh`, `mddocs/reference.architecture/agent-authoring-workflow.md`

---

## Decision 6 — Commit and Push Acceptance Gate

### Context

Agents with autonomous write access to git can commit and push work without
adequate human review, creating risk of incorrect changes landing, secrets being
committed, and unauditable history.

### Decision

All commits and pushes require explicit HIL acceptance before execution.
Enforced in two layers:

1. **Instruction layer** — `.opencode/commit-push-gate.md` is loaded as a system
   instruction. Agents must present a staged change summary and wait for explicit
   acceptance before running `git commit` or `git push`.

2. **Permission layer** — `opencode.json` sets `"git commit *": "ask"` and
   `"git push *": "ask"`, triggering a platform-level confirmation prompt.

Acceptance signals: "lgtm", "commit it", "go ahead", "yes".
Ambiguous signals ("ok", "sure") are not acceptance — agent must ask for clarification.

### Consequences

**Positive:**
- Every commit is human-reviewed before landing
- Double-enforcement provides defense in depth
- Audit trail in session log for every accepted commit

**Negative / Trade-offs:**
- Intentional friction — adds a confirmation step to every commit and push
- Cannot be waived — no session-level "proceed autonomously" override

### See also

`.opencode/commit-push-gate.md`, `opencode.json`

---

## Decision 7 — Branch Protection and Merge Strategy

### Context

The repository needs a branching strategy that protects `main` as stable,
supports active development on `dev`, provides stable release lines, and
preserves branch history for auditability.

### Decision

Three permanent branch tiers:

| Branch | Purpose | Who can push |
|---|---|---|
| `main` | Stable, reviewed code | Merge only (no direct push) |
| `dev` | Active development integration | Feature branches merge here first |
| `release/vX.Y.Z` | Stable release lines | Release-engineer via tag workflow |

Feature/task work uses short-lived branches from `dev`:
- Naming: `<type>/<ticket-id>-<short-slug>`
- Types: `feat`, `fix`, `docs`, `security`, `poc`, `review`, `release`

Merge strategy: `git merge --no-ff` everywhere — merge commits are required.
Flow: `feat/*` → `dev` → `main` → (tag) → `release/vX.Y.Z`

> **Superseded by ADR-0026 (2026-08-20).** The wholesale flow above (treating `dev` as
> the release candidate) is replaced by a curated release-branch model: `dev` is the
> integration + durability surface, release prep branches are cut from `main`, and only
> complete/closed tickets' commits are cherry-picked onto them. See ADR-0026 for the
> authoritative branch model. The branch-tier table above remains accurate for branch
> *purpose*, but `dev`'s role is now "integration + durability surface, never the release
> candidate."

### Consequences

**Positive:**
- `main` is always in a known-good state
- No-fast-forward merges make history readable and auditable
- `release/*` branches allow patch work on older releases without touching main

**Negative / Trade-offs:**
- Merge commits add noise in simple linear workflows
- Requires CI validation before merge to main (TC-002)

### See also

`mddocs/reference.architecture/release-process.md`, `.git-ci.yml`
