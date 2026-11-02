# ADR-0002: mcp-rag-docs — Local BM25 Search MCP Server for mddocs/ Corpus

**Date:** 2026-06-22
**Status:** accepted

---

## Context

Agents operating in this framework frequently need to look up runbooks, ADRs, and
reference material from the `mddocs/` corpus. The current approach — reading individual
files via the `Read` tool — requires the agent to know the file path in advance. There
is no discovery or relevance-ranking layer.

As the corpus grows, the gap between "I need information about X" and "I know the exact
path to the file about X" becomes a meaningful friction point for agent productivity.

**Challenge:** How do we give agents a fast, offline, zero-credential search interface
over the `mddocs/` corpus that integrates into the existing stdio MCP architecture and
remains portable across machines?

**Constraints:**
- Local-only — no cloud calls, no credentials, no network sockets
- No package installs at session time — `deny[]` rules block pip/npm at runtime
- Offline-capable — must work after a one-time cache warm
- Corpus scope: `mddocs/` only
- Zero always-on process — stdio subprocess model only
- Portable — no absolute paths baked into committed config

---

## Decisions

### D1 — Retrieval strategy: inline BM25Okapi (standard library only)

Options considered:
1. **`rank-bm25` (PyPI)** — BM25 library, but pulls `numpy` (~20 MB) as a transitive
   dependency. Unacceptable for a portable bootstrap framework where the dependency
   surface should be minimal and explicit.
2. **Inline BM25Okapi (chosen)** — BM25Okapi scoring implemented directly in `server.py`
   using only `math` and `re` from the standard library. ~60 lines. Zero transitive
   dependencies beyond `fastmcp`.
3. **Local dense embeddings (`sentence-transformers`)** — ~80 MB model download,
   cold-start latency, heavy supply chain surface. Eliminated.
4. **API-backed embeddings** — requires network call and credential at query time.
   Violates local-only constraint. Eliminated.

`math` and `re` are Python standard library modules — no install, no CVE surface,
no supply chain risk.

### D2 — Index persistence: in-memory, rebuilt at startup

The index is built in memory at subprocess launch from the current state of `mddocs/`.
No persistent cache file, no stale-index risk, no gitignore entry needed.

At the current corpus size (< 500 files), the index builds in under one second.
If corpus growth causes unacceptable startup latency, a persisted index can be added
without changing the tool interface.

### D3 — Chunking: section-level (split on `##` headings)

Files are split on `##` heading boundaries. Each chunk carries
`{file_path, section_heading, content, line_start}` metadata. This gives finer-grained
relevance than file-level retrieval and allows agents to navigate directly to the
relevant section.

### D4 — Runtime: `uv run` with inline script dependencies

`uv` is declared as a prerequisite. Inline `# /// script` dependency declarations
make `server.py` self-contained — a single file with no surrounding package structure.
`uv` resolves `fastmcp` into an isolated cache on first run; subsequent launches are
fully offline.

### D5 — MCP framework: FastMCP

FastMCP provides a minimal tool decorator API. One dependency, well-maintained,
pinned to an exact version. No raw MCP SDK boilerplate.

### D6 — Tool surface: three tools

| Tool | Signature | Purpose |
|------|-----------|---------|
| `search_docs` | `(query: str, top_k: int = 5)` | BM25 search; returns ranked sections |
| `list_docs` | `(path_prefix: str = "")` | List indexed files; optional prefix filter |
| `get_doc` | `(file_path: str)` | Return full content of a file within `mddocs/` |

### D7 — Configuration: relative paths via OpenCode `cwd`

OpenCode's local MCP `cwd` resolves relative to the workspace root. Both the script
path and `--docs-root` argument are relative paths — no absolute paths in committed
config. Portability confirmed by test: `uv run mddocs/mcp/mcp-rag-docs/server.py
--docs-root mddocs` starts correctly from the workspace root.

---

## Consequences

**Positive:**
- Zero infrastructure — no gateway, no cloud, no always-on daemon
- Fully offline after one-time `uv` cache warm (~4–6 MB for fastmcp only)
- Portable — no absolute paths in committed config; works on any checkout
- Minimal dependency surface — one PyPI package (`fastmcp`), stdlib BM25
- Single-file server — entire implementation in `mddocs/mcp/mcp-rag-docs/server.py`
- Section-level chunks improve agent precision over file-level retrieval

**Negative / Trade-offs:**
- BM25 does not handle synonyms or paraphrase — queries must use terms present in corpus
- `uv` is an added prerequisite (alongside `git`, `mdbook`, `direnv`, `pass`)
- `uv` first-run requires outbound network; subsequent launches are offline
- Index is rebuilt on every session start (~once per session)

---

## Security

- Server runs as current user — no privilege escalation
- `--docs-root` is validated at startup; server exits if path does not exist
- `get_doc` enforces path containment via `pathlib.resolve()` + `is_relative_to()` —
  path traversal attempts return an error, not content
- No credentials in tool arguments
- Read-only — no write tools exposed

**CVE scan:** `fastmcp==3.4.2` scanned with `pip-audit 2.10.1` via `uv run --python 3.12`.
Result: no known vulnerabilities. Scan artifact: `mddocs/mcp/mcp-rag-docs/cve-scan.txt`.

---

## Implementation Notes

Server: `mddocs/mcp/mcp-rag-docs/server.py`
CVE scan: `mddocs/mcp/mcp-rag-docs/cve-scan.txt`
Operations reference: `mddocs/mcp/mcp-rag-docs/README.md`

OpenCode config entry (`opencode.json`):
```json
"rag-docs": {
  "type": "local",
  "command": ["uv", "run", "mddocs/mcp/mcp-rag-docs/server.py", "--docs-root", "mddocs"],
  "enabled": true
}
```

AI toolchain template: `.mcp.json.template` — regenerate with:
```bash
COLLECTION_ROOT="$(pwd)" envsubst < .mcp.json.template > .mcp.json
```
