# Example: Release Process

**Scenario:** The team is ready to cut `v1.0.0` — the first production release of
AgenticCore. Shows the full release workflow from version proposal through
release branch and README update, with all HIL gates.

---

## 1. Task Created

The HIL signals readiness: *"dev looks good, let's do v1.0.0."*

**baseline-steward** — the framework release owner/gate — creates the release ticket in
`tasks.yaml` and owns the release end-to-end:

```yaml
- id: TC-010
  title: "Release v1.0.0"
  description: "Cut the first production release of AgenticCore."
  acceptance_criteria:
    - "mddocs/release-notes/v1.0.0.md committed to main"
    - "Security-reviewer APPROVED on release branch"
    - "Tag v1.0.0 pushed"
    - "Branch release/v1.0.0 cut and pushed"
    - "README as-built updated"
  priority: P1
  size: M
  agent: baseline-steward
  status: ready
```

baseline-steward provisions bench `.02` on branch `release/TC-010-v1.0.0-prep` and
tasks **release-engineer** to execute the tactical mechanics.

---

## 2. Version Confirmed (G-1)

Release-engineer collects evidence:

```sh
git log $(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD --oneline
```

Output shows 89-file bootstrap commit, scripts relocation, examples addition,
and release-engineer agent update — all new capabilities, no prior release.

Release-engineer proposes to baseline-steward → surfaced to HIL:

> "Proposed: v1.0.0. This is the initial production release — no prior tag exists.
> All framework capabilities are new. Semantic versioning: 1.0.0 (initial stable release)."

HIL: *"Confirmed. v1.0.0."*

---

## 3. Release Prep Branch Created (G-2)

```sh
git checkout main
git pull origin main
git checkout -b release/v1.0.0-prep
```

---

## 4. Release Notes Written (G-3)

Release-engineer creates `mddocs/release-notes/v1.0.0.md` from the template,
consolidating:
- All tickets in `tasks.yaml` at `status: merged`
- ADR-0001 through ADR- (all accepted in this cycle)
- Commit history

Requests security-reviewer pass:
> "@security-reviewer please review release/v1.0.0-prep — release notes and
> all framework artifacts."

Security-reviewer responds:

```
SECURITY REVIEW VERDICT: APPROVED

Summary: No credential patterns, no sensitive values, no supply chain concerns
         in release artifacts.

Findings: none

Required actions before merge: none
```

---

## 5. Release Notes Reviewed by HIL (G-4)

baseline-steward surfaces: *"Release notes for v1.0.0 are at
`mddocs/release-notes/v1.0.0.md` on branch `release/v1.0.0-prep`.
Security-reviewer: APPROVED. Ready for your review."*

HIL reviews, requests one change: *"Add a note in Known Limitations that
the CI pipeline (TC-002) is still pending."*

Release-engineer updates the notes. baseline-steward re-surfaces.

HIL: *"lgtm on the notes."*

---

## 6. Merge Prep Branch to Main (G-5)

Release-engineer executes. baseline-steward confirms with HIL:

> "Ready to merge `release/v1.0.0-prep` to `main`. Confirm?"

HIL: *"Go ahead."*

```sh
git checkout main
git merge --no-ff release/v1.0.0-prep \
  -m "release: merge v1.0.0 release notes to main [TC-010]"
git push origin main
```

---

## 7. Tag Created and Pushed (G-6)

baseline-steward confirms with HIL:

> "Ready to tag `v1.0.0` from `main` at SHA `abc1234`. Confirm?"

HIL: *"Confirmed."*

```sh
git tag -a v1.0.0 -m "release: v1.0.0"
git push origin v1.0.0
```

---

## 8. Release Branch Cut (G-7)

> "Ready to cut `release/v1.0.0` from tag `v1.0.0`. Confirm?"

HIL: *"Go ahead."*

```sh
git checkout -b release/v1.0.0 v1.0.0
git push origin release/v1.0.0
git checkout main
```

---

## 9. README As-Built Updated (G-8)

Release-engineer updates `README.md`:

```markdown
## As-Built

| Version | Date | Release Notes | Status |
|---|---|---|---|
| v1.0.0 | 2026-06-22 | [Release Notes](mddocs/release-notes/v1.0.0.md) | current |
```

Commits, baseline-steward confirms with HIL, pushes.

---

## 10. Relay Completion

```markdown
## Relay pending — 2026-06-22

**Destination:** .01 / baseline-steward
**Request:** Mark TC-010 as released
**Detail:** v1.0.0 released. All gates passed. Tag pushed. Branch cut. README updated.
```

baseline-steward marks TC-010 `released`, tears down bench `.02` with HIL authorization.

---

## Key Points

- Eight explicit HIL gates — no gate covers any subsequent gate
- Ownership split: **baseline-steward** owns/gates the framework release; **release-engineer**
  executes the tactical mechanics under its tasking (`HIL → baseline-steward → release-engineer`)
- Security-reviewer pass is mandatory before HIL sees the release artifacts
- One correction requested by HIL during notes review — incorporated before LGTM
- Release-engineer never pushes autonomously — every push is confirmed
- Relay note is the hand-off signal — baseline-steward closes the ticket, not the agent
