# ADR-0032: Classification Metadata and Standard ID Contracts

**Date:** 2026-11-17
**Status:** proposed
**Supersedes:** —
**Superseded by:** —

## Context

ADR-0029 D4 adopts an annotation-first metadata contract for `mddocs/`
artefacts. The annotation pass (AC-0013) and the metadata standard
(`mddocs/scripts/metadata-standard.md`) introduced a family of classification
identifiers for framework artefacts — `SH-` (scripts), `SDX-` (indexes),
`REF-` (references), `STD-` (standards), and `SEED-` (seed templates). These
sit alongside the governance identifiers `ADR-` (decisions) and `AC-`
(tickets) and the review-ledger identifiers `SF-`/`RF-` (findings) and
`SR-`/`RR-` (reviewer runs, ADR-0019).

This ADR records the decision for what these classification identifiers are,
how they relate to governance identities, and the rules governing them — so the
framework treats them as a **contract**, not ad hoc labels, and keeps the
namespace surface as small as best practice allows.

## Decision

1. **Three distinct ID classes.**
   - **(a) Governance IDs** — `ADR-NNNN` (decisions), `AC-NNNN` (tickets), and
     the ADR-0019 ledger IDs (`SF-`/`RF-` findings, `SR-`/`RR-` reviewer runs).
     These are authoritative identities.
   - **(b) Classification IDs** — `SH-NNNN`, `SDX-NNN`, `REF-NNN`, `STD-NNN`,
     `SEED-<NAME>` for `mddocs/` artefacts. These are metadata values that
     classify framework content.
   - **(c) Taxonomy-local IDs** — `CTX-<SLUG>` for adopted contexts (ADR-0031).
   The classes are **not** interchangeable.
2. **Classification IDs are contracts.** Each classification ID:
   - is **stable and immutable once published** (principle P4) — never renumber
     or reuse;
   - follows its documented kind pattern (§1 of `metadata-standard.md`) and is
     registered in the standard's registry;
   - is carried in the artefact's own frontmatter / `.meta.yaml` (authoritative
     source), with the registry as a navigation aid.
3. **Minimize namespace sprawl.** Do **not** add a new ID kind without an ADR.
   Prefer reusing an existing kind over inventing a new prefix. The taxonomy
   does not introduce governance IDs beyond `ADR`/`AC` (and the ADR-0019 ledger
   IDs); `ACT-`, `PROPOSAL-`, and the ad hoc `DKT-` scoping tag are **retired**
   (see Implementation Notes).
4. **Governance identity is not delegated to metadata.** A classification ID
   does not grant authority; governance is carried by `ADR-` (decisions),
   `AC-` (tickets), and the ledger IDs.

## Consequences

**Positive:**
- A single documented contract governs classification IDs; the namespace stays
  small and predictable.
- Classifies content without adding governance authority.

**Negative / Trade-offs:**
- The contract adds ceremony (registry + per-artefact frontmatter) for what is
  largely documentation classification — the cost of machine-readable metadata.

**Neutral:**
- No change to the existing `ADR`/`AC`/ledger ID schemes.

## Implementation Notes

- **Retired IDs.** `ACT-` (activities now tie to `AC-` tickets via
  `source_ticket`), `PROPOSAL-` (the taxonomy proposal is superseded by
  ADR-0029 and archived), and the ad hoc `DKT-` scoping tag were retired during
  taxonomy adoption.
- The metadata standard's ID-kind table (§1) and registry (§8) are the
  operational contract this ADR governs.
