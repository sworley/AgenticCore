# ADR-0011: Lead-Engineer Identity Anchoring and HIL Working Agreement

**Date:** 2026-06-08
**Status:** proposed
**Supersedes:** —

## Prior Art

EXAMPLE-ADR- (Lead-Engineer Identity Anchoring and HIL Working Agreement, 2026-06-08).
Identity anchoring model, session reconstruction pattern, and HIL working agreement
structure carried forward; EXAMPLE-specific persona references and instance details removed.

---

## Context

The lead-engineer persona is reconstructed at every session open from AGENT.md and
session memory. The current `.01/AGENT.md` is purely procedural: it defines what to do
(own the queue, provision benches, coordinate) but does not define who the agent is —
voice, communication style, relationship to the HIL, or how context is restored on a
cold start.

Four questions need resolution:

1. **Q1 — Identity anchoring:** What language in AGENT.md reliably pins voice, role, and HIL relationship across session restarts?
2. **Q2 — Session-open anchor phrase:** Should there be a canonical trigger phrase, and if so, what must the agent produce in response?
3. **Q3 — Standing rules — AGENT.md vs. memory:** Which standing rules belong in AGENT.md directly?
4. **Q4 — Agent team context:** Does a brief roster belong in `.01/AGENT.md`?

## Decision Drivers

- Persona consistency across session restarts without relying on memory file load order
- Terse, direct communication style is the established working norm — it must be explicit
- The HIL is owner and final decision-maker; this relationship must be unambiguous
- Standing rules that affect every session must be in AGENT.md, not memory
- The agent team roster changes infrequently; it should live where it is authoritative

## Considered Options

### Q1 — Identity anchoring language

- **Option A:** Add a named Identity and Working Style section to `.01/AGENT.md` with explicit voice, role, and HIL relationship statements
- **Option B:** Rely on org-level AGENT.md and session memory to reconstruct persona
- **Option C:** Add a minimal one-line role assertion at the top of `.01/AGENT.md`

### Q2 — Session-open anchor phrase

- **Option A:** Define a canonical phrase ("Lead-engineer, session open") with a specified response format: role confirmation + checklist + memory context restoration
- **Option B:** No canonical phrase — rely on the session-open checklist and natural language
- **Option C:** Canonical phrase only — define the phrase but leave the response format implicit

### Q3 — Standing rules placement

- **Option A:** Move all standing process rules from memory to AGENT.md
- **Option B:** Keep standing rules in memory; add a note in AGENT.md to read memory before acting
- **Option C:** Hybrid — rules that affect every session go in AGENT.md; task-specific rules stay in memory

### Q4 — Agent team context

- **Option A:** Add a full team roster to `.01/AGENT.md`
- **Option B:** Keep team context in org-level AGENT.md only
- **Option C:** Add brief roster to `.01/AGENT.md` as a reference section pointing to `.agentic/agents/`

## Decision

| Question | Chosen Option |
|---|---|
| Q1 | Option A — dedicated Identity and Working Style section |
| Q2 | Option A — canonical phrase with specified response format |
| Q3 | Option C — hybrid: session-critical rules in AGENT.md; task/project state in memory |
| Q4 | Option C — brief roster in `.01/AGENT.md` pointing to `.agentic/agents/` |

**Q1 rationale:** A named section with explicit voice, role, and HIL relationship statements
is directly loadable at session open. Relying on memory load order has produced the persona
drift this ADR is fixing.

**Q2 rationale:** A canonical phrase with a defined response format gives the HIL a
predictable session-open signal and gives the agent a structured restore sequence.

**Q3 rationale:** Rules that must apply in every session belong in AGENT.md where they
load unconditionally. Task context, project state, and per-user observations belong in memory.

**Q4 rationale:** The lead-engineer's primary function is coordination across the agent
team. A brief roster with pointers to canonical definitions gives the agent team awareness
without duplicating authoritative definitions.

### Rules classification — AGENT.md vs. memory

Rules in AGENT.md (session-critical, must not be missed):
- Review before push (stage + diff + explicit approval)
- No PII in docs
- Three-strikes pivot rule
- LGTM is the acceptance gate
- Fact-backed decisions
- Secrets hygiene (reference only)
- No attribution statements

Rules that stay in memory (project/task state, user profile, feedback history):
- Task queue state at session end
- User profile and preferences
- All feedback_*.md entries (behavioral refinements learned over time)

## Consequences

**Positive:**
- Persona is anchored in a file that loads unconditionally at session open
- Critical standing rules are in policy (AGENT.md), not supplementary context (memory)
- The agent team roster is visible in the lead-engineer's own file

**Negative / Trade-offs:**
- `.01/AGENT.md` grows; future edits must maintain the distinction between policy and context
- The canonical anchor phrase becomes a convention that must be documented for new users

**Neutral:**
- The three-layer context model (_context.md, .agentic/agents/, AGENT.md) serves different
  scopes and should not be collapsed

## Lessons Learned

- Persona drift is a AGENT.md authoring gap, not a memory system gap. Memory is
  supplementary context; policy belongs in the file that loads unconditionally.
- The distinction between "policy" (AGENT.md) and "context" (memory) needs to be
  stated explicitly so future edits preserve the boundary.
- Branch-isolated AGENT.md files drift. Any file maintained by hand on a long-lived
  branch will diverge; the cascade + symlink pattern is the fix.

## Related

- [ADR-: AI toolchain Profile Inheritance](adr--opencode-profile-inheritance.md)
- [ADR-0008: Orchestrator Subagent Routing Layer](adr-0008-orchestrator-subagent-routing-layer.md)
- [ADR-0009: Agent Portability Model](adr-0009-agent-portability-model.md)
