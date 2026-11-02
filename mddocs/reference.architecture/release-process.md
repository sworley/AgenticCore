# Runbook: Release Process

**Agent:** release-engineer
**Triggered by:** Explicit task from lead-engineer
**Requires:** HIL approval at every numbered gate below

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
| G-2 | Release prep branch created | lead-engineer task |
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

Present to lead-engineer and HIL:
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

Present staged diff to lead-engineer. Relay to `.01` for HIL surface.

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

**Destination:** .01 / lead-engineer
**Request:** Mark release ticket AP-NNN as merged
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

## Verification Checklist

- [ ] `mddocs/release-notes/vX.Y.Z.md` committed to main
- [ ] Security-reviewer APPROVED verdict obtained
- [ ] HIL LGTM received for release notes (G-4)
- [ ] HIL explicit confirmation for merge (G-5), tag (G-6), release branch (G-7)
- [ ] Tag `vX.Y.Z` visible: `git tag -l`
- [ ] Branch `release/vX.Y.Z` visible: `git branch -r`
- [ ] README as-built updated
- [ ] Relay note committed and pushed
