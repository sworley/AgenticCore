# ADR-0005: Prompt Traceability and Session Logging

**Date:** 2026-05-08
**Status:** accepted
**Supersedes:** —

## Prior Art

EXAMPLE-ADR-0018 (Prompt Traceability and Session Logging, 2026-05-08). Session
logging model, traceability chain (prompt → task → branch → commit), and
artifact hygiene requirements carried forward unchanged.

---

## Context

Each agentic work session produces three types of knowledge that are currently disconnected:

1. **The prompt** — the exact user request that initiated the work
2. **The implementation** — commits, branches, tasks in `tasks.yaml`
3. **The lesson** — behavioral rules saved to `~/.agentic/projects/.../memory/`

The traceability chain today is:
```
user prompt → (paraphrased) → task.description → commit → ADR
                                                              ↕
                                                       memory/feedback_*.md
                                                    (no task back-reference)
```

Verbatim prompts exist in `.jsonl` session transcripts but those files are large,
unindexed, ephemeral, and not linked to any task or commit.

## Decision Drivers

- Recovery and audit: can we reconstruct *why* a change was made from the artifacts alone?
- Lessons learned: can we navigate from a task to the behavioral rules it generated?
- Overhead: the solution must not require significant per-task authoring burden
- Verbatim prompt text may contain sensitive operational context; storage of full
  transcripts must respect the secrets hygiene policy

## Considered Options

### Option A — tasks.yaml schema additions

Add two optional fields to every task:

```yaml
prompt_ref: "Short paraphrase or verbatim quote of the user prompt that spawned this task"
lessons_learned:
  - feedback_runbook_script_convention.md   # memory file names generated from this work
```

- Good: zero new tooling; integrates with existing sprint-metrics and task review workflow
- Bad: `prompt_ref` is a paraphrase, not verbatim — fidelity depends on the author

### Option B — Session log index (future target)

A dedicated audit archive under `mddocs/audits/sessions/` with one file per session.

**Archive structure:**
```
mddocs/audits/sessions/
├── index.md
├── YYYY-MM-DD-<slug>.md
└── rollup-YYYY-MM.md
```

- Good: verbatim prompt capture; session-level narrative; searchable across time
- Bad: adds per-session authoring overhead; full transcript verbatim storage may surface
       sensitive operational context

### Option C — ADR template additions

Add `## Prompts / Origin` and `## Lessons Learned` sections to the ADR template.

- Good: zero overhead for non-ADR tasks; captures architecturally significant decisions
- Bad: only covers decisions that warranted an ADR; routine tasks not captured

## Decision

**Chosen: Options A + C now; Option B is the documented long-term target.**

A and C together close the most critical traceability gaps with near-zero overhead:
- `prompt_ref` in tasks.yaml ties every task to its originating request
- `lessons_learned` in tasks.yaml creates a navigable link from task → memory file
- ADR `## Prompts / Origin` captures conversation context for architectural decisions
- ADR `## Lessons Learned` is the permanent home for surprises and behavioral gotchas

Option B remains the target for full session-level traceability. It is specced here in
enough detail to implement as a future sprint.

## Consequences

**Positive:**
- Every task links to its originating prompt and any lessons it generated
- ADRs contain the conversation context needed to understand *why* — not just *what*

**Negative / Trade-offs:**
- `prompt_ref` fidelity is author-dependent; paraphrases may lose nuance
- Option B overhead deferred, not eliminated; the session log gap persists

**Neutral:**
- Option B is documented precisely enough to implement without the original conversation

## Lessons Learned

- Session transcripts (`.jsonl`) are high-fidelity but practically inaccessible for
  audit; they require an index layer to be useful — which is exactly what Option B provides
- The gap between "what the agent did" and "why the user asked for it" is invisible
  in git history alone; `prompt_ref` is the minimal viable bridge

## Related

- [ADR-: AI toolchain Config Versioning and Bench Manifest](adr-0011-lead-engineer-identity-anchoring.md)
