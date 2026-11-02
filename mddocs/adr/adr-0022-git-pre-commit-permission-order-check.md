# ADR-0022: Git-Native Pre-Commit Permission-Order Check and Install-Only Hook Installer

**Date:** 2026-07-30
**Status:** proposed
**Supersedes:** —
**Superseded by:** —

## Context

opencode evaluates `permission` rules with **last-match-wins** semantics: when
multiple glob patterns match a command, the pattern declared **last** in the object
wins. A catch-all `"*"` that is not the first key therefore silently overrides every
more-specific rule declared before it. This repo confirmed a live instance of that
ordering bug and fixed it under TC-036 — the corrected `opencode.json` now declares
`"*": "ask"` as the first key under `permission.bash`, with `"git *": "allow"`
preceding all the specific `git ... : "ask"` rules.

TC-036 fixed the live config but left the failure mode ungated: nothing prevents a
future edit — by any tool or any human — from reintroducing an out-of-order catch-all.
TC-035 productizes two artifacts to close that gap and to make the corrected config
reusable:

1. A committed `opencode.json.template` with the permission block written
   catch-all-first by construction.
2. A regression guard that verifies the ordering invariant at commit time.

**Two existing hook surfaces, and why neither is sufficient alone.**

This repo already ships `.agentic/hooks/` **PreToolUse** hooks (e.g. `secret-guard.py`,
`package-install-guard.py`). Those hooks intercept **AI toolchain tool calls** — they
fire when AI toolchain is about to run a Bash command or a Write. They do **not** fire
on a `git commit` produced by any other path: a human running `git commit` at a
terminal, opencode's own git usage, an editor's git integration, or a CI job. A
permission-ordering regression can be introduced and committed through any of those
paths, entirely outside AI toolchain's PreToolUse surface.

A **git-native pre-commit hook** fires on every commit to this repo regardless of
which tool or CLI produced it. That is the correct surface for a commit-time content
invariant. The two mechanisms are therefore **parallel and complementary**, not a
replacement:

| Surface | Fires on | Covers |
|---|---|---|
| `.agentic/hooks/` PreToolUse | AI toolchain tool calls | AI toolchain-initiated Bash/Write only |
| git pre-commit (this ADR) | any `git commit` in this repo | all commit paths — human, CLI, any tool |

**Precedent — stated precisely.** The ordering-check *logic* (catch-all-must-be-first
under last-match-wins) is derived from TC-036, this repo's own confirmed live fix. The
*mechanism* — a git `pre-commit` hook plus an installer that places it into the git
hooks directory — is **newly introduced by this ADR**. There is no `.git/hooks/`
tracking, no committed hook-installer, and no `core.hooksPath` convention anywhere in
this repo today. This ADR does not extend or generalize any pre-existing git-hook
infrastructure, because none exists; it establishes the first instance.

## Decision

Introduce a git-native pre-commit permission-order check as a **parallel** enforcement
surface to the existing AI toolchain PreToolUse hooks, and ship an **install-only**
installer for it. Concretely:

1. **`.agentic/hooks/pre-commit-permission-order-check.py`** — a Python 3 git
   pre-commit hook. When `opencode.json` or `opencode.json.template` is among the
   staged files, it parses the **staged** version and verifies that `"*"` is the first
   key in every permission object whose keys are glob patterns (currently
   `permission.bash`). It fails the commit (non-zero exit, offending file/object named
   on stderr) if the catch-all is not first. Scalar permission entries
   (`webfetch`, `websearch`) are not glob objects and are not checked.

2. **`opencode.json.template`** — a committed template mirroring `opencode.json`, with
   the `permission.bash` block written catch-all-first by construction and the full
   deny/allow/ask rule set preserved. Environment-specific values (`model`,
   `default_agent`) are represented as `${...}` substitution placeholders, matching the
   `${COLLECTION_ROOT}` convention already used in `.mcp.json.template`. Session-Open
   command customization is documented as an explicit instantiation step in the
   bootstrap runbook, **not** baked into the template JSON.

3. **`.agentic/scripts/install-git-hooks.sh`** — an install-only script that copies the
   tracked hook into the git hooks directory and wires it as `pre-commit`. It resolves
   the hooks path with `git rev-parse --git-path hooks` (worktree-safe — returns the
   git-common-dir hooks path correctly from a linked worktree, unlike a hardcoded
   `.git/hooks/`) and makes the installed hook executable. There is **no `--check`
   mode** — the script does one thing: install.

### Template placeholder handling in the hook

