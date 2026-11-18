# ADR-0030: Forward-Only ADR Adoption and Historical Coexistence

**Date:** 2026-11-16
**Status:** accepted
**Supersedes:** - (resolves the "future migration ADR" placeholder)
**Superseded by:** -
**Governed by:** ADR-0029 (D1/D2) - this is the focused record of that resolution

## Context

ADR-0029 (accepted 2026-11-12) adopted the documentation and knowledge taxonomy
and resolved ADR placement as **D1 (forward-only)** and **D2 (directed
coexistence)**:

- **D1:** new ADRs use `mddocs/management/governance/decisions/` from approval
  onward; the existing 28 ADRs remain in `mddocs/adr/`.
- **D2:** both index files are live, with the new index `primary: true` and the
  historical index `primary: false, lifecycle: superseded` carrying a `redirect`.

This ADR records the chosen resolution and **closes the question** of whether the
historical ADRs will be physically relocated.

## Decision

1. **No physical migration.** The existing 28 ADRs remain at
   `mddocs/adr/adr-NNNN-<slug>.md` indefinitely as the canonical historical
   record. They are **not** moved to `management/governance/decisions/`.
2. **Forward-only.** Every new ADR from ADR-0029 onward is placed in
   `mddocs/management/governance/decisions/`.
3. **Coexistence with primary/redirect.** Both index paths remain live:
   `management/governance/decisions/index.md` is `primary: true` (active);
   `mddocs/adr/index.md` is `primary: false, lifecycle: superseded` and
   `redirect`s to the active index.
4. **Flat global sequence.** ADR numbering is a single flat sequence
   independent of physical location.
5. **Future relocation is a new decision.** If a future relocation of the
   historical ADRs is ever warranted, it will be made via a new ADR through the
   HIL process - not assumed or pre-committed here.

## Consequences

**Positive:**
- Existing ADRs and all their links are left untouched (no churn, no breakage).
- The historical set remains discoverable in its canonical location.
- The forward-only rule is clear and self-contained; no placeholder work exists.

**Negative / Trade-offs:**
- Two index files coexist; readers must understand `primary`/`redirect` to find
  the active index.
- ADRs referencing `mddocs/adr/` paths stay valid only because those paths are
  unchanged.

**Neutral:**
- ADR numbering is unchanged (flat global sequence).
- No impact on ADR-0015 (adoption model) or `export-framework.sh`.

## Implementation Notes

- Active index: `management/governance/decisions/index.md` lists ADRs from
  ADR-0029 onward.
- Historical index: `mddocs/adr/index.md` retains the ADR-0000…0028 set with
  `redirect`.
- **No** `git mv`, index collapse, or link rewrite is performed.
