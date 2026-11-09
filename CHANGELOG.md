# Changelog

All notable changes to AgenticCore are documented here.
Versioning follows semantic versioning: `MAJOR.MINOR.PATCH` (see
[`mddocs/reference.architecture/release-process.md`](mddocs/reference.architecture/release-process.md)).
Release history starts with the open-source baseline; see `mddocs/release-notes/` for
published notes.

## [v0.5.0] — 2026-11-01

Initial open-source baseline (starting point for the formal release process).

- Established the `.core/` governance and enforcement layer (instruction
  contract, invariants, security/docs policy, hooks, scripts, bootstrap, task queue).
- Canonical agent roster (`.agents/`) with 16 roles, auto-synced via
  `sync-agents.sh` to `.opencode/agents/`.
- ADR governance set carried forward (see `mddocs/adr/`).
- Benchmark/worktree bench model; `tasks.yaml` + `bench-registry.yaml` schemas.
- Sanitized for open-source: no organization, customer, or vendor-specific
  identifiers. Git hosting consolidated to a single generic reference.
