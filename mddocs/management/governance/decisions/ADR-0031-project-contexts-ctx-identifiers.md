# ADR-0031: Project Contexts and CTX Identifiers

**Date:** 2026-11-17
**Status:** accepted
**Supersedes:** -
**Superseded by:** -

## Context

The documentation and knowledge taxonomy (ADR-0029) defines a two-plane
`mddocs/` structure - `management/` (the harness itself) and `projects/`
(durable documentation about adopted work contexts). The management plane is
implemented; the projects plane was defined as an **additive capability** with
no speculative context directories created (ADR-0029 future action Q5).

This ADR records the decision for what a **project context** is, how it is
identified, and its required structure, so the first adopted context - and every
one after it - is governed by a stable contract rather than ad hoc convention.
It also resolves the `CTX-` identifier as a taxonomy-local identity, distinct
from the governance IDs `ADR-` and `AC-`.

## Decision

1. **A context is a durable documentation scope.** `projects/<context>/` holds
   harness-owned documentation **about** a work context (customer engagement,
   COE, AI Accelerator, research initiative, or other independently managed
   effort). It does **not** hold the context's customer work product, which
   remains in an independently owned Git repo (ADR-0015; ADR-0028 plane
   separation).
2. **Context identity.** A context's `index.md` uses `kind: context` with a
   stable local ID `CTX-<SLUG>` (uppercase slug, e.g. `CTX-ACME`), plus
   `title`, `purpose: <controlled term>`, and `status: active`. The `CTX-` ID
   is a taxonomy-local identity, not a governance ID.
3. **Required structure.** Each context directory requires an `index.md` and
   may use the sub-trees `activities/`, `artifacts/`, `decisions/`,
   `evidence/`, and `references/`. No sub-tree is created speculatively.
4. **No speculative seeding (Q5).** A `projects/<context>/` directory is
   created only when a real context is adopted. The projects plane currently
   holds no contexts.
5. **Context does not grant write permission.** Membership in a `projects/`
   subtree does not by itself authorize project agents to write it; approved
   execution controls must explicitly permit it (ADR-0015; ADR-0028).

## Consequences

**Positive:**
- Contexts are governed by a stable contract; `CTX-` is a small, bounded
  taxonomy-local namespace.
- The projects plane can be adopted incrementally without speculative empty
  folders.
- The repository boundary (what belongs in the harness Git repo vs a customer's
  repo) is explicit.

**Negative / Trade-offs:**
- Adds one bounded identifier namespace (`CTX-`) beyond the governance IDs.
- No adopted context exists yet, so the contract is defined but unproven in
  production.

**Neutral:**
- No change to ADR-0015 (adoption model) or the management plane.
- Work initiation/approval remains governed by the existing management-plane
  workflow, not by this ADR.

## Implementation Notes

- `mddocs/projects/index.md` documents the plane, context grammar, and
  repository boundary; this ADR is the governing decision.
- The first adopted context seeds the first `projects/<slug>/` (ADR-0029 Q5).
