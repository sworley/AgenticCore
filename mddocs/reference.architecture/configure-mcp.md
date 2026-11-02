# Runbook: Configure MCP Servers

**Agent:** ops-engineer
**Triggered by:** New clone, new machine, or new bench provisioning

---

## Overview

This runbook covers the one-time MCP configuration steps required after cloning
AgenticCore or provisioning a new bench. The framework ships with one MCP server:
`mcp-rag-docs` — a local BM25 search server for the `mddocs/` corpus.

See [ADR-0002](../adr/adr-0002-mcp-rag-docs.md) for design decisions.
See [ADR-0003](../adr/adr-0003-mcp-stdio-architecture.md) for the stdio architecture rationale.

---

## Prerequisites

| Tool | Check | Install |
|---|---|---|
| `uv` | `which uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

`uv` must be on `PATH`. It is used to launch `server.py` at session start and to
resolve `fastmcp` into an isolated dependency cache on first run.

---

## Step 1 — Warm the dependency cache (first run only)

On the first invocation, `uv` downloads `fastmcp==3.4.2` and its dependencies
(~4–6 MB). All subsequent session starts are fully offline.

```bash
# Run from the repository root
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs &
sleep 15 && kill %1
```

Wait for these two lines to appear on stderr before killing:

```
[mcp-rag-docs] corpus root: /abs/path/to/mddocs
[mcp-rag-docs] indexed NNN sections from /abs/path/to/mddocs
```

If those lines do not appear within 30 seconds, the cache warm is still in progress —
wait longer or check network connectivity.

**Verify the cache is warm (no downloading output):**

```bash
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs 2>&1 &
sleep 6 && kill %1
# Expected: startup lines only, no "Downloading" lines
```

---

## Step 2 — OpenCode: verify rag-docs entry in opencode.json

The `opencode.json` at the repository root already contains the `rag-docs` MCP entry
with relative paths. No edits are needed. Verify it is present:

```bash
python3 -c "import json; d=json.load(open('opencode.json')); print(list(d.get('mcp',{}).keys()))"
# Expected: ['rag-docs']
```

---

## Step 3 — AI toolchain: generate .mcp.json from template

`.mcp.json` is gitignored and machine-specific. Generate it once per checkout:

```bash
COLLECTION_ROOT="$(pwd)" envsubst < .mcp.json.template > .mcp.json
```

Verify:

```bash
python3 -c "import json; d=json.load(open('.mcp.json')); print(list(d['mcpServers'].keys()))"
# Expected: ['rag-docs']
```

---

## Step 4 — Verify the server at session start

**OpenCode:** Start a session and confirm `search_docs`, `list_docs`, and `get_doc`
are available as tools.

**AI toolchain:** Start a session and run `/mcp` — `rag-docs` should show as connected.

If the server does not appear, follow the diagnostic steps in
[mcp-rag-docs Operations Reference](../mcp/mcp-rag-docs/README.md).

---

## Step 5 — Run smoke tests (optional but recommended)

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

---

## Updating After Corpus Changes

The index is rebuilt at every session start from the current state of `mddocs/`. No
manual rebuild step is needed. New files committed to `mddocs/` are automatically
included at the next session start.

To pick up mid-session edits: close and reopen the session.

---

## Related

- [mcp-rag-docs Operations Reference](../mcp/mcp-rag-docs/README.md) — detailed diagnostics and version bump
- [ADR-0002](../adr/adr-0002-mcp-rag-docs.md) — rag-docs design decisions
- [ADR-0003](../adr/adr-0003-mcp-stdio-architecture.md) — stdio MCP architecture
- [Provision Worker Bench](provision-worker-bench.md) — includes cache warm step
