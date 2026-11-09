# AgenticCore

Portable agentic framework — documentation-first, mdBook-based, git-worktree bench model
for developers, DevOps engineers, and SREs building AI-assisted workflows.

---

## Start Here

- **Adopting this framework into your own project?** → [Quick Start (Adopter)](#quick-start-adopter)
- **Working on the framework itself?** → [Contributing / Extending](#contributing--extending-maintainer)

Want a visual map of the whole system first? Start with the
[`mddocs/onboarding/visual-overview.md`](mddocs/onboarding/visual-overview.md)
— benches, personas, workflows, and the agent roster at a glance. The full guide
lives in the docs: [`mddocs/onboarding/getting-started.md`](mddocs/onboarding/getting-started.md).

---

## What This Is

AgenticCore provides a structured, repeatable scaffold for operating AI coding agents
in a team or solo engineering context. It defines:

- **Roles and governance** — human-in-the-loop (HIL) acceptance gates, agent boundaries, no self-approval
- **Bench model** — git-worktree-based isolated workspaces (`.00` HIL, `.01` lead-engineer, `.02`+ workers)
- **Agent definitions** — portable agent specs for OpenCode and compatible runtimes (auto-synced from `.agents/`)
- **Documentation system** — mdBook-based docs with ADRs, runbooks, onboarding, and examples
- **Security controls** — hooks, commit/push gates, credential injection via `pass` + `direnv`
- **Task queue** — `tasks.yaml` as the single source of truth for all work items

---

## Releases

The current baseline is **v0.7.0** (2026-11-09). The initial open-source baseline was
**v0.5.0** (2026-11-01). Releases follow a curated, gated process owned by
`baseline-steward` with tactical execution by `release-engineer` — see the
[Release Process runbook](mddocs/reference.architecture/release-process.md) and
[`CHANGELOG.md`](CHANGELOG.md). Release notes are published under
[`mddocs/release-notes/`](mddocs/release-notes/UNRELEASED.md).

---

## Quick Start (Adopter)

Your adopted project is **not** a clone of this framework — adoption exports a
versioned, severed release into your own target directory, with no framework remote,
upstream reference, or commit history afterward (ADR-0015). You do need a local copy
of the framework to *run* the export from, so obtain it first (below).

### Prerequisites

| Tool | Purpose | Min version |
|---|---|---|
| `git` | Version control + worktrees | 2.35+ |
| `bash` | Runs `export-framework.sh` | 4.x+ |
| `mdbook` | Build documentation | 0.5.x |
| `direnv` | Credential injection via `.envrc` | 2.x |
| `pass` | Secrets store (GPG-backed) | 1.7+ |
| OpenCode or compatible runtime | AI coding agent runtime | latest |

> **Toolchain helper:** validate (or install) the docs/dev toolchain — `mdbook`,
> `mdbook-mermaid`, `typos-cli`, `shellcheck`, `gh`, `jq` — with
> `./mddocs/scripts/setup/toolchain.sh --check` (read-only) or `--install` (opt-in).
> The Python deps (`mcp`, `pyyaml`, `fastmcp`) are provisioned into a project-local
> `.venv` at adoption time.

### 1. Create or change to a working directory

```sh
mkdir -p ~/dev && cd ~/dev
```

> **Path layout (optional):** this Quick Start uses a simple flat path. For a
> multi-project setup that mirrors your git host/group structure (recommended once
> you wire in credentials and secrets), see the target-path guidance in
> [Bootstrap New Project](mddocs/reference.architecture/bootstrap-new-project.md).

### 2. Clone the latest released version of the framework

Run all Quick Start commands from your working directory (`~/dev`); do **not** `cd`
into the clone. The clone lands at `./AgenticCore`:

```sh
git clone --branch main https://git.example.com/example-group/AgenticCore.git
```

> **What you'll see (and why it's fine):** cloning the release tag can print a few
> alarming-looking lines — all expected:
>
> - `warning: refs/tags/<tag> <sha> is not a commit!` — the release tag is an
>   *annotated* tag (it points at a tag object, not a commit directly); the warning is
>   cosmetic and the clone still succeeds.
> - `You are in 'detached HEAD' state.` — expected whenever you check out a tag rather
>   than a branch; it is not an error.
> - A `Username for ...` / `Password for ...` prompt — expected for an authenticated
>   host. See [Bootstrap New Project](mddocs/reference.architecture/bootstrap-new-project.md)
>   if you haven't wired up credentials yet.

See `CHANGELOG.md` for the current baseline version.

### 3-7. Onboard with one command (recommended)

Still in your working directory, `adopt.sh` wraps steps 3-7 (create target, run
export, validate, generate AI toolchain settings) into a single call:

```sh
bash ./AgenticCore/mddocs/scripts/setup/adopt.sh --target ./my-project --slug MYPROJECT
```

The script echoes the resolved target path and asks you to confirm before creating
anything:

```
Target directory:   ~/dev/my-project.01

This directory will be created (mkdir -p) and populated with the
framework export. Confirm? [y/N]
```

Type `y` and press Enter to proceed. If the path is wrong, press Enter (or type
anything other than `y`/`yes`) to abort — then re-run with the correct `--target`.

> **The `.01` management-layer suffix is always appended.** `--target` is your *base*
> project name; the harness appends `.01` to create the lead-engineer management layer.
> So `--target ./my-project` becomes `./my-project.01`, and `--target ./myproject.v0.01`
> becomes `./myproject.v0.01.01` (a base that already ends in `.01` still gets the
> management-layer `.01` on top). `.00` (HIL) and `.02`+ (worker) benches are then
> provisioned as siblings in the same parent: `./myproject.v0.01.00`, `./myproject.v0.01.02`,
> ... The base name is your own choice; only the `.01` layer suffix is enforced at adoption.

> **A project-local Python environment is provisioned for you.** As part of
> onboarding, `adopt.sh` creates `<project>/.venv` and installs the harness's
> pinned Python deps from `requirements.txt` (MCP servers, review-ledger,
> rag-docs), then validates the modules import. It also builds `.envrc` from
> `.envrc.template` so the venv is **sourced automatically when you `cd`** into
> the project (run `direnv allow` once). To re-provision: `./mddocs/scripts/setup/python-env.sh`.

> **The harness doesn't prescribe an agent runtime.** The core is tool-agnostic
> (roles, process, benches, MCP servers). `--tool` selects an optional adapter —
> default `none` = bring your own:
>
> ```sh
> bash ./AgenticCore/mddocs/scripts/setup/adopt.sh --target ./my-project --slug MYPROJECT --tool opencode
> ```
>
> `--tool opencode` generates local opencode config + a `start-opencode.sh`;
> `--tool codex` writes a `.codex/` reference + a `start-codex.sh`. Each start
> script `cd`s into the project root so opencode/codex uses the local config
> (your global config still applies). See
> [Tooling Contract](mddocs/reference.architecture/tooling-contract.md).

> **Scripted / non-interactive use:** pass `-y` / `--yes` to skip the confirmation
> prompt. Use this in CI pipelines or wrapper scripts where the path is already
> validated by the caller:
>
> ```sh
> bash ./AgenticCore/mddocs/scripts/setup/adopt.sh \
>   --target ./my-project --slug MYPROJECT --yes
> ```
>
> In non-interactive mode (stdin not a TTY) without `--yes`, the script fails
> immediately if `--target` is omitted — there is no hidden prompt.

Preview first with `--dry-run` (zero side effects — reports what would happen, creates
nothing; skips the confirmation prompt automatically):

```sh
bash ./AgenticCore/mddocs/scripts/setup/adopt.sh --target ./my-project --slug MYPROJECT --dry-run
```

`adopt.sh` orchestrates existing tooling only — it calls `export-framework.sh` for the
export itself and surfaces its exit code faithfully; a failed export aborts immediately
with no further steps run. Full reference:
[adopt.sh](mddocs/scripts/setup/adopt.md).

<details>
<summary>What it does / manual path (steps 3-7 explicit)</summary>

#### 3. Create your base target directory

Name the target with your *base* project name. The export appends the `.01` management
plane suffix automatically (given `./my-project`, it creates `./my-project.01`):

```sh
mkdir -p ./my-project
```

> **Why `.01`?** The `.01` suffix marks this as your lead-engineer management plane —
> the long-living workspace that owns your task queue and provisions other benches.
> Your agent runtime (OpenCode/AI toolchain) recognizes the `.01` namespace and operates
> as `lead-engineer` within it (`.00` = HIL, `.02`+ = workers). Tooling such as
> `git-sync.sh` also derives your project/group name by stripping this suffix. See the
> [Bench Model](mddocs/onboarding/bench-model.md) for the full namespace hierarchy.
>
> The **slug** (below) is your project identity and does **not** carry the suffix —
> only the directory does. The `.01` layer suffix is appended automatically at adoption
> (even a base that already ends in `.01`, e.g. `myproject.v0.01`, becomes the management
> layer `myproject.v0.01.01`).

#### 4. Run the export into your target

Still in your working directory, run the export by relative path — `export-framework.sh`
auto-detects Flow A (empty-dir init) or Flow B (re-home into an existing repo):

```sh
./AgenticCore/mddocs/scripts/export-framework.sh --target ./my-project --slug MYPROJECT
```

The script echoes the resolved target path and requires `y` confirmation before
creating anything (same prompt as `adopt.sh`). Pass `--yes` to skip the confirmation
for scripted use.

#### 5. Change into your new project

```sh
cd ./my-project.01
```

#### 6. Validate

```sh
./mddocs/scripts/check-env.sh
mdbook build mddocs/
```

#### 7. Generate agent runtime settings

Configure the opencode adapter (regenerates `.opencode/agents/` and writes
`start-opencode.sh`). opencode reads the committed `opencode.json` directly, so
no machine-local generation step is required; use the gitignored
`opencode.json.local` for machine-specific overrides.

```sh
bash mddocs/scripts/setup/tool-adapter.sh --tool opencode
```

</details>

### 8. Open an agentic session

```sh
opencode   # or: opencode
```

Say: **"Lead-engineer, session open"** — as an adopter you operate as
`lead-engineer` for your own project, distinct from framework development
(`baseline-steward`).

The full procedure — prerequisites, both flows, validation steps, and a manual
fallback — lives in
[Bootstrap New Project](mddocs/reference.architecture/bootstrap-new-project.md).

### Full onboarding guide

Start at `mddocs/onboarding/getting-started.md` — it identifies you as an adopter
vs. contributor and routes accordingly.

---

## Contributing / Extending (Maintainer)

Contributing to the framework itself starts with cloning this repository — see
[Getting Started § Contributing to the Framework](mddocs/onboarding/getting-started.md#contributing-to-the-framework)
for the full clone-and-setup procedure. The rest of this section covers layout and
workflow once your environment is set up.

### Repository layout

```
.agents/          Canonical agent definitions (source of truth)
.agentic/          AI toolchain config — agents auto-synced from .agents/
.opencode/        OpenCode config — agents auto-synced from .agents/
.core/work/            Session state and relay notes
mddocs/           mdBook source — all documentation lives here
  adr/            Architecture Decision Records
  onboarding/     Getting started guides
  reference.architecture/  Runbooks and process docs
  examples/       Worked examples
  release-notes/  Per-release frozen release notes
  scripts/        Operational scripts
tasks.yaml        Task queue — .01 is sole writer
PROCESS.md        Governance, roles, lifecycle, and hard rules
AGENT.md         Lead-engineer persona and session procedures
bench-registry.yaml  Registered worktree benches
```

### Workflow overview

1. Add a task to `tasks.yaml` (`backlog` → `ready`)
2. Provision a worker bench: `mddocs/reference.architecture/provision-worker-bench.md`
3. Assign the task to the bench (`claimed` → `in_progress`)
4. Work on the bench; commit artifacts to the feature branch
5. Set status to `branch_ready`; request HIL review
6. HIL LGTM → merge to `dev` (no-ff); task moves to `merged`
7. Tear down bench (requires HIL authorization)

Releases are curated separately from `dev` onto `main` — see
`mddocs/reference.architecture/release-process.md`.

Full procedure: `mddocs/reference.architecture/`

### Agent sync

Agent definitions live in `.agents/`. To propagate changes to both OpenCode and compatible runtimes:

```sh
bash .agents/sync-agents.sh
```

### Adding an ADR

Copy `mddocs/adr/adr-template.md` → `mddocs/adr/adr-NNNN-title.md`.
Update `mddocs/adr/index.md` and `mddocs/SUMMARY.md`.

### Security-relevant changes

Any change to agent definitions, hooks, plugins, CI pipeline, or credential plumbing
requires a two-pass review (implementing agent self-review + adversarial security-reviewer pass)
before HIL acceptance. See `PROCESS.md §6`.

---

## Documentation

Full documentation is available via mdBook:

```sh
mdbook serve mddocs/
```

Key sections:

- `mddocs/onboarding/` — visual overview, agent roster, getting started, repo structure, bench model
- `mddocs/reference.architecture/` — all runbooks and process docs
- `mddocs/faq/` — distilled Q&A from working sessions, each linked to its canonical source
- `mddocs/adr/` — architecture decisions (ADR-0001 through ADR-0027)
- `mddocs/examples/` — worked examples: ticket lifecycle, bench session, ADR process, release

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow and the
governance rules that apply to all changes. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
for community expectations.

## License

Released under the [MIT License](LICENSE).
