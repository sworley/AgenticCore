# Runbook: review-ledger MCP Server

**Task:** TC-026  
**Server path:** `mcp/review-ledger/server.py`  
**ADR ref:** ADR-0019 (security-reviewer audit contract, D-1 through D-3)

---

## Overview

`review-ledger` is a file-backed YAML ledger MCP server providing structured
finding management for security and documentation/code reviews. It implements
two separate server instances, each bound to a dedicated backing path, enforcing
access tier separation at the process level (ADR-0019 D-1).

---

## Two-Instance Architecture

| Instance | Backing path | Finding IDs | Run IDs | Wired to |
|---|---|---|---|---|
| `review-ledger-security` | `.security/` | `SF-NNN` | `SR-YYYY-MM-DD-NN` | security-reviewer, hil-assistant |
| `review-ledger-reviews` | `.reviews/` | `RF-NNN` | `RR-YYYY-MM-DD-NN` | docs-reviewer, code-reviewer, hil-assistant |

No `path_tier` parameter exists on any tool. The instance itself determines
the backing path and ID namespace, preventing callers from cross-writing tiers.

---

## Server Launch

Each instance is launched with `uv run` and three required CLI args:

```sh
# Security instance
uv run mcp/review-ledger/server.py \
  --data-path .security \
  --id-prefix SF \
  --run-prefix SR

# Reviews instance
uv run mcp/review-ledger/server.py \
  --data-path .reviews \
  --id-prefix RF \
  --run-prefix RR
```

The server prints its resolved data path to stderr at startup. Verify this
matches the expected path before using the server in a session.

---

## MCP Config Wiring (`.mcp.json.template`)

Both instances are registered in `.mcp.json.template`. The `${COLLECTION_ROOT}`
variable is expanded at launch time by the MCP host:

```json
"review-ledger-security": {
  "type": "stdio",
  "command": "uv",
  "args": [
    "run",
    "${COLLECTION_ROOT}/mcp/review-ledger/server.py",
    "--data-path", "${COLLECTION_ROOT}/.security",
    "--id-prefix", "SF",
    "--run-prefix", "SR"
  ]
},
"review-ledger-reviews": {
  "type": "stdio",
  "command": "uv",
  "args": [
    "run",
    "${COLLECTION_ROOT}/mcp/review-ledger/server.py",
    "--data-path", "${COLLECTION_ROOT}/.reviews",
    "--id-prefix", "RF",
    "--run-prefix", "RR"
  ]
}
```

---

## Access Model — Which Tools Go in Which Agent Configs

### All agents with ledger access (both instances)

| Tool | Purpose |
|---|---|
| `log_finding` | Record a new finding |
| `log_reviewer_run` | Record a reviewer run with verdict |
| `list_findings` | Query findings by status/severity |
| `get_finding` | Retrieve a single finding with provenance |
| `request_finding_update` | Propose a status change (writes pending record only) |
| `get_audit_report` | Aggregate report: severity/status counts, trend, velocity |

### hil-assistant only

| Tool | Purpose |
|---|---|
| `approve_finding_update` | Apply a pending status change to a finding |

`approve_finding_update` must be wired **only** into the hil-assistant MCP
configuration. This implements ADR-0019 D-3: the request/approve split ensures
no agent can unilaterally close or mitigate a finding. The HIL controls all
finding status changes.

**Never** wire `approve_finding_update` into security-reviewer, docs-reviewer,
code-reviewer, lead-engineer, or attendant configs.

---

## Concurrent Write Safety (ADR-0019 D-2)

All writes use `fcntl` advisory file locking:

- Append operations (`log_finding`, `log_reviewer_run`, `request_finding_update`)
  open the file in append mode and hold `LOCK_EX` for the duration of the write.
- Update operations (`approve_finding_update`) write to a `.yaml.tmp` file under
  lock, then atomically rename to replace the original.
- The lock is always released in a `finally` block regardless of write outcome.

