# Runbook: Agent Session Tracking

**Category:** Platform & Developer Tooling
**Last Updated:** 2026-04-23
**Owner:** Platform Engineering

## Overview

AI toolchain sub-agents are stateless — each spawned agent starts with no memory of prior
work. Session tracking bridges that gap by combining four layers of persistence:

| Layer | Mechanism | Survives Session? | Location |
|-------|-----------|-------------------|----------|
| Long-term project/user context | File-based memory | Yes | `~/.agentic/projects/<hashed-project-path>/memory/` |
| In-session task coordination | TaskCreate/TaskList tools | No | In-memory only |
| Cross-session task continuity | Session state file | Yes | `.agentic/session-state.md` |
| Agent invocation audit | Append-only log | Yes | `.agentic/agent-audit.log` |

This runbook documents the manual procedures for each layer — how to read, write, and
recover from each when automation is unavailable.

---

## Prerequisites

- Access to the collection root
- Read/write access to `.agentic/` within the collection root
- No special tools required — all manual steps use standard text editing and `date` / `echo`

---

## Layer 1 — Long-Term Memory (`~/.agentic/projects/<hashed-project-path>/memory/`)

### What it is

Persistent markdown files written and read by the main AI toolchain session (not sub-agents).
Survives across sessions. Contains user profile, feedback rules, and project state that
should inform all future conversations.

### File locations

```
~/.agentic/projects/<hashed-project-path>/memory/
  MEMORY.md                    ← index loaded into every session context
  user_profile.md              ← user role, preferences, expertise
  feedback_*.md                ← behavioral guidance (what to do / avoid)
  project_*.md                 ← active epics, initiatives, project state
```

The path hash is derived from the git root: `echo "<abs-path>" | sed 's/[^a-zA-Z0-9]/-/g'`

### Manual read procedure

```bash
cat ~/.agentic/projects/<hashed-project-path>/memory/MEMORY.md
```

Each entry in `MEMORY.md` is a pointer to a specific file. Read the relevant files for
the context you need.

### Manual write procedure

1. Create a new file: `~/.agentic/projects/<hashed-project-path>/memory/<type>_<topic>.md`
2. Use the frontmatter format:
   ```markdown
   ---
   name: <short name>
   description: <one-line description>
   type: user | feedback | project | reference
   ---

   <content>
   **Why:** <reason>
   **How to apply:** <when this guidance kicks in>
   ```
3. Add a pointer line to `MEMORY.md`:
   ```markdown
   - `[Title](filename.md)` — one-line hook (under 150 chars)
   ```

### When to write manually

- A project decision was made that AI toolchain should know about in future sessions
- A behavioral preference needs to be recorded (e.g., "always run what-if before deploy")
- A new epic or initiative starts

---

## Layer 2 — In-Session Task Coordination (TaskCreate/TaskList)

### What it is

Task objects created in-memory during a AI toolchain session using the TaskCreate,
TaskUpdate, and TaskList tools. Used by `lead-engineer` to track work within a session.
**Lost when the session ends.**

### Manual equivalent

Maintain a scratch list in any text editor during the session. The format that maps to
TaskCreate/TaskUpdate is:

```
[ ] Task subject — description (owner: <agent>)
[>] Task subject — currently in progress
[x] Task subject — completed
[!] Task subject — blocked by: <reason>
```

### Recovering task state after session loss

Read `.agentic/session-state.md` (Layer 3). If that file is current, it lists all
outstanding tasks at the time the last session ended. Recreate them manually or ask
`lead-engineer` to recreate them from the file at the start of a new session.

---

## Layer 3 — Cross-Session Task Continuity (`.agentic/session-state.md`)

### What it is

A markdown file written by `lead-engineer` before a session ends when there are
outstanding tasks. Read at the start of the next session to restore context.

### File location

```
.agentic/session-state.md
```

### File format

```markdown
# Session State
Last updated: 2026-04-23T14:30:00Z

## Outstanding Tasks
- [ ] Provision worker bench — next step: run provision-bench.sh (owner: ops-engineer)
- [ ] Update runbook — in progress (owner: docs-engineer)

## Completed This Session
- [x] Write ADR draft
- [x] Commit session-state.md template

## Last Active Work
Was mid-way through reviewing the backlog items for the next sprint.
```

### Manual read procedure (start of session)

```bash
cat .agentic/session-state.md
```

Recreate outstanding tasks using TaskCreate or note them in your scratch list before
beginning work.

### Manual write procedure (end of session)

Run `TaskList` in AI toolchain to get current task state, then write the output to
`.agentic/session-state.md`. If AI toolchain is unavailable, write manually:

