# ADR-0023: Config-Enforced opencode MCP Tool Restriction for `approve_finding_update`

**Date:** 2026-07-31
**Status:** accepted
**Supersedes:** —
**Superseded by:** —

## Context

[ADR-0019](adr-0019-role-hierarchy-persona-convention-security-audit-contract.md) D-6
defines the review-ledger MCP access model. The `resolve` (mitigate/close) function is
process-gated on explicit Hil LGTM, and the request/approve split — `request_finding_update`
(proposable by the Lead role) versus `approve_finding_update` (HIL-only) — is the mechanism
that enforces Invariant #5 ("never self-approve work"). Only `hil-assistant`, the `.00`
HIL-proximate persona, is authorized to apply a pending finding-status change.

TC-031 wired two write/approval-capable review-ledger MCP server instances
(`review-ledger-security` and `review-ledger-reviews`) into the **global** `mcp` block of
`opencode.json`. Under opencode, every tool exposed by a registered MCP server is available
to **every agent by default** — there is no implicit per-agent scoping of MCP tools. As a
result, `approve_finding_update` was reachable from every subagent, not just `hil-assistant`.
This means the request/approve split — and therefore the Invariant #5 self-approval barrier
it enforces — was **convention-enforced only** on the opencode side: nothing in configuration
prevented, for example, `security-reviewer` or `lead-engineer` from calling
`review-ledger-security_approve_finding_update` directly and self-applying a finding update.

This gap is tracked as finding **SF-025** (relates to **SF-011**).

Both server instances expose the approve tool under a namespaced tool name:

- `review-ledger-security_approve_finding_update`
- `review-ledger-reviews_approve_finding_update`

A single glob `*_approve_finding_update` matches **both** names — the `*` covers the
server-instance prefix while the `_approve_finding_update` suffix is exact. (JSON has no
comment syntax, so this glob-coverage fact is recorded here rather than inline in the config.)

## Decision

Use opencode's `tools` boolean map to enforce the restriction in **configuration** rather
than by convention. Two blocks are added to both `opencode.json` and its portable template
`opencode.json.template`:

1. **Top-level global deny** — disables the approve tool for all agents:

   ```json
   "tools": {
     "*_approve_finding_update": false
   }
   ```

2. **Per-agent re-enable for `hil-assistant` only** — via a new top-level `agent` block:

   ```json
   "agent": {
     "hil-assistant": {
       "tools": {
         "*_approve_finding_update": true
       }
     }
   }
   ```

The per-agent `tools` map overrides the global map for that agent, so `hil-assistant`
retains access while every other agent is denied. This upgrades ADR-0019 D-6's opencode-side
wiring for `approve_finding_update` from **convention-enforced** to **config-enforced**,
closing SF-025 on the opencode side. See
[ADR-0019](adr-0019-role-hierarchy-persona-convention-security-audit-contract.md) D-6.

## Consequences

**Positive:**

- The self-approval barrier for finding updates is now enforced by opencode configuration,
  not merely by agent-definition convention. A subagent cannot call the approve tool even if
  its persona instructions were bypassed or misread.
- `hil-assistant` is the single re-enable point, matching the ADR-0019 D-6 authority model
  exactly — one authorized persona, config-verified.
- The fix is identical in `opencode.json` and `opencode.json.template`, so any project
  bootstrapped from the framework template inherits the restriction with no extra step.

**Negative / Trade-offs:**

- **`tools` is `@deprecated` in the opencode schema.** As of opencode v1.1.1 the schema tags
  the `tools` field `@deprecated Use 'permission'`. However, `permission` currently has **no
  MCP-tool-name key path** — it cannot express a rule keyed on a specific MCP tool name — and
  the live opencode MCP documentation still prescribes `tools` for exactly this per-agent MCP
  tool scoping. `tools` is therefore the only documented, working mechanism for this control.
  We adopt it consciously, with the future-fragility noted: if a future opencode release
  removes `tools` before `permission` gains MCP-tool-name support, this restriction breaks and
  must be re-expressed. This should be tracked as a follow-up and re-verified on opencode
  version bumps.
- **Hand-maintained, not generated.** `opencode.json` is **not** produced by
  `sync-agents.sh` — it is not projected from `.agents/_meta.yaml`. This restriction is
  therefore hand-maintained in `opencode.json` and `opencode.json.template` directly. A future
  agent-roster or MCP-wiring change that touches these files must preserve both blocks by hand;
  there is no generator that re-emits them. This governance point is intentional (the MCP block
  itself is hand-wired), but it means the two files are the sole source of truth for this control.
