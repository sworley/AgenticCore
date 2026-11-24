# ADR-0032: Classification Metadata and Standard ID Contracts

**Date:** 2026-11-17
**Status:** accepted
**Supersedes:** -
**Superseded by:** -

## Context

ADR-0029 D4 adopts an annotation-first metadata contract for `mddocs/`
artefacts. The annotation pass (AC-0013) and the metadata standard
(`mddocs/scripts/metadata-standard.md`) introduced a family of classification
identifiers for framework artefacts - `SH-` (scripts), `SDX-` (indexes),
`REF-` (references), `STD-` (standards), and `SEED-` (seed templates). These
sit alongside the governance identifiers `ADR-` (decisions) and `AC-`
(tickets) and the review-ledger identifiers `SF-`/`RF-` (findings) and
`SR-`/`RR-` (reviewer runs, ADR-0019).

This ADR records the decision for what these classification identifiers are,
how they relate to governance identities, and the rules governing them - so the
framework treats them as a **contract**, not ad hoc labels, and keeps the
namespace surface as small as best practice allows.

## Decision

1. **Three distinct ID classes.**
   - **(a) Governance IDs** - `ADR-NNNN` (decisions), `AC-NNNN` (tickets), and
     the ADR-0019 ledger IDs (`SF-`/`RF-` findings, `SR-`/`RR-` reviewer runs).
     These are authoritative identities.
   - **(b) Classification IDs** - `SH-NNNN`, `SDX-NNN`, `REF-NNN`, `STD-NNN`,
     `SEED-<NAME>` for `mddocs/` artefacts. These are metadata values that
     classify framework content.
   - **(c) Taxonomy-local IDs** - `CTX-<SLUG>` for adopted contexts (ADR-0031).
   The classes are **not** interchangeable.
2. **Classification IDs are contracts.** Each classification ID:
   - is **stable and immutable once published** (principle P4) - never renumber
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
  largely documentation classification - the cost of machine-readable metadata.

**Neutral:**
- No change to the existing `ADR`/`AC`/ledger ID schemes.

## Implementation Notes

- **Retired IDs.** `ACT-` (activities now tie to `AC-` tickets via
  `source_ticket`), `PROPOSAL-` (the taxonomy proposal is superseded by
  ADR-0029 and archived), and the ad hoc `DKT-` scoping tag were retired during
  taxonomy adoption.
- The metadata standard's ID-kind table (§1) and registry (§8) are the
  operational contract this ADR governs.

## Amendment 2026-11-19: management tooling home and ID allocations

**Scope.** Adopt the team-workspace provisioning and adoption toolchain as
canonical reusable tooling under `mddocs/management/tooling/`, and register its
artefacts under the existing classification-ID kinds (no new kind is
introduced, per decision 3).

**Decision.**

1. **Canonical tooling home.** `mddocs/management/tooling/` is the canonical
   home for reusable framework tooling, implementation, schemas, tests,
   dependency locks, documentation scripts, and rendering assets. Existing
   `mddocs/scripts/` artefacts are **not** physically migrated in this change;
   that relocation remains a separate decision (the tooling convention does not
   itself move existing root-level components).
2. **ID allocations.** The adopted artefacts are allocated `SH-0029` through
   `SH-0045` (executables and tests), `REF-0002` through `REF-0009`
   (schemas, dependency locks, and rendering assets), and `SDX-005`/`SDX-006`
   (the tooling and git-hook indexes). Each is registered in the metadata
   standard (§8 and §8.1).
3. **Metadata scope.** The `reference` classification kind now also covers
   non-executable data and asset artefacts (schemas, dependency locks,
   dependency declarations, rendering assets), each carried in a `.meta.yaml`
   companion with `document_type: reference`. `reconcile-metadata-registry.py`
   (SH-0028) scans the tooling home in addition to `mddocs/scripts/`.
4. **Dedup.** The tooling tree's stock mdBook mermaid assets were redundant with
   the taxonomy-fixed root `mddocs/` mermaid bundle (AC-0013) and were dropped;
   the root bundle remains the single wired source.
5. **Naming.** The `AgenticTeam` default in the tooling is a generic workspace
   role and team-name default, not a reference to this project's identity; it is
   retained as-is and overridden by adopting teams with their own name.

**Consequences:** The classification namespace grows by the new IDs but stays
within the existing kinds. The shipped adoption surface (`allowed_in_adopter_repos:
true`) now includes the toolchain (ADR-0015 D-9). The framework gains a single,
annotated, canonical tooling home.

## Amendment 2026-11-20: reject harness-coupled tooling

**Scope.** Revise the adopted tooling scope: formally reject the team-workspace
provisioning toolchain and git commit guardrail that cannot be made functional
in this framework because they depend on harness assets not present here, and
retain only the self-contained, functional artefacts.

**Decision.**

1. **Rejected (not adopted).** The following were formally rejected as not
   having supporting assets in this framework and were removed from
   `mddocs/management/tooling/`: `scripts/template-deploy.sh`,
   `scripts/team-adopt.sh`, `scripts/adoption_state.py`,
   `scripts/receipt_check.py`, `scripts/create_venv.py`,
   `scripts/install_dependencies.py` and their tests (`SH-0029` through
   `SH-0034`, `SH-0038` through `SH-0043`); the git commit guardrail
   `git-hooks/` (`SH-0037`, `SH-0044`, `SDX-006`); the harness dependency locks
   `python/requirements/` (`REF-0007` through `REF-0009`); and the
   project-protection test-requirements pointer `requirements-test.txt`
   (`REF-0006`), which referenced the rejected harness test lock. These depend
   on a project `pyproject.toml` (whose SHA-256 is pinned in
   `verified-target.json`) and generated lock files that are not part of this
   framework. The classification-ID allocations for these items are withdrawn
   from the metadata standard (§8 and §8.1).
2. **Retained (adopted).** Only the self-contained, functional artefacts remain:
   `SDX-005` (tooling index), `REF-0002` through `REF-0005` (mddoc rendering
   assets and the project-protection profile schema), `SH-0035`/`SH-0036`
   (mdBook validation and build helpers), and `SH-0045`
   (project-protection schema test).
3. **Durable rule.** This rejection follows the Definition-of-Done rule
   (PROCESS.md §4): no harness-coupled, unverifiable capability is adopted or
   shipped as silent technical debt.

**Consequences:** The tooling home ships only self-contained capability that is
functional in this repository. The rejected items remain documented here as a
durable decision so the framework knows they were considered and rejected, and
may be re-evaluated if the harness assets are later made available.
