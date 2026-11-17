---
id: SDX-002
document_type: index
status: active
lifecycle: active
domain: Management
---

# Hooks and Utilities

Standalone scripts used as hooks or session utilities.

| Script | Language | Purpose |
|--------|----------|---------|
| [statusline-command.sh](statusline-command.md) | zsh | Display bench name, branch, agent, and context % in the session status line |
| [update-summary-on-adr-write.py](update-summary-on-adr-write.md) | python3 | PostToolUse hook — auto-insert new ADR rows into the active ADR index (`mddocs/management/governance/decisions/index.md`) on Write |

**statusline-command.sh** — deploy to `~/.opencode/statusline-command.sh` (or configure
in `opencode.json`). Reads JSON from stdin and outputs a formatted status line showing
the bench name extracted from the working directory path, current branch, active agent,
and context window percentage.

**update-summary-on-adr-write.py** — configure as a `PostToolUse` hook in
`.opencode/settings.json` (or `.agentic/settings.local.json`) for the Write tool event.
Fires when an ADR file matching `mddocs/management/governance/decisions/adr-*.md` is
written (the forward-only active location, per ADR-0029 D1 / ADR-0030), reads the
title/status/date, and inserts a row into the active ADR index
`mddocs/management/governance/decisions/index.md`. Historical ADRs under `mddocs/adr/`
are not touched. Exits 0 silently if the file is not an active-location ADR or if the
row is already present.
