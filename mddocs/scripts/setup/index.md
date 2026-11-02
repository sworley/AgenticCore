# Onboarding Scripts

Scripts for bootstrapping and verifying the AgenticCore development environment.

| Script | Reference | Purpose |
|--------|-----------|---------|
| [adopt.sh](adopt.md) | [Bootstrap New Project](../../reference.architecture/bootstrap-new-project.md) | Single-command adopter onboarding — wraps README Quick Start (Adopter) steps 3-7 (create target, run `export-framework.sh`, validate, generate AI toolchain settings) |
| [opencode.json](init-opencode-settings.md) | [getting-started](../../onboarding/getting-started.md) | Generate `.mcp.json` and `.agentic/settings.local.json` from portable templates — run once after clone or when the repo moves |
| [phase2-dev-toolchain.sh](phase2-dev-toolchain.md) | — | Install the Phase 2 docs and developer toolchain (mdbook, typos, shellcheck, gh, jq) via cargo and brew |
| [verify-toolchain.sh](verify-toolchain.md) | — | End-state verification — checks all required tools and reports PASS/WARN/FAIL |

Run from any directory — all scripts derive the collection root from their own location:

```bash
# First-time setup: generate machine-specific AI toolchain settings
bash mddocs/scripts/setup/opencode.json
```

The script is idempotent and safe to re-run.

- [Getting Started](../../onboarding/getting-started.md) — full onboarding procedure for new users
