# ADR-0021: Per-Agent Model Tiering (Opt-In Overrides on Top of the Default)

**Date:** 2026-07-29
**Status:** accepted
**Supersedes:** —
**Superseded by:** —

## Acceptance / Amendment Note (2026-08-03)

**Status advanced `proposed` → `accepted`.** The live-verification gap recorded in
the original Implementation Notes is now closed by the SF-045 runtime-log analysis
(2026-08-03), and this ADR's tier assignments have been amended to pin all 14 agents
explicitly (TC-041, option C-strict).

**Evidence (SF-045, runtime-log method).** The investigation used opencode's own
runtime log (`~/.local/share/opencode/log/opencode.log`), which emits a
`message=stream ... modelID=<model> session.id=<ses> agent=<agent> mode=<...>`
record for every request. That record is the model opencode actually *resolved and
sent to the provider* — independent of any agent self-report. The log analysis proved:

- **Pins bind at runtime.** Pinned agents held their pinned model 16/16 (100%) for
  sessions started after the pin commit was loaded by a fresh opencode process
  (opencode loads config once at startup). This confirms ADR-0021's core claim —
  per-agent pins bind at runtime — as verified live, not merely static config.
- **Unpinned subagents inherit the parent session's runtime model, not the config
  default.** Unpinned subagents matched their parent-model-at-dispatch 76/78 (97%);
  the two misses were mid-session parent model switches. They did **not** fall through
  to the top-level `sonnet-5` config default. This corrects a factual assumption
  carried in ADR-0020 (see the resolution-precedence correction below and the
  correction note now added to ADR-0020).
- **Timeline inflection.** The `docs-reviewer` runtime timeline showed the exact
  inflection at the 2026-07-29 pin commit (`7157d1a`): `sonnet-4-6`/`sonnet-5` before,
  `haiku-4-5` after.
- **The 2026-07-31 "anomaly" was real, not an artifact.** An unpinned `code-reviewer`
  ran on `opus-4-8` (not `sonnet-5`); the log confirmed this was the real resolved
  model, inherited from an `opus-4-8` parent `lead-engineer` session — direct evidence
  of parent-model inheritance, not a self-report error.

**Amendment (TC-041, option C-strict).** Because unpinned subagents inherit the parent
session's runtime model rather than the ADR-0020 default, the seven agents previously
"left unpinned" carried an inheritance-dependent, non-deterministic tier. The HIL
decision (TC-041) is to pin **all 14 agents explicitly** to eliminate any reliance on
inheritance, preserving this ADR's reasoned tier spread exactly — no tier judgment is
changed. The seven formerly-unpinned agents are now explicitly pinned to `sonnet-5`
(the same tier they were intended to run on), making the assignment inheritance-proof.
Step-1 implementation (`.agents/_meta.yaml`, `.opencode/agents/*.md`) was reviewed by
`security-reviewer` — APPROVED clean, run SR-2026-08-03-01.

Final committed spread: `opus-4-8` ×6, `sonnet-5` ×7, `haiku-4-5` ×1 — **all 14 agents
pinned; no agent relies on inheritance.**

---

## Context

[ADR-0020](adr-0020-default-model-selection.md) set `provider/model-sonnet-5`
as the single top-level `model` default in `opencode.json`, applied to all 14 agents
in this repo regardless of role. That decision evaluated `opus-4-8` and deliberately
did not select it as the default, citing cost and the framework's tool-call-heavy,
moderate-reasoning-depth workload profile as a whole.

This ADR does **not** revisit or change that default. It adds an orthogonal,
opt-in mechanism: a per-agent `model:` override, mirroring the existing
`permission:` field pattern already used in `.agents/_meta.yaml`.

> **Correction (2026-08-03, SF-045).** The original text here stated that agents left
> unpinned "continue to resolve to the ADR-0020 default with zero behavior change."
> The SF-045 runtime-log analysis proved this is incorrect for **subagents**: an
> unpinned subagent resolves to its **parent session's runtime model**, not the
> top-level `opencode.json` default. The TC-041 amendment (option C-strict) resolves
> this by pinning all 14 agents explicitly, so no agent relies on inheritance — see the
> Acceptance / Amendment Note above.

opencode's model resolution precedence (highest wins):

1. Per-agent `model:` (agent markdown frontmatter or `opencode.json` `agent.<name>.model`)
2. For a **subagent** with no per-agent pin: the **parent session's runtime model**
   (inherited at dispatch) — **not** automatically the top-level config default. This
   is the key factual correction established by the SF-045 runtime-log analysis
   (2026-08-03): unpinned subagents matched parent-model-at-dispatch 76/78 (97%),
   with the two misses attributable to mid-session parent model switches. See the
   Acceptance / Amendment Note.
