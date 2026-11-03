# FAQ: Which Git Hosts Does git-sync Support?

**Question (2026-11-02 session):** "Which git hosts are supported by the workspace
sync tool?"

## Answer

`git-sync.sh` is host-agnostic — it clones/updates every project in a configured Git
group and mirrors the group's namespace structure. It works against **local GitHub**
and **customer GitLab** instances (and any other Git host speaking the same API
convention). The host/group is configured in
`~/.config/git-sync/profiles` (see the
[git-sync runbook](../operations/runbooks/git-sync-runbook.md)).

> **Naming note:** the tool is called `git-sync` (not `gl-sync`) because it is no
> longer GitLab-specific — it supports both GitHub and GitLab.

## Canonical References

- [Runbook: git-sync — Git Workspace Sync](../operations/runbooks/git-sync-runbook.md)
- [git-sync.sh](../scripts/operations/git-sync.md)

## Provenance

- **Session:** 2026-11-02 — "git-sync naming / hosted git" Q&A.
