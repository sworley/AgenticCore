# Example: Bench Session Walkthrough

**Scenario:** A release-engineer agent opens on bench `.02`, does a focused unit
of work, and closes cleanly. Shows what a well-run bench session looks like from
open to close.

---

## Opening the Session

The HIL opens an agentic session in the `.02` worktree directory. The agent reads
its `AGENT.md` automatically and orients:

```
TICKET: TC-002
BRANCH: feat/TC-002-add-ci-pipeline
PATTERN: A
TASK: Write .git-ci.yml for mdBook build and Git Pages publish
```

Agent confirms orientation to HIL:

> "On bench `.02`, branch `feat/TC-002-add-ci-pipeline`. Task is TC-002 —
> add the CI pipeline for mdBook Pages. Starting with a read of `mddocs/book.toml`
> to understand the build configuration."

---

## Orienting in the Bench

Before writing anything, the agent reads relevant context:

```
Read: mddocs/book.toml          → understand mdBook config
Read: mddocs/SUMMARY.md         → confirm source structure
Read: .gitignore                → confirm mddocs/book/ is excluded
Read: mddocs/operations/runbooks/build-publish-mddocs.md  → read the runbook
```

From `build-publish-mddocs.md` the agent confirms:
- Build command: `mdbook build mddocs/`
- Output path: `mddocs/book/`
- Mermaid preprocessor required: `mdbook-mermaid`
- Pages deployment target: `public/`

---

## Doing the Work

Agent proposes the `.git-ci.yml` structure to HIL before writing:

> "Planning two jobs: `build-docs` (cargo-cached mdbook build, artifacts to
> `mddocs/book/`) and `pages` (copies to `public/`). Rules: build on push to
> `main` and `release/*`; pages deploy on `main` and tags only. Proceed?"

HIL: *"Yes."*

Agent writes the file, then validates locally:

```sh
mdbook build mddocs/
echo "Exit: $?"   # → Exit: 0
ls mddocs/book/   # → index.html present
```

---

## Committing

Agent presents staged diff summary before committing:

> "Staged: `.git-ci.yml` (new file, 47 lines). Adds `build-docs` and `pages`
> jobs. Rust cache keyed to mdbook version. No other files changed. Commit?"

HIL: *"lgtm"*

```sh
git add .git-ci.yml
git commit -m "feat: add Git CI pipeline for mdBook Pages [TC-002]"
# → [feat/TC-002-add-ci-pipeline a3f9c12] feat: add Git CI...
```

---

## Closing the Session

Before ending, the agent runs the session-close steps:

**Step 1 — Verify bench is clean:**
```sh
git status
# → nothing to commit, working tree clean
```

**Step 2 — Write relay note** (since work is complete and branch-ready):

```markdown
## Relay pending — 2026-06-23

**Destination:** .01 / lead-engineer
**Task:** TC-002
**Request:** Update status to branch_ready
**Branch:** feat/TC-002-add-ci-pipeline
**SHA:** a3f9c12
**Detail:** .git-ci.yml written and tested locally. Build exits 0.
           All acceptance criteria met.
```

```sh
git add .core/work/relay-pending.md
git commit -m "chore: relay TC-002 branch-ready signal [TC-002]"
```

**Step 3 — Confirm to HIL:**

> "Bench `.02` is clean. Relay note written for lead-engineer. Work is complete —
> `.git-ci.yml` committed at `a3f9c12`. Nothing left in this session."

---

## Key Points

- Agent reads context before writing — `book.toml`, the runbook, `.gitignore`
- Agent proposes structure and waits for HIL confirmation before writing
- Agent presents diff summary and waits for explicit LGTM before committing
- Relay note is committed as its own commit — it's a trackable artifact
- Bench is verified clean before the session ends
- The agent never pushes — that's the lead-engineer's job after HIL review
