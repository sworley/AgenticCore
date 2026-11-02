# Sign-Off Package

**Trigger:** Before presenting any commit or push to the HIL for approval.

**Agent:** baseline-steward (`.01`)
**Defined by:** ADR-0019 D-7

---

## Purpose

The sign-off package is the single consolidated gate between task execution and HIL approval.
The HIL does not approve intermediate delegation steps. All reviewer verdicts, open findings,
and blocking items are assembled first; the HIL sees one package and responds with LGTM or
redirect.

---

## Procedure

### Step 1 — Summarize the diff

```sh
git diff main...HEAD --stat
git diff main...HEAD
```

Capture: which files changed, line counts, nature of changes (new file, edit, delete).

### Step 2 — Collect reviewer verdicts

List each reviewer invoked for this task. For each:
- Agent name (security-reviewer, docs-reviewer, code-reviewer)
- Verdict (APPROVED | APPROVED WITH NOTES | BLOCKED)
- Run ID (SR-/RR- prefixed, as returned by `log_reviewer_run()`)
- Finding IDs associated with the run

If any reviewer returned `BLOCKED`, the sign-off package must not be presented to the HIL
until remediation is complete and a follow-up verdict has been obtained.

### Step 3 — Surface open findings

Query both review ledger paths:

```
review-ledger-security: list_findings(status=open)
review-ledger-reviews:  list_findings(status=open)
```

Present: finding ID, severity, file, one-line description, age in days.

Flag any finding older than 7 days as an **escalation item** — present these first and
explicitly, before the full findings list.

### Step 4 — State blocking items

List any items that would prevent merge:
- Open `BLOCKED` verdicts not yet remediated
- Acceptance criteria from the task definition not yet met
- Findings with severity `finding` (not `note` or `warning`) that are unresolved
- mdbook build gate failures (if branch touches `mddocs/`)

If there are no blocking items, state: `Blocking items: none`.

### Step 5 — Present to HIL

Format the package as follows:

```
## Sign-Off Package — <task-id>: <title>

### Diff Summary
<files changed, line counts, nature of changes>

### Reviewer Verdicts
| Agent | Verdict | Run ID | Findings |
|---|---|---|---|
| security-reviewer | APPROVED WITH NOTES | SR-YYYY-MM-DD-NN | SF-NNN, SF-NNN |
| docs-reviewer     | APPROVED            | RR-YYYY-MM-DD-NN | none |
| code-reviewer     | APPROVED            | RR-YYYY-MM-DD-NN | none |

### Open Findings
**Escalations (>7 days old):**
- SF-NNN [warning, 12 days]: <file> — <description>

**All open findings:**
- SF-NNN [note, 3 days]: <file> — <description>

### Blocking Items
<none | list>
```

Wait for explicit HIL LGTM before proceeding to merge or push.

---

## Verification

Sign-off package is complete when:
- [ ] Diff summary captured
- [ ] All reviewer verdicts listed with run IDs
- [ ] No `BLOCKED` verdict outstanding
- [ ] Both ledger paths queried; findings older than 7 days flagged as escalations
- [ ] Blocking items stated (or confirmed none)
- [ ] Package presented to HIL; LGTM received before any merge/push action

---

## Escalation

If a reviewer is unavailable or returned an error, note this explicitly in the package.
Do not proceed without the required review unless the HIL explicitly waives it in the
current conversation.
