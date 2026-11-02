# Example: Ticket Lifecycle

**Scenario:** Adding a Git CI pipeline for mdBook Pages publication (task TC-002).
Follows the task from `backlog` entry through `merged`.

---

## 1. Task Created (backlog → ready)

The lead-engineer adds TC-002 to `tasks.yaml` at session open after identifying
the gap during bootstrap review.

```yaml
- id: TC-002
  title: "Git CI — mdBook Pages pipeline"
  description: "Configure .git-ci.yml to build mdBook and publish to Git Pages."
  acceptance_criteria:
    - "Pipeline passes on push to main"
    - "Pages URL is accessible"
  priority: P2
  size: S
  agent: release-engineer
  status: ready
  created: 2026-06-22
  updated: 2026-06-22
```

Lead-engineer surfaces it to HIL: *"TC-002 is ready — adds the CI pipeline for docs
publishing. Small task, release-engineer. Want me to spin up a bench?"*

HIL: *"Yes, provision it."*

---

## 2. Bench Provisioned (ready → claimed)

Lead-engineer provisions `.02` from `.01`:

```sh
./mddocs/scripts/provision-bench.sh \
  --bench 02 --ticket TC-002 --type feat --slug add-ci-pipeline
```

Output:
```
==> provision-bench
    bench:  ~/dev/my-project.02
    branch: feat/TC-002-add-ci-pipeline

==> Bench provisioned successfully
```

Lead-engineer deploys the Pattern A AGENT.md to the bench and updates `tasks.yaml`:

```yaml
  status: in_progress
  bench: ".02"
  branch: feat/TC-002-add-ci-pipeline
  started_at: 2026-06-23
```

---

## 3. Work Executed on the Bench

The release-engineer agent opens in `.02`. It reads the assignment from `AGENT.md`:

```
TICKET: TC-002
BRANCH: feat/TC-002-add-ci-pipeline
TASK: Write .git-ci.yml for mdBook build and Git Pages publish
```

Agent creates `.git-ci.yml`, validates `mddocs/book.toml`, tests a local build:

```sh
mdbook build mddocs/
# Exit 0 — build succeeded
```

Commits on the bench branch:

```
feat: add Git CI pipeline for mdBook Pages [TC-002]

- build-docs job: cargo-cached mdbook build on push to main/release/*
- pages job: copies mddocs/book/ to public/ for Git Pages
- rust cache keyed to mdbook version to avoid reinstall on every run
```

---

## 4. Branch Ready — Relay to Lead-Engineer

Bench lead cannot write `tasks.yaml` directly. Writes to `.core/work/relay-pending.md`:

```markdown
## Relay pending — 2026-06-23

**Destination:** .01 / lead-engineer
**Task:** TC-002
**Request:** Update status to branch_ready
**Branch:** feat/TC-002-add-ci-pipeline
**SHA:** a3f9c12
**Detail:** .git-ci.yml written and tested locally. All acceptance criteria met.
```

---

## 5. Lead-Engineer Processes Relay (in_progress → branch_ready)

At next session open, lead-engineer reads `relay-pending.md`, updates `tasks.yaml`:

```yaml
  status: branch_ready
  note: "Branch feat/TC-002-add-ci-pipeline ready. SHA: a3f9c12. Awaiting HIL review."
  updated: 2026-06-23
```

Clears the relay entry. Surfaces to HIL:

*"TC-002 is branch-ready. `.git-ci.yml` adds mdBook build and Pages publish.
Branch: `feat/TC-002-add-ci-pipeline` at `a3f9c12`. Ready for your review."*

---

## 6. HIL Reviews and Accepts (branch_ready → accepted → merged)

HIL reviews the diff on the branch. Signals: *"lgtm"*

Lead-engineer merges immediately on receipt:

```sh
git checkout main
git merge --no-ff feat/TC-002-add-ci-pipeline \
  -m "feat: add Git CI pipeline for mdBook Pages [TC-002]"
git push origin main
```

Updates `tasks.yaml`:

```yaml
  status: merged
  completed_at: 2026-06-23
  updated: 2026-06-23
```

---

## 7. Bench Teardown

Lead-engineer requests teardown authorization: *"Tearing down `.02` — TC-002 merged."*

HIL: *"Go ahead."*

```sh
git worktree remove ~/dev/my-project.02
git branch -d feat/TC-002-add-ci-pipeline
```

Updates `bench-registry.yaml`:
```yaml
  status: torn_down
```

---

## Key Points

- The lead-engineer never executes the task work — that happens on `.02`
- Bench leads relay through `relay-pending.md`; they never write `tasks.yaml` directly
- LGTM triggers an immediate merge — no additional confirmation step
- Bench teardown is a separate HIL authorization, distinct from LGTM on the work
- The commit message carries the ticket ID — searchable in `git log`
