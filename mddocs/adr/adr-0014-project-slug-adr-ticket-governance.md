# AC ADR-0014: Project Task Slug and ADR Ticket Governance

**Date:** 2026-07-02
**Status:** Accepted
**Supersedes:** —
**Superseded by:** —

## Prior Art

EXAMPLE ADR-0015 (Program-Level Task Governance and Unified Slug, 2026-05-06).
This ADR generalizes the `EXAMPLE-` slug pattern established in the example-project
program to a framework-level onboarding convention applicable to any project
adopting AgenticCore.

---

## Context

AgenticCore is a portable framework adopted by projects with independent
identities, team structures, and source control namespaces. Two gaps were
identified during the TC-0020 ADR provenance audit (2026-07-02):

**Gap 1 — Slug fragmentation.** Projects that adopt the framework have no
defined convention for naming tasks, branches, or tickets. Without a declared
slug, task IDs across projects collide, cross-project references are ambiguous,
and agentic commit discipline has no stable anchor. The framework itself
currently uses three-digit IDs (`TC-001`) while ADRs use four-digit numbers
(`ADR-0001`) — an inconsistency that adds friction.

**Gap 2 — ADR lineage loss.** When a new project is initialized from a
predecessor (as AC was built from patterns incubated in EXAMPLE), all reference
to the predecessor's architectural lineage is severed at project creation.
Future stewards reading an ADR have no way to trace its origins or the
operational experience that shaped it.

A third requirement emerged during the same audit: a cross-project citation
format is needed so that projects can reference each other's decisions and
tickets in release notes, commit messages, and documentation without ambiguity.

---

## Decision Drivers

- Every task, branch, commit, and ADR ticket must be unambiguously traceable
  to a specific project without reading surrounding context
- ADR and task IDs must use a consistent digit count across all ID types
- ADRs must support being referenced as tickets in any Git hosting platform
  (Git, GitHub, Azure DevOps, or equivalent)
- New projects must declare their slug at initialization — not retroactively
- Predecessor ADR lineage must be preserved as a permanently accessible record
- Cross-project citations must be unambiguous and self-identifying

---

## Decisions

### D-1: Project task slug — `<PROJECT>-NNNN`

Every project adopting AgenticCore declares a short, uppercase slug at
initialization. The slug is derived from the project's canonical name or
program identifier. Format: uppercase ASCII letters only, no spaces or special
characters, hyphen-separated from the four-digit sequence number.

Examples:
- `TC-0017` — AgenticCore framework (this project)
- `EXAMPLE-0183` — example-project program (existing, unchanged)
- `ACME-0001` — hypothetical adopter project

The slug is declared in three places on day one:
- `AGENT.md` — `## Project Slug` section (visible to all agents at session open)
- `tasks.yaml` — `slug:` field in the file header block
- `PROCESS.md` — branch naming example updated to use the active slug

Slug selection criteria (guidance for new projects):
- Short: two to six uppercase letters preferred
- Derived from the canonical program or project name, not a team or person name
- Unique within the organization's portfolio of AC-adopting projects

Slugs are permanent for the life of a project. Renaming a slug requires a
new ADR documenting the migration mapping and rationale.

> **Note:** Slug initialization procedure is defined in ADR-0015 D-5 —
> the slug is prompted and written by `export-framework.sh` during project
> initialization, before the first commit.

---

### D-2: Four-digit IDs universally

All sequence numbers across all ID types in AgenticCore-governed projects
use four digits: `TC-0001`, `AC ADR-0001`. No exceptions.

Current three-digit IDs in `tasks.yaml` (`TC-001` through `TC-020`) are
migrated to `TC-0001` through `TC-0020` as an implementation task spawned from
this ADR. ADR filenames and numbers already use four digits — no change
required for ADRs.

---

### D-3: Git is required; platform is not prescribed

Every project governed by AgenticCore requires a Git repository. Commit
discipline, branch naming, and ADR ticket linkage all depend on Git being
the authoritative source of record.

The specific hosting platform (Git, GitHub, Azure DevOps, or a self-hosted
equivalent) is not prescribed by the framework. ADR references, slug prefixes,
and ticket linkage formats are platform-agnostic.

> **Resolved — see ADR-0015:** Distribution model is export + git init
> (ADR-0015 D-1). Git is required; hosting platform is adopter's choice.
> AI toolchain / OpenCode on a AI toolchain-compatible API is the second hard
> requirement (ADR-0015 D-2). No AC history is present in adopter repos.

---

### D-4: ADR as a tracked ticket type

An ADR is a first-class ticket in the project's issue tracker, referenced as
`<PROJECT> ADR-NNNN`. Example: `AC ADR-0014`.

The ADR ticket is the decision anchor — an Epic-equivalent that owns the
architectural decision and links to child implementation tickets:

- **ADR ticket** (`AC ADR-0014`) — the decision record; follows the ADR
  template; status tracks the ADR lifecycle (`proposed` → `accepted` →
  `superseded`)
- **Child tickets** (`AC-NNNN`) — implementation tasks spawned from the ADR's
  Implementation Notes; linked to the parent ADR ticket

The ADR document in `mddocs/adr/` is the written record. The ADR ticket in
the issue tracker is the work-tracking anchor. Both are required for an ADR
to be considered complete when a hosted issue tracker is available.

For local-only or pre-tracker installations, the ADR document alone suffices
until the issue tracker is configured; the ticket reference field is left blank.

---

### D-5: Prior Art section in ADRs

Every ADR that derives from or was informed by a predecessor project's ADR
must include a `## Prior Art` section immediately after the document header,
before `## Context`. Format:

```
## Prior Art

<PROJECT> ADR-NNNN (<Short Title>, <Date>). <One sentence describing what
was generalized, adapted, or superseded.>
```

Multiple Prior Art entries are allowed. This section is the permanent
cross-project lineage record — it does not imply the predecessor ADR is
equivalent, only that its operational experience informed this decision.

The ADR-0000 template is updated to include this section (blank by default,
with instructions to populate when a predecessor exists).

---

### D-6: Cross-project citation format

When any project document (release notes, commit message, ADR, runbook)
references a decision or ticket from another AC-adopting project, the
canonical citation format is:

- **ADR reference:** `<PROJECT>-ADR-NNNN`  — e.g., `EXAMPLE-ADR-0015`, `AC-ADR-0014`
- **Ticket reference:** `<PROJECT>-NNNN` — e.g., `EXAMPLE-0183`, `TC-0020`

Each project is responsible only for its own ADR and ticket history. A cross-
project citation is a read-only reference — the citing project does not own
or update the cited artifact. Slug uniqueness (D-1) is the load-bearing
requirement for citations to remain unambiguous.

This convention applies in:
- `mddocs/release-notes/` — cross-project feature provenance
- Commit messages — when implementing a feature ported from another project
- ADR `## Prior Art` sections (D-5)
- `tasks.yaml` `note:` fields when a task originates from a cross-project request

---

## Consequences

**Positive:**
- All task references in commits, branches, agent logs, and ADR documents are
  unambiguous across projects
- ADR lineage is preserved as a forward-accessible record in every ADR that
  has a predecessor
- The ADR-as-Epic model gives hosted projects a structured way to track
  architectural decisions with implementation children
- Four-digit IDs eliminate the three/four-digit inconsistency in current AC
  artifacts
- Cross-project citations are self-identifying — no lookup required to
  determine which project owns a referenced ticket

**Negative / Trade-offs:**
- Existing `tasks.yaml` files with three-digit IDs require a migration pass.
  All `blocked_by:` references, branch names in notes, and related commit
  message patterns must be updated. Mechanical but non-trivial.
- Slugs are permanent. A poorly chosen slug (too generic, too long) creates
  friction for the project's lifetime. Onboarding guidance must include
  selection criteria.
- Slug uniqueness is a convention, not a technical enforcement. Organizations
  with many AC-adopting projects may need a lightweight slug registry to
  prevent collisions. This is deferred to ADR-0015.

**Neutral:**
- Projects without an issue tracker skip D-4 (ticket linkage) without
  violating D-1, D-2, D-5, or D-6. The framework is not platform-dependent.

---

## Implementation Notes

The following tasks are spawned from this ADR:

1. **Migrate AC `tasks.yaml`** — rename `TC-001` through `TC-020` to
   `TC-0001` through `TC-0020`; update all `blocked_by:` references
2. **Add `slug: AC` header block to `tasks.yaml`**
3. **Add `## Project Slug` section to `AGENT.md`** — value: `AC`
4. **Update ADR-0000 template** — add `## Prior Art` section (blank default
   with fill instructions)
5. **Backfill Prior Art sections** — AC ADR- through ADR-0011 have direct
   EXAMPLE predecessors; add one-line Prior Art entries to each
6. **Update `PROCESS.md`** — branch naming example to use `AC-NNNN` format
7. **Update `getting-started.md`** — add slug declaration step (procedure
   deferred until ADR-0015 defines the onboarding flow)

All items are unblocked. ADR-0015 is accepted; D-3 and D-5 are resolved.

---

## Related

- [ADR-0001: Bootstrap Architecture](adr-0001-bootstrap-architecture.md)
- [ADR-: AI toolchain Profile Inheritance](adr-0009-agent-portability-model.md)
- [ADR-0013: Pattern A — Two-Flavor Model](adr-0013-pattern-a-two-flavor-model.md)
- [ADR-0015: Framework Distribution and Adoption Model](adr-0015-framework-distribution-adoption-model.md) — open question in D-3 and D-5
- `EXAMPLE-ADR-0015` — Prior art: Program-Level Task Governance and Unified Slug
