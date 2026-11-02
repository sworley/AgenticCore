# ADR-0026: Release-Branch Curation Model (git-flow-style)

**Date:** 2026-08-20
**Status:** accepted
**Supersedes:** ADR-0001 (branch-flow portion only — the `feat/* → dev → main → tag → release/*` wholesale flow and the branch-tier purpose table)

## Context

The framework carried two conflicting descriptions of the release workflow:

1. **ADR-0001** described the flow as `feat/* → dev → main → (tag) → release/vX.Y.Z`,
   with `dev` as "active development integration" that merges to `main` wholesale at
   release. Under this reading **`dev` is the release candidate** — everything on `dev`
   ships at the next cutover. Releases v1.0.0–v1.3.0 were cut this way ("merge dev → main
   for vX.Y.Z").

2. **`release-engineer.md`** instructed cutting a `release/vX.Y.Z-prep` branch **from
   `main`**, writing release notes on it, reviewing, then merging prep → `main`. This is a
   curation model, but it was silent on **how work on `dev` reaches the prep branch**.

Two forces made the conflict material:

- **Durability.** Confirmed-valid work should be committed and pushed to `dev` promptly so
  that an inter-session interruption (e.g. loss of laptop access) cannot strand it. Under
  the "dev == release candidate" reading this is unsafe: pushing confirmed-but-not-yet-
  releasable work to `dev` stages half-finished work for the next release.

- **Release cleanliness.** A release should contain only complete, closed work — selected
  deliberately — not "whatever happens to be on `dev` at cutover time."

These are the same realization from two directions: **`dev` should be a safe integration
and durability surface, and releases should be _curated_ from it, not _equal_ to it.**

The constraint that shaped the mechanism: **`main` is append-only / merge-only** (ADR-0004)
— no `rebase`, no `reset`, no history rewrite. Any "catch `dev` up to the release baseline"
step must therefore be a **merge**, never a rebase. `dev` is also shared and pushed (a
consequence of the durability goal), so rebasing `dev` is likewise prohibited.

## Decision

Adopt an explicit **git-flow-style release-branch curation model**, framework-development
scoped. Branch roles become unambiguous:

| Branch | Contains | Role |
|---|---|---|
| `dev` | in-development artifacts (unfinished work, pending backlog) **and** complete tickets awaiting release selection | integration + **durability/backup surface**; **never** the release candidate |
| `release/vX.Y.Z-prep` | cut **from `main`**; only complete, closed tickets' commits **cherry-picked** in | curated release candidate — clean by construction, releasable at any time |
| `main` | tagged baselines only | append-only release history (ADR-0004) |
| `release/vX.Y.Z` | cut from the release tag | preserved release line for later patch work |

**Release cutover sequence:**

```
main (previous release tag baseline, e.g. v1.3.0)
  │
  ├──▶ cut release/vX.Y.Z-prep  FROM main         (starts clean at last release)
  │        ▲
  │        │  cherry-pick ONLY complete/closed tickets' commits (from dev)
  │      dev
  │        │
  │     write release notes on prep; validate; security-reviewer + docs-reviewer
  │        │
  ├──▶ merge prep → main (--no-ff)                (main = new tagged baseline)
  │        │
  │     tag vX.Y.Z from main (annotated)
  │        │
  └──▶ cut release/vX.Y.Z from the tag; push
           │
        merge main → dev (--no-ff)                (catch dev up to release/tag/notes baseline)
```

**Curation mechanic — cherry-pick, not merge-the-feature-branch.** A completed ticket's
feature branch has already been merged to `dev` (via `--no-ff`). To place that ticket on the
prep branch, **cherry-pick the ticket's commits from `dev` onto `release/vX.Y.Z-prep`**. This
keeps the prep branch clean by construction and avoids reintroducing feature branches. Only
tickets that are **complete and closed** are eligible for cherry-pick.

**Catch-up is a merge, never a rebase.** After the release, `main → dev` is merged `--no-ff`
so `dev` shares the release baseline (tag, notes, release commits). `main` is append-only
(ADR-0004); `dev` is shared/pushed — neither may be rebased.

**Task-lifecycle change.** A new terminal state `released` is introduced:

- `merged` — landed on `dev` (integrated, backed up), **not necessarily** release-selected.
- `released` — the ticket's commits were cherry-picked into a release prep branch and shipped
  to `main` under a tag. This is terminal.
- **Closed = complete, never reopened.** A closed/released ticket's work is final; new work
  opens a new ticket.

**Durability rule (now safe).** Because `dev` is explicitly the integration/durability
surface and not the release candidate, HIL-confirmed work is committed and pushed to `dev`
promptly, so an inter-session interruption cannot strand it. This does **not** weaken the
commit/push acceptance gate — the HIL's validation is the trigger for the durability push,
not a bypass of confirmation.

**Framework-development scoped.** Adopters inherit none of this. The `dev`-staging /
release-curation discipline is a framework-development workflow, not an adoption requirement.
The exported baseline, `bootstrap-new-project.md`, and `export-framework.sh` are unchanged by
this decision (see ADR-0015, ADR-0025, and TC-063/FF-2 — adopters run their own branch
strategy).

## Consequences

**Positive:**
- `dev` is a genuine durability surface — confirmed work is backed up promptly and safely,
  addressing the inter-session data-loss concern.
- The release branch is clean by construction; low overhead at cutover; releasable at any
  time because it only ever contains complete, closed work.
- Release contents are deliberately curated, not incidental to what sits on `dev`.
- Reconciles the previously-conflicting ADR-0001 flow and `release-engineer.md` procedure.
- Honors ADR-0004: `main` stays append-only; catch-up is merge-back, never rebase.
- Clear terminal `released` state improves auditability of what actually shipped vs. what is
  merely integrated.

**Negative / Trade-offs:**
- Cherry-picking per-ticket at release time is more deliberate than a single `dev → main`
  merge. Tickets spanning many commits or carrying `--no-ff` merge commits require care
  (cherry-pick the ticket's commit range; use `-m 1` for merge commits where needed).
- Two branch surfaces (`dev` integration vs. prep curation) is more model to hold than a
  single staging branch.
- A ticket present on `dev` but not yet complete must be excluded from a release by simply
  not being selected — discipline is required to track completeness accurately (the
  `merged` vs. `released` distinction exists precisely to make this explicit).

**Neutral:**
- Prior releases (v1.0.0–v1.3.0) were cut under the wholesale model; they remain valid — this
  ADR governs releases from v1.4.0 forward.
- `release-engineer.md` already cut prep from `main`; this ADR fills the previously-missing
  "how dev work arrives on prep" step (cherry-pick) rather than reversing that procedure.

## Implementation Notes

- **Supersedes** the branch-flow portion of ADR-0001: its `feat/* → dev → main → (tag) →
  release/*` flow line and the branch-tier purpose table are replaced by the model above.
  ADR-0001 remains authoritative for the rest of the bootstrap architecture.
- **AGENT.md** — the "dev is the staging branch" standing rule is reframed to "dev is the
  integration + durability surface; releases are curated onto `release/*-prep` from `main`,"
  and the durability push rule is added.
- **PROCESS.md** — §4 gains the `released` terminal state and the closed-never-reopened rule;
  §5 documents the cherry-pick curation mechanic and the merge-back catch-up.
- **release-engineer.md / baseline-steward.md** — the release sequence makes the
  cherry-pick-complete-tickets-from-`dev` step and the `main → dev` merge-back explicit.
- **ADR-0004** is the binding constraint for the no-rebase / merge-back requirement.
- **ADR-0015 / ADR-0025** — this decision is framework-dev scoped and does not alter the
  adopter distribution or write-protection models.

## Addendum — 2026-08-21: All-Selected Merge Mechanic

This ADR prescribes **cherry-pick-per-ticket** as the literal curation mechanic (see
Decision, above). That remains correct and required whenever `dev` holds a **mix** of
release-selected and unselected/in-development work — a wholesale `merge dev` in that
situation would pull unselected work onto the release, violating the curation guarantee.

**HIL decision (2026-08-21, during the v1.4.0 cut).** Adopt an explicit standard mechanic
for the common **all-selected clean case** — where every commit on `dev` since the last
release belongs to a release-selected (complete/closed) ticket. In that case, instead of
replaying each ticket's commits individually, cut `release/vX.Y.Z-prep` from `main` and
then `git merge --no-ff dev`. This produces a prep tree identical to `dev`, preserves
per-ticket commit history for audit, and avoids the conflict risk of replaying 20+
interdependent commits (including `-m 1` merge commits) for zero payload difference.

**The discriminator (selection rule) chooses the mechanic:**

- All commits on `dev` since the last release are release-selected → `merge --no-ff dev`
  into prep.
- `dev` holds a mix (some tickets not release-selected) → cherry-pick only the selected
  tickets' commits (the original mechanic; strictly preserved).

**Precondition check for the merge path.** Before choosing merge, confirm every commit in
`origin/main..dev` maps to a release-selected (complete/closed) ticket. If any commit
belongs to unselected/in-development work, cherry-pick must be used instead.

**Note.** v1.4.0 was the first release cut under this ADR and used the all-selected merge
mechanic (verified: no unselected work was present on `dev` at cutover).

This addendum is framework-development scoped; no adopter surface.
