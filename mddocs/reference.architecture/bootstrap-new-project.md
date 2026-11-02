# Bootstrap New Project

**Purpose:** Adopt the AgenticCore framework into a new or existing project
repository using `export-framework.sh`, the supported adoption path (ADR-0015 D-1,
D-7).

**Audience:** Lead-engineer, baseline-steward, or senior engineer onboarding a new
project or re-homing the framework into an existing customer codebase.

**Script:** `mddocs/scripts/export-framework.sh`

---

## Overview

`export-framework.sh` exports a versioned AgenticCore release into a target
directory and establishes the adopter repository's independent Git identity. No
framework remote, upstream reference, or framework commit history is present in the
adopter repository afterward (ADR-0015 D-1, D-7).

The script supports two adoption flows, detected automatically from the target
directory's state or selected explicitly with `--flow`:

| Flow | Target state | What happens |
|---|---|---|
| **A — empty-dir init** (greenfield) | Target is empty or does not exist | Framework content is copied in, `git init` runs, a clean new repo is produced |
| **B — re-home** (brownfield) | Target is already a git repository with customer code | Framework files are overlaid into the existing tree; any framework remote is severed |

Both flows converge on the same result: framework content at the repository root, the
adopter's slug written (D-5), a `framework-version.txt` baseline reference (D-1), and
**no framework remote, upstream reference, or framework commit history, refs, or
objects reachable from the adopter repository.**