3. Local top-level `model` (`opencode.json`) — this is what a **top-level / primary**
   session resolves to when it has no per-agent pin; it is *not* the fallback for an
   unpinned subagent, which inherits from its parent instead (item 2).
4. Global `~/.config/opencode/opencode.json` `model`
5. Built-in opencode fallback

A per-agent pin always wins over both inheritance and the top-level default; this is
exactly the seam ADR-0020 left open ("Opus-tier models were not selected; they are
available for one-off use via the opencode model switcher when deeper reasoning is
warranted" — this ADR formalizes that seam as a persistent per-agent config choice
instead of a manual per-session switcher action). Because pins sit at the top of the
precedence list, the TC-041 amendment's explicit pinning of all 14 agents makes each
agent's resolved model deterministic and independent of parent-session inheritance.

**Provider registry check (done, no blocker):** `~/.config/opencode/opencode.json`'s
`ExampleProvider` provider already lists `model-runtime-opus-4-8` and `model-runtime-haiku-4-5`
alongside `model-runtime-sonnet-5` / `model-runtime-sonnet-4-6` — confirmed by reading
the file directly at implementation time (2026-07-29). No provider registry change is
required to land the tiers below.

**Roster note:** this repo's 14-agent roster differs from other engagements that have
implemented a similar pattern (this repo has `attendant`, `hil-assistant`, `ux-engineer`,
`release-engineer`, `code-reviewer` with no equivalent elsewhere). The tier assignments
below are this repo's own decision, evaluated against this repo's roles and workload —
not copied from any other agent family.

---

## Decision

Add an optional `model:` key under the `opencode:` block in `.agents/_meta.yaml`,
emitted by `sync-agents.sh`'s `build_opencode_frontmatter()` into
`.opencode/agents/<name>.md` frontmatter, exactly mirroring how `permission:` is
already emitted. The field is opencode-only — `build_agent_frontmatter()` is
untouched, and `.agentic/agents/*.md` output is unaffected by design (confirmed
zero-diff after regeneration, not merely assumed).

### Tier assignments

**High-reasoning / security-critical → `provider/model-opus-4-8`:**

| Agent | Rationale |
|---|---|
| `lead-engineer` | Sole task-queue and bench-lifecycle coordinator. Routing and gate decisions compound across an entire session; a bad call here is expensive to unwind. |
| `orchestrator` | Its entire output is a routing plan — invariant coverage, gap detection, fallback determination. Correctness of the plan *is* the job; there is no downstream check that catches a subtly wrong plan before it executes. |
| `security-reviewer` | Adversarial review is the last gate before merge. A false `APPROVED` verdict is the highest-cost failure mode in the framework — it converts a security review into a false assurance. |
| `security-engineer` | Implements security controls and hook logic directly. Reasoning errors here are exploitable, not just incorrect — this is an implementation role, not just an evaluation role. |
| `ai-engineer` | Edits agent definitions and MCP servers that gate every other agent's behavior (permissions, tool access, invariant loading). An error here is systemic — it can silently change what every other agent is allowed to do. |
| `baseline-steward` | This repo's framework-steward role — the `.01` analogue of `lead-engineer` at the framework layer (versioning, scrubbing, release lifecycle, worktree teardown authorization). Governs decisions that are hard or costly to reverse once merged/released. Evaluated explicitly per the ticket's prompt and included in the high tier for the same reason as `lead-engineer`: it is a sole, stateful coordinator role, not a bounded evaluative task. |

**Cheap / mechanical → `provider/model-haiku-4-5`:**

| Agent | Rationale |
|---|---|
| `docs-reviewer` | Evaluative-only gate: spell check via `typos-cli`, broken-link detection, ADR status-field progression, style conformance. Checklist-shaped work with low reasoning depth and (potentially) high call volume — a good fit for the cheapest tier that still handles tool calls reliably. |

**General-purpose reasoning → `provider/model-sonnet-5` (explicitly pinned):**

These seven agents were originally left unpinned on the assumption they would fall
through to the ADR-0020 `sonnet-5` default. The SF-045 runtime-log analysis (2026-08-03)
showed that unpinned subagents inherit the *parent session's* runtime model rather than
the config default, making that fall-through non-deterministic. Under the TC-041
amendment (option C-strict) they are now **explicitly pinned to `sonnet-5`** — the same
tier they were intended to run on, but now inheritance-proof. Their original per-agent
rationale is preserved unchanged below; the only addition is that the pin is now
explicit to remove parent-inheritance ambiguity.

