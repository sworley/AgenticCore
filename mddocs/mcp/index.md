# MCP Servers

Custom MCP (Model Context Protocol) tool servers for the AgenticCore framework.
Each server is a self-contained directory containing the runtime implementation,
operations reference, and security audit artifact.

| Server | Runtime | Tools | Reference |
|--------|---------|-------|-----------|
| [`mcp-rag-docs`](mcp-rag-docs/README.md) | `uv run server.py` | `search_docs`, `list_docs`, `get_doc` | [ADR-0002](../adr/adr-0002-mcp-rag-docs.md) |
| `review-ledger` (security instance) | `uv run server.py` | `list_findings`, `log_finding`, `log_reviewer_run`, `request_finding_update`, `approve_finding_update` | [Runbook](../operations/runbooks/review-ledger-runbook.md) |
| `review-ledger` (reviews instance) | `uv run server.py` | `list_findings`, `log_finding`, `log_reviewer_run`, `request_finding_update` | [Runbook](../operations/runbooks/review-ledger-runbook.md) |

The `review-ledger` server is launched as **two instances** from the same
`mcp/review-ledger/server.py`, each bound to a different backing path and
ID/run prefix:

| opencode.json entry | Data path | Prefixes |
|---------------------|-----------|----------|
| `review-ledger-security` | `.core/review-ledger/security` | `SF` / `SR` |
| `review-ledger-reviews` | `.core/review-ledger/reviews` | `RF` / `RR` |

`approve_finding_update` is wired **only** into the `hil-assistant` agent (ADR-0019
D-3) — never into security-reviewer, docs-reviewer, or code-reviewer.

`mcp-rag-docs` directory contains:
- `server.py` — runtime implementation (launched via `uv run` at session start)
- `README.md` — operations reference: prerequisites, cache warm, diagnostics, version bump procedure
- `cve-scan.txt` — pip-audit security scan artifact, updated on every dependency version bump

Configuration: MCP servers are configured inline in `opencode.json` at the repo root
(read directly by OpenCode); use the gitignored `opencode.json.local` for
machine-specific overrides. See [Configure MCP Servers](../reference.architecture/configure-mcp.md)
for setup and cache warm procedures.
