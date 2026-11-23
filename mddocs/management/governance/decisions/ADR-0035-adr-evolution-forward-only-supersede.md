# ADR-0035: ADR Evolution - Forward-Only Supersede and Historical Coexistence

**Date:** 2026-11-20
**Revised:** 2026-11-21 (scope forward-only supersede to released records; add pre-release correction allowance)
**Status:** accepted
**Supersedes:** ADR-0030 (and the ADR-placement resolution made in ADR-0029 D1/D2)
**Superseded by:** -
**Governed by:** ADR-0029 (D1/D2 placement resolution, carried forward here)

## Context

ADR-0029 (accepted 2026-11-12) adopted the documentation and knowledge taxonomy and
resolved ADR placement as D1 (forward-only) and D2 (directed coexistence). ADR-0030
(accepted 2026-11-16) recorded that resolution in a focused record and closed the
question of physical relocation.

In practice, the harness later revised accepted ADRs in place using **amendments /
addendums** (ADR-0012, ADR-0015, ADR-0021, ADR-0026, ADR-0032, ADR-0034). This
fragments the governing record for a decision, so a reader cannot tell at a glance
what governs today, and it blocks clean consolidation: a decision that has accrued
amendments has no single, self-contained statement of the current decision.

This ADR restates the ADR evolution convention as a single, enforceable rule -
**forward-only supersede** - and carries forward the ADR-placement resolution from
ADR-0029 D1/D2 and ADR-0030, so the convention lives in one clean record.

The convention must also be consistent with the harness's release model. The
harness is developed on feature branches, integrated and validated on the `dev`
branch, and only released to `main` when it is production ready. A decision
becomes binding to the shipped harness only when it is released. Until then, it
is still being decided, so correcting it in place is part of development and must
not trigger the overhead of a supersession. This ADR records that distinction
explicitly.

## Decision

### D1 - Two epochs: pre-release correction, released supersede

A decision is **released** when its record is present on the `main` release branch
and is part of a shipped harness. Before release, the record exists only in the
`dev` integration branch or a feature branch.

- **Pre-release.** While the record has not shipped to `main`, it may be
  **corrected in place** as part of development. A correction is recorded with an
  `**Revised:** <date>` metadata line and a short note in the body, so the change
  is auditable. No superseding ADR is required, because a decision that has not
  shipped cannot meaningfully be superseded - it is still being decided. This
  avoids the inefficiency of superseding a decision before it is released.
- **Released.** Once the record is on `main`, its text is never edited. Any
  subsequent change - additive, revisionary, or a reversal - produces a **new**
  ADR that `supersedes` the prior one, with explicit `Supersedes` / `Superseded by`
  linkage.

The superseding ADR is the single, complete source of truth from that point
forward: it **embodies** the substance of the decision it supersedes, rewritten
clean rather than pasted, so the prior ADR's file is not needed to understand the
current decision.

### D2 - No in-place amendment / addendum / modify (after release)

After release, accepted ADR text is never edited in place. The terms **Amendment**,
**Addendum**, and **Modify / Revise** describe the *intent* of a change to a
released decision; they are never a license to edit a released record. All three
intents resolve to a new superseding ADR.

The only allowed metadata transition on a released ADR is its lifecycle status:
`accepted` -> `superseded`, recording `Superseded by: <new ID>`.

Before release, in-place correction is permitted under D1. A pre-release record
corrected in place carries `Revised:` metadata and is not treated as a
supersession.

### D3 - Supersession ledger

Every released ADR that is superseded is recorded in a single, machine-checked
ledger at `mddocs/management/governance/decisions/supersession-ledger.yaml`, the
authoritative record of every supersedence. The `reconcile-metadata-registry.py`
gate validates the ledger, so a supersession cannot be recorded inconsistently or
dropped silently. See the field contract and the retire-and-remove gate in
`AGENTICCORE_SPEC.md` (ADR Lifecycle / Supersession Ledger).

### D4 - Retire-and-remove gate

Removing a superseded ADR file from the tree is a governed act. A prior ADR is
retired and removed only when every condition holds:

1. The superseding ADR records `Supersedes: <retired ID>` and is `accepted`.
2. The superseding ADR genuinely embodies the retired decision - no governing
   constraint is silently dropped. Every constraint either carries forward, or is
   explicitly `waived` in the ledger entry with a written rationale (the accept or
   waive decision).
3. The ledger entry records `retired: true` and a `retired_git_ref`, and passes the
   `reconcile` gate.
4. For a significant decision, a security pass and HIL LGTM precede the removal.
5. The retired ADR's row is removed from the active index, cross-references are
   repointed, and `check-links` / `mdbook build` stay green.

No agent - including lead-engineer - may remove a superseded ADR until this gate is
satisfied.

### D5 - Placement and historical coexistence (carried from ADR-0029 D1/D2 + ADR-0030)

- New ADRs are placed in `mddocs/management/governance/decisions/`.
- The existing 28 ADRs remain in `mddocs/adr/` indefinitely as the canonical
  historical record; no physical migration is planned.
- Both index paths remain live: `management/governance/decisions/index.md` is
  `primary: true` (active); `mddocs/adr/index.md` is `primary: false`,
  `lifecycle: superseded` and `redirect`s to the active index.
- ADR numbering is a single flat global sequence independent of physical location.
- Future relocation of the historical ADRs is a new decision via a new ADR through
  the HIL process - not assumed or pre-committed here.

## Consequences

**Positive:**

- The convention is consistent with the harness's development and release model:
  improve and correct in `dev`, freeze on `main`.
- A decision is not superseded before it ships, so pre-release improvements do not
  incur supersession bookkeeping, and the record stays single and self-contained.
- The forward-only rule remains enforceable once a decision is actually binding.
- Consolidation is possible: a released decision that accrued in-place amendments
  can be recreated as one clean ADR that supersedes the old record(s).
- The supersession ledger makes the accept/waive gate enforceable rather than
  aspirational, so a retired decision is provably replaced and nothing is silently
  dropped.

**Negative / Trade-offs:**

- A clear definition of released (present on `main`) is required; the model is
  slightly more nuanced than a blanket "never edit accepted text."
- Two index files coexist during the historical-transition period; readers must
  understand `primary` / `redirect` to find the active index.
- A superseding ADR must be complete and self-contained, so it may be longer than a
  minimal amendment - this is the price of a single source of truth.

**Neutral:**

- ADR numbering is unchanged (flat global sequence).
- ADR-0029 remains the documentation-taxonomy adoption decision; only its D1/D2
  placement resolution is carried forward here.
- No impact on ADR-0015 (adoption model) or `export-framework.sh`.

## Implementation Notes

- This revision is itself a pre-release correction (ADR-0035 is present only on the
  `dev` branch and has not shipped to `main`), so it is made in place with a
  `Revised:` metadata line rather than as a supersession.
- Active index: `management/governance/decisions/index.md` marks ADR-0030 as
  `superseded` (by ADR-0035) and lists ADR-0035 as the governing record.
- Supersession ledger: `management/governance/decisions/supersession-ledger.yaml`
  records the ADR-0030 -> ADR-0035 transition with `retired: false` (removal is
  gated on ADR-0035 reaching `accepted`).
- **No** `git mv`, index collapse, or link rewrite of the historical set is
  performed in this change.
