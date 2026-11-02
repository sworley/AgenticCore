# MCP Server Test Scripts

Smoke tests for the MCP servers configured in this framework.
Run these to verify MCP server health after dependency updates or corpus changes.

| Script | Server | Reference | Method | Tests |
|--------|--------|-----------|--------|-------|
| [test-mcp-rag-docs.py](test-mcp-rag-docs.md) | mcp-rag-docs | [configure-mcp](../../reference.architecture/configure-mcp.md) | Python + `UvStdioTransport` (MCP protocol) | `search_docs` ×3, `list_docs`, `get_doc` |
| [test-mcp-filesystem.sh](test-mcp-filesystem.md) | filesystem | [configure-mcp](../../reference.architecture/configure-mcp.md) | bash + direct file ops | `read_file`, `list_directory`, `search_files`, `get_file_info` |
| [test-mcp-git.sh](test-mcp-git.md) | git | [configure-mcp](../../reference.architecture/configure-mcp.md) | bash + git CLI | `log`, `status`, `list_branches`, `show_commit`, `get_remote_info` |
| [run-all.sh](run-all.md) | all | — | runner | invokes all test scripts; exits 0 on full pass |

```bash
# Run all tests from repo root
bash mddocs/scripts/mcp-tests/run-all.sh

# Run rag-docs test individually
uv run mddocs/scripts/mcp-tests/test-mcp-rag-docs.py
```

All scripts are idempotent and read-only. No side effects.

`mcp-rag-docs` is tested at the MCP protocol level via `fastmcp` `UvStdioTransport`.
This exercises the actual stdio subprocess launch, dependency resolution, index build,
and tool dispatch — not just the Python logic in isolation. The dependency cache must be
warm before running — see [Configure MCP Servers](../../reference.architecture/configure-mcp.md).

Called from `ops-engineer` session-open health checks when a corpus milestone is flagged
or MCP health needs investigation, and for manual verification after dependency updates
or `server.py` changes.

- [Configure MCP Servers](../../reference.architecture/configure-mcp.md) — setup and cache warm
- [mcp-rag-docs Operations Reference](../../mcp/mcp-rag-docs/README.md)
- [ADR-0002](../../adr/adr-0002-mcp-rag-docs.md) — rag-docs design decisions
