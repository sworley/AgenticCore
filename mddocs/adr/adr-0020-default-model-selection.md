# ADR-0020: Default Model Selection for opencode Sessions

**Date:** 2026-07-21
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Context

AgenticCore runs agentic sessions through the opencode UI. The `model` field in
`opencode.json` sets the default model for all sessions and subagent invocations.
Without an explicit `model` entry, opencode falls back to its own default, which may
change across versions — creating non-deterministic behavior across sessions.

> **Correction (2026-08-03, cross-ref [ADR-0021](adr-0021-per-agent-model-tiering.md)
> and SF-045).** The statement above that the top-level `model` field "sets the default
> model for all sessions and subagent invocations" is imprecise for **unpinned
> subagents**. The SF-045 runtime-log analysis (2026-08-03, using opencode's own
> `~/.local/share/opencode/log/opencode.log` `message=stream ... modelID=<model>`
> records) established the real behavior:
>
> - The top-level `opencode.json` `model` default applies to **top-level / primary
>   sessions** that carry no per-agent pin.
> - An **unpinned subagent** inherits its **parent session's runtime model** at
>   dispatch — it does **not** automatically fall through to this top-level default.
>   (Unpinned subagents matched parent-model-at-dispatch 76/78 = 97%; the two misses
>   were mid-session parent model switches.)
>
> This ADR's decision below is unchanged and remains the controlling decision for the
> top-level default; only the factual characterization of subagent fall-through is
> corrected. ADR-0021 (TC-041, option C-strict) resolves the resulting non-determinism
> by pinning all 14 agents explicitly, so no agent relies on inheritance.

The framework workload profile is framework stewardship: writing and reviewing ADRs
and runbooks, authoring and syncing agent definitions, running mdbook builds, and
coordinating multi-step task sequences. This workload is tool-call-heavy with moderate
reasoning depth requirements and extended session lengths.

Candidate models evaluated (source: models.dev, 2026-07-21):

| Model | Context | Output | Cost (in/out per MTok) | Notes |
|---|---|---|---|---|
| `model-runtime-sonnet-4` | 1M | 64K | $3 / $15 | Prior default; workhorse for coding agents |
| `model-runtime-sonnet` | 1M | 128K | $2 / $10 | Everyday agent model; coding, planning, browsing |
| `model-runtime-opus` | 1M | 128K | $5 / $25 | Highest reasoning tier |
| `model-runtime-creative` | 1M | 128K | $10 / $50 | Creative writing and controlled agent workflows |

Key constraints:
- Sessions route through the operator's employer-defined vendor gateway — the
  `ExampleProvider` provider defined in `~/.config/opencode/opencode.json` — not directly
  against `cloud-provider/*` model IDs. Vendor routing is governed by the operator's
  employment terms and is not a per-project choice.
- The model must support `tool_call` — all agent coordination depends on tool use.
- Cost matters; sessions are long and token-heavy due to large context files and
  multi-step task sequences.

---

## Decision

Set `provider/model-sonnet-5` as the default model in `opencode.json`.

This replaces the implicit fallback to `model-runtime-sonnet-4`, which was in use
prior to this ADR.

**Correction (2026-07-21, same day):** this ADR originally recorded the decision as
`cloud-provider/runtime-model-sonnet` — a raw Model Runtime model ID that bypasses the
operator's required `ExampleProvider` vendor gateway. That value was live in `opencode.json`
for part of one session and broke authentication (undefined provider). The model
selection rationale below (sonnet-5 over sonnet-4-6/opus/fable) is unaffected — only
the provider-qualified ID was wrong. Corrected same day; see Implementation Notes.

---

## Consequences

**Positive:**
- Lower cost: $2/$10 per MTok vs $3/$15 — approximately 33% reduction on both input
  and output tokens.
- Larger output window: 128K vs 64K — reduces mid-session truncation risk in long
  agentic workflows.
- Newer model with later release date (2026-06-30 vs 2026-02-17).
- Explicit `model` field eliminates opencode version-default drift.

**Negative / Trade-offs:**
- sonnet-5 is newer and has less operational history in this framework than sonnet-4-6.
- If sonnet-5 regresses on tool-call reliability, sessions will degrade silently until
  the model is changed.

**Neutral:**
- Opus-tier models were not selected; they are available for one-off use via the
  opencode model switcher when deeper reasoning is warranted.
- The `small_model` field is not set; opencode will use its own default for lightweight
  tasks such as title generation.

---

## Implementation Notes

- `opencode.json` — `model` field set to `provider/model-sonnet-5`. The
  `ExampleProvider` provider (an `openai-compatible` gateway) is defined once in the
  operator's global `~/.config/opencode/opencode.json`, not per-project; a
  project-level override must use the same provider prefix or it will fail to
  resolve.
- Model IDs sourced from [models.dev](https://models.dev) — re-evaluate at each minor
  framework release against the current models.dev catalog. Re-evaluation must
  preserve the operator's required vendor-gateway prefix; do not substitute a raw
  cloud-provider model ID (e.g. `cloud-provider/*`) even if models.dev lists one.
- To override for a single session: use the opencode model switcher in the UI.