| Agent | Rationale |
|---|---|
| `code-reviewer` | Considered for the mechanical tier per the ticket's seed proposal, but rejected: unlike `docs-reviewer`'s checklist-shaped checks, code review requires semantic judgment about correctness, edge cases, and convention fit — closer to `sonnet-5`'s target workload than to a mechanical pass. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity — this role was directly implicated in the 2026-07-31 inheritance observation). |
| `attendant` | Considered per the ticket's seed proposal, but rejected: `attendant` executes real autonomous task work on the HIL's behalf in Pattern W benches, not gate-checking. Execution risk profile is closer to a general worker than to an evaluative gate. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |
| `docs-engineer` | Authoring work (ADRs, runbooks) benefits from the general-purpose reasoning `sonnet-5` already provides; no signal that this role needs opus-tier depth or that haiku-tier is sufficient. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |
| `ops-engineer` | Scripts/automation/runbook implementation — general dev workload, no differentiating signal. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |
| `release-engineer` | CI/CD pipeline and tactical release execution — general dev workload, no differentiating signal. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |
| `ux-engineer` | UI/UX evaluation and authoring — general dev workload, no differentiating signal. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |
| `hil-assistant` | HIL-proximate scratch/coordination role in `.00` — general workload, no differentiating signal. Now explicitly pinned to `sonnet-5` (SF-045: avoids parent-inheritance ambiguity). |

**Final state — all 14 agents pinned, no agent relies on inheritance:**

| Tier | Count | Agents |
|---|---|---|
| `provider/model-opus-4-8` | 6 | `lead-engineer`, `orchestrator`, `security-reviewer`, `security-engineer`, `ai-engineer`, `baseline-steward` |
| `provider/model-sonnet-5` | 7 | `code-reviewer`, `attendant`, `docs-engineer`, `ops-engineer`, `release-engineer`, `ux-engineer`, `hil-assistant` |
| `provider/model-haiku-4-5` | 1 | `docs-reviewer` |

The seven `sonnet-5` agents are not a "lower tier" — they carry the same
general-purpose default ADR-0020 selected, now expressed as an explicit pin rather than
an inherited fall-through. Any agent's tier can be revised later with a follow-up ADR
amendment if evidence emerges (e.g. observed reasoning failures, or a cost/latency case
for `haiku-4-5`).

### Mechanism

```yaml
# .agents/_meta.yaml
security-reviewer:
  opencode:
    mode: subagent
    model: provider/model-opus-4-8
    permission:
      bash: deny
      edit: deny
```

`sync-agents.sh`'s `build_opencode_frontmatter()` emits `model:` as a top-level
frontmatter key (immediately after `mode:`, before `permission:`) only when the
`model:` key is present in `_meta.yaml`:

```markdown
---
description: ...
mode: subagent
model: provider/model-opus-4-8
permission:
  bash: deny
  edit: deny
---
```

This is the exact frontmatter shape opencode's own Markdown agent format
documents for a per-agent model override (`provider/model-id`, e.g.
`provider/model-opus-4-8`) — confirmed against opencode's published
Agents documentation at implementation time, not assumed.

---

## Consequences

**Positive:**
- Additive over the ADR-0020 default — no agent's workload tier changes from its
  intended assignment; the seven general-purpose agents run on the same `sonnet-5`
  ADR-0020 selected, now as an explicit, inheritance-proof pin (TC-041, per the SF-045
  finding that unpinned subagents inherit the parent session's model rather than the
  config default).
- `.agentic/agents/*.md` output is provably unaffected (verified zero-diff after
  regeneration), keeping the two tool outputs decoupled per their existing
  generation contract.
- Highest-blast-radius roles (routing, security review, agent-config authorship)
  get the deepest-reasoning tier available without changing the framework-wide
  default cost profile set by ADR-0020.
- Established as a repeatable pattern: future roster changes or new roles can
  be tiered by adding one line to `_meta.yaml`, no `sync-agents.sh` changes needed.

**Negative / Trade-offs:**
- Six agents now cost more per token (`opus-4-8`: $5/$25 per MTok vs `sonnet-5`'s
  $2/$10) — a deliberate trade against ADR-0020's cost-minimization rationale,
  scoped narrowly to roles where the cost of a bad decision is judged higher than
  the token-cost delta.
- Tier assignments are a judgment call, not a benchmarked result — no A/B data
  exists yet showing `opus-4-8` outperforms `sonnet-5` for these specific roles
  in this framework. Revisit if operational history suggests otherwise.
