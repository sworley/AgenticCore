# Session Reasoning Log

Automatic capture of the natural-language reasoning layer — why decisions were made,
what alternatives were rejected, and what the user intended — into an append-only on-disk
log that survives context compaction and session boundaries.

---

## The Problem

AI toolchain's auto-compact and context-window compression preserve *outcome* (what
changed, captured in git commits and memory notes) but discard *reasoning* — the
conversational NLU layer. That layer is what allows a follow-on session to understand
rather than just re-execute. Without it, a new session must reconstruct intent from
artifacts alone, which leads to:

- Re-asking questions the prior session already answered
- Missing the "why not X" context behind decisions (alternatives that were rejected)
- Losing the user's framing of a problem even when the fix was committed correctly

---

## Solution

A single hook script (`session-logger.py`) wires into three AI toolchain hook events:

| Event | What is captured |
|-------|-----------------|
| `UserPromptSubmit` | Every user message — the intent and framing layer |
| `PostToolUse` | Significant agent actions (Agent, Workflow, Bash, Edit, Write) |
| `Stop` | Turn boundary marker |

Output is a plain-text append-only log at `_scratch/sessions/YYYY-MM-DD_<session-id[:8]>.log`.

---

## Log Format

```
=== SESSION: <session_id> | 2026-07-02 14:00:00Z ===

[14:00:01Z] USER: Can we build a session logging system...

[14:00:05Z] BASH: ls AgenticCore.v1/.agentic/hooks/

[14:00:12Z] WRITE: AgenticCore.v1/.agentic/hooks/session-logger.py

[14:00:14Z] AGENT(docs-engineer) [bg]: Write runbook for session-reasoning-log
  prompt: Write a runbook documenting...

[14:00:18Z] WORKFLOW: image-validate
  note: agents spawned inside this workflow are not individually logged

[14:01:02Z] STOP — turn end
```

---

## Agent vs Workflow — The Key Distinction

**`Agent` tool calls** (top-level, from the main session) are logged individually:
```
AGENT(security-reviewer) [bg]: Review hook changes
  prompt: Review the following changes for security issues...
```

**`Workflow` tool calls** are logged as a single entry:
```
WORKFLOW: my-workflow-name
  note: agents spawned inside this workflow are not individually logged
```

This is an important limitation: a workflow that spawns 50 subagents will appear as
one log line. The workflow's subagents run inside the workflow runtime and never pass
through the main session's hook layer. The log records *that* a workflow ran and *which
one*, but not the internal agent calls.

If the reasoning behind individual workflow subagent calls matters, either:
1. Use top-level `Agent` tool calls for work that needs to be traced
2. Read the workflow journal at `.agentic/sessions/<run-id>/journal.jsonl` (contains
   every subagent's return value but not their intermediate reasoning)

---

## What Is NOT Logged

By design, the hook filters out tool calls that are infrastructure noise rather than
reasoning signal:

- `Read`, `LSP`, `mcp__filesystem__*`, `mcp__git__*` — lookups and queries
- `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode`, `TaskCreate`, `TaskUpdate` — scaffolding
- `WebFetch`, `WebSearch` — research operations (these are logged separately by `egress-audit-log.py`)

This keeps the log readable and focused on decisions, not on every file the session
opened.

---

## Secret Redaction

The hook applies redaction patterns that mirror `secret-scan-output.py` with additions
for CLI flag forms:

- `--password <value>` → `--password [REDACTED]`
- `--client-secret <value>` → `--client-secret [REDACTED]`
- `--tenant <uuid>` → `--tenant [REDACTED]`
- `--client-id <uuid>` → `--client-id [REDACTED]`
- `SP_CLIENT_SECRET=<value>` → `SP_CLIENT_SECRET=[REDACTED]`
- `GIT_TOKEN=<value>` → `GIT_TOKEN=[REDACTED]`
- `glpat-<token>` → `glpat-[REDACTED]`
- Subscription UUIDs in resource paths → `[SUB-REDACTED]`
- Object/group ID UUIDs → `[UUID-REDACTED]`

Embedded newlines are stripped from all logged strings to prevent log-injection attacks.
Paths under the repo parent directory are shortened to `<bench-name>/rest/of/path`.

---

## Log Location and Lifecycle

```
AgenticCore.v1/
  _scratch/
    sessions/
      2026-07-02_426a694b.log   ← one file per day per session ID
      2026-07-03_7f3b2c91.log
```

- **One file per (date, session_id[:8]) pair.** A session that runs across midnight
  creates two files.
- **Gitignored.** `_scratch/sessions/` is excluded from git. Logs are never committed.
- **Never truncated.** The hook only appends. Old log files accumulate until manually
  pruned.
- **No rotation.** If you want to archive or prune old logs, do it manually.
  Typically keep the last 30 days; anything older can be deleted without consequence.

---

## How to Use a Session Log

At the start of a new session after a context compaction, read the most recent log file
before doing any work:

```bash
# Find the most recent log
ls -lt _scratch/sessions/ | head -5

# Read it
cat _scratch/sessions/2026-07-02_426a694b.log
```

The log gives you the intent, decision points, and turn boundaries without requiring
you to re-read the full conversation history. Use it to:

- Understand what the user was trying to accomplish
- Identify where the prior session stopped and why
- Avoid re-proposing alternatives that were already rejected

---

## Hook Registration

The hook is registered in `.agentic/settings.local.json` (gitignored — machine-local).
The template at `.agentic/settings.local.json.template` includes the blocks so they
survive a settings rebuild:

```json
"UserPromptSubmit": [
  { "hooks": [{ "type": "command", "command": "python3 \"${REPO_ROOT}/.agentic/hooks/session-logger.py\"" }] }
],
"PostToolUse": [
  {
    "matcher": "Agent|Workflow|Bash|Edit|Write|NotebookEdit",
    "hooks": [{ "type": "command", "command": "python3 \"${REPO_ROOT}/.agentic/hooks/session-logger.py\"" }]
  }
],
"Stop": [
  { "hooks": [{ "type": "command", "command": "python3 \"${REPO_ROOT}/.agentic/hooks/session-logger.py\"" }] }
]
```

> **Note:** The hook takes effect after a session restart. The current session will not
> log until you restart AI toolchain.

---

## Relationship to Other Session Tools

| Tool | Captures | Survives compact? |
|------|---------|-------------------|
| Memory notes | Facts, decisions, current state | Yes (written explicitly) |
| Git commits | What changed, outcome | Yes |
| `session-close-reminder.py` | Dirty worktree warning at Stop | Yes (fires next turn) |
| **Session reasoning log** | Intent, reasoning, turn flow | **Yes (on disk, automatic)** |

The session reasoning log complements but does not replace the end-of-focus memory write.
Memory notes are written deliberately and cover what to do next; the log is automatic and
covers how you got there.

---

## Source

Hook script: `.agentic/hooks/session-logger.py`

Related:
- [Runbook: Session Continuity](session-continuity.md)
- [Runbook: Session Open Checklist](../../reference.architecture/session-open-checklist.md)
- [Runbook: Session Close Checklist](../../reference.architecture/session-close-checklist.md)
