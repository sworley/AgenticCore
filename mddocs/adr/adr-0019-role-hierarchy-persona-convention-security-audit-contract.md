# ADR-0019: Agentic Role Hierarchy, Persona Convention, Bounded-Context Worker Axiom, Reviewer Ledger as Framework Primitive, and Delegation Autonomy Boundary

**Date:** 2026-07-10
**Status:** accepted
**Supersedes:** —

## Prior Art

- EXAMPLE-ADR- (Lead-Engineer Identity Anchoring, 2026-06-08) — session-open anchor,
  AGENT.md policy/memory split, `.00` behavioral overlay model; carried forward into
  AC ADR-0011.
- EXAMPLE-ADR- (Agent Context Drift — Guardrail Policy, 2026-07-09) — cross-bench drift
  incident; `.00` persona collision with generic "assistant" identity as root cause.
- EXAMPLE-ADR-0011 (Agentic Orchestration Architecture, 2026-05-05) — User → Lead-Engineer →
  Security gate → Specialists delegation flow; Pattern H addendum defining `.00` as
  permanent HIL workspace.

---

## Context

Three related gaps motivate this ADR:

**Gap 1 — Role hierarchy is undocumented.** The framework has running ADRs for identity
anchoring (ADR-0011), bench isolation (ADR-0007), agent portability (ADR-0009), and
distribution (ADR-0015). None defines the canonical delegation chain across contexts.
The Hil re-explains the hierarchy every session because no single document states it.

**Gap 2 — `.00` persona is unnamed.** The `.00` workspace has been called "owner assistant",
"assistant", "Pattern H", and "lead-engineer in scratch mode" across ADRs and sessions.
The collision with the generic "assistant" identity caused a real drift incident documented
in EXAMPLE-ADR-. The AC framework has not assigned a canonical name.

**Gap 3 — Reviewer findings are untracked and unassembled.** The current process allows
`APPROVED WITH NOTES` verdicts to defer finding logging to a future session. Session-state
notes have no provenance link to the reviewer run and no Hil escalation path. Findings age
silently. More broadly, no structured reviewer (security-reviewer, docs-reviewer,
code-reviewer) produces a persistent, queryable output — verdicts and notes exist only in
conversation context and are lost at session end.

**Gap 4 — No delegation autonomy boundary is defined.** Structural reviews (security,
docs, code) are known required gates. Requiring Hil to approve each delegation step adds
friction without adding value. The framework has no canonical statement of what
baseline-steward executes autonomously vs. what surfaces to Hil for a decision.

These gaps share a root cause: the framework documents individual decisions but has no
canonical statement of the organizational model that connects them.

---

## Decision Drivers

- Hil must not re-explain the delegation chain; one ADR is the authoritative reference
- Persona naming must be unambiguous and collision-free across all tools and contexts
- All reviewer findings must be traceable from discovery to resolution with full provenance
- The Hil must see a complete sign-off package — not a series of mid-stream notifications
- The agent team must scale cleanly: context windows small, agents LLM-substitutable,
  lateral coordination minimized
- Access control for sensitive review data must follow role function, not persona name —
  names are context-specific and change across adoptions
- Structural reviews are known required gates; delegation to them must be autonomous

---

## Considered Options

### D-1: Role hierarchy documentation

- **Option A:** One canonical ADR defining the three-context chain, delegation direction,
  and role/persona mapping
- **Option B:** Update each existing ADR with cross-references
- **Option C:** Reference architecture page in mddocs/ (non-binding)

### D-2: `.00` persona name

- **Option A:** `hil-assistant` — hyphenated, follows agent naming convention, explicitly
  signals HIL-proximate role
- **Option B:** `owner-assistant` — descriptive but "owner" is not a framework concept
- **Option C:** Continue "lead-engineer in scratch mode" — no new name; document behavioral
  overlay only

### D-3: Bounded-context worker axiom placement

