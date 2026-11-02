# Hooks and Utilities

Standalone scripts used as hooks or session utilities.

| Script | Language | Purpose |
|--------|----------|---------|
| [statusline-command.sh](statusline-command.md) | zsh | Display bench name, branch, agent, and context % in the session status line |
| [update-summary-on-adr-write.py](update-summary-on-adr-write.md) | python3 | PostToolUse hook — auto-insert new ADR entries into `mddocs/SUMMARY.md` on Write |

**statusline-command.sh** — deploy to `~/.opencode/statusline-command.sh` (or configure
in `opencode.json`). Reads JSON from stdin and outputs a formatted status line showing
the bench name extracted from the working directory path, current branch, active agent,
and context window percentage.

**update-summary-on-adr-write.py** — configure as a `PostToolUse` hook in
`.opencode/settings.json` (or `.agentic/settings.local.json`) for the Write tool event.
Fires when an ADR file matching `mddocs/adr/adr-*.md` is written, reads the H1 title,
and inserts an entry into `mddocs/SUMMARY.md` after the last existing ADR entry.
Exits 0 silently if the file is not an ADR or if the entry is already present.
