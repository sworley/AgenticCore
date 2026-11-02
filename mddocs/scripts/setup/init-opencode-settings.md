# init-opencode-settings (opencode.json)

Generates the machine-local AI toolchain settings from portable templates:
`.mcp.json` and `.agentic/settings.local.json`. Run once after cloning the project
or when the repository moves.

```sh
bash mddocs/scripts/setup/opencode.json
```

The script is idempotent and safe to re-run. The committed `opencode.json` is used
directly by OpenCode; no generation step is required for OpenCode itself.

## What It Produces

- `.mcp.json` — MCP server wiring (tool-local overrides)
- `.agentic/settings.local.json` — machine-specific agent runtime settings

These files are gitignored (machine-local) and derive from the portable templates in
the repo.

## Related

- [Getting Started](../../onboarding/getting-started.md)
- [Configuration Reference](../../configuration.md)
- [adopt.sh](adopt.md)
