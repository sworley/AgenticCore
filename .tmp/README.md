# .tmp - Ephemeral / Scratch Workspace

`.tmp` is the **project-local scratch directory** for ephemeral work. It is the
durable convention for "throwaway inputs/outputs that should never touch the
tracked tree or git history." This file (`.tmp/README.md`) is the *one tracked
reference* documenting how `.tmp` is meant to be used and kept clean.

## Purpose

Put work here that you need for the moment but do **not** intend to commit,
push, or ship:

- Scratch notes and working drafts
- Throwaway scripts and one-off analysis
- Experiment / diff output, logs, and test artifacts
- Downloads and files pulled in just for inspection
- Temporary copies of files you are about to transform

Doing this in a project-local `.tmp` (instead of `/tmp`) keeps scratch work
associated with the project and lets the project clean it up on its own terms.

## Scope: workspace root, available to all workbenches

`.tmp` is the **workspace-root transient directory**. It sits at the root of the
workspace so it is available to every workbench in the project (the `.00` owner
workspace, the `.01` lead-engineer management plane, and the `.02`+ worker
benches), giving them all a common place for scratch/throwaway work that never
touches the tracked tree or git history.

There are two manifestations, and they share this one rule:

| Location | What it is |
|----------|-----------|
| `<workspace>/<repo>/.tmp/` (in-repo) | The tracked convention. `README.md` is committed; all other `.tmp` content is gitignored. |
| `<workspace>/.tmp/` (outside the repo) | The shared scratch directory at the workspace root, available to all workbenches. Not tracked by git. |

**Only `.tmp/README.md` is tracked.** Nothing else under `.tmp/` is ever added to
`.git`, and nothing under `.tmp/` except this README is carried through the
adoption process.

## Standings rule (machine + agent)

The standing rule (see `AGENT.md`) is:

> **Ephemeral work stays local** - do throwaway/scratch work in `./.tmp` at the
> project root (gitignored, not `/tmp`), so it never leaks into the tree or
> history. Keep it out of any tracked path.

## What goes where (contrast)

| Path | Use |
|------|-----|
| `./.tmp/**` | Ephemeral, throwaway. Ignored. Never committed. |
| `./.tmp/README.md` | The durable reference (this file). Committed. |
| tracked paths | Anything you intend to keep, share, or ship. |

## Gitignore contract

`.gitignore` treats `.tmp` as scratch:

```
.tmp/*
!.tmp/README.md
```

So all scratch content under `./.tmp` is ignored, while `README.md` (this
reference) remains tracked. A scratch file is therefore never accidentally
committed.

## Sensitive data

`.tmp` is **not** a safe place for secrets, tokens, credentials, PII, or
customer data. The project's no-secret / no-PII rules apply everywhere, `.tmp`
included. If you must inspect a sensitive value, redact it and clear it
immediately; never persist it here.

## Using it

```sh
mkdir -p .tmp            # on demand; the dir may be absent
cp file.txt .tmp/        # stage throwaway work here
# ... do scratch work ...
rm -rf .tmp/*            # clear scratch (keeps README.md)
```

## Scrubbing / lifecycle

- **On demand:** create `.tmp` when you need it; it is not required to exist.
- **When done:** delete scratch files. `rm -rf .tmp/*` is safe - it leaves
  `README.md` in place.
- **Session close:** the session-close checklist should clear `.tmp` of anything
  not needed for the next session.
- **Don't `git clean` blindly:** `.tmp` is ignored, so `git clean` may not touch
  it; remove its contents explicitly with `rm -rf .tmp/*` (careful not to delete
  `README.md`).
- **Don't leave the only copy here:** anything you want to keep belongs in a
  tracked path (or the appropriate `docs/`/`.agents/`/`.core/` location), not in
  `.tmp`.

## Framework export note

`export-framework.sh` excludes `.tmp` from the adopter tree (see
`FRAMEWORK_EXCLUDE_PATTERNS`), so scratch content can never leak into a shipped
or adopted project. A fresh `.tmp/README.md` (this convention, written for the
adopting project) is seeded to every adopted project by `seed_adopter_state()`,
so the reference carries forward - only the README reaches the adopter, never
scratch files.

This reference (`.tmp/README.md`) lives in the framework source and is committed
via git, which is how it reaches maintainers and contributors.

## Related

- `AGENT.md` - standing rule: "Ephemeral work stays local"
- `.gitignore` - `.tmp/*` ignore + `!.tmp/README.md` exception
- `mddocs/scripts/export-framework.sh` - excludes `.tmp` from adoption exports,
  seeds a fresh `.tmp/README.md` to adopters
