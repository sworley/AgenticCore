# python-env.sh

<a href="python-env.sh" download>Download python-env.sh</a> · bash · [Bootstrap New Project](../../reference.architecture/bootstrap-new-project.md)

Creates the project-local Python virtualenv (`.venv`) and installs/validates the
harness's required Python packages. The harness is Python-only for its MCP servers
(review-ledger, rag-docs); this script gives every adopted workspace an isolated,
reproducible environment so those servers and their dependencies work without
polluting the machine-wide Python.

What it does:

- **`--create`** — creates `<repo-root>/.venv` with `python3 -m venv` (skipped if it
  already exists).
- **`--install`** — `pip install -r requirements.txt` into `.venv`.
- **`--check`** — verifies the required modules import (`mcp`, `yaml`, `fastmcp`);
  exits non-zero if any are missing.
- **`--freeze`** — regenerates `requirements.txt` via `pip freeze` (harness
  maintenance; run in a clean venv and commit the result).

With no flags it runs `--create`, `--install`, `--check` — the adoption default. It is
idempotent and safe to re-run.

```sh
# Adoption default: create .venv, install requirements.txt, validate imports
./mddocs/scripts/setup/python-env.sh

# Re-provision after a requirements.txt change, or on a fresh clone
./mddocs/scripts/setup/python-env.sh --install --check

# Regenerate the pinned snapshot (harness maintenance; run in a clean venv)
./mddocs/scripts/setup/python-env.sh --freeze

# Preview without side effects
./mddocs/scripts/setup/python-env.sh --dry-run
```

`requirements.txt` is committed and ships with the export; `.venv/` is gitignored. The
project's `.envrc` sources `.venv/bin/activate` so the environment is active as soon as
you `cd` into the project (run `direnv allow` once).

```bash
{{#include python-env.sh}}
```
