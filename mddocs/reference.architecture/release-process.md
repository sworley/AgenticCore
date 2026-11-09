# Runbook: Release Process

**Owner / gate:** baseline-steward
**Tactical execution:** release-engineer
**Triggered by:** Explicit task from lead-engineer; the framework release is owned and
gated by baseline-steward and executed by release-engineer
**Requires:** HIL approval at every numbered gate below

---

## Scope & Ownership

This runbook defines the **AgenticCore framework release** flow (the curated release
baseline). Ownership is split:

- **baseline-steward** owns and gates the release (versioning, scope curation, adopter
  impact classification, propagation guidance, the security/docs gates, and the HIL
  surface for every gate G-1..G-8).
- **release-engineer** executes the tactical git mechanics (cut prep branch,
  cherry-pick/merge curated commits, create/push the tag, cut the release branch, update
  README as-built) **under** baseline-steward's tasking — `HIL → baseline-steward →
  release-engineer`.

Adopter-project releases use the same mechanics but are owned by the `lead-engineer` and
executed by `release-engineer`; they are out of scope for this runbook.

---

## Repository-Specific Mechanics (branch-protected repos)

On a branch-protected host (e.g. GitHub with PR-only `main`/`dev`, signed commits, and a
required `verify` CI check), the git writes below are performed via **pull requests**, not
direct pushes. The gates are unchanged; the PR merge is the mechanism:

- **G-5** — push `release/vX.Y.Z-prep` and open a PR → `main`; merge on HIL LGTM + CI green.
- **G-7** — push the `release/vX.Y.Z` branch and open a PR → `main`.
- **G-8** — update the README as-built on a branch and open a PR → `main`.
- **Release close** — mark the scoped tickets `released` (terminal, ADR-0026), then catch
  `dev` up by opening a PR `main → dev` (`--no-ff`, never rebase — `main` is append-only per
  ADR-0004). Verify: `git merge-base --is-ancestor main dev`.

**First release bootstrap.** Before the first release under this model there are no tags,
so `git describe --tags` (Step 1) fails. Establish the baseline tag first:

```sh
git tag -a vX.Y.Z -m "baseline: vX.Y.Z" <current-main-sha>
git push origin vX.Y.Z
```

**Before merging `main` into a catch-up branch, `git pull origin main` first** — using a
stale local `main` leaves `dev` behind the as-built baseline. Verify the catch-up with
`git merge-base --is-ancestor main dev` after the PR is merged.

---

## Prerequisites

- All tickets scoped to this release are at `status: merged` in `tasks.yaml`
- No `in_progress` items remain on the release scope
- `main` is clean and up to date: `git status` + `git log origin/main..HEAD`
- `mdbook build mddocs/` exits 0 locally
- Release version proposed and confirmed by HIL

---

## Release Gates Summary

Every gate below requires its own explicit HIL confirmation. No prior LGTM
covers a subsequent gate.

| Gate | Action | Requires |
|---|---|---|
| G-1 | Version confirmed | HIL verbal confirmation |
| G-2 | Release prep branch created | baseline-steward task |
| G-3 | Release notes written (incl. adopter impact section) | security-reviewer APPROVED |
| G-4 | Release notes reviewed | HIL LGTM |
| G-5 | Merge prep → main | HIL LGTM |
| G-6 | Tag created and pushed | HIL explicit confirmation |
| G-7 | Release branch cut and pushed | HIL explicit confirmation |
| G-8 | README as-built updated | HIL LGTM |

---

## Procedure

### Step 1 — Propose version (G-1)

Collect evidence for the version bump:
```sh
# Commits since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# ADRs accepted since last release
grep -l "Status: accepted" mddocs/adr/*.md
```

Present to baseline-steward and HIL:
> "Proposed: vX.Y.Z — reason: [MAJOR/MINOR/PATCH justification]. Last release: vA.B.C."

Wait for explicit HIL confirmation of the version number before proceeding.

### Step 2 — Create release prep branch (G-2)

```sh
git checkout main
git pull origin main
git checkout -b release/vX.Y.Z-prep
```

**How `dev` work arrives on prep.** ADR-0026 and its 2026-08-21 addendum define two
mechanics; a precondition check chooses between them:

1. **Precondition check:** enumerate `git log origin/main..dev --oneline` and confirm
   whether every commit maps to a release-selected (complete/closed) ticket.
2. **All-selected path** — every commit on `dev` since the last release belongs to a
   release-selected ticket:
   ```sh
   git merge --no-ff dev
   ```
3. **Mixed path** — `dev` holds any unselected/in-development commits: cherry-pick only
   the selected tickets' commit ranges (use `-m 1` for `--no-ff` merge commits):
   ```sh
   git cherry-pick <ticket-commit>..<ticket-commit>
   # or, for a --no-ff merge commit on dev:
   git cherry-pick -m 1 <merge-commit-sha>
   ```

See [ADR-0026](../adr/adr-0026-release-branch-curation-model.md) and its Addendum —
2026-08-21 for the full discriminator rationale.

### Step 3 — Write release notes (G-3)

Create `mddocs/release-notes/vX.Y.Z.md` using the template at
`mddocs/reference.architecture/release-notes-template.md`.

Sources to consolidate:
- `git log <last-tag>..HEAD --oneline` — all commits in scope
- `tasks.yaml` — all `merged` tickets since last release. Only release-**selected**
  (complete/closed) tickets are in scope for the release, consistent with the curation
  model; the mechanic used to land them on prep (merge vs. cherry-pick) is chosen per the
  Step 2 discriminator and does not change what is in scope here.
- `mddocs/adr/` — all ADRs with `Status: accepted` since last release
- `.core/work/session-state-*.md` — session notes for context

**Security gate before proceeding:**
Request security-reviewer pass on all release artifacts:
> "Requesting security-reviewer pass on release/vX.Y.Z-prep branch."

Do not proceed until `SECURITY REVIEW VERDICT: APPROVED` is received.

**Note:** Complete the adopter impact classification in Step 3.5 before requesting
the security-reviewer pass. If any `Required` items are security fixes, include the
migration notes in the security-reviewer scope.

### Step 3.5 — Adopter impact classification

Complete before Step 3's security-reviewer pass. Classify each change as one of:

| Class | Meaning |
|---|---|
| **Transparent** | Internal improvement; no adopter-visible interface changed |
| **Optional** | New capability; existing adopter behavior unchanged |
| **Required** | Breaking change or security fix; adopters on prior release are affected |

Add a section to the release notes:

```markdown
## Adopter Impact

| Class | Items |
|---|---|
| Required | <list or "none"> |
| Optional | <list or "none"> |
| Transparent | <remaining changes> |
```

If any `Required` items are present, include a **Migration Notes** subsection with
explicit steps for adopters to reconcile. Do not mark the release ready until
migration notes are written for every `Required` item.

See [Adopter Reconciliation Model](adopter-reconciliation.md) for the full
propagation policy.

### Step 4 — Commit release notes

```sh
git add mddocs/release-notes/vX.Y.Z.md
git commit -m "docs: release notes for vX.Y.Z [AP-NNN]"
```

Present staged diff to baseline-steward. Relay to `.01` for HIL surface.

### Step 5 — HIL review of release notes (G-4)

Wait for HIL LGTM on the release notes content specifically.
This gate covers the notes only — not the merge.

### Step 6 — Merge prep branch to main (G-5)

Confirm with HIL: *"Ready to merge release/vX.Y.Z-prep to main. Branch: release/vX.Y.Z-prep. Confirm?"*

On explicit HIL confirmation:
```sh
git checkout main
git merge --no-ff release/vX.Y.Z-prep \
  -m "release: merge vX.Y.Z release notes to main [AP-NNN]"
git push origin main
```

### Step 7 — Create and push annotated tag (G-6)

Confirm with HIL: *"Ready to tag vX.Y.Z from main at SHA [sha]. Confirm?"*

On explicit confirmation:
```sh
git tag -a vX.Y.Z -m "release: vX.Y.Z"
git push origin vX.Y.Z
```

### Step 8 — Cut release branch (G-7)

Confirm with HIL: *"Ready to cut release/vX.Y.Z from tag vX.Y.Z. Confirm?"*

On explicit confirmation:
```sh
git checkout -b release/vX.Y.Z vX.Y.Z
git push origin release/vX.Y.Z
git checkout main
```

### Step 9 — Update README as-built (G-8)

Update `README.md` as-built table — mark prior release `superseded`, add new entry.

Commit:
```sh
git add README.md
git commit -m "docs: update README as-built for vX.Y.Z [AP-NNN]"
git push origin main
```

Confirm with HIL before push.

### Step 10 — Relay completion

Write relay note to `.core/work/relay-pending.md`:

```markdown
## Relay pending — YYYY-MM-DD

**Destination:** .01 / baseline-steward
**Request:** Mark release ticket AP-NNN as released
**Detail:** vX.Y.Z released. Tag pushed. Branch release/vX.Y.Z cut.
            README as-built updated. All gates passed.
```

Commit relay note:
```sh
git add .core/work/relay-pending.md
git commit -m "chore: relay release vX.Y.Z completion [AP-NNN]"
git push origin main
```

---

## Rollback

If any gate fails after merge to `main`:

1. Do not delete the tag — tags are immutable records
2. Create a new patch release (vX.Y.Z+1) with the fix
3. Document the issue in the next release notes under "Known Issues"

If the tag has not yet been pushed:
```sh
git tag -d vX.Y.Z   # delete local tag only
```

---

## Operational Notes (from prior releases)

Practical hard-won rules for executing a release cleanly:

- **`approve_finding_update` is HIL-only and not in baseline-steward's toolset.** If a
  security/review finding must be updated during a release and the tool is unavailable,
  use the documented manual-fallback protocol: HIL explicitly authorizes a manual
  hand-edit, annotate each change as `manual-fallback`, and still stage → diff → commit.
- **Never hand-edit `findings.yaml` with a generic text editor.** Use a structure-preserving
  Python script (not `yaml.safe_dump`), then validate with `yaml.safe_load` before staging;
  a naive line edit corrupts the 0/2-space indentation.
- **`docs-engineer` has no bash/git tool.** The release owner/steward runs `mdbook build`
  and `git commit` on its behalf each iteration.
- **Reviewer agents auto-log to ledgers.** Watch for duplicate run_ids and for uncommitted
  ledger changes that block a checkout; commit gate records before switching branches.
- **The all-selected vs mixed discriminator is mandatory.** Before choosing
  `git merge --no-ff dev`, verify every commit in `origin/main..dev` maps to a
  release-selected ticket; if any does not, use per-ticket cherry-pick. The signal for a
  correct all-selected merge is a prep tree byte-identical to `dev`.

---

## Verification Checklist

- [ ] `mddocs/release-notes/vX.Y.Z.md` committed to main
- [ ] Security-reviewer APPROVED verdict obtained
- [ ] HIL LGTM received for release notes (G-4)
- [ ] HIL explicit confirmation for merge (G-5), tag (G-6), release branch (G-7)
- [ ] Tag `vX.Y.Z` visible: `git tag -l`
- [ ] Branch `release/vX.Y.Z` visible: `git branch -r`
- [ ] README as-built updated
- [ ] Relay note committed and pushed
