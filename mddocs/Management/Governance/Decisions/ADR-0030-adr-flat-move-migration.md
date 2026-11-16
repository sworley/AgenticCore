# ADR-0030: Flat-Move ADR Relocation (D1/D2 implementation)

**Date:** 2026-11-15
**Status:** proposed
**Supersedes:** —
**Superseded by:** —
**Authorizes:** the physical `git mv` of the historical ADR set (ADR-0029 D1/D2)

## Context

ADR-0029 (accepted 2026-11-12) adopted the documentation and knowledge taxonomy
and deferred the physical relocation of the 28 historical ADRs to a **future
migration ADR**:

- **D1 (forward-only):** new ADRs use `mddocs/Management/Governance/Decisions/`
  from approval onward; the historical ADRs stay in `mddocs/adr/`.
- **D2 (directed coexistence):** both index files are live
  (`mddocs/adr/index.md` as `primary: false, lifecycle: superseded`;
  `mddocs/Management/Governance/Decisions/index.md` as `primary: true`).

This period of dual-index coexistence is now in effect (ADR-0029 was accepted on
2026-11-12; its D4–D8 frontmatter and companion stubs were landed on
2026-11-15). This ADR governs the physical relocation that collapses the dual
index into one canonical home. The ADR numbering is a **flat global sequence
independent of physical location** and does not change.

The migration is link-sensitive. A Q2 link-integrity audit (Appendix A) and a Q1
ADR-internal path-reference audit (Appendix B) establish the baseline. The
framework's link checker is `mddocs/scripts/check-links.sh`; the docs hook
`mddocs/scripts/update-summary-on-adr-write.py` hardcodes the old ADR directory.

## Decision

Perform a **flat-move relocation** of the historical ADR set:

1. `git mv` each file from `mddocs/adr/adr-NNNN-<slug>.md` to
   `mddocs/Management/Governance/Decisions/adr-NNNN-<slug>.md`, preserving
   filenames, ADR IDs, and content.
   - Set covered: `adr-0001` … `adr-0028`, plus the template
     `adr-0000-template.md`.
2. **Collapse the dual index:** make
   `mddocs/Management/Governance/Decisions/index.md` the single live index.
   Remove `mddocs/adr/index.md` and the now-empty `mddocs/adr/` directory.
   (The active index already carries `records: ADR-0029 onward`; after the move
   it lists the full historical + current sequence.)
3. **Update every internal link** that points at `mddocs/adr/` to the new
   prefix `mddocs/Management/Governance/Decisions/`:
   - `mddocs/SUMMARY.md` mdBook nav entries (29–30 entries);
   - cross-references across the corpus (Appendix A);
   - `mddocs/scripts/update-summary-on-adr-write.py` (the `adr_dir` path and the
     match glob `mddocs/adr/adr-*.md`).
4. **No other content changes.** Preserve ADR numbering, metadata, and the
   frontmatter contract. Do not convert ADRs to package folders (deferred).

**Out of scope:** script physical restructuring (D4), `Projects/` seeding (Q5),
and any change to ADR-0015 (adoption model).

## Consequences

**Positive:**
- One canonical ADR home; the dual-index coexistence and its `primary`/`redirect`
  bookkeeping are retired.
- Consistent with D1 (forward-only) and the taxonomy's P4 (stable IDs) / P5
  (packages, at the file level here).
- Flat move keeps filenames and IDs stable, so link edits are prefix-only and
  low-risk; `git mv` preserves history.

**Negative / Trade-offs:**
- One-time churn across ~94 references in ~32 files, dominated by `SUMMARY.md`
  (29–30 entries) and the docs hook.
- The `update-summary-on-adr-write.py` hook path must be updated in the same
  change, or future ADR entries will be inserted into a stale location.
- The relocation is link-sensitive and must be validated (link check + mdbook
  build) in the same PR.

**Neutral:**
- ADR numbering is unchanged; the flat global sequence continues (next number
  already allocated to this ADR).
- No impact on the adopter contract (ADR-0015) or on `export-framework.sh`
  behavior (ADR-0029 D4 note that `mddocs/adr` ships; it still ships, at the new
  path).

## Implementation Notes

1. `git mv` all `mddocs/adr/adr-*.md` → `mddocs/Management/Governance/Decisions/`.
2. Update `mddocs/SUMMARY.md` ADR entries and the nav section header.
3. Update cross-references across the corpus (regex: `mddocs/adr/` → new prefix;
   relative links resolved accordingly).
4. Update `mddocs/scripts/update-summary-on-adr-write.py` (`adr_dir`,
   match glob).
5. Remove `mddocs/adr/index.md`; update `Management/Governance/Decisions/index.md`
   `records` to span ADR-0000 through ADR-0030.
6. Delete the now-empty `mddocs/adr/` directory.
7. Validate: `mddocs/scripts/check-links.sh`, `mdbook build mddocs`, and grep
   for any residual `mddocs/adr/` references.
8. **Rollback:** the change is link/metadata-only; revert is `git mv` back plus
   restoring `SUMMARY.md`, the hook path, and the historical index.

---

## Appendix A — Link-integrity audit (Q2 baseline)

Audited 2026-11-15 (pre-migration):

- **94 references** to ADR paths (`mddocs/adr/…` or relative `adr/…`) across
  **32 files**.
- **`mddocs/SUMMARY.md`** carries **29–30** ADR navigation entries (largest
  surface).
- **`mddocs/scripts/update-summary-on-adr-write.py`** hardcodes the ADR directory
  in 2 places (`adr_dir = project_root + "/mddocs/adr/"`, glob
  `mddocs/adr/adr-*.md`).
- Other affected docs (by reference count):
  `ACT-DKT-0002` (6), `.core/invariants.md` (5),
  `mddocs/examples/adr-decision-process.md` (4), `ADR-0029` (4),
  `AgenticCore-Documentation-Knowledge-Taxonomy-Proposal.v4.md` (4),
  `mddocs/adr/index.md` (3), `mddocs/AGENTICCORE_SPEC.md` (3),
  `README.md` (3), `CONTRIBUTING.md` (3), plus minor references in
  `mddocs/scripts/update-summary-on-adr-write.py`,
  `mddocs/scripts/setup/adopt.sh`, `mddocs/scripts/export-framework.sh`,
  `mddocs/reference.architecture/release-process.md`,
  `.opencode/agents/docs-engineer.md`, and others.

## Appendix B — Q1 ADR-internal path-reference audit

Filesystem path references **inside** ADR bodies (to `mddocs/`, `_config/`,
`mddocs/scripts/`, `.core/`, `.agents/`, `reference.architecture/`):
`adr-0019` (21), `adr-0001` (16), `adr-0002` (13), `adr-0021` (7),
`adr-0012` (6), `adr-0009` (5), `adr-0027` (4), `adr-0024`/`adr-0017`/`adr-0013`/
`adr-0003` (3 each), `adr-0014`/`adr-0005` (2 each), and 1 each for the remainder.

**Finding:** the Q1 hypothesis that `adr-0026` contains breaking path references
did **not** materialize — `adr-0026` has **zero** such references. Most ADR-internal
references point at code/config paths that **do not move** in this migration
(`scripts/`, `.core/`, `.agents/`, `_config/`), so they are unaffected by the ADR
relocation. The migration's link exposure is concentrated in external links
**to** the ADR files (SUMMARY + cross-refs), as captured in Appendix A.
