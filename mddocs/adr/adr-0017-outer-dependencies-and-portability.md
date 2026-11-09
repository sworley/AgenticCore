# AC ADR-0017: Outer Dependencies and Portable Configuration

**Date:** 2026-07-02
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Prior Art

EXAMPLE-ADR-0010 (Outer Dependencies and Portable Configuration, 2026-05-05).
This ADR generalizes the portability conventions established in that document
as framework-level standards applicable to any AgenticCore adopter.
Infrastructure-specific outer dependency entries (cloud toolchain, CA bundles,
Azure credentials) are adopter-specific and are not carried forward.

---

## Context

All tooling, scripts, and agent configuration in an AgenticCore-governed
project must be usable by any engineer who clones the repository — regardless
of their username, home directory path, or where on disk they clone it.

Without explicit conventions, projects accumulate hardcoded absolute paths,
machine-specific configuration committed to git, and onboarding steps that
require manual find-and-replace. This creates a class of "works on my machine"
failures that are invisible until a second engineer attempts to use the project.

This ADR establishes:
1. The categories of outer dependencies that live outside the project root and
   are inherently machine-specific
2. The portability conventions that apply to everything committed inside the
   project root

---

## Decision Drivers

- **Portability** — any engineer clones the repo and runs a single init script;
  no manual path substitution required
- **Maintainability** — machine-specific values are generated at setup time,
  not committed; committed artifacts are always portable
- **Discoverability** — onboarding engineers have a single catalog of what must
  be set up outside the project root before the project is usable
- **Auditability** — outer dependencies are visible at ADR level so changes
  (new credential requirements, new tool dependencies) are deliberate decisions

---

## Outer Dependencies — Categories

These items live outside the project root. They are required for the toolchain
to function but cannot be committed to the project repository. Each engineer
satisfies them on their own machine following the project's onboarding guide.

| Category | Examples | Notes |
|----------|---------|-------|
| Shell environment | `~/.zshrc`, `~/.bashrc` | PATH, tool-specific env vars, non-credential config vars |
| Secret store | `pass`, system keychain, organizational vault | Credential values only — never committed; see ADR-0016 |
| Language runtimes and package managers | `python3`, `uv`, `node`, `cargo` | Installed via system package manager or version manager |
| System package manager | Homebrew (macOS), apt, etc. | Platform-dependent; tool resolution via `$PATH` |
| Generated configuration | `.mcp.json`, `settings.local.json` | Machine-specific; gitignored; generated from templates at setup time |
| Credential injection tooling | `direnv` or equivalent | Injects env vars at directory entry; see ADR-0018 |

Individual projects document their specific outer dependencies in their
`getting-started.md` or equivalent onboarding guide.

---

## Portability Conventions (Inside the Project Root)

The following conventions apply to all scripts, configuration, and
documentation committed to any AgenticCore-governed project.

### Convention 1: Scripts derive the project root from their own location

All shell scripts determine `COLLECTION_ROOT` (or equivalent root variable)
at runtime using `$BASH_SOURCE[0]` / `$(dirname ...)` traversal. No absolute
paths to the project root are hardcoded.

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTION_ROOT="$(cd "$SCRIPT_DIR/<relative-path-to-root>" && pwd)"
```

Relative traversal depth depends on where the script lives within the project.
Reference implementation: `mddocs/scripts/` in this repository.

No script may contain `/Users/<username>/`, `/home/<username>/`, or any
absolute path that embeds a machine-specific or person-specific component.

---

### Convention 2: Machine-specific configuration uses template + envsubst

Configuration files that require absolute paths (e.g., MCP server config,
AI toolchain permissions) are committed as `.template` files using
`${VARIABLE}` placeholders. Machine-specific files are generated at setup
time by `opencode.json`:

```
.mcp.json.template                   ← committed (portable)
.agentic/settings.local.json.template ← committed (portable)
.mcp.json                            ← gitignored (machine-specific, generated)
.agentic/settings.local.json          ← gitignored (machine-specific, generated)
```

`envsubst` is used to expand `${HOME}` and `${COLLECTION_ROOT}` into the
generated files. Generated files are always gitignored; their templates are
always committed.

---

### Convention 3: Documentation uses relative paths or placeholder notation

Documentation that refers to paths within the project uses:
- Relative paths from the repo root (e.g., `mddocs/scripts/`, `.agentic/agents/`)
- The notation `<collection-root>/...` when an absolute reference is necessary
  for clarity

Hardcoded usernames, home directory paths, and machine-specific absolute paths
are not permitted in any committed documentation.

---

### Convention 4: External tool paths use `$HOME`-relative or `command -v` resolution

Scripts that reference tools outside the project root use:
- `$HOME/.local/...` or `$HOME/.cargo/bin/...` for user-local tool installs
- `command -v <tool>` for system package manager-installed tools (resolved via
  `$PATH`)
- Never `/Users/<username>/...` or `/home/<username>/...`

---

## Consequences

**Positive:**
- Any engineer clones the repository and runs `opencode.json` —
  no manual path substitution required
- Machine-specific configuration is never committed, eliminating the
  "works on my machine" failure class
- The outer dependency catalog in each project's onboarding guide is a single
  source of truth for setup prerequisites
- Scripts are portable across usernames, home directory layouts, and OS
  architectures

**Negative / Trade-offs:**
- `opencode.json` must be run after cloning; if skipped, generated
  files (`.mcp.json`, `settings.local.json`) are absent and MCP servers will
  not start
- `envsubst` (from `gettext`) must be present before `opencode.json`
  can run; it is a setup dependency
- Reviewing generated files for debugging requires re-running the generator
  rather than reading the committed version

---

## Related

- [ADR-0001: Bootstrap Architecture](adr-0001-bootstrap-architecture.md) — original scaffold decisions; portability was a design requirement from day one
- [ADR-0002: mcp-rag-docs](adr-0002-mcp-rag-docs.md) — MCP server config uses the template model defined here
- [ADR-0015: Framework Distribution and Adoption Model](adr-0015-framework-distribution-adoption-model.md) — export+init model depends on these conventions
- [ADR-0018: Credential Injection Pattern](adr-0018-credential-injection-pattern.md) — credential injection tooling is an outer dependency per this ADR
- `mddocs/scripts/setup/tool-adapter.sh` — generates the agent-runtime adapter (regenerates `.opencode/agents/`, writes a start script); machine-local overrides go in the gitignored `opencode.json.local`
