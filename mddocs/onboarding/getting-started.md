# Getting Started

This guide starts with one question, because the two answers lead to completely
different setup procedures: **are you adopting the framework into your own project,
or contributing to the framework itself?**

> **New to AgenticCore?** Get oriented in one place first — the
> [Visual Overview](visual-overview.md) shows the bench hierarchy, personas,
> workflows, and agent roster at a glance. Then come back to the routing question
> below.

## Which Are You?

Answer this before running any command below — the two paths diverge immediately,
and the first contributor setup step is `git clone` of the framework repository,
which is **not** what an adopter should do.

- **Adopting** — you want to bring AgenticCore into your own (or a customer's)
  project. You will never hold a role in the framework's own git history, and you
  never clone the framework repository directly for this purpose. Go to
  [Adopting the Framework](#adopting-the-framework) below.
- **Contributing** — you want to work on the AgenticCore framework itself: fix a
  bug, add a feature, write documentation, or otherwise change framework source and
  submit it back through the framework's own `dev` branch. Go to
  [Contributing to the Framework](#contributing-to-the-framework) below.

If you are not sure which applies: if your work will ever be merged back into the
AgenticCore framework's own repository, you are contributing. If you are
consuming a release to build something else, you are adopting.

---

## Adopting the Framework

**Do not `git clone` the framework repository for this.** Adoption uses a dedicated
script, `export-framework.sh`, that exports a versioned release into your target
directory and **severs** any connection back to the framework's git history —
your resulting project has no framework remote, no upstream reference, and no
framework commit history reachable from it. See
[ADR-0015](../adr/adr-0015-framework-distribution-adoption-model.md) D-1/D-3 for the
full model.

The full procedure — including prerequisites, the exact commands, validation steps,
and a manual fallback — lives in
[Bootstrap New Project](../reference.architecture/bootstrap-new-project.md). This
section only helps you self-identify which of the two adoption flows applies to you
before you go there.

### Which adoption flow do I need?

The flow is determined entirely by **the state of your target directory** — not by
whether you have used AgenticCore before.

| Flow | Target directory state | Typical case |
|---|---|---|
| **A — empty-dir init** ("greenfield") | Empty, or does not exist yet | Starting a brand-new project with no existing code |
| **B — re-home** ("brownfield") | An existing git repository that already contains customer code | Adding the framework to a codebase that already exists — **including the first time you adopt the framework into it** |

The names "greenfield" and "brownfield" refer only to whether **customer code
already exists in the target directory** — they do **not** refer to whether the
framework was previously deployed there. A first-time adoption into an existing
customer repository is Flow B (re-home), even though the framework itself has never
touched that directory before.

Once you know your flow, go to
[Bootstrap New Project](../reference.architecture/bootstrap-new-project.md) for the
full procedure and run `mddocs/scripts/export-framework.sh` as documented there.

> This page does not cover which branch you should work on inside your adopted
> project after export — that is determined by your own project's branch strategy,
> not by this guide.

---

## Contributing to the Framework

The rest of this page walks you through setting up your local environment and
making your first contribution to the AgenticCore framework itself.

### Write Access — What You Can and Cannot Push

If you are new to the framework, read this before you clone anything.

- **You clone the framework repository read-only by default.** Write access to
  `main` is gated server-side to the Maintainer role — a newcomer's clone cannot push
  or merge to `main` regardless of local Git configuration.
- **How you contribute:** at the Developer role (or below), you work through the
  normal [PROCESS.md](../../PROCESS.md) task/branch/review flow — branch from `dev`,
  open a merge request, pass the review gates, and land on `dev`. You never target
  `main` directly; `dev` → `main` happens only at a release cutover with explicit HIL
  acceptance.
- **Full model:** see
  [ADR-0025](../adr/adr-0025-framework-write-protection-model.md) for the complete
  layered write-protection decision — adoption posture, server-side branch
  protection, and role-management guardrails.

### Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| `git` | Version control | System package |
| `direnv` | Credential injection | `brew install direnv` |
| `mdbook` | Documentation build | `cargo install mdbook` |
| `pass` | Credential store (optional) | `brew install pass` |
| `jq` | JSON processing | `brew install jq` |
| `uv` | Python runner for MCP server | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| An AI coding tool | OpenCode or AI toolchain | See tool documentation |

> **Note on `direnv` and `pass`:** These tools are only needed if your credential
> store uses them. For local-only use without Git integration, you can skip both
> and leave `GIT_TOKEN` unset. The framework will function without Git
> credentials; only `git-sync.sh` and the `rotate-git-pat` runbook require them.

### Setup

#### 1. Clone the repository

```sh
git clone https://git.example.com/your-group/AgenticCore.git
cd AgenticCore
```

#### 2. Configure credentials

```sh
cp .envrc.template .envrc
```

Edit `.envrc` and wire your credential store (e.g., `pass`). Then:

```sh
direnv allow
```

Verify:
```sh
echo $GIT_HOST      # should print your Git host
echo $GIT_TOKEN    # should print your PAT (redact this after checking)
```

#### 3. Generate AI toolchain settings

```sh
bash mddocs/scripts/setup/opencode.json
```

This script generates `.mcp.json` and `.agentic/settings.local.json` from the
committed templates, resolving all paths for your current machine. It is
idempotent — safe to re-run if you move the repository to a different directory.

> **Important:** MCP servers and hooks will not work without this step. Re-run
> it any time the repository moves.

#### 4. Verify MCP configuration

Confirm `.mcp.json` was generated and is valid:

```sh
jq . .mcp.json
```

Expected: a JSON object with an `mcpServers` key. If `jq` reports a parse error,
re-run Step 3.

Run the MCP smoke tests to confirm `mcp-rag-docs` is live:

```sh
bash mddocs/scripts/mcp-tests/run-all.sh
```

Expected output: `MCP tests: 1/1 passed`. If the test fails, check that `uv` is
installed and that the binary paths in `.mcp.json` resolve correctly.

#### 5. Verify environment

```sh
./mddocs/scripts/check-env.sh
```

Expected output: `All checks passed`. If any check fails, resolve it before
continuing.

#### 6. Build the docs

```sh
mdbook build mddocs/
mdbook serve mddocs/
# Open http://localhost:3000
```

#### 7. Open an agentic session

If using OpenCode:
```sh
opencode
# Say: "Lead-engineer, session open"
```

If using AI toolchain:
```sh
opencode
# Say: "Lead-engineer, session open"
```

### What Happens at Session Open

The lead-engineer agent will:
1. Run `git status` to confirm `.01` is clean
2. Run `git worktree list` to surface open benches
3. Scan `tasks.yaml` for in-progress or blocked items
4. Surface the top item with its next step

## Next Steps

- [Visual Overview](visual-overview.md) — the system at a glance
- [Repository Structure](repository-structure.md) — understand the layout
- [Agentic Workflow Overview](agentic-workflow-overview.md) — understand how work flows
- [Bench Model](bench-model.md) — understand the namespace hierarchy