- **Option A:** State the axiom in this ADR; add cross-reference in `invariants.md`
- **Option B:** Add directly to `invariants.md` as a prohibition
- **Option C:** Reference architecture page — non-binding

### D-4: Security-reviewer output contract

- **Option A:** `APPROVED WITH NOTES` requires findings logged to `.core/review-ledger/security/findings.yaml`
  in the same invocation — deferred logging is non-compliant
- **Option B:** Notes continue to session-state; docs-engineer opens gap tasks retroactively
- **Option C:** All notes promoted to blocking findings — no `APPROVED WITH NOTES` verdict

### D-5: Reviewer ledger as framework primitive

- **Option A:** Ledger is a universal pattern — every structured reviewer writes the same
  two-file schema (per-finding, per-run); storage path varies by sensitivity
  (`.core/review-ledger/security/` for security-reviewer; `.core/review-ledger/reviews/` for docs-reviewer, code-reviewer);
  one MCP server backs both paths; git history is the audit trail
- **Option B:** Security-only ledger — security-reviewer writes to `.core/review-ledger/security/`; other
  reviewers continue to produce session-context-only output
- **Option C:** External system (Git issues, database)

### D-6: Review ledger MCP access model

- **Option A:** Function-based wiring — access by role function (log / surface / resolve /
  investigate), not persona name; sensitivity tier determines which backing path is
  accessible (`.core/review-ledger/security/` gated; `.core/review-ledger/reviews/` broadly readable by Lead role)
- **Option B:** Name-based wiring — enumerate persona names per path
- **Option C:** Broad read, narrow write (no sensitivity distinction)

### D-7: Delegation autonomy boundary

- **Option A:** Structural reviews (security-reviewer, docs-reviewer, code-reviewer) are
  autonomous gates — baseline-steward delegates without asking; Hil sees all results
  assembled in a sign-off package before commit
- **Option B:** Each delegation step requires Hil approval before proceeding
- **Option C:** Autonomous delegation with no sign-off package — Hil sees only the final
  diff

---

## Decision

### D-1 — One canonical ADR (Option A)

This ADR is the authoritative statement of the delegation chain. All agents, adopters,
and future ADRs reference it.

**Canonical context / role / persona table:**

| Context | Lead role instance | Persona name | Authority scope |
|---|---|---|---|
| `.00` | Hil-adjacent | `hil-assistant` | HIL-proximate; subordinate to `.01` Lead-Engineer |
| `.01` | Lead-Engineer | `baseline-steward` (framework) / `lead-engineer` (project) | Authoritative below Hil |
| `.02`+ | lead-engineer | `attendant` (Pattern W) / `lead-engineer` (Pattern A) | Subordinate to `.01` Lead-Engineer |

**Delegation flow:**

```
.00:   Hil → hil-assistant → [local agents | .01 Lead-Engineer (delegate)] → hil-assistant → Hil
.01:   Hil → Lead-Engineer → [local agents | .02+ lead-engineer (delegate)] → Lead-Engineer → Hil
.02+:  Lead-Engineer (.01) → lead-engineer (.02+) → [local agents] → lead-engineer → Lead-Engineer (.01) → Hil
```

Key properties:

- One Lead role per context; persona name is context-specific and does not alter authority
- `.02`+ lead-engineer reports to `.01` Lead-Engineer — Hil is not in the `.02`+ loop
- `hil-assistant` is HIL-proximate but not authoritative over `.01` Lead-Engineer
- Worker agents are bounded-context; they do not hold cross-session state, coordinate
  laterally, or route work independently

### D-2 — `hil-assistant` (Option A)

The canonical name for the `.00` persona is `hil-assistant`. All framework references,
agent definitions, and AGENT.md templates use this name.

**Capitalization convention:**
- `Hil-Assistant` — proper noun in prose
- `hil-assistant` — agent file names, code references, YAML keys
- `Hil` — generic reference to the human-in-the-loop role
- `hil` — lowercase in generic or code contexts

