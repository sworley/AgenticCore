# init-opencode-settings

opencode reads the committed `opencode.json` directly — no machine-local
generation step is required. MCP servers are configured inline in `opencode.json`,
and `.opencode/agents/` is regenerated from the canonical `.agents/` source.

## Setup

Configure the opencode adapter (regenerates `.opencode/agents/`, writes
`start-opencode.sh`) — or use it at adoption time with `--tool opencode`:

```sh
bash mddocs/scripts/setup/tool-adapter.sh --tool opencode
```

## Machine-local overrides

For machine-specific settings (alternate MCP config, local runtime overrides,
host-specific values) use the gitignored `opencode.json.local`. opencode
deep-merges it over the committed `opencode.json`:

```jsonc
{
  // machine-local overrides merged over opencode.json
}
```

## Related

- [Getting Started](../../onboarding/getting-started.md)
- [Configuration Reference](../../configuration.md)
- [adopt.sh](adopt.md)
