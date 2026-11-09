# Task Queue Operations

**Purpose:** Working with `tasks.yaml` — creating, claiming, transitioning, and closing tasks.

**Owner:** lead-engineer (`.01`) — sole writer of `tasks.yaml`

---

## Task Schema Reference

```yaml
- id: AC-NNNN
  title: Short title (< 80 chars)
  description: Full description of the task and its scope
  acceptance_criteria:
    - Specific, verifiable criterion 1
    - Specific, verifiable criterion 2
  priority: P2          # P1=critical P2=high P3=normal P4=low
  size: M               # XS=<1h S=1-4h M=4-8h L=1-2d XL=>2d
  agent: docs-engineer  # preferred agent
  status: backlog       # see lifecycle
  branch: ""            # set when claimed
  bench: ""             # set when claimed (e.g. ".02")
  blocked_by: []        # list of task IDs
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  started_at: ""
  completed_at: ""
  labels: []            # free-form tags
  note: ""              # lead-engineer notes
  steps:
    - "[ ] Step 1"
    - "[x] Completed step"
```

---

## Lifecycle

```
backlog → ready → claimed → in_progress → branch_ready → awaiting_review → accepted → merged
```

| Status | Set by | Meaning |
|---|---|---|
| `backlog` | lead-engineer | Not yet scheduled |
| `ready` | lead-engineer | Schedulable; bench can be assigned |
| `claimed` | lead-engineer | Bench assigned, work not started |
| `in_progress` | bench-lead (via relay) | Active work underway |
| `branch_ready` | bench-lead (via relay) | Deliverables committed, awaiting HIL review |
| `awaiting_review` | lead-engineer | HIL review explicitly requested |
| `accepted` | lead-engineer (on HIL LGTM) | Approved; ready to merge |
| `merged` | lead-engineer | Landed to `dev` (integration surface; not yet release-selected — ADR-0026) |

---

## Operations

### Find claimable tasks

```sh
python3 -c "
import yaml, sys
with open('tasks.yaml') as f:
    tasks = yaml.safe_load(f) or []
ready = [t for t in tasks if t.get('status') == 'ready' and not t.get('blocked_by')]
for t in sorted(ready, key=lambda x: x.get('priority', 'P9')):
    print(f\"{t['id']} [{t['priority']}] {t['size']:2s} {t['title']}\")
"
```

### Claim a task

Update in `tasks.yaml`:
```yaml
  status: claimed
  bench: ".02"
  branch: feat/AC-NNNN-short-slug
  updated: YYYY-MM-DD
```

### Mark in-progress

```yaml
  status: in_progress
  started_at: YYYY-MM-DD
  updated: YYYY-MM-DD
```

### Mark branch-ready

```yaml
  status: branch_ready
  updated: YYYY-MM-DD
  note: "Branch feat/AC-NNNN-short-slug ready for review. SHA: <sha>"
```

### Close / merge

```yaml
  status: merged
  completed_at: YYYY-MM-DD
  updated: YYYY-MM-DD
```

---

## Gap Label Convention

Tasks that represent a systemic gap — a missing capability, process hole, or
architectural weakness — should carry a `gap` label. This separates them from
normal feature/fix work and ensures they surface at session-open for HIL visibility.

```yaml
labels: [gap]
```

Any agent or the HIL may identify a gap. The lead-engineer creates the task and
applies the label. Gap tasks follow the standard lifecycle.

### Identifying gap tasks at session-open

```sh
python3 -c "
import yaml
with open('tasks.yaml') as f:
    tasks = yaml.safe_load(f) or []
gaps = [t for t in tasks
        if 'gap' in t.get('labels', [])
        and t.get('status') in ('backlog', 'ready', 'claimed', 'in_progress')]
if gaps:
    print(f'{len(gaps)} open gap(s):')
    for t in gaps:
        print(f'  {t[\"id\"]} [{t[\"status\"]}] {t[\"title\"]}')
else:
    print('No open gaps.')
"
```

Surface open gap count and titles to HIL at session-open alongside in-progress
and branch-ready items.

---

## Field-Feedback Label Convention

Tasks that originate from real-world use of a deployed AgenticCore release —
observations, friction, or defects encountered by an operator running a fresh
deployment in the field — should carry a `field-feedback` label. This distinguishes
items driven by actual adopter experience from framework-internal work, so their
signal (and volume) can be traced back to deployment use.

```yaml
labels: [field-feedback]
```

The label answers "did this come from someone actually using a shipped release?"
It composes with other labels — a field-reported defect is
`labels: [field-feedback, bug]`; a first-run onboarding rough edge is
`labels: [field-feedback, developer-experience]`. Where the item also reveals a
systemic hole, add `gap` as well.

Any agent or the HIL may relay field feedback. The lead-engineer (or
baseline-steward, for framework tasks) creates the task and applies the label.
Field-feedback tasks follow the standard lifecycle. High-signal moments to watch:
fresh startup, first bench provision, and initial release consumption — these
surface bootstrap and onboarding gaps invisible to a long-lived bench.

### Identifying field-feedback tasks at session-open

```sh
python3 -c "
import yaml
with open('tasks.yaml') as f:
    tasks = yaml.safe_load(f) or []
fb = [t for t in tasks
      if 'field-feedback' in t.get('labels', [])
      and t.get('status') in ('backlog', 'ready', 'claimed', 'in_progress')]
if fb:
    print(f'{len(fb)} open field-feedback item(s):')
    for t in fb:
        print(f'  {t[\"id\"]} [{t[\"status\"]}] {t[\"title\"]}')
else:
    print('No open field-feedback items.')
"
```

---

## Cross-Bench Relay

Bench leads cannot write `tasks.yaml` directly. Use `relay-pending.md`:

```markdown
## Relay pending — YYYY-MM-DD

**Destination:** .01 / lead-engineer
**Task:** AC-NNNN
**Request:** Update status to branch_ready
**Branch:** feat/AC-NNNN-short-slug
**SHA:** <sha>
**Detail:** All acceptance criteria met. Ready for HIL review.
```

The lead-engineer processes relay items at session open.
