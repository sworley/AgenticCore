# Onboarding Scripts

Scripts for bootstrapping and verifying the AgenticCore development environment.

| Script | Reference | Purpose |
|--------|-----------|---------|
| [adopt.sh](adopt.md) | [Bootstrap New Project](../../reference.architecture/bootstrap-new-project.md) | Single-command adopter onboarding — wraps README Quick Start (Adopter) steps 3-7 (create target, run `export-framework.sh`, validate, generate the agent adapter) |
| `tool-adapter.sh` | [tooling-contract](../../reference.architecture/tooling-contract.md) | Generate/configure the agent-runtime adapter (opencode/codex) — regenerates `.opencode/agents/` and writes a start script |
| `model-distribution.sh` | [tooling-contract](../../reference.architecture/tooling-contract.md) | Tailor/review the per-agent LLM model distribution (write `model:` into `.opencode/agents/*.md`) |
| [phase2-dev-toolchain.sh](phase2-dev-toolchain.md) | — | Install the Phase 2 docs and developer toolchain (mdbook, typos, shellcheck, gh, jq) via cargo and brew |
| [verify-toolchain.sh](verify-toolchain.md) | — | End-state verification — checks all required tools and reports PASS/WARN/FAIL |

Run from any directory — all scripts derive the collection root from their own location:

```bash
# Configure the opencode adapter (regenerates .opencode/agents/ + start-opencode.sh)
bash mddocs/scripts/setup/tool-adapter.sh --tool opencode

# (optional) apply the per-agent model distribution from .agents/model-profile.yaml
bash mddocs/scripts/setup/model-distribution.sh --apply
```

opencode reads the committed `opencode.json` directly, so no machine-local
generation step is required. For machine-specific overrides, use the gitignored
`opencode.json.local`.

- [Getting Started](../../onboarding/getting-started.md) — full onboarding procedure for new users