This provides correctness under concurrent writer scenarios (e.g. two agents
logging findings simultaneously). `fcntl` advisory locks are not enforced by
the kernel against processes that do not use `flock`; all writers must use this
server rather than writing YAML files directly.

---

## ID Namespace Conventions

### Finding IDs

- Security instance: `SF-001`, `SF-002`, ..., `SF-NNN`
- Reviews instance: `RF-001`, `RF-002`, ..., `RF-NNN`
- IDs are assigned sequentially by reading the existing maximum from the backing
  file on each call. IDs are never reused.

### Run IDs

- Security instance: `SR-2026-07-14-01`, `SR-2026-07-14-02`, ...
- Reviews instance: `RR-2026-07-14-01`, `RR-2026-07-14-02`, ...
- Counter resets each calendar day. Multiple runs on the same day increment the
  two-digit suffix (01, 02, ...).

---

## Backing File Schema

Both instances use identical YAML schemas. The security instance files are the
canonical reference; the review instance files follow the same structure.

### `findings.yaml`

```yaml
- id: SF-001
  severity: note           # note | warning | finding
  status: open             # open | mitigated | closed
  source:
    commit: abc1234        # git commit hash or label
    reviewer_run: SR-YYYY-MM-DD-NN  # populated by log_reviewer_run
    agent: security-reviewer
  file: path/to/file.py
  line: 42                 # null if not applicable
  description: "brief description"
  resolution: null         # populated when mitigated/closed
  opened: 2026-07-14
  closed: null             # populated when mitigated/closed
```

### `reviewer-log.yaml`

```yaml
- run_id: SR-2026-07-14-01
  commit_reviewed: abc1234
  verdict: approved_with_notes  # clean | approved_with_notes | blocked
  finding_ids: [SF-001, SF-002]
  agent: security-reviewer
  timestamp: 2026-07-14T18:00Z
```

### `pending-<id>.yaml` (transient)

Written by `request_finding_update`; removed by `approve_finding_update`.
Do not edit these files manually; use the MCP tools.

```yaml
finding_id: SF-001
proposed_status: mitigated
rationale: "fixed in commit abc1234 — patch applied"
requested_at: 2026-07-14T18:00Z
requested_by: security-reviewer
```

---

## Adding a Reviewer Run and Linking Findings

The typical workflow for a security-reviewer run:

1. Call `log_finding` for each finding discovered. Note the returned IDs.
2. Call `log_reviewer_run` with the collected `finding_ids` and the commit reviewed.
3. The run ID (`SR-...`) can be recorded in the source `reviewer_run` field of
   findings if needed (use `request_finding_update` to propose a correction).

---

## Requesting and Approving a Finding Status Change

Only the HIL (via hil-assistant) may close or mitigate findings.

**Agent workflow:**
```
request_finding_update("SF-006", "mitigated", "separate server instances implemented in TC-026")
```

**HIL workflow (hil-assistant):**
```
get_finding("SF-006")          # review the pending update
approve_finding_update("SF-006")  # apply it
```

---

## Troubleshooting

**Server fails to start:** Verify `uv` is installed and `mcp/review-ledger/server.py` exists.
Run `./mddocs/scripts/check-env.sh` to confirm environment prerequisites.

**`data_path` not found warning:** The backing path does not exist yet; the server will
create it on the first write. If the path is wrong, stop the server and restart with
the correct `--data-path` argument.

**Stale `pending-<id>.yaml`:** If an update was requested but never approved, the pending
file remains. Inspect it with `get_finding`, then either approve it (hil-assistant) or
remove it manually with `rm .security/pending-sf-NNN.yaml`.

**ID collision risk:** IDs are assigned by reading the current maximum at write time.
Under heavy concurrent load, two simultaneous `log_finding` calls could theoretically
read the same maximum before either writes. The `fcntl` lock reduces but does not
eliminate this window — writes are serialized but reads are not. In practice, reviewer
runs are not high-frequency and this is not a production concern.