- **AI toolchain residual gap — NOT fixed by this ticket.** AI toolchain's `tools:` frontmatter
  is an **allow-only allowlist** with allow-by-default semantics when omitted. It cannot cleanly
  express "deny one MCP tool for every agent, then allow it for exactly one agent." Achieving
  the equivalent on the CC side would require enumerating an explicit allowlist on every agent
  that deliberately excludes `approve_finding_update` — a materially different and more invasive
  change. This ticket does **not** modify any AI toolchain agent allowlist; the CC-side control
  for `approve_finding_update` remains **convention-enforced only** (as already stated in the
  `.mcp.json.template` header prose). This residual gap is documented here explicitly and should
  be tracked separately.
- **Defense-in-depth backstop deferred.** A `tool.execute.before` plugin backstop was considered
  as a second, mechanism-independent enforcement layer. It was deferred: the opencode docs are
  silent on whether plugin hooks receive the invoking-agent identity, which the backstop would
  need to allow-list `hil-assistant`. That requires an empirical spike before it can be relied on,
  and is tracked as a separate follow-up.

**Neutral:**

- No agent definition, `_meta.yaml`, or `sync-agents.sh` change is involved — the fix is
  config-only and does not flow through the generator.
- The other six review-ledger tools are unaffected (see Verification).

## Verification

**Static (performed at authoring time):**

- `python3 -m json.tool opencode.json` — passes (valid JSON).
- `opencode.json.template` — valid JSON after neutral placeholder substitution
  (`${OPENCODE_MODEL}` / `${OPENCODE_DEFAULT_AGENT}` replaced with a literal, then parsed);
  committed with placeholders intact.
- Programmatic confirmation that the top-level `tools` map denies `*_approve_finding_update`
  and that `hil-assistant` is the **only** agent whose `agent.<name>.tools` re-enables it — in
  both files.

**Regression reasoning (no behavior change to other tools):**

The glob `*_approve_finding_update` matches only tool names ending in `_approve_finding_update`.
The other six review-ledger tools — `log_finding`, `log_reviewer_run`, `list_findings`,
`get_finding`, `request_finding_update`, `get_audit_report` — do **not** end in that suffix and
are therefore **not** matched by the deny. `request_finding_update` in particular is deliberately
left available to the Lead role (it only writes a pending record; it does not apply it). All six
remain available to the agents that had them before this change. The `rag-docs` server tools are
likewise unaffected.

**Live verification (completed 2026-07-31, opencode v1.18.10):**

Live confirmation was performed against a running opencode process that had loaded the merged
`opencode.json`, by dispatching subagents and reading each agent's actual runtime tool inventory:

1. Non-HIL agent (`security-reviewer`): both `review-ledger-security_approve_finding_update` and
   `review-ledger-reviews_approve_finding_update` are **absent** from the tool set. The agent sees
   only the six sibling ledger tools per server (`log_finding`, `log_reviewer_run`, `list_findings`,
   `get_finding`, `request_finding_update`, `get_audit_report`). **Confirmed.**
2. `hil-assistant`: both `approve_finding_update` variants **are** present and invocable, alongside
   the six sibling tools per server (fourteen total). **Confirmed.**
3. The six sibling tools — including `request_finding_update` — remain available to the non-HIL
   role, confirming the glob deny is scoped to the `_approve_finding_update` suffix only. **Confirmed.**

The tools-map mechanism binds at runtime as designed: the global deny removes the approve tool from
every agent, and the per-agent `hil-assistant` re-enable restores it for that persona alone. The
single glob `*_approve_finding_update` correctly covers both server-instance prefixes. This upgrades
the opencode-side enforcement of the ADR-0019 D-6 request/approve split from convention to
configuration, verified live.

Status advanced to `accepted` on completion of this live verification.

## Implementation Notes

- **`opencode.json`** (repo root) — added a top-level `"tools"` block (global deny of
  `*_approve_finding_update`) and a top-level `"agent"` block re-enabling the tool for
  `hil-assistant` only, both placed between the existing `mcp` and `permission` blocks. No
  other field or key order changed; `$schema` preserved.
- **`opencode.json.template`** (repo root) — identical two blocks applied, with the template's
  `${OPENCODE_MODEL}` / `${OPENCODE_DEFAULT_AGENT}` placeholders left intact, so a bootstrapped
  project inherits the restriction.
- **`.mcp.json.template`** — AI toolchain MCP config; its header already documents that
  `approve_finding_update is HIL-only` as convention. Left unchanged in code; the CC residual gap
  is documented in the Consequences section above. No CC agent allowlist was modified.
- **Not touched:** `sync-agents.sh` (this fix does not flow through `_meta.yaml`), any git hook or
  installer (Invariant #10), `findings.yaml` / the ledger (finding-status updates are handled by
  the Lead role via `request_finding_update` after review).
- **Cross-reference:**
  [ADR-0019](adr-0019-role-hierarchy-persona-convention-security-audit-contract.md) D-6
  (review-ledger MCP access model; request/approve split enforcing Invariant #5). This ADR upgrades
  the opencode-side enforcement of that model from convention to configuration. Finding SF-025
  (relates to SF-011).
