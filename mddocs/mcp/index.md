# MCP Servers

Custom MCP (Model Context Protocol) tool servers for the AgenticCore framework.
Each server is a self-contained directory containing the runtime implementation,
operations reference, and security audit artifact.

| Server | Runtime | Tools | ADR |
|--------|---------|-------|-----|
| [mcp-rag-docs](mcp-rag-docs/README.md) | `uv run server.py` | `search_docs`, `list_docs`, `get_doc` | [ADR-0002](../adr/adr-0002-mcp-rag-docs.md) |

Each server directory contains:
- `server.py` — runtime implementation (launched via `uv run` at session start)
- `README.md` — operations reference: prerequisites, cache warm, diagnostics, version bump procedure
- `cve-scan.txt` — pip-audit security scan artifact, updated on every dependency version bump

Configuration: `.mcp.json.template` (AI toolchain) and `opencode.json` (OpenCode) at the repo root.
See [Configure MCP Servers](../reference.architecture/configure-mcp.md) for setup and cache warm procedures.
