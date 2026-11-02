# Release Notes Template

**Copy this template when preparing release notes.**
Store completed notes as `mddocs/release-notes/vX.Y.Z.md`.

Release notes are **frozen at merge**. Never edit a released notes file.
For tag-only releases (no `release/*` branch), omit the Branch field.

---

# Release vX.Y.Z

**Date:** YYYY-MM-DD
**Tag:** `vX.Y.Z`
**Branch:** `release/vX.Y.Z` *(omit for tag-only releases)*
**Previous release:** vA.B.C *(use "none" for the first release)*

## Summary

One paragraph describing the overall theme of this release — what changed and why,
not just a list. Write for a developer or SRE picking up this framework for the
first time or upgrading from the previous version.

## What Changed

### New Capabilities
<!-- Features, new agents, new scripts, new runbooks -->
- ...

### Improvements
<!-- Non-breaking enhancements to existing capabilities -->
- ...

### Fixes
<!-- Bug fixes, documentation corrections -->
- ...

### Infrastructure / Pipeline
<!-- CI/CD, toolchain, dependency changes -->
- ...

## Architecture Decisions

ADRs accepted in this release cycle:

```markdown
| ADR | Title | Decision |
|---|---|---|
| ADR-NNNN | [Title](../adr/adr-NNNN-title.md) | One-sentence summary |
```

## Tickets Merged

| ID | Title | Type |
|---|---|---|
| AP-NNN | Ticket title | feat/fix/docs/security |

## Known Limitations

Items deferred to a future release or requiring follow-on work:
- ...

## Upgrade Notes

Steps required when upgrading from vA.B.C to this version (if any):
- ...

*If none: "No breaking changes. Drop-in upgrade from vA.B.C."*