The `workspace/owner` branch name is unchanged. `bench-AGENT.md.pattern-h` is updated
to declare `hil-assistant` as the persona name.

### D-3 — Axiom in this ADR, cross-referenced from invariants.md (Option A)

**Bounded-context worker axiom:**

> Agents are bounded-context workers. Each agent maximizes depth within its assigned
> domain and minimizes cross-cutting context. The Lead role at each context level is the
> sole stateful coordinator. Worker agents receive work, execute it, and return results —
> they do not hold cross-session state, coordinate laterally with peer agents, or route
> work independently.

This axiom mirrors microservices design: depth over breadth, single responsibility,
explicit interfaces. It governs all agent authoring decisions — new agents are measured
against it at definition time.

A "Design Axioms" section is added to `invariants.md` cross-referencing this ADR.
The axiom is a load-bearing design principle, not a prohibition.

### D-4 — Same-invocation logging required (Option A)

`APPROVED WITH NOTES` is only valid when all notes are logged to `.core/review-ledger/security/findings.yaml`
before the reviewer session exits. Deferred logging is non-compliant.

**Verdict taxonomy:**

| Verdict | Meaning |
|---|---|
| `clean` | No findings; no logging required |
| `approved_with_notes` | One or more `note` or `warning` findings logged; no blocking issues |
| `blocked` | One or more `finding` severity items; branch may not proceed until resolved |

**Severity taxonomy:**

| Severity | Meaning |
|---|---|
| `note` | Informational; improvement opportunity; non-blocking |
| `warning` | Should be addressed before next release; non-blocking for current merge |
| `finding` | Blocking; branch may not be marked `branch_ready` until resolved |

**Hil escalation:** the session-open checklist surfaces all `open` findings by count and
title every session. Findings older than 7 days are flagged as explicit Hil escalation
items regardless of severity.

### D-5 — Reviewer ledger as framework primitive (Option A)

The two-file ledger schema is universal. Every structured reviewer uses it. Storage path
varies by sensitivity tier:

| Reviewer | Backing path | Sensitivity |
|---|---|---|
| `security-reviewer` | `.core/review-ledger/security/` | MCP write-gated (Lead role + security-engineer only via MCP tools); git-readable by any repo collaborator — see note below |
| `docs-reviewer` | `.core/review-ledger/reviews/` | Broadly readable by Lead role via MCP and git |
| `code-reviewer` | `.core/review-ledger/reviews/` | Broadly readable by Lead role via MCP and git |

**Note on `.core/review-ledger/security/` git visibility:** MCP role gating controls which agents can write
or query `.core/review-ledger/security/` via the `review-ledger` server. It does not restrict git-level
read access — anyone with `git clone` access to the repo can read `.core/review-ledger/security/findings.yaml`
directly. For most framework and internal adopter contexts this is acceptable: findings
describe code locations and issue categories, not credential values or sensitive data.
Finding descriptions must not reproduce sensitive content verbatim (see D-5 schema
guidance). Adopters operating in environments where security findings require stricter
confidentiality should replace `.core/review-ledger/security/` with an out-of-band store and gitignore
the path.

**Per-finding schema** (both paths, `SF-` prefix for security, `RF-` for reviews):

```yaml
- id: SF-NNN                           # SF-NNN (.core/review-ledger/security/) or RF-NNN (.core/review-ledger/reviews/)
  severity: note                       # note | warning | finding
  status: open                         # open | mitigated | closed
  source:
    commit: <sha>
    reviewer_run: SR-YYYY-MM-DD-NN     # SR- for security, RR- for reviews
    agent: security-reviewer           # or docs-reviewer, code-reviewer
  file: <repo-relative path>
  line: <line number or null>
  description: "<one-line description>"  # identify issue category and location only;
                                         # do not reproduce sensitive content verbatim
  resolution: null                     # populated when mitigated or closed
  opened: YYYY-MM-DD
  closed: null
```

**Per-run schema** (both paths):

