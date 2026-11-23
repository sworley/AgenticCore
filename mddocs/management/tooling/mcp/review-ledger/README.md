---
document_type: index
status: active
lifecycle: active
primary: true
domain: Management
category: Tooling
purpose: MCP server section for the review-ledger sign-off/approval workflow
---

# review-ledger MCP Server

**Top:** [MCP servers](../README.md)

**Runtime anchor (not moved).** The review-ledger server lives at the harness root
as an established runtime anchor: `mcp/review-ledger/` (with `pyproject.toml`),
entrypoint `mcp/review-ledger/server.py`. The native runtime stays in place and
is referenced, not moved (AC-0013 D4 / P10).

**Server:** `review-ledger`
**Launch:** `uv run server.py`
**ADR:** [ADR-0023](../../../../adr/adr-0023-opencode-mcp-tool-restriction.md) (config-enforced tool restriction for `approve_finding_update`)

## Tools

| Tool | Purpose |
|---|---|
| `list_findings` | List open findings |
| `log_finding` | Record a finding |
| `log_reviewer_run` | Record a reviewer run |
| `request_finding_update` | Request a finding update |
| `approve_finding_update` | Approve a finding update (gated) |

## Operations

The primary operations content for the review-ledger workflow lives in the
assurance plane:

- [Review Ledger Runbook](../../../../operations/runbooks/review-ledger-runbook.md) - the sign-off package assembly procedure before HIL approval.

> The review-ledger runbook completes its reroute to
> `management/assurance/reviews/ledger-runbook/` (D8) in the assurance stage;
> this cross-reference is updated there.

**Owner:** maintained by the harness. The MCP documentation homes live under the
tooling category (ADR-0029); the runtime code and its location are fixed by the
established runtime anchor.
