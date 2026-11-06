# toolchain.sh

<a href="toolchain.sh" download>Download toolchain.sh</a> · bash · [Bootstrap New Project](../../reference.architecture/bootstrap-new-project.md)

Manages the harness's **non-Python** (docs/dev) dependencies — the toolchain analogue of
[python-env.sh](python-env.md). It **validates** what's present and can **install** what's
missing, without forcing installs on an adopter.

The framework's docs and agentic quality gates depend on these tools:
`mdbook` (docs build), `mdbook-mermaid` (diagram renderer), `typos-cli` (spellcheck, used
by `docs-reviewer`), `shellcheck`, `gh`, `jq`.

- **`--check` (default, read-only)** — validates every tool and reports PASS/FAIL/WARN
  with an install hint for anything missing. It never installs anything.
- **`--install` (opt-in)** — installs missing tools via `cargo`/`brew` (and `apt`).
- **`--dry-run`** — shows what `--install` would do without doing it.

```sh
# Validate the toolchain (read-only; the default)
./mddocs/scripts/setup/toolchain.sh --check

# Install what's missing (opt-in, best-effort)
./mddocs/scripts/setup/toolchain.sh --install

# Preview install without side effects
./mddocs/scripts/setup/toolchain.sh --dry-run --install
```

## Pinned versions
Tools are pinned in the script's manifest to match the framework's CI/validation:

| Tool | Tier | Installer | Pin |
|------|------|-----------|-----|
| `git`, `jq`, `python3`, `uv` | required | system | — |
| `mdbook` | required | `cargo` | `0.4.40` |
| `mdbook-mermaid` | optional | `cargo` | `0.17.0` |
| `typos-cli` | optional | `cargo` | `1.48.0` |
| `shellcheck`, `gh` | optional | `brew` | — |

> **Note on mdbook version:** `mdbook` is pinned to **`0.4.40`** to match
> `.github/workflows/ci.yml` and the README's "0.4.x" prerequisite. The legacy
> `phase2-dev-toolchain.sh` pins `0.5.3`, which is **out of sync** (mdbook 0.5.x
> breaks mdbook-linkcheck — see TC-017 and AGENT.md).

```bash
{{#include toolchain.sh}}
```