```yaml
- run_id: SR-YYYY-MM-DD-NN             # SR- for security, RR- for reviews
  commit_reviewed: <sha>
  verdict: approved_with_notes         # clean | approved_with_notes | blocked
  finding_ids: []                      # finding ID list; empty for clean runs
  agent: security-reviewer             # or docs-reviewer, code-reviewer
  timestamp: YYYY-MM-DDTHH:MMZ
```

Both paths committed to the framework repo. Git history is the audit trail. Adopters
inherit empty ledgers on adoption — correct behavior.

### D-6 — Function-based MCP wiring (Option A)

The `review-ledger` MCP server backs both `.core/review-ledger/security/` and `.core/review-ledger/reviews/`. Access is
assigned by role function, not persona name. The sensitivity tier determines which
backing path is accessible.

| Function | Role | Backing path | MCP tools |
|---|---|---|---|
| **Log** findings | `security-reviewer` | `.core/review-ledger/security/` | `log_finding`, `log_reviewer_run` |
| **Log** findings | `docs-reviewer`, `code-reviewer` | `.core/review-ledger/reviews/` | `log_finding`, `log_reviewer_run` |
| **Surface** to Hil | Lead role at wired context | both paths | `list_findings`, `get_finding`, `get_audit_report` |
| **Resolve** (mitigate/close) | Lead role, explicit Hil LGTM required | both paths | `update_finding` |
| **Investigate** | `security-engineer` | `.core/review-ledger/security/` only | all tools |

No `.02`+ agents receive direct access. Findings surface upward through the delegation
chain. `update_finding` is process-gated on explicit Hil LGTM — same as any irreversible
action under standing rules.

### D-7 — Autonomous delegation with sign-off package (Option A)

Structural reviews are known required gates. The Hil already knows they will run; asking
permission to run them is friction without value. baseline-steward delegates to
security-reviewer, docs-reviewer, and code-reviewer autonomously when a review is
required by standing rules or task acceptance criteria.

The Hil does not approve delegation steps mid-stream. The Hil approves the **sign-off
package** before any commit or push.

**Sign-off package — assembled by baseline-steward before presenting to Hil:**

1. **Diff summary** — what changed, which files, line counts
2. **Reviewer verdicts** — one line per reviewer run: agent, verdict, finding count
3. **Open findings** — all `open` items from both ledger paths, with SF-/RF- IDs,
   severity, age, and description
4. **Escalations** — any finding older than 7 days, surfaced explicitly regardless
   of severity
5. **Blocking items** — any `finding`-severity item; these must be resolved before
   the Hil is asked to approve

The Hil sees everything in one pass. Nothing is buried in session history. The gate
is at commit, not at each delegation step.

**Directional decisions are still collaborative.** The autonomy boundary applies to
execution: running known gates, implementing agreed designs, assembling results.
It does not apply to decisions with architectural tradeoffs or options — those surface
to Hil before execution, as this ADR itself demonstrates. The distinction:
- Execution work → autonomous, assembled into sign-off package
- Directional decisions → options surfaced to Hil first, then autonomous execution

---

## Consequences

**Positive:**
- Role hierarchy is canonical; re-explanation becomes "see ADR-0019"
- `hil-assistant` eliminates the generic "assistant" collision that caused the EXAMPLE
  drift incident (EXAMPLE-ADR-)
- All reviewer findings have traceable provenance from discovery to resolution,
  regardless of reviewer type
- Ledger as a framework primitive: adding a new reviewer type requires no new schema
  design — it inherits the pattern
- Function-based MCP access survives persona renaming and framework adoption without
  rewiring
- Bounded-context axiom is the load-bearing reference for all future agent authoring
- Team health is observable over time across all reviewer types: finding ratios, verdict
  trend, mean time to resolution
- Sign-off package gives the Hil a complete, assembled view at the one moment it matters

**Negative / Trade-offs:**
- `hil-assistant` requires updates to `bench-AGENT.md.pattern-h` and any existing
  `.00` references in docs
