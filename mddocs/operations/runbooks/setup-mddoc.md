# Runbook: Set Up mddoc Local Documentation Site

## Overview

Installs and configures the tools needed to build and serve the `mddocs/` documentation
site locally using [mdbook](https://rust-lang.github.io/mdBook/) with Mermaid diagram
support. Run this once per machine; Mermaid assets are committed and need no per-clone
setup.

## Prerequisites

- Access: none — local machine setup only
- Tools: `cargo` (Rust package manager) — install from [rustup.rs](https://rustup.rs) if not present
- State: `mddocs/` directory cloned from the repository

## Steps

### 1. Install or update Rust

```bash
# First-time install
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Update an existing installation
rustup update stable
```

Verify:
```bash
rustc --version   # should be 1.88.0 or later
```

### 2. Install mdbook

```bash
cargo install mdbook
```

Verify:
```bash
mdbook --version
```

Mermaid diagrams are rendered **client-side** using the committed
`mermaid.min.js` + `mermaid-init.js` assets, wired through `additional-js` in
`mddocs/book.toml`. There is no `mdbook-mermaid` preprocessor and no per-checkout
setup step.

### 3. Serve the documentation site

```bash
cd mddocs
mdbook serve --open
```

Opens the site at `http://localhost:3000` with live hot-reload on file save.

To build a static snapshot without serving:

```bash
cd mddocs
mdbook build
# Output written to mddocs/book/ — do not commit this directory
```

## Validation

```bash
mdbook build 2>&1 | grep -E "INFO|ERROR"
```

Expected: two `INFO` lines, no `ERROR` lines:
```
INFO Book building has started
INFO HTML book written to .../mddocs/book
```

Clean up the build output after verifying:
```bash
rm -rf mddocs/book/
```

## Rollback

Tool installation is non-destructive. To remove:

```bash
cargo uninstall mdbook
```

## Mermaid Diagram Usage

Mermaid diagrams render in Git (natively) on GitHub/GitLab, and in the mdBook site
via the committed `mermaid.min.js` + `mermaid-init.js` assets (`additional-js` in
`book.toml`). Use a fenced code block tagged `mermaid`:

````markdown
```mermaid
graph TD
    A[Start] --> B{Decision}
    B -- Yes --> C[Action]
    B -- No  --> D[Alternate]
```
````

**When to use a diagram vs. prose:**

| Use a diagram | Stick with prose / table |
|---------------|--------------------------|
| Multi-step flows with branches or decisions | Linear numbered steps |
| Component relationships and data flows | Simple two-column mappings |
| State machines (host pool lifecycle, pipeline states) | Single-level attribute lists |
| Sequence of calls across systems | Parameter references |
| Architecture topology with network boundaries | One-to-one lookups |

**Common diagram types:**

| Type | Keyword | Best for |
|------|---------|----------|
| Flowchart | `graph TD` / `graph LR` | Deployment decisions, runbook flows |
| Sequence | `sequenceDiagram` | Auth flows, API call chains, CI/CD stages |
| State | `stateDiagram-v2` | Host pool lifecycle, image pipeline states |
| Pie | `pie` | Backlog distribution, coverage metrics |
| Gantt | `gantt` | Phased deployment timelines |

Keep each diagram to one concept. Use `graph TD` for hierarchies, `graph LR` for
pipeline stages. Node labels should match the exact resource or command name used
in the surrounding runbook steps.

## Updating Tools

```bash
rustup update stable
cargo install mdbook   # re-run to upgrade to the latest version
```

To refresh the Mermaid bundle, replace `mddocs/mermaid.min.js` with a newer release
from `https://cdn.jsdelivr.net/npm/mermaid@<version>/dist/mermaid.min.js`.

## Related

- [mddocs README](../../index.md)
- [Runbook Index](../index.md)