- Adds one more piece of per-agent config to keep in sync when a role's scope
  changes (e.g. if `baseline-steward`'s responsibilities narrow, its tier
  assignment should be re-evaluated, not left stale).

**Neutral:**
- The top-level `model` default in `opencode.json` is unchanged by this ADR.
  ADR-0020 remains the controlling decision for that field; this ADR only
  documents the opt-in override layer built on top of it.
- `docs-reviewer` is the only agent pinned to `haiku-4-5`; other
  mechanical/evaluative roles (`code-reviewer`) were considered for that tier and
  explicitly kept on `sonnet-5` — see rationale table above.

---

## Implementation Notes

- `.agents/_meta.yaml` — `model:` key added under the `opencode:` block. Original
  round (2026-07-29): `lead-engineer`, `orchestrator`, `ai-engineer`,
  `baseline-steward`, `security-engineer`, `security-reviewer`
  (`provider/model-opus-4-8`) and `docs-reviewer`
  (`provider/model-haiku-4-5`). TC-041 amendment (2026-08-03): the remaining
  seven agents — `code-reviewer`, `attendant`, `docs-engineer`, `ops-engineer`,
  `release-engineer`, `ux-engineer`, `hil-assistant` — pinned to
  `provider/model-sonnet-5`, so all 14 agents now carry an explicit `model:`
  pin. Schema comment block at the top of the file updated to document the field and
  cross-reference this ADR.
- `.agents/sync-agents.sh` — `build_opencode_frontmatter()` (previously at line 231)
  now emits `model:` immediately after `mode:` when present in the parsed config,
  mirroring the existing `permission:` emission. `parse_meta()`'s generic
  `indent == 4` key-value branch already captures arbitrary `<key>: <value>`
  pairs under `opencode:` via its fallback regex match — no dedicated `model:`
  parsing branch was needed (unlike `permission:`, which requires nested-block
  handling); this was confirmed by tracing the parser logic, not assumed.
- `.opencode/agents/*.md` — regenerated via `.agents/sync-agents.sh`. Original round
  changed seven files (`lead-engineer.md`, `orchestrator.md`, `ai-engineer.md`,
  `baseline-steward.md`, `security-engineer.md`, `security-reviewer.md`,
  `docs-reviewer.md`). TC-041 amendment changed the remaining seven
  (`code-reviewer.md`, `attendant.md`, `docs-engineer.md`, `ops-engineer.md`,
  `release-engineer.md`, `ux-engineer.md`, `hil-assistant.md`), each gaining exactly
  one `model:` line in frontmatter. All 14 `.opencode/agents/*.md` files now carry a
  `model:` pin.
- `.agentic/agents/*.md` — confirmed zero-diff after regeneration
  (`git diff .agentic/agents/` produces no output). `build_agent_frontmatter()`
  was not modified and does not read the `model:` key.
- **Fresh-process live verification — gap now CLOSED (SF-045, 2026-08-03):** the
  original proposed-status text recorded an open gap — static config verification had
  been done (ExampleProvider registry lists both target models; emitted frontmatter matches
  opencode's documented `model:` field format; `sync-agents.sh` parse → emit path
  traced end to end), but no live fresh-opencode-process confirmation that a pinned
  agent actually resolves to and runs on its intended model at runtime had been
  performed. **That gap is now closed.** The SF-045 investigation analyzed opencode's
  own runtime log (`~/.local/share/opencode/log/opencode.log`), which emits a
  `message=stream ... modelID=<model> session.id=<ses> agent=<agent> mode=<...>` record
  for every request — the model opencode actually resolved and sent to the provider,
  independent of any agent self-report. The analysis confirmed pinned agents held
  their pinned model 16/16 (100%) for sessions started after the pin commit was loaded
  by a fresh opencode process (opencode loads config once at startup), and that the
  `docs-reviewer` timeline flipped exactly at the 2026-07-29 pin commit (`7157d1a`).
  This satisfies the ticket's live-verification acceptance criterion and is the basis
  for advancing this ADR's status to `accepted`. (The same analysis also established
  that unpinned subagents inherit the parent session's runtime model rather than the
  config default — the factual correction reflected in the Context and Acceptance /
  Amendment sections above.)
- Cross-reference: [ADR-0020](adr-0020-default-model-selection.md) remains the
  controlling decision for the top-level `opencode.json` `model` default. This
  ADR adds an opt-in override layer on top of it and does not modify, contradict,
  or supersede it.
