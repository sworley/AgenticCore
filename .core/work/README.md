# .core/work — Task Queue & Session State

This directory holds the machine-readable task queue used by `lead-engineer`
to orchestrate agent work, and the session-state notes used to resume work
across sessions.

Human-readable backlog: `mddocs/backlog.md`
Governance: `mddocs/adr/adr-0001-bootstrap-architecture.md`,
`mddocs/adr/adr-0014-project-slug-adr-ticket-governance.md`,
`mddocs/reference.architecture/task-queue-operations.md`

## Files

| File | Purpose |
|------|---------|
| `../tasks.yaml` | The authoritative task queue — all agent-workable items with their current state |
| `tasks.yaml` | (archived copies, if any) — retained per-session snapshots |
| `README.md` | This file — schema reference for agents |
| `session-state-<date>.md` | Per-session resume notes |

`.core/worktrees/` (sibling, gitignored) holds per-task git worktrees while work
is in progress. They are created and removed by `lead-engineer` as part of the
sprint cycle.

## Task Schema

`tasks.yaml` is a top-level `tasks:` list. Each item:

```yaml
tasks:
  - id: <string>                 # Unified task id — AC-NNNN (ADR-0014)
    title: <string>              # Short human-readable title
    description: <string>        # What needs to be done; enough context to start
    acceptance_criteria: <str>   # What done looks like; used by lead-engineer for review
    adr: [ADR-NNNN]              # Optional — governing ADR(s); required for governed behavior
    priority: P1|P2|P3           # P1 = blocking/critical, P2 = important, P3 = strategic
    size: XS|S|M|L|XL            # XS < 4h, S < 1d, M 1–3d, L 3–5d, XL 1–2w
    agent: <agent-name>          # Specialist responsible (see the agent roster)
    status: <status>             # See lifecycle below
    branch: <string>|null        # Branch name when in_progress or later; null otherwise
    blocked_by: [<id>, ...]      # Ids that must reach `merged` before this starts
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    bench: ".01"|".02"|etc.      # Which bench worktree executed this task
    started_at: "YYYY-MM-DDTHH:MM:SS"  # When status → in_progress
    completed_at: "YYYY-MM-DDTHH:MM:SS" # When status → merged
    steps:                       # Checkbox sub-steps for within-ticket provenance
      - "[ ] Uncompleted step"
      - "[x] Completed step"
    labels:                      # Classification tags for filtering/reporting
      - <string>
    note: <string>               # Disposition note for cancelled/deferred tasks
    prompt_ref: <string>         # Short paraphrase/verbatim of the originating prompt
    lessons_learned:             # Memory file names or ADR refs generated from this task
      - <filename>
```

## Task Lifecycle

```
backlog → ready → claimed → in_progress → branch_ready → awaiting_user_review → accepted → merged
            ↑                                                                       ↑         ↓
        (user only)                                                             (user only) cancelled (any stage)
```

## Rules

- Only `.01` (lead-engineer) writes to `tasks.yaml`.
- Agent task work never happens directly in `.01`.
- A task moves from `in_progress` to `branch_ready` only when the artifact is
  committed and pushed.
- `accepted` requires explicit HIL approval — no agent may self-approve.
