# adopt.sh

<a href="adopt.sh" download>Download adopt.sh</a> · bash · [Runbook](../../reference.architecture/bootstrap-new-project.md)

Single-command adopter onboarding — wraps README [Quick Start
(Adopter)](../../../README.md#quick-start-adopter) steps 3-7 (create target, run
`export-framework.sh`, validate, generate AI toolchain settings). Steps 2 (clone) and 8
(open an agentic session) remain manual.

Key behaviors:

- **`--target` is optional when stdin is a TTY.** If omitted, the script prompts
  interactively with a suggested path based on the TC-074 convention
  (`<workdir>/<toolset>/<host>/<group>/<project>`). Required in non-interactive mode.
- **Confirmation before `mkdir -p`.** Whether `--target` came from a flag or a prompt,
  the resolved path is echoed and requires explicit `y` confirmation before the
  directory is created. Any other input aborts with no side effects.
- **`-y` / `--yes`** skips the confirmation prompt for scripted or non-interactive use.
  `adopt.sh` automatically forwards `--yes` to `export-framework.sh` so the path is
  not confirmed a second time.
- **Relative `--target` paths work** (TC-084) — e.g. `--target ./my-project` is
  canonicalized to an absolute path immediately after `mkdir -p` (`./my-project.01`).
- **The `.01` management-layer suffix is always appended.** `--target` is your base
  project name; the harness appends `.01` (so `./my-project` -> `./my-project.01`, and
  `./myproject.v0.01` -> `./myproject.v0.01.01`).
- **`--dry-run`** skips the confirmation prompt entirely (zero side effects end to end).
- **Python environment is provisioned (Step 5).** After the export, `adopt.sh` runs
  `python-env.sh` in the target: it creates `<target>/.venv`, installs the pinned
  `requirements.txt`, and validates the harness's Python modules (`mcp`, `yaml`,
  `fastmcp`) import. It then builds `.envrc` from `.envrc.template` so the venv is
  **sourced automatically** on `cd` — but only after you run **`direnv allow`** once in
  the project (the first `cd` into a newly created `.envrc` always requires it). See
  [python-env.sh](python-env.md).
- **Toolchain is checked (Step 6).** `adopt.sh` runs `toolchain.sh --check` against the
  docs/dev toolchain (`mdbook`, `typos`, `shellcheck`, `gh`, `jq`). If everything is
  present at the pinned version it proceeds; if a required or optional tool is missing
  or out of date it offers to **install/update or skip** (interactive). Skipping does not
  fail adoption — it prints a note on what was skipped and its impact, then continues.
  Nothing is force-installed unless you choose to. See [toolchain.sh](toolchain.md).
- **`--tool none|opencode|codex`** selects an agent-runtime adapter (default
  `none` = bring your own). Prompted interactively if omitted and stdin is a TTY.
  `opencode` generates local opencode config + `start-opencode.sh`; `codex` writes a
  `.codex/` reference + `start-codex.sh`. The harness core is tool-agnostic.
- **`--regen`** force-regenerates the agent adapter and re-applies the model
  distribution, refreshing the framework's canonical agent source and setup scripts
  into the target while preserving its `.agents/model-profile.yaml`. On an existing
  framework export it skips the full re-export and updates agents/models in place —
  a fast way to bring a project up to date with newer agents or models. On a fresh
  target it runs after the normal export.

```bash
{{#include adopt.sh}}
```
