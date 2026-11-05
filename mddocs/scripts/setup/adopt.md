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
- **`--tool none|opencode|codex`** selects an agent-runtime adapter (default
  `none` = bring your own). Prompted interactively if omitted and stdin is a TTY.
  `opencode` generates local opencode config + `start-opencode.sh`; `codex` writes a
  `.codex/` reference + `start-codex.sh`. The harness core is tool-agnostic.

```bash
{{#include adopt.sh}}
```