```bash
# Get current timestamp
date -u +%Y-%m-%dT%H:%M:%SZ

# Then edit .agentic/session-state.md with your editor
# List all outstanding tasks from your scratch list
# List all tasks completed this session
# Add one sentence on what was in progress
```

### Validation

```bash
# Confirm file exists and has a recent timestamp
head -3 .agentic/session-state.md
```

Expected: `Last updated:` line within the last working session.

---

## Layer 4 — Agent Invocation Audit (`.agentic/agent-audit.log`)

### What it is

An append-only log of every specialist agent invocation made by `lead-engineer`.
Provides a chronological record of what was delegated, to whom, and the outcome.

### File location

```
.agentic/agent-audit.log
```

### Log format

```
ISO timestamp | agent name | task subject | status | task ID
```

Example entries:
```
2026-04-23T14:05:22Z | docs-engineer | draft runbook for hook rollback | completed | Task #4
2026-04-23T14:12:44Z | security-engineer | review hook rule changes | completed | Task #5
2026-04-23T14:31:00Z | release-engineer | cut v0.0.2 release | failed | Task #6
```

### Manual write procedure

After each agent invocation, append a line:

```bash
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | <agent-name> | <task-subject> | <completed|failed|blocked> | Task #<id>" >> .agentic/agent-audit.log
```

If AI toolchain is unavailable, write the line manually with a text editor. Keep entries
in chronological order; do not delete entries.

### Manual read / audit procedure

```bash
# View full log
cat .agentic/agent-audit.log

# View entries for a specific agent
grep "docs-engineer" .agentic/agent-audit.log

# View failed or blocked invocations
grep -E "failed|blocked" .agentic/agent-audit.log

# View entries for a specific date
grep "2026-04-23" .agentic/agent-audit.log
```

### Reconstructing work history from the log

To understand what happened in a previous session when `session-state.md` is incomplete:

1. Find the session's date range in the log.
2. Identify all agents invoked and their task subjects.
3. Cross-reference failed/blocked entries with the outstanding tasks in `session-state.md`.
4. Use the task subjects to locate any files created or modified — check `git log` for
   commits made in the same time window.

---

## Full Manual Recovery Procedure

Use this when AI toolchain is unavailable and you need to understand and continue the
last agentic session's work manually.

### Step 1 — Read session state

```bash
cat .agentic/session-state.md
```

Note: outstanding tasks, last active work.

### Step 2 — Read the audit log

```bash
grep "$(date -u +%Y-%m-%d)" .agentic/agent-audit.log
# If nothing today, try yesterday's date
grep "$(date -u -v-1d +%Y-%m-%d)" .agentic/agent-audit.log   # macOS
```

Note: any failed or blocked entries that need attention.

### Step 3 — Check memory for project context

```bash
cat ~/.agentic/projects/<hashed-project-path>/memory/MEMORY.md
# Read the project_*.md files for active epics
```

### Step 4 — Identify the manual commands

For each outstanding task, find the relevant runbook in `mddocs/operations/runbooks/`
or `mddocs/reference.architecture/`.

### Step 5 — Execute manually and update the log

After completing manual work, append to the audit log:

```bash
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | manual | <task-subject> | completed | manual" >> .agentic/agent-audit.log
```

Update `session-state.md` to remove completed tasks.

---

## Validation

```bash
# Confirm all tracking files are present
ls -la .agentic/session-state.md .agentic/agent-audit.log

# Confirm memory index is present
ls ~/.agentic/projects/<hashed-project-path>/memory/MEMORY.md
```

---

## Rollback

All tracking files are append-only or overwritten on each session. To reset:

```bash
# Reset session state (clears outstanding tasks)
cat > .agentic/session-state.md << 'EOF'
# Session State
Last updated: <timestamp>

## Outstanding Tasks
_(none)_

## Completed This Session
_(none)_

## Last Active Work
_(reset manually)_
EOF

# Audit log is never reset — it is the permanent record
# If log is corrupted, move it aside and create a fresh one
mv .agentic/agent-audit.log .agentic/agent-audit.log.bak
echo "## agent-audit.log" > .agentic/agent-audit.log
echo "## Format: ISO timestamp | agent | task subject | status | task ID" >> .agentic/agent-audit.log
```

---

## Related

- `.agentic/agents/lead-engineer.md` — session tracking instructions for the orchestrator
- `.agentic/session-state.md` — live session state file
- `.agentic/agent-audit.log` — agent invocation audit log
- `~/.agentic/projects/<hashed-project-path>/memory/MEMORY.md` — long-term memory index
- [Session Continuity](session-continuity.md) — commit-early-commit-often Stop hook and end-of-focus memory write practices
