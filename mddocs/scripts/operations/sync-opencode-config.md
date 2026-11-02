# sync-agent-config.sh

Sync AGENT.md files between the `_config/` repo archive and on-disk parent-directory
locations. See the
[Sync Agent Config runbook](../../operations/runbooks/sync-opencode-config.md) for
full usage.

```sh
bash mddocs/scripts/sync-agent-config.sh --deploy    # _config/ → on-disk
bash mddocs/scripts/sync-agent-config.sh --collect   # on-disk → _config/
bash mddocs/scripts/sync-agent-config.sh --check     # diff only; exits 1 if out of sync
```

Related: [Sync Agent Definitions](../../operations/runbooks/sync-agent-definitions.md)
(in `mddocs/operations/runbooks/`).
