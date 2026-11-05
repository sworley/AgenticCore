# Runbook: Configure MCP Servers

**Agent:** ops-engineer
**Triggered by:** New clone, new machine, or new bench provisioning

---

## Overview

This runbook covers the one-time MCP configuration steps required after cloning
AgenticCore or provisioning a new bench. The framework ships with **three** MCP
server entries, configured **inline** in `opencode.json` (read directly by
OpenCode; no `.mcp.json` generation step is needed):

| opencode.json entry | Server | Purpose |
|---------------------|--------|---------|
| `rag-docs` | `mddocs/mcp/mcp-rag-docs/server.py` | BM25 search over the `mddocs/` corpus |
| `review-ledger-security` | `mcp/review-ledger/server.py` | Security findings/review ledger (data path `.core/review-ledger/security`, prefixes `SF`/`SR`) |
| `review-ledger-reviews` | `mcp/review-ledger/server.py` | Review ledger (data path `.core/review-ledger/reviews`, prefixes `RF`/`RR`) |

The `review-ledger` server is launched as two instances, each bound to a dedicated
backing path and ID/run prefix.

See [ADR-0002](../adr/adr-0002-mcp-rag-docs.md), the
[review-ledger runbook](../operations/runbooks/review-ledger-runbook.md), and
[ADR-0003](../adr/adr-0003-mcp-stdio-architecture.md) for the stdio architecture rationale.

---

## Prerequisites

| Tool | Check | Install |
|---|---|---|
| `uv` | `which uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

`uv` must be on `PATH`. It is used to launch `server.py` at session start and to
resolve dependencies into an isolated cache on first run.

---

## Step 1 — Warm the dependency cache (first run only)

On the first invocation, `uv` downloads each server's dependencies. Subsequent
session starts are fully offline.

```bash
# Run from the repository root
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs &
sleep 15 && kill %1

uv run mcp/review-ledger/server.py --data-path .core/review-ledger/security --id-prefix SF --run-prefix SR &
sleep 15 && kill %1
```

Wait for the startup lines on stderr before killing (e.g. the indexed-corpus line
for `mcp-rag-docs`, and the resolved data-path line for `review-ledger`). If they do
not appear within 30 seconds, the cache warm is still in progress — wait longer or
check network connectivity.

**Verify the cache is warm (no downloading output):**

```bash
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs 2>&1 &
sleep 6 && kill %1
# Expected: startup lines only, no "Downloading" lines
```

---

## Step 2 — OpenCode: verify the MCP entries in opencode.json

The `opencode.json` at the repository root already contains all three MCP entries
with relative paths. No edits are needed. Verify they are present:

```bash
python3 -c "import json; d=json.load(open('opencode.json')); print(list(d.get('mcp',{}).keys()))"
# Expected: ['rag-docs', 'review-ledger-security', 'review-ledger-reviews']
```

---

## Step 3 — Verify the servers at session start

**OpenCode:** Start a session. Confirm the MCP servers are connected:

```bash
opencode mcp list
```

Expected: `rag-docs`, `review-ledger-security`, and `review-ledger-reviews` each
report `connected`.

Confirm the expected tools are available: `search_docs`, `list_docs`, `get_doc`
(`rag-docs`); `list_findings`, `log_finding`, `log_reviewer_run`,
`request_finding_update` (`review-ledger-security` / `review-ledger-reviews`).

If a server does not appear, follow the diagnostic steps in
[mcp-rag-docs Operations Reference](../mcp/mcp-rag-docs/README.md) or
[review-ledger runbook](../operations/runbooks/review-ledger-runbook.md).

---

## Step 4 — Run smoke tests (optional but recommended)

```bash
uv run mddocs/scripts/mcp-tests/test-mcp-rag-docs.py
```

Expected output:

```
[PASS] search_docs 'session open checklist' — N result(s)
[PASS] search_docs 'agent bench model' — N result(s)
[PASS] search_docs 'BM25 index rebuild' — N results (acceptable)
[PASS] list_docs — N document(s) indexed
[PASS] get_doc 'adr/adr-0001-bootstrap-architecture.md' — content non-empty

rag-docs: 5/5 passed
```

The `review-ledger` server has no automated smoke test; verify it via `opencode mcp
list` (Step 3) and the [review-ledger runbook](../operations/runbooks/review-ledger-runbook.md).

---

## Updating After Corpus Changes

The `rag-docs` index is rebuilt at every session start from the current state of
`mddocs/`. No manual rebuild step is needed. New files committed to `mddocs/` are
automatically included at the next session start.

To pick up mid-session edits: close and reopen the session.

---

## Related

- [mcp-rag-docs Operations Reference](../mcp/mcp-rag-docs/README.md) — detailed diagnostics and version bump
- [Review Ledger Runbook](../operations/runbooks/review-ledger-runbook.md) — review-ledger server details and tools
- [MCP Servers Index](../mcp/index.md) — server inventory
- [ADR-0002](../adr/adr-0002-mcp-rag-docs.md) — rag-docs design decisions
- [ADR-0003](../adr/adr-0003-mcp-stdio-architecture.md) — stdio MCP architecture
- [Provision Worker Bench](provision-worker-bench.md) — includes cache warm step
