# ADR-0027: Authoring-Agent Execution Model — Execution-Light Workers, Lead-Run Gates

**Date:** 2026-08-21
**Status:** accepted
**Supersedes:** (none)
**Superseded by:** (none)

## Context

Field finding FF-4 (ticket TC-065) surfaced a capability-boundary question during
TC-061. The `docs-engineer` agent authored its documentation content correctly, but
holds no `bash`/`git` capability (`.agents/_meta.yaml`: `permission: { bash: deny,
edit: allow }`). It therefore could not run its own mandatory `mdbook build` gate or
`git commit` its work. It correctly flagged this as a capability boundary rather than
fabricating a build result, and the lead/steward ran the gate and commit on its behalf
each iteration.

FF-4 posed the question: is the "no bash" posture an oversight, or intentional — and
should authoring subagents be granted minimal execution capability to run their own
gates? This is a tool-wiring / capability-boundary question, not a policy-weakening one:
no invariant or process gate is in question, only which role holds the wiring to execute.

Options considered:

- **(A) Keep authoring agents execution-light; the Lead runs their gates.** [chosen]
- **(B) Grant minimal scoped `bash`/`git` to authoring agents** so they run their own
  gates and commit their own work.
- **(C) Introduce a dedicated gate-runner mechanism** (a specialist agent or tool) that
  all agents route execution needs through.

For contrast within the current team: `ops-engineer` and `ai-engineer` carry `bash: ask`
— they are execution-capable roles by design. `docs-engineer` is uniquely `bash: deny`,
the execution-light authoring role.

## Decision

Authoring subagents (`docs-engineer` and peer authoring roles) are **execution-light by
design**: they hold edit/read/write and MCP capability but **not** `bash`/`git`
execution. Running their mandatory gates (`mdbook build`, link check) and
committing/landing their work is the responsibility of the **Lead** (`lead-engineer` /
`baseline-steward`), the sole stateful coordinator at each context level.

This is a deliberate least-privilege security control, not an oversight. **No tool grants
change** as a result of this ADR — `docs-engineer` remains `bash: deny` in
`.agents/_meta.yaml`, unchanged.

## Consequences

**Positive:**

- Minimal attack/tool surface for authoring agents — declining `bash`/`git` for
  `docs-engineer` is a conscious least-privilege posture.
- Clean alignment with the **bounded-context worker axiom** (ADR-0019 D-3): authoring
  agents are bounded-context workers that receive work, execute it within their domain,
  and return results; the Lead is the sole stateful coordinator that runs their gates and
  lands their work. This ADR is **complementary** to ADR-0019, applying its axiom to the
  authoring-agent execution question.
- No weakening of Invariant 5 (no self-approval). An agent running a build gate is not
  self-approval in any case; here the authoring agent does not even run the gate — the
  Lead does. Merge and push remain HIL-gated throughout.
- Small, reversible decision. It records existing posture; it changes no wiring.

**Negative / Trade-offs:**

- Per-docs-ticket coordination friction: the Lead must run `mdbook build` and `git
  commit` for the authoring agent on every iteration. This is accepted deliberately as
  the cost of the least-privilege posture — the Lead is a manual step in the authoring
  gate loop.

**Neutral:**

- Revisitable. See the maturation path in Implementation Notes; the option to grant
  scoped execution later is preserved, not foreclosed.

## Implementation Notes

- **No `.agents/_meta.yaml` change.** `docs-engineer` stays `permission: { bash: deny,
  edit: allow }`. This ADR documents existing posture; it does not alter any tool grant.
- The Lead-run assist pattern is documented in the `docs-engineer` agent definition
  (`.agents/docs-engineer.md`) and in the agent-authoring workflow reference
  (`reference.architecture/agent-authoring-workflow.md`).
- Cross-references: ADR-0019 (D-3 bounded-context worker axiom — complementary). Provenance:
  field finding FF-4 / ticket TC-065.

### Future Direction (deferred — out of scope for this ADR)

The framework **may** later, as separate and larger design decisions:

- (a) grant `docs-engineer` its own narrowly-scoped gate-execution capability (e.g.
  permission to run `mdbook build` only), and/or
- (b) route all agents' execution needs through a dedicated specialist agent
  (cf. option C above).

These are **not scoped** in this ADR and are **not designed here** — they are recorded
so the maturation option is not lost. Any adoption of either path requires its own ADR
and a security-reviewer pass on the resulting tool-grant change.
