# Runbook: Session Continuity — Commit Discipline and End-of-Focus Memory Write

**Category:** Platform & Developer Tooling
**Last Updated:** 2026-05-13
**Owner:** Platform Engineering

**Companion Script:** `.agentic/scripts/check-worktree-hygiene.sh` (check-mode only — audits worktree state, no changes)

## Overview

This runbook documents two session continuity practices adopted after an OS patch
reboot interrupted active agentic sessions. Git and file state survived the reboot
cleanly; the loss was in-flight conversation context — what was being worked on at
the moment of interruption.

Two mitigations are in place:

| Practice | Mechanism | What it preserves |
|----------|-----------|-------------------|
| Commit Early, Commit Often | Stop hook + behavioral rule | File state across any interruption |
| End-of-Focus Memory Write | Behavioral rule + memory template | Task context across session boundaries |

---

## Prerequisites

- Access to the collection root
- `.agentic/settings.local.json` deployed from template (Stop hook must be present)
- Python 3 in PATH (required by the Stop hook)

---

## Practice 1 — Commit Early, Commit Often

### What it means

Agents commit after each **discrete unit of work** — a completed subtask, a generated
artifact that is ready, a decision that landed in a file. Changes are not accumulated
across multiple subtasks before committing.

A "unit of work" is anything describable in a one-line commit subject.

### Automated enforcement — Stop hook

`.agentic/hooks/session-close-reminder.py` fires as a `Stop` hook at the end of every
agent turn. It:

1. Runs `git worktree list --porcelain` to enumerate all worktrees
2. Checks `git status --short` in each
3. Emits a warning to stderr if any worktree has uncommitted changes
4. Is silent when all worktrees are clean

The hook is informational — it never blocks the agent. Exit code is always `0`.

### Hook location

```
.agentic/hooks/session-close-reminder.py
```

Registered in `settings.local.json.template` under the `Stop` event:

```json
"Stop": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"/path/to/.agentic/hooks/session-close-reminder.py\""
      }
    ]
  }
]
```

### Companion script — manual check

```bash
.agentic/scripts/check-worktree-hygiene.sh
```

Exits `0` if all worktrees are clean. Exits `1` if any have uncommitted changes and
prints a list of dirty worktrees with their `git status --short` output.

```bash
# Run audit
.agentic/scripts/check-worktree-hygiene.sh

# Expected output when clean:
All worktrees clean.

# Expected output when dirty:
DIRTY: /path/to/<program>.02
  M  .agentic/work/tasks.yaml
  ?? mddocs/operations/runbooks/new-runbook.md
```

---

## Practice 2 — End-of-Focus Memory Write

### What it means

Before switching tasks or ending a session, write a brief `project` type memory note
capturing the current state. This ensures the next session (or a session after an
interruption) can reconstruct what was in progress without re-reading the full
conversation history.

### When to write

- Before switching from one ticket to another
- Before ending a session (session-close checklist item)
- After a decision lands that affects the next work item

### Memory note template

Write or update a `project_queue_state_<date>.md` file in
`~/.agentic/projects/.../memory/` using this format:

```markdown
---
name: queue-state-<YYYY-MM-DD>
description: Session state snapshot — active task, status, next step
metadata:
  type: project
---

Current focus: <AC-NNNN> — <ticket title>
Status: <where I stopped — e.g., "hook implemented, runbook in progress">
Next: <immediate next step>
Open: <any blocking question or pending decision, or "none">

**Why:** Session continuity — preserves in-flight context across interruptions.
**How to apply:** Read at session open to restore focus before checking tasks.yaml.
```

Add a pointer to `MEMORY.md`:

```markdown
- [Task queue state — session end YYYY-MM-DD](project_queue_state_YYYY-MM-DD.md) — ...
```

### Manual procedure (no AI toolchain available)

```bash
# Get timestamp
date -u +%Y-%m-%dT%H:%M:%SZ

# Write memory file (substitute actual path hash)
MEMORY_DIR="$HOME/.agentic/projects/<hashed-project-path>/memory"
cat > "$MEMORY_DIR/project_queue_state_$(date +%Y-%m-%d).md" << 'EOF'
---
name: queue-state-YYYY-MM-DD
description: Session state snapshot — active task, status, next step
metadata:
  type: project
---

Current focus: AC-NNNN — <title>
Status: <where stopped>
Next: <next step>
Open: <open questions or "none">

**Why:** Session continuity.
**How to apply:** Read at session open to restore focus.
EOF

# Add pointer to index
echo "- [Task queue state — session end YYYY-MM-DD](project_queue_state_YYYY-MM-DD.md) — <one-line hook>" \
  >> "$MEMORY_DIR/MEMORY.md"
```

---

## Validation

```bash
# Confirm hook exists and is executable
ls -la .agentic/hooks/session-close-reminder.py

# Confirm companion script exists and is executable
ls -la .agentic/scripts/check-worktree-hygiene.sh

# Run companion script
.agentic/scripts/check-worktree-hygiene.sh

# Confirm Stop hook is in the live settings
python3 -c "import json; d=json.load(open('.agentic/settings.local.json')); print('Stop' in d['hooks'])"

# Confirm Stop hook is in the template
python3 -c "import json; d=json.load(open('.agentic/settings.local.json.template')); print('Stop' in d['hooks'])"
```

Expected: all files present and executable; companion script exits 0 (clean); both
settings checks print `True`.

---

## Rollback

To disable the Stop hook without removing it:

```bash
# Comment out the Stop section in settings.local.json by removing the "Stop" key
python3 -c "
import json
path = '.agentic/settings.local.json'
with open(path) as f: d = json.load(f)
d['hooks'].pop('Stop', None)
with open(path, 'w') as f: json.dump(d, f, indent=2); f.write('\n')
print('Stop hook removed from live settings')
"
```

The template (`settings.local.json.template`) is the committed source of truth — do
not modify it during a rollback. Restore the live settings from the template when ready
to re-enable:

```bash
cp .agentic/settings.local.json.template .agentic/settings.local.json
```

---

## Related

- [Agent Session Tracking](agent-session-tracking.md) — full session persistence model (memory, session-state.md, audit log)
- `.agentic/hooks/session-close-reminder.py` — Stop hook implementation
- `.agentic/scripts/check-worktree-hygiene.sh` — companion audit script
- `.agentic/settings.local.json.template` — hook registration source of truth
- `~/.agentic/projects/<hashed-project-path>/memory/MEMORY.md` — long-term memory index
