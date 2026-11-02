# mcp-rag-docs — Operations Reference

**Server:** `rag-docs`
**Location:** `mddocs/mcp/mcp-rag-docs/server.py`
**ADR:** [ADR-0002](../../adr/adr-0002-mcp-rag-docs.md)

---

## Overview

`mcp-rag-docs` is a local stdio MCP server that provides BM25 full-text search over
the `mddocs/` corpus. It is launched by OpenCode and AI toolchain as a subprocess at
session start via `uv run`. No always-on process is required.

**Dependencies:** `fastmcp==3.4.2` only. BM25Okapi scoring is implemented inline
using the Python standard library — no `numpy`, no `rank-bm25`.

**Index lifecycle:** The index is built entirely in memory at subprocess launch. It
requires no persistent cache, no scheduled rebuild, and no manual invalidation — every
session start produces a fresh index from the current state of `mddocs/`. New files
committed to `mddocs/` are automatically included at the next session start.

**To pick up mid-session edits:** close and reopen the session. There is no
intra-session refresh command.

**Tools exposed:**

| Tool | Signature | Purpose |
|------|-----------|---------|
| `search_docs` | `(query: str, top_k: int = 5)` | BM25 search; returns ranked sections with file path, heading, snippet, score |
| `list_docs` | `(path_prefix: str = "")` | List all indexed files; optional prefix filter |
| `get_doc` | `(file_path: str)` | Return full content of a file within `mddocs/` |

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `uv` | Python package runner — resolves fastmcp at session start | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

`uv` must be on `PATH`. Verify: `which uv`

---

## First-Run Cache Warm

`uv` resolves `fastmcp==3.4.2` into an isolated cache on the **first** invocation.
This requires outbound PyPI access (~4–6 MB download). All subsequent launches are
fully offline — `uv` serves dependencies from the local cache.

**Run the warm step once per machine before going air-gapped:**

```bash
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs &
sleep 15 && kill %1
```

Wait for the startup lines to appear on stderr before killing:

```
[mcp-rag-docs] corpus root: /...
[mcp-rag-docs] indexed NNN sections from /...
```

---

## OpenCode Configuration

Add to `opencode.json` under `mcp`:

```json
"rag-docs": {
  "type": "local",
  "command": [
    "uv",
    "run",
    "mddocs/mcp/mcp-rag-docs/server.py",
    "--docs-root",
    "mddocs"
  ],
  "enabled": true
}
```

Paths are relative to the workspace root. No absolute paths required.

---

## AI toolchain Configuration

Regenerate `.mcp.json` from the template after cloning:

```bash
COLLECTION_ROOT="$(pwd)" envsubst < .mcp.json.template > .mcp.json
```

---

## Diagnostic — Server Not Available at Session Start

If `search_docs`, `list_docs`, or `get_doc` are not available, the server failed to
start. Diagnose in order:

### Step 1 — Confirm `uv` is on PATH

```bash
which uv && echo "uv present" || echo "uv MISSING"
```

If missing: install per Prerequisites above.

### Step 2 — Confirm `server.py` exists

```bash
ls mddocs/mcp/mcp-rag-docs/server.py && echo "server present" || echo "MISSING"
```

### Step 3 — Run the server manually and inspect output

```bash
uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs 2>&1 &
sleep 8 && kill %1
```

Expected output:
```
[mcp-rag-docs] corpus root: /abs/path/to/mddocs
[mcp-rag-docs] indexed NNN sections from /abs/path/to/mddocs
```

Any `Downloading` lines on first run are normal — cache warm in progress.
A Python traceback indicates a dependency or syntax error.

### Step 4 — Restart the AI session

MCP servers are launched at session start. If the cache warm just completed,
a session restart is required for the server to appear.

---

## Dependency Version Bump Procedure

1. Update the pin in `server.py` `# /// script` header
2. Run a fresh CVE scan and update `cve-scan.txt`:
   ```bash
   printf 'fastmcp==<new-version>\n' | uv run --python 3.12 --with pip-audit -- pip-audit --desc auto -r /dev/stdin
   ```
3. Update `cve-scan.txt` with new scan date, versions, and output
4. Warm the cache on each bench after the version change
5. Commit `server.py` and `cve-scan.txt` together

---

## Files

| File | Purpose |
|------|---------|
| `server.py` | MCP server implementation — FastMCP + inline BM25Okapi |
| `cve-scan.txt` | pip-audit scan artifact |
| `README.md` | This file — operations reference |

---

## Related

- [ADR-0002](../../adr/adr-0002-mcp-rag-docs.md) — architectural decisions and security sign-off
