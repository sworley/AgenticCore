# FAQ: How Is Web Access Restricted?

**Question (2026-11-02 session):** "What guardrails are in place for restricting web
search?"

## Answer

Web tools (WebFetch / WebSearch) are restricted by several layers:

1. **Per-call approval** — `opencode.json` sets `webfetch` and `websearch` to `ask`,
   so every web call requires explicit HIL approval at call time.
2. **Hard block hook** — `.core/hooks/block-web-tools.py` is a blocking `PreToolUse`
   hook (wired in `settings.local.json.template`) that blocks WebFetch/WebSearch
   unless `TOOLCHAIN_WEB_ALLOWED=1` is set for the session. This is the default —
   web tools are **off** unless explicitly enabled.
3. **Audit trail** — `.core/hooks/egress-audit-log.py` logs every web call to
   `~/.agentic/audit/session-<date>.jsonl`.
4. **Content inspection gate** — any external content (fetched URLs, third-party API
   responses, external repos, user-supplied data) must pass a `security-engineer`
   inspection before any agent acts on it (see ADR-0006 and `.core/invariants.md`).

**To allow web access for a session:**

```sh
export TOOLCHAIN_WEB_ALLOWED=1
```

Then re-run. The block is at the session env level; setting it is a deliberate,
per-session decision.

## Canonical References

- [ADR-0006: External Content Gate Scope](../adr/adr-0006-external-content-gate-scope.md)
- [Session Open Checklist](../reference.architecture/session-open-checklist.md)

## Provenance

- **Session:** 2026-11-02 — "web search guardrails" Q&A.
