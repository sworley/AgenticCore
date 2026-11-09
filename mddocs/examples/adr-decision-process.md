# Example: ADR Decision Process

**Scenario:** The team needs to decide whether to add an MCP RAG server for
documentation search. Shows how a decision moves from question to accepted ADR.

---

## 1. The Question Surfaces

During a session the HIL asks: *"Should we add an MCP server to let agents
search the mddocs/ corpus directly?"*

This is a non-trivial architectural decision — it affects the toolchain, adds
a dependency, and changes how agents access documentation. It warrants an ADR.

Lead-engineer routes to docs-engineer: *"Write a proposed ADR for adding an
MCP RAG docs server. Context: agents currently read files directly; question
is whether a search server adds enough value to justify the dependency."*

---

## 2. Docs-Engineer Drafts the ADR

Docs-engineer opens `mddocs/adr/adr-0000-template.md`, creates `adr-0028-mcp-rag-docs-server.md`.

Researches context by reading:
```
Read: mddocs/adr/index.md                    → check next ADR number
Read: mddocs/onboarding/agentic-workflow-overview.md  → understand current agent access patterns
Read: opencode.json                          → check current MCP config
```

Drafts the ADR:

```markdown
# ADR-0028: MCP RAG Docs Server for Documentation Search

**Date:** 2026-06-24
**Status:** proposed

## Context

Agents currently access documentation by reading files directly via the Read
tool. As mddocs/ grows, full-file reads become expensive in context usage.
A BM25 search server (MCP protocol) would let agents issue targeted queries
instead of reading entire files.

Options:
1. Continue with direct file reads — zero dependency, works today
2. Add a local MCP RAG server (FastMCP + BM25) — adds search capability,
   adds a Python/uv dependency
3. Use a vector store (embeddings) — higher quality retrieval, significantly
   higher operational complexity

## Decision

Add an optional local MCP RAG docs server using FastMCP and BM25 over the
mddocs/ corpus. Server is local stdio — no network egress. Dependency on
uv (Python package runner). Configuration in opencode.json as an opt-in MCP
entry; disabled by default until corpus reaches meaningful size.

## Consequences

**Positive:**
- Agents can search by keyword without reading entire files
- Reduces context consumption on large documentation corpora
- Local stdio — no external network dependency or data egress

**Negative / Trade-offs:**
- Adds uv as a runtime dependency
- BM25 is keyword-based — no semantic search
- Server must be running for MCP queries to work; fallback is direct reads

**Neutral:**
- Disabled by default — projects can opt in when corpus justifies it

## Implementation Notes

Server implementation: mddocs/mcp/ (to be added in AC-NNNN)
Configuration: opencode.json → mcp.rag-docs (disabled: true by default)
```

Commits to the bench branch.

---

## 3. Lead-Engineer Surfaces for HIL Review

Lead-engineer relays branch-ready, surfaces to HIL:

> "ADR-0028 proposed — MCP RAG docs server. Optional, local stdio, BM25 over
> mddocs/. Disabled by default. Draft is at `mddocs/adr/adr-0028-mcp-rag-docs-server.md`
> on branch `docs/AC-NNNN-adr-0028-mcp-rag-docs`. Ready for your review."

---

## 4. HIL Reviews and Decides

HIL reads the ADR. May push back on options, ask for a tradeoff to be made
explicit, or approve as-is.

In this case HIL notes: *"Add a note that this is only useful once mddocs/
exceeds ~50 files — below that, direct reads are fine."*

Docs-engineer adds to Consequences:

```markdown
**Neutral:**
- Disabled by default — enable when mddocs/ corpus exceeds ~50 files;
  below that threshold, direct file reads are more efficient
```

HIL: *"lgtm"*

---

## 5. ADR Accepted and Merged

Lead-engineer merges. Updates ADR status field to `accepted`:

```markdown
**Status:** accepted
```

Updates `mddocs/adr/index.md` with the new entry.

---

## Key Points

- The ADR is written *before* implementation — it captures the decision, not the result
- Three options are considered; only one is chosen, with explicit tradeoffs
- HIL feedback is incorporated before LGTM — the ADR reflects the actual decision made
- Status field progresses: `proposed` → `accepted` (or `superseded` if revisited later)
- The ADR is the durable record — future engineers can read why this choice was made,
  not just what was chosen
