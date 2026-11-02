# Operations Scripts

Automation scripts collocated with documentation for browsability alongside runbooks.
All scripts are POSIX-compliant shell (zsh where noted). Each has a companion runbook
in `mddocs/operations/runbooks/`.

| Script | Language | Runbook | Purpose |
|---|---|---|---|
| [git-sync.sh](git-sync.md) | zsh | [git-sync runbook](../../operations/runbooks/git-sync-runbook.md) | Clone/update all repos in a Git group |
| [check-env.sh](check-env.md) | sh | [sync-agent-definitions](../../operations/runbooks/sync-agent-definitions.md) | Validate developer environment |
| [bench-status.sh](bench-status.md) | sh | — | Show all worktree states |
| [provision-bench.sh](provision-bench.md) | sh | [provision-worker-bench](../../reference.architecture/provision-worker-bench.md) | Provision a worker bench |
| [check-worktree-hygiene.sh](check-worktree-hygiene.md) | sh | [session-continuity](../../operations/runbooks/session-continuity.md) | Verify all worktrees are clean |
| [sync-agent-config.sh](sync-opencode-config.md) | bash | [sync-opencode-config](../../operations/runbooks/sync-opencode-config.md) | Sync AGENT.md files between archive and on-disk locations |
| [read-audit-log.sh](read-audit-log.md) | bash | — | Pretty-print the session egress audit log |
| [check-links.sh](check-links.md) | sh | [check-links runbook](../../operations/runbooks/check-links-runbook.md) | Validate internal markdown links in mddocs/ |

All scripts are invoked from the repository root:

```sh
./mddocs/scripts/git-sync.sh --profile <name>
./mddocs/scripts/check-env.sh
./mddocs/scripts/bench-status.sh
./mddocs/scripts/provision-bench.sh --bench 02 --ticket AP-NNN --type feat --slug slug
./mddocs/scripts/check-worktree-hygiene.sh
./mddocs/scripts/check-links.sh
```

To add a new script: create it in `mddocs/scripts/`, set `chmod +x`, write a companion runbook in `mddocs/operations/runbooks/`, and add entries to this index and `mddocs/SUMMARY.md`.