The template carries `${...}` placeholders that are not valid JSON until instantiation.
The permission block itself contains no placeholders, but the hook must not crash on
the template as committed. Before parsing, the hook replaces any `${...}` token with a
neutral literal, then parses tolerantly. This lets the same check run against both the
live `opencode.json` (no placeholders) and the `opencode.json.template` (placeholders
present) without special-casing either.

### HIL decisions recorded by this ADR

- **Install-only; `--check` mode dropped.** The ticket permitted dropping `--check`
  rather than shipping dead code. The installer ships the install path only. Nothing is
  wired into any Session-Open checklist (`AGENT.md`, `lead-engineer.md`,
  `baseline-steward.md`).
- **This ADR ships the mechanism; it does not install it.** Installing a git hook is a
  privileged, per-repo action governed by Invariant #10 (no installing/modifying git
  hooks without explicit written authorization). The deliverables are the tracked hook
  source, the installer script, and this ADR — all committed. Actually running
  `install-git-hooks.sh` against any `.git/hooks/` (or setting `core.hooksPath`) is a
  **separate, explicitly HIL-authorized action** that is out of scope for TC-035 and was
  not performed during authoring.

## Consequences

**Positive:**
- Closes the TC-036 regression gap at the commit boundary for **all** commit paths, not
  just AI toolchain tool calls.
- `opencode.json.template` makes the corrected, catch-all-first permission block a
  reusable artifact for new instantiations, removing the chance of re-deriving the bug
  by hand.
- Worktree-safe installer — the hook installs correctly from a linked worktree, not
  just the primary working tree.
- Mechanism and installer are committed and reviewable independently of the privileged
  install action, keeping Invariant #10 intact.

**Negative / Trade-offs:**
- Git hooks are per-clone and per-repo — they are not distributed automatically by
  `git clone`. Every environment that wants the guard must run the installer explicitly.
  This is inherent to git hooks and is the reason an installer exists at all.
- Introduces a second enforcement surface with its own maintenance cost. If the
  permission-object shape changes (e.g. a new nested glob object under `permission`),
  the hook's `find_glob_objects` traversal already handles nested dicts generically, but
  any change to opencode's evaluation semantics would require revisiting the invariant.
- Dropping `--check` means there is no dry-run/audit mode; re-adding one is a future
  ticket if an audit use-case emerges.

**Neutral:**
- The existing `.agentic/hooks/` PreToolUse hooks are unchanged. This ADR adds a parallel
  surface and does not modify, supersede, or depend on them.
- The live `opencode.json` is unchanged by this ADR — TC-036 already corrected it; this
  ADR guards it going forward and provides the template.

## Implementation Notes

- **`opencode.json.template`** (repo root) — mirrors the current `opencode.json`
  structure: `$schema`, `shell`, `instructions`, `model`, `default_agent`, `share`,
  `autoupdate`, `plugin`, `mcp` (rag-docs, review-ledger-security, review-ledger-reviews),
  `permission` (bash, webfetch, websearch), `compaction`. `model` and `default_agent`
  are `${OPENCODE_MODEL}` and `${OPENCODE_DEFAULT_AGENT}` placeholders. Validated as
  well-formed JSON after a dummy substitution; committed with placeholders intact.
- **`.agentic/hooks/pre-commit-permission-order-check.py`** — reads staged content via
  `git show :<path>`, neutralizes `${...}` placeholders before `json.loads`, and checks
  every glob-shaped permission object for catch-all-first ordering. Follows the house
  hook style (shebang, stderr messages, non-zero exit to block). Docstring states the
  failure mode generically with a reference to this repo's own TC-036 instance only — no
  external engagement or cross-repo provenance.
- **`.agentic/scripts/install-git-hooks.sh`** — install-only zsh script following the
  `inspect-repo-configs.sh` house style. Resolves the hooks dir via
  `git rev-parse --git-path hooks`, copies the hook under a stable name, and installs or
  idempotently updates a `pre-commit` dispatcher (preserving any pre-existing
  `pre-commit`). Authored as tracked source only; not executed during this ticket.
- **Instantiation step** — documented in
  [Bootstrap New Project](../reference.architecture/bootstrap-new-project.md) (the
  runbook that already copies and customizes `opencode.json`), covering
  `opencode.json.template` → `opencode.json`, `${...}` placeholder substitution, and the
  Session-Open command customization point.
- **Cross-reference:** TC-036 (live permission-ordering fix — the source of the ordering
  logic). This ADR introduces the git-native mechanism and installer, which have no
  prior instance in this repo.
