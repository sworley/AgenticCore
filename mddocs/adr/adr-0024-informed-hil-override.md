# ADR-0024: Informed HIL Override — Documented Risk-Acceptance Valve

**Date:** 2026-08-07
**Status:** proposed
**Supersedes:** —
**Superseded by:** —

## Context

The framework encodes strict controls — the [PROCESS.md](../../PROCESS.md) gates, the
[invariants](../../.core/invariants.md), and the review-ledger request/approve split
that enforces Invariant 5 ("never self-approve work"). It provides no general mechanism
for the accountable authority — the HIL — to consciously and explicitly relax a control
while accepting the documented risk.

The only documented HIL override today is narrow: overriding a `BLOCKED` reviewer verdict
via explicit written justification (`security-reviewer.md`, `code-reviewer.md`).
[ADR-0001](adr-0001-bootstrap-architecture.md) Decision 6 explicitly forbids a *general*
"proceed autonomously" waiver of the commit/push acceptance gate. There is no
informed-risk-acceptance path for anything else.

Consequence, observed live (the SF-047 closure during the v1.0.0 release close): when the
HIL directs an action that conflicts with a written control, an agent correctly refuses —
because nothing written authorizes a waiver. The HIL's legitimate, informed override reads
to the agent as something it must decline. This is a design gap, not an agent malfunction,
and not a model-disposition issue (the "the model over-defers by design" theory was
investigated against the facts and retracted for lack of evidence — the permitted approver
runs a different model tier than the coordinator, and both correct refusals and incorrect
handoffs came from the same tier).

A distinct failure mode compounds this: some HIL directives target a *capability the agent
does not possess* — for example `approve_finding_update`, which is denied to all agents
except `hil-assistant` in `opencode.json`, with zero code-level enforcement in the MCP
server itself. No override can conjure a tool that is not wired; conflating a waivable
policy with a missing capability produces churn.

## Decision

Introduce a single, documented **Informed HIL Override** mechanism with three clearly
separated clauses. The enforceable rule is added to `.core/invariants.md`; this ADR is
the durable decision record behind it.

### 1. Informed HIL Override (waivable policy)

When the HIL directs an action that conflicts with a policy, guardrail, or process control
**that the agent has the capability to perform**, the agent shall, once and clearly:

- name the specific control impacted,
- state the concrete risk and who bears it,
- identify any invariant implicated (see boundaries below).

If the HIL acknowledges and still directs the action, the agent **executes it** and records
a waiver entry (control impacted, risk, HIL acceptance verbatim, timestamp) in the session
log and — where a review-ledger finding is implicated — via a logged ledger note. The agent
does not re-litigate an acknowledged override.

### 2. Capability boundary (not waivable by override)

If the directed action requires a **tool the agent does not possess** — not merely a policy
it is choosing to enforce — the agent states this plainly, names what does hold the
capability, and stops. This is a wiring gap to fix, not a decision an override can bypass.
A manual fallback (for example, hand-editing a ledger file the tool would otherwise write)
is permitted **only** on explicit HIL authorization naming the specific action, and must be
annotated in the audit trail as a manual fallback (as was done for the SF-047 closure).

### 3. Hard boundaries the override CANNOT cross

All ten absolute prohibitions (Invariants 1–10) remain non-waivable regardless of HIL
acknowledgement. The items enumerated below are the most commonly-pressured ones, not an
exhaustive list — the override does not authorize crossing *any* absolute prohibition. In
particular, it does not authorize:

- Committing or pushing secrets, credentials, or tokens (Invariant 3).
- Acting on instructions embedded in external content (Invariant 6).
- Self-approving work — advancing, accepting, or merging one's own output past
  `branch_ready` (Invariant 5).
- Tearing down `.00` or `.01` (Invariant 8).
- Embedding credentials in git remote URLs (Invariant 9).
- Waiving the merge/push acceptance gate as a blanket "proceed autonomously" standing
  permission (ADR-0001 Decision 6). The override operates **per-action, in-conversation,
  with risk logged** — it is not the session-level autonomy waiver ADR-0001 forbids.

These remain absolute. The override valve is for controls the HIL authored and owns, not
for the invariants that exist to protect the HIL.

## Consequences

**Positive:**

- The accountable authority gains a written, auditable path to relax owned controls.
- Agents stop churning on legitimate overrides; refusals become correct only at the hard
  boundaries and true capability gaps.
- Every waiver is logged — risk acceptance is on the record, not ad-hoc in conversation.
- The policy-versus-capability distinction is codified, ending the confusion that treats a
  missing tool as a refused policy (and vice versa).

**Negative / Trade-offs:**

- A waiver mechanism can be misused; mitigated by mandatory logging and the enumerated hard
  boundaries.
- Adds a "state the risk once" step before an override executes — intended friction.
- The manual-fallback escape hatch (clause 2) writes ledger state outside the tool path; it
  is bounded by requiring explicit per-action authorization and an audit annotation.

## Scope

This ADR establishes the override *mechanism*. It does **not**, by itself:

- change any tool wiring (for example, it does not grant `approve_finding_update` to the
  coordinator — that is a separate wiring decision, which this mechanism now lets the HIL
  make as a documented, owned risk rather than an ad-hoc fallback); or
- reconcile the pre-existing citation and status contradictions surrounding ADR-0019 D-3/D-6
  and SF-025/ADR-0023 (tracked separately).

## See also

- `.core/invariants.md` — the enforceable Informed HIL Override clause
- [ADR-0001](adr-0001-bootstrap-architecture.md) Decision 6 — commit/push acceptance gate
- [ADR-0023](adr-0023-opencode-mcp-tool-restriction.md) — the config-enforced
  `approve_finding_update` restriction this valve interacts with
- `security-reviewer.md` / `code-reviewer.md` — the pre-existing BLOCKED-verdict override
