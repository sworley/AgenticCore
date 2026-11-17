# ADR-0033: Project Context Adoption / Q5 Seeding

**Date:** 2026-11-17
**Status:** accepted
**Supersedes:** —
**Superseded by:** —

## Context

ADR-0029 adopted the two-plane `mddocs/` taxonomy and set a **future action (Q5)**:
the first `projects/<context>/` directory is created when the first adopted
customer context is live. ADR-0031 then codified the context contract — what a
context is, its `CTX-<SLUG>` identity, and its required structure — and repeated
the Q5 rule that no context directory is seeded speculatively.

Neither ADR defined the **operation** for bringing an existing project's
documentation into the projects plane. That gap produced real friction in the
first adoption attempt:

- The lead-engineer treated the import as ordinary **feature task work**, routing
  it through a Pattern A worker bench and then expecting the HIL to open a
  client/session in that bench to review the pushed result.
- The content sat on the seam between *customer work product* (in `.00`) and
  *harness-owned documentation about the context* (the `projects/` plane), and no
  operational rule distinguished the two.
- When asked about moved files, the agent could not move `.00` content and simply
  reported a **security block** (Invariant 7) instead of guiding the correct,
  HIL-directed path.

## Decision

1. **Project-context adoption (Q5 seeding) is a distinct, HIL-directed
   management-plane documentation operation — not Pattern A feature task work.**
   It does **not** require a `.02+` worker bench, and the HIL is **not** asked to
   open a session in a bench to review a pushed import. Review is a
   `docs-reviewer` verdict plus HIL LGTM on the branch/diff.
2. **Classify the plane boundary first, as an explicit HIL decision.** Content is
   either (a) customer work product — stays in the customer repo under `.00`,
   gitignored by `.01` (ADR-0006; ADR-0028); (b) harness-owned documentation
   *about* the context — moves to `projects/<context>/`; or (c) harness internals —
   stays in `management/`. No content moves before this is decided.
3. **`.00` content movement is per-action HIL directed (Invariant 7).** An agent
   asked to move/copy `.00` content into the harness plane states the control, the
   concrete next step (HIL per-action direction to seed `projects/<context>/`), and
   waits — it does **not** refuse outright or improvise. The runbook is the path.
4. **Compose, don't duplicate.** When adopting the framework into an existing
   project repo, run the framework adoption first (ADR-0015; `export-framework.sh`,
   `--flow empty|rehome`), then seed `projects/<context>/`. The two are separate
   operations that build on each other.
5. **No new identifiers.** Reuse the context contract (ADR-0031) and the
   classification-ID taxonomy (ADR-0032). The seeding operation introduces no new
   ID class.

## Consequences

**Positive:**
- The import is a first-class, low-ceremony operation instead of a misapplied
  feature-task flow, removing the "open a session in a bench to review" friction.
- The plane boundary is explicit, so the `.00` / `projects/` seam (customer work
  product vs harness-owned docs) is decided deliberately rather than by default.
- Invariant 7 blocks become actionable guidance rather than dead ends.

**Negative / Trade-offs:**
- Adds one more procedural ADR; the boundary classification still rests on HIL
  judgment per context (a deliberate, accountable decision, not fully automated).
- No script automates the seeding yet — it is a manual/HIL-directed operation
  (a script may be scoped as follow-on once the contract has soak time).

**Neutral:**
- No change to ADR-0015 (framework adoption), ADR-0006/ADR-0028 (plane
  separation), or the management plane.
- No change to the ID taxonomy.

## Implementation Notes

- `mddocs/reference.architecture/adopt-project-context.md` documents the
  procedure; this ADR is the governing decision.
- `mddocs/projects/index.md` carries the plane-boundary table and points to the
  runbook; `lead-engineer` and `attendant` instructions carry the import-vs-
  feature-task distinction and the actionable Invariant 7 guidance.
