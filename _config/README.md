# _config — AGENT.md Recovery Archive

This directory tracks copies of AGENT.md files that live outside the git tree
(e.g., org-level, parent directory, or user-level AGENT.md files).

## Purpose

These files are the authoritative versions tracked in git. If the on-disk files
are lost or overwritten, recover from here.

## Files

| Archive File | On-Disk Location | Purpose |
|---|---|---|
| `repos-AGENT.md` | `<project-root>/AGENT.md` | Universal rules for all repos |

## Keeping In Sync

On-disk files are authoritative for content. Copy back to this directory when
changes are made on-disk:

```sh
cp ~/files/repos/AGENT.md _config/repos-AGENT.md
git add _config/repos-AGENT.md
git commit -m "docs: sync repos-AGENT.md archive"
```

## Recovery

To restore on-disk from archive:

```sh
cp _config/repos-AGENT.md ~/files/repos/AGENT.md
```
