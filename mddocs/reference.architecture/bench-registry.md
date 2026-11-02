# Bench Registry

**Purpose:** Track the state of all open and historical worktree benches.

**File:** `bench-registry.yaml` at repository root.

---

## Schema

```yaml
benches:
  - id: ".00"
    pattern: H
    branch: workspace/owner
    ticket: ""
    status: active        # active | idle | torn_down | locked
    locked: false         # if true, worktree remove requires explicit HIL justification
    created: YYYY-MM-DD
    notes: "HIL workspace — never tear down"

  - id: ".01"
    pattern: A
    branch: main
    ticket: ""
    status: active
    locked: true
    created: YYYY-MM-DD
    notes: "Lead-engineer — never tear down"
```

## Status Values

| Status | Meaning |
|---|---|
| `active` | Bench is in use |
| `idle` | Bench exists but no active work |
| `torn_down` | Worktree removed; branch may still exist |
| `locked` | Cannot be torn down without explicit HIL justification |

## Rules

- `.00` and `.01` are always `locked: true`
- Never run `git worktree remove` on a bench with `locked: true` without written HIL instruction in the current conversation
- Update status to `torn_down` immediately after `git worktree remove`
- Keep historical entries — do not delete torn-down entries

## Operations

### List active benches

```sh
python3 -c "
import yaml
with open('bench-registry.yaml') as f:
    data = yaml.safe_load(f)
for b in data.get('benches', []):
    if b['status'] in ('active', 'idle'):
        print(f\"{b['id']:6s} {b['pattern']} {b['status']:10s} {b['branch']}\")
"
```

### Check for locked benches before teardown

```sh
python3 -c "
import yaml, sys
with open('bench-registry.yaml') as f:
    data = yaml.safe_load(f)
bench_id = sys.argv[1]
for b in data.get('benches', []):
    if b['id'] == bench_id:
        if b.get('locked'):
            print(f'BLOCKED: {bench_id} is locked — requires explicit HIL instruction')
            sys.exit(1)
        print(f'OK: {bench_id} is not locked')
" ".02"
```
