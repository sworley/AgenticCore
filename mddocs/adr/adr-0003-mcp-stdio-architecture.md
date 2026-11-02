# ADR-0003: Local stdio MCP Architecture

**Date:** 2026-06-22
**Status:** accepted

---

## Context

The framework needs a structured integration layer so AI agents can access tools
beyond file and shell operations — in particular, the `mddocs/` corpus search server
and any future tool servers added by adopters.

**Challenge:** How do we integrate local tool servers into the AI agent workflow
without cloud infrastructure, always-on processes, or per-client reconfiguration?

**Constraints:**
- Local-only — no cloud deployment, no network sockets
- Extensibility — adding a new tool server must not require reconfiguring every client
- Security isolation — a failure in one server must not affect others
- No always-on process — zero operational overhead when agents are not running

---

## Considered Options

1. **Direct stdio MCP servers** *(chosen)* — each tool server is a subprocess launched
   by the AI client via stdio. One entry per server in `opencode.json` / `.mcp.json`.
2. **Local HTTP proxy** — a thin localhost process multiplexes to stdio backends. Single
   config entry, but adds an always-on process and lifecycle complexity.
3. **Self-hosted cloud gateway** — cloud-hosted MCP endpoint with authentication layer.
   Out of scope for a local developer workflow.
4. **Direct CLI calls (no MCP)** — agents call tools directly via Bash. No structured
   tool definitions, no JSON Schema validation, client-specific only.

---

## Decision

**Option 1 — Direct stdio** is chosen.

Each server is an isolated subprocess launched by the AI client at session start.
All communication is local process IPC — no network sockets, no HTTP, no
authentication layer. Adding a new tool server requires one entry in `opencode.json`
and one entry in `.mcp.json.template`.

### Why not Option 2 (local HTTP proxy)?

A proxy adds an always-on process with lifecycle management, port assignment, and
restart handling — with no benefit in a single-developer local workflow. The AI client
already manages stdio subprocess lifecycle natively.

### Why not Options 3 and 4?

Option 3 introduces cloud infrastructure out of scope for a portable local framework.
Option 4 bypasses structured tool definitions — no JSON Schema, no per-tool privilege
scoping, and tooling is client-specific.

---

## Consequences

**Positive:**
- Zero infrastructure — no gateway, no always-on process, no cloud resources
- Each server subprocess is isolated — one broken server does not affect others
- Adding a tool requires one config entry and a binary/script install
- No network exposure — all MCP communication is local process IPC
- Consistent with how OpenCode and AI toolchain both handle MCP natively

**Negative / Trade-offs:**
- Each AI client requires its own config entry per server (no single shared config)
- No single audit choke point — each server logs independently
- Direct stdio does not support multi-client scenarios without per-client config

---

## Architecture

```
OpenCode / AI toolchain
  └─ stdio ─── mcp-rag-docs   (uv run mddocs/mcp/mcp-rag-docs/server.py)
  └─ stdio ─── <future>       (one entry per additional tool server)
```

**Transport:** stdio only. Subprocess lifecycle managed by the AI client.
**Config:** `opencode.json` (OpenCode) and `.mcp.json` (AI toolchain, generated from `.mcp.json.template`).

---

## Server Inventory

| Server | Runtime | Status | Scope |
|---|---|---|---|
| `mcp-rag-docs` | `uv run server.py` | Complete | `search_docs`, `list_docs`, `get_doc` over `mddocs/` |

Future servers are added by appending an entry to `opencode.json` and `.mcp.json.template`.

---

## See Also

- [ADR-0002](adr-0002-mcp-rag-docs.md) — rag-docs server design decisions
- [Configure MCP Servers](../reference.architecture/configure-mcp.md) — setup runbook
- `.mcp.json.template` — AI toolchain template
- `opencode.json` — OpenCode MCP config