- Same-invocation logging depends on TC-026 (MCP server) being live; a paper process
  (manual YAML edit) is the interim until then
- Both `.core/review-ledger/security/` and `.core/review-ledger/reviews/` require adopters to initialize empty ledgers at
  adoption time (export-framework.sh, tracked in ADR-0015 D-1, handles this)
- Sign-off package assembly is a new baseline-steward responsibility; quality of the
  package depends on all reviewer agents producing structured output

**Neutral:**
- `hil-assistant` naming does not affect `.00` authority or behavior — purely a naming
  formalization
- Bounded-context axiom describes current practice; it formalizes rather than changes
  behavior
- Directional decisions remain collaborative — D-7 autonomy boundary applies to
  execution, not to architectural choices with tradeoffs

---

## Implementation Notes

Follow-on tasks opened alongside this ADR:

- **TC-025** — Seed `.core/review-ledger/security/` and `.core/review-ledger/reviews/` ledgers; create `.agents/hil-assistant.md`;
  update `bench-AGENT.md.pattern-h`; add "Design Axioms" cross-reference to `invariants.md`;
  update memory feedback file for delegation autonomy boundary
- **TC-026** — MCP server `review-ledger` (generalized, two backing paths, 6 tools,
  D-6 access model); companion runbook; `check-env.sh` validation
- **TC-027** — Wire security-reviewer, docs-reviewer, code-reviewer, and session-open
  checklist to `review-ledger` MCP; update `.mcp.json` bootstrap templates; implement
  sign-off package assembly in baseline-steward workflow (blocked by TC-026)

Interim paper process (until TC-026 lands): all reviewers manually append to the
appropriate ledger YAML before issuing `APPROVED WITH NOTES`. The same-invocation
logging rule and sign-off package requirement are binding from this ADR's acceptance
date regardless of MCP server availability.

---

## Security Reviewer Sign-Off

- **Verdict:** APPROVED WITH NOTES
- **Run:** SR-2026-07-10-01
- **Date:** 2026-07-10
- **Commits reviewed:** d58b013, 96ccd61
- **Notes (3 warnings, 5 notes — non-blocking):**
  1. `warning` — MCP path-tier enforcement gap: `path_tier` is caller-supplied; no native MCP caller authentication. TC-026 must resolve before implementation (options: separate server instances per tier, or server-side role config map). Added to TC-026 acceptance criteria.
  2. `warning` — `.core/review-ledger/security/` git-visibility vs. "access-controlled" language tension. ADR updated: MCP gating governs tool access; git-level read is unrestricted. Adopter guidance added for stricter confidentiality environments.
  3. `warning` — `update_finding` has no technical enforcement of the Hil LGTM requirement. TC-026 must decide: accept convention-only, or implement `update_finding_request` / `approve_update` split. Added to TC-026 acceptance criteria.
  4. `note` — No `env_scope` declared in commits. TC-025 runbook should add guidance.
  5. `note` — `description` field is free text; could capture sensitive content. Schema guidance added to D-5.
  6. `note` — Interim paper-process has no compliance monitoring. Lightweight gate recommended: docs-engineer verifies findings.yaml updated before `branch_ready`.
  7. `note` — Sign-off package is self-assembled with no independent verification. Known design limitation; Hil is aware.
  8. `note` — Concurrent write safety not specified in TC-026. Added to TC-026 acceptance criteria.

---

## Related

- [ADR-0007: Bench Scope Isolation](adr-0007-bench-scope-isolation.md)
- [ADR-0009: Agent Portability Model](adr-0009-agent-portability-model.md)
- [ADR-0011: Lead-Engineer Identity Anchoring](adr-0011-lead-engineer-identity-anchoring.md)
- [ADR-0013: Pattern A — Two-Flavor Model](adr-0013-pattern-a-two-flavor-model.md)
- [ADR-0015: Framework Distribution and Adoption Model](adr-0015-framework-distribution-adoption-model.md)