This runbook replaces the earlier manual copy-scaffold procedure. That procedure
predated `export-framework.sh` and is retained below only as a **manual fallback**
(for environments where the script cannot run) — see
[Manual fallback](#manual-fallback-for-environments-where-the-script-cannot-run).

---

## Prerequisites

- `git` (>= 2.5)
- `bash` — the script uses bash-only features and must not be run under `/bin/sh` or
  `dash`
- A Git (or other Git host) project already created for the adopter repo, if the
  adopter wants a remote from day one — `export-framework.sh` does not create a
  remote Git project; it only initializes/overlays the local repository and severs any
  framework-resolving push path
- For Flow B: the existing customer tree should be in a clean git working state (see
  D-7.2 below) — commit or stash pending work before running the script

---

## Which flow do I need?

- **Starting a brand-new project with no existing code** → Flow A (empty-dir init).
  Point `--target` at an empty or nonexistent directory.
- **Adding the framework to an existing customer codebase that already has its own
  git history** → Flow B (re-home). Point `--target` at that repository's root.

If the target directory exists, is non-empty, and is **not** a git repository, flow
detection is ambiguous and the script stops rather than guessing — pass `--flow`
explicitly.

> **Name the target with a `.01` suffix.** For a management-plane adoption, suffix the
> `--target` directory with `.01` (e.g. `~/dev/my-project.01`). This marks it as the
> lead-engineer `.01` namespace: the agent runtime recognizes `.01` and operates as
> `lead-engineer` within it, and tooling such as `git-sync.sh` derives your
> project/group name by stripping the `.NN` suffix. The **slug** is your project
> identity and does not carry the suffix — only the directory does. See the
> [Bench Model](../onboarding/bench-model.md) for the full `.00`/`.01`/`.02`+ hierarchy.

---

## Choosing your target path

> **PLACEHOLDER — to be completed (tracked in the backlog).** This section will
> document the recommended **host/group-mirroring target-path convention** for
> multi-project adopters, i.e. structuring `--target` as
> `<working-dir>/<git-toolset>/<git-host>/<group-or-project>` (for example
> `~/dev/git/git.example.com/acme-group/acme-project`) rather than a flat path.
>
> **Why it matters (summary):** the framework itself is path-agnostic (ADR-0015 D-2
> imposes no directory layout). However, credential-injection tooling that selects
> secrets by git remote/context, and workspace-sync tooling that consumes a
> group/project path, are simpler to wire when the on-disk layout mirrors the git
> host/group structure. Adopters who intend to wire in secrets and multi-instance
> credentials later will benefit from adopting this layout at bootstrap time.
>
> This is a **recommended convention, not a requirement.** The full write-up —
> including the exact derivation rule and its relationship to the credential
> injection pattern (ADR-0018) — is deferred; secrets/credential wiring is out of
> scope for the current adoption path and will be addressed alongside this section.

For now, a simple flat target path (e.g. `~/dev/my-project`) is fully supported and
is what the README Quick Start uses.

---

## One-command onboarding (recommended)

`mddocs/scripts/setup/adopt.sh` wraps the create-target, run-export, validate, and
generate-AI toolchain-settings steps below (README Quick Start steps 3-7) into a single
call.

Preview first (zero side effects):

```sh
bash mddocs/scripts/setup/adopt.sh --target /path/to/target --slug ACME --dry-run
```

Real run (interactive — the script prompts for confirmation before creating anything):

```sh
bash mddocs/scripts/setup/adopt.sh --target /path/to/target --slug ACME
```

The script echoes the resolved target path and asks:

```
Target directory:   /path/to/target

This directory will be created (mkdir -p) and populated with the
framework export. Confirm? [y/N]
```

Type `y` to proceed. Any other input aborts with no side effects.

> **Non-interactive / scripted use:** pass `-y` / `--yes` to skip the confirmation.
> In non-interactive mode (stdin not a TTY), `--target` is required; the script
> fails immediately with exit code 1 if it is omitted.

> **Relative paths work:** `--target ./my-project.01` is valid — the path is
> canonicalized to an absolute path immediately after `mkdir -p` (TC-084), so
> downstream steps (validation, agent configuration generation) are always working
> against the correct location.

> **Choosing your target path:** See [Choosing your target path](#choosing-your-target-path)
> below for the recommended TC-074 path convention. A simple flat path such as
> `~/dev/my-project.01` is fully supported and is what the README Quick Start uses.

`adopt.sh` orchestrates `export-framework.sh` — it does not reimplement any part of
the export or its D-7 confidentiality controls. A non-zero exit from
`export-framework.sh` aborts `adopt.sh` immediately, with its exit code and message
surfaced verbatim; see [adopt.sh](../scripts/setup/adopt.md).

The manual procedure below documents each step this script performs, and remains the
reference for running any single step independently (e.g. re-running validation only,
or re-generating agent configuration after moving the repo).

---

## Procedure

### Step 1 — Preview with `--dry-run` (recommended)

Before making any changes, preview what the script would do:

```sh
mddocs/scripts/export-framework.sh --target /path/to/target --dry-run
```

`--dry-run` reports the flow selected, the files that would be copied or moved, and
the configuration that would be severed, without writing anything — zero side effects
(D-7.4). It is safe to run repeatedly.

### Step 2 — Run the export

**Flow A — empty-dir init:**

```sh
mddocs/scripts/export-framework.sh --target /path/to/new-project
```

**Flow B — re-home into an existing tree:**

```sh
mddocs/scripts/export-framework.sh --target /path/to/existing-customer-repo
```

In both cases, before `mkdir -p` runs, the script echoes the resolved target path and
requires explicit confirmation:

```
Target directory:   /path/to/new-project

This directory will be created (mkdir -p) and populated with the
framework export. Confirm? [y/N]
```

Type `y` to proceed. Any other input aborts immediately with no side effects. To skip
the confirmation prompt for scripted use, pass `-y` / `--yes`.

If `--slug` is not supplied and stdin is a TTY, the script also prompts interactively:

```
Adopter project slug (uppercase ASCII, e.g. ACME):
```

The slug must be non-empty uppercase ASCII. It is written to `AGENT.md`,
`tasks.yaml`, and `PROCESS.md` (D-5). In non-interactive mode (stdin not a TTY),
`--slug` is required — pass it directly:

```sh
mddocs/scripts/export-framework.sh --target /path/to/target --slug ACME
```

### Step 3 — Validate

```sh
cd /path/to/target
./mddocs/scripts/check-env.sh        # verify environment
mdbook build mddocs/                 # verify docs build
git log --oneline -1                 # confirm the initial commit recorded the release
cat framework-version.txt            # confirm the baseline reference
git remote -v                        # confirm no framework remote is present
```

### Step 4 — Flow B only: review the reconciliation report

Flow A never produces this file — an empty-dir init has no pre-existing content to
reconcile, so skip this step for Flow A.

Flow B stages **only** the framework manifest into the re-home commit (every path
copied from the framework release, plus the generated `framework-version.txt` and the
slug-edited `AGENT.md`/`tasks.yaml`/`PROCESS.md`). It never runs a blind `git add -A`,
so any content that already existed in the customer tree before the re-home is left
exactly as it was — untouched and untracked, not swept into the framework commit.

The script writes `.framework-rehome-report.txt` at the target repo root listing every
such pre-existing, untracked path. Read it and act on it before your first commit on
top of the re-home:

```sh
cat /path/to/target/.framework-rehome-report.txt
```

For each path listed, decide:

- **Should not be tracked** → add it to `.gitignore` yourself. The script never writes
  `.gitignore` — this is always an explicit operator decision, never automatic.
- **Should be tracked** → `git add <path>` yourself.

Once every listed path is classified, the report file has served its purpose — delete
it (or commit it as a team record, if you prefer; it is not framework or customer
history, just a point-in-time provenance note).

```sh
rm /path/to/target/.framework-rehome-report.txt
```

`--dry-run` previews this classification (framework-vs-customer path counts, and the
customer paths themselves) to stdout without writing the report file or touching the
target at all (D-7.4).

---

## Command reference

```
Usage: export-framework.sh [--target <dir>] [--flow empty|rehome] [--slug <SLUG>]
                            [--dry-run] [--force] [-y|--yes]

  --target <dir>       Target directory for the adopter repo. Optional when
                       stdin is a TTY — prompted interactively with a suggested
                       path (TC-074 convention) and confirmed before mkdir -p.
                       Required in non-interactive mode (exit 1 if absent and
                       stdin is not a TTY).
  --flow empty|rehome  Explicit flow selection (required if detection is ambiguous)
  --slug <SLUG>        Adopter project slug (non-empty uppercase ASCII)
  --dry-run            Report only — zero side effects (skips confirmation prompt)
  --force              Override the Flow B dirty-tree guard ONLY
  -y, --yes            Skip the --target confirmation prompt (scripted use)
```

| Argument | Required | Notes |
|---|---|---|
| `--target <dir>` | Interactive: optional (prompted). Non-interactive: required. | Directory to initialize (Flow A) or overlay into (Flow B). Relative paths are supported (TC-084). A confirmation prompt is shown before `mkdir -p` unless `--yes` is passed or `--dry-run` is active. |
| `--flow empty\|rehome` | Only when detection is ambiguous | Forces flow selection instead of auto-detecting |
| `--slug <SLUG>` | Only in non-interactive mode | Uppercase ASCII only; prompted interactively otherwise |
| `--dry-run` | No | Report-only preview; guarantees zero side effects (D-7.4); skips confirmation |
| `--force` | No | Overrides the Flow B dirty-tree guard (D-7.2) **only** — see below |
| `-y, --yes` | No | Skips the `--target` confirmation prompt for scripted/non-interactive adoption |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (including the no-op/idempotent path and `--dry-run`) |
| `1` | Argument or usage error |
| `2` | Ambiguous flow detection — explicit `--flow` required |
| `3` | Target-identity guard tripped (D-7.6) — target is the framework repository itself, or a nested/parent framework worktree |
| `4` | Dirty-tree guard tripped (D-7.2) — Flow B target is not a clean working tree and `--force` was not given |
| `5` | Remote-severance assertion failed (D-7.3) — a push path to the framework repository still exists |
| `6` | History/refs/object scrub verification failed (D-7.5) |
| `7` | Slug validation failed |

A non-zero exit from the severance (`5`) or history-scrub (`6`) checks means the
script detected a confidentiality risk and stopped. Do not re-run with a workaround —
investigate the reported offending configuration or state directly (the script prints
it) before retrying.

---

## Safety behaviors you will encounter

`export-framework.sh` enforces several non-negotiable safety and confidentiality
controls. Understanding them helps you interpret the script's output correctly rather
than treating a stop as a bug.

### Re-home dirty-tree interlock (D-7.2)

Flow B refuses to run against a customer tree that is not a clean git working tree
(uncommitted changes or untracked files that an overlay could clobber). The script
aborts with exit code `4` and makes **no changes**.

`--force` overrides **this guard only**. It does not weaken any other control. If you
pass `--force`, the script echoes a warning and proceeds with the overlay — review the
dirty status it prints first.

**Why:** re-homing writes framework files directly into a tree the operator cares
about. A one-shot, confidentiality-sensitive bootstrap operation must not silently
overwrite uncommitted customer work.

### Remote severance — verified, not assumed (D-7.3)

Severing the framework remote is a **confidentiality control**, not a convenience
step. If an adopter forgets to sever the framework remote, customer code can later be
pushed back to the framework repository — a pollution risk, and the reason TC-050 was
filed.

The script does not just remove a remote named `origin` and call it done. It verifies,
by **resolved push target** (not by name or substring match), that after severance the
remote set is empty or contains only the adopter's own remotes — never anything that
resolves to the framework repository, including through SSH-form remotes, `insteadOf`/
`pushInsteadOf` rewrite rules, `remote.pushDefault`, and `branch.<name>.pushRemote`. If
any framework-resolving push path survives, the script **aborts loudly with exit code
`5`** and prints the offending configuration.

This assertion runs on **every invocation** — including the idempotent no-op path and
`--dry-run` (in report-only form) — so a framework remote or rewrite rule reintroduced
after initial adoption is caught, not silently tolerated. **`--force` does not
override this assertion.**

### No framework history, refs, or objects remain (D-7.5)

Removing a remote does not remove objects, `refs/remotes/*`, `FETCH_HEAD`, reflog
entries, tags, or notes already fetched from it. The script's post-condition — "no
framework commit history reachable" — is verified independently of remote severance:
it checks for surviving `refs/remotes/*`, a non-empty `FETCH_HEAD`, and unreachable
objects, and it scrubs (reflog expire, `gc --prune=now`) before verifying. If framework
history state still survives the scrub, the script **aborts with exit code `6`**.

This check also runs on every invocation, and is **not overridable** by `--force` or
any other flag.

### Target-identity guard (D-7.6)

Independent of the dirty-tree check, the script confirms the target is not the
framework repository itself and not a nested or parent framework worktree. If it is,
the script refuses to operate and exits with code `3`. This catches an operator
accidentally pointing `--target` at the wrong tree (e.g. a sibling bench of the
framework checkout itself).

### `--dry-run` preview (D-7.4)

`--dry-run` reports the flow, the files that would move or copy, and the configuration
that would be severed — with **zero side effects**: no config writes, no ref updates,
no file moves, no object changes. Re-running the script against an already-initialized
adopter repo (Flow A: `.git` + `framework-version.txt` present; Flow B:
`framework-version.txt` present) is a no-op that reports the existing baseline rather
than re-exporting — but still re-runs the D-7.3 and D-7.5 assertions, so drift is
caught even on a repeat invocation.

---

## Post-Bootstrap Checklist

- [ ] `git remote -v` in the target repo shows no remote resolving to the framework
- [ ] `framework-version.txt` present at the repo root with the correct release tag
- [ ] `AGENT.md`, `tasks.yaml`, and `PROCESS.md` carry the adopter's slug
- [ ] `mddocs/` builds without errors (`mdbook build mddocs/`)
- [ ] `./mddocs/scripts/check-env.sh` passes
- [ ] Initial commit message records the framework release version
- [ ] A remote Git project exists and is wired (`git remote add origin <adopter-repo-url>`), if desired — the script never adds an adopter remote on its own initiative
- [ ] Working/integration branch created and pushed, per the adopter's own branch
      strategy (the framework does not prescribe a branch layout — see
      [ADR-0015](../adr/adr-0015-framework-distribution-adoption-model.md) D-8)

---

## Manual fallback (for environments where the script cannot run)

Use this procedure only when `export-framework.sh` genuinely cannot run (for example,
no bash available, or a sandboxed environment that blocks the script's file
operations). This is the same nine-step procedure the HIL originally hand-executed
before `export-framework.sh` existed (ADR-0015 D-7 background).

**This procedure is not an optional lighter-weight alternative.** ADR-0015 D-7 requires
that a manual adopter perform the **same confidentiality checks the script enforces**
(D-7.3 remote severance and D-7.5 history/refs/object scrub). Skipping the verification
steps below reintroduces the exact confidentiality gap TC-050 was filed to close: if a
framework remote survives, customer code can later be pushed to the framework
repository.

### Manual re-home procedure

1. Create the customer root directory and change into it (or use an existing customer
   repository root).
2. Populate the customer codebase (e.g. via `git-sync.sh`, or however the customer
   repository is normally obtained).
3. Clone the framework into a throwaway subdirectory:
   ```sh
   git clone <framework-repo-url> ./_framework-import
   ```
4. Move all framework files and directories (including hidden ones, excluding `.git`)
   up one level into the customer root:
   ```sh
   (cd _framework-import && tar -c --exclude=.git .) | tar -x -C .
   ```
5. **Before removing the throwaway subdirectory, capture its file list as your
   framework manifest** — this is the same manifest `export-framework.sh` builds
   automatically (TC-051), and it is what makes step 6's reconciliation deterministic
   instead of a guess:
   ```sh
   (cd _framework-import && find . -path ./.git -prune -o -type f -print) | sed 's#^\./##' > /tmp/framework-manifest.txt
   rm -rf ./_framework-import
   ```
6. **Reconcile pre-existing customer content against the manifest.** Immediately after
   the move, list every untracked path (`--untracked-files=all` expands untracked
   directories to their individual files, so the comparison against the manifest's
   file-level paths lines up):
   ```sh
   git status --porcelain --untracked-files=all | grep '^??' | sed 's/^?? //' | sort \
     > /tmp/untracked.txt
   comm -23 /tmp/untracked.txt <(sort /tmp/framework-manifest.txt)
   ```
   Every path `comm` prints existed in the customer tree before the re-home and is not
   framework content — the same distinction `export-framework.sh`'s
   `.framework-rehome-report.txt` report makes automatically (see
   [Step 4](#step-4--flow-b-only-review-the-reconciliation-report) above). For each
   such path, decide:
   - **Should not be tracked** → add it to `.gitignore` yourself.
   - **Should be tracked** → `git add <path>` yourself.
   Do this now, before staging anything — the commit at the end of this procedure
   should only ever contain the framework manifest paths plus your own explicit
   `git add` decisions, never a blind `git add -A` over the whole tree.
7. Sever the framework remote and every other push path that could reach it:
   ```sh
   git remote remove <framework-remote-name>
   # Repeat for every remote name returned by: git remote
   ```
8. **Required — verify no push path to the framework survives (D-7.3).** Do not treat
   step 7 as sufficient on its own; a name-based removal misses rewrite rules,
   `pushDefault`, and per-branch overrides. Run **all** of the following and confirm
   each returns nothing that resolves to the framework:
   ```sh
   # No remote at all should resolve to the framework:
   git remote -v

   # Check the PUSH target of every remote explicitly (catches multiple
   # pushurl entries per remote, and SSH-form URLs, that `remote -v` output
   # can be easy to eyeball past):
   for r in $(git remote); do
     echo "== $r =="
     git remote get-url --push --all "$r"
   done

   # No insteadOf / pushInsteadOf rewrite rule should point at the framework:
   git config --get-regexp 'url\..*\.(insteadof|pushinsteadof)'

   # remote.pushDefault must not point at anything resolving to the framework:
   git config --get remote.pushDefault

   # No per-branch pushRemote override should point at the framework:
   git config --get-regexp '^branch\..*\.pushremote$'
   ```
   If any of these commands returns a URL or remote name that resolves to the
   framework repository — including through a rewrite rule or a mirror URL, not only
   an exact literal match — remove or reconfigure it and re-check before proceeding.
9. **Required — verify no framework history, refs, or objects remain (D-7.5).** The
   clone in step 3 fetched framework objects into a `.git` you have since discarded,
   but if any framework-related git state was fetched into the **customer repository's
   own** object store (for example, if a framework remote was ever added and fetched
   directly into the customer repo rather than into the throwaway clone), it survives
   remote removal. Confirm none remains:
   ```sh
   # No remote-tracking refs should remain after severance:
   git for-each-ref refs/remotes

   # FETCH_HEAD should be empty or absent:
   cat "$(git rev-parse --git-common-dir)/FETCH_HEAD" 2>/dev/null

   # No unreachable objects should remain (run gc first to clear anything
   # legitimately pruneable, then check):
   git reflog expire --expire=now --all
   git gc --prune=now
   git fsck --unreachable
   ```
   `git for-each-ref refs/remotes` must return nothing. `FETCH_HEAD` must be empty or
   not exist. `git fsck --unreachable` must report nothing. If any of these checks
   returns output, do not proceed to commit — investigate and remove the offending
   ref, file, or object first.

Only after both verification blocks (step 8 and step 9) come back clean, **and** step 6's
reconciliation is complete (every pre-existing customer path classified — gitignored or
explicitly `git add`ed), continue.

First, write the adopter's slug (to `AGENT.md`, `tasks.yaml`, and `PROCESS.md`, per
ADR-0015 D-5 — these are already in your framework manifest from step 5, since they
came from the framework tree) and a `framework-version.txt` recording the framework
release and export date (matching the D-1 baseline-reference contract — this one is
newly generated, so add it to your manifest). Then commit — staging the manifest
explicitly rather than a blind `git add -A`, so an unclassified customer path you
missed in step 6 cannot silently ride along into the framework commit:

```sh
echo 'framework-version.txt' >> /tmp/framework-manifest.txt
git add -f --pathspec-from-file=/tmp/framework-manifest.txt --
git commit -m "feat: re-home AgenticCore into existing tree"
```

(`-f` is required because a framework path may legitimately fall under a pre-existing
customer `.gitignore` rule; the manifest is the authority on what is framework content
here, not the customer's ignore rules.)

---

## Related

- [ADR-0015: Framework Distribution and Adoption Model](../adr/adr-0015-framework-distribution-adoption-model.md) — D-1, D-5, D-7 (binding spec for this runbook)
- [Adopter Reconciliation Model](adopter-reconciliation.md) — how framework improvements reach adopters after initial adoption
- `mddocs/scripts/export-framework.sh` — the script this runbook documents
- `mddocs/scripts/test-export-framework-severance.sh` — the confidentiality-assertion test harness (D-7.3 / D-7.5 proof)
