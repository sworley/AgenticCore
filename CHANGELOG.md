# Changelog

All notable changes to AgenticCore are documented here.
Versioning follows semantic versioning: `MAJOR.MINOR.PATCH` (see
[`mddocs/reference.architecture/release-process.md`](mddocs/reference.architecture/release-process.md)).
Release history starts with the open-source baseline; see `mddocs/release-notes/` for
published notes.

## [v0.7.0] — 2026-11-09

Maintenance/consistency release.

- Completed the `AP` → `AC` namespace migration across docs, bench tooling, and
  ADRs (framework consistency).
- Dependency refresh: `mcp` 1.30.0, `fastmcp` 3.4.10, `fastmcp-slim` 3.4.10.
- Release-process hardening (repository-specific mechanics + operational notes).
- See `mddocs/release-notes/v0.7.0.md` for the full release notes.

## [v0.6.0] — 2026-11-08

First release under the formalized release/baseline process.

- Adoption toolchain: project-local Python venv (`python-env.sh`), generic toolchain
  manager (`toolchain.sh`), mdBook 0.5.3 standardization, `.envrc` hardening.
- Formalized release process: baseline-steward owner/gate ↔ release-engineer executor
  split; release runbook re-attributed; release scaffolding on the v0.5.0 baseline.
- Docs/governance: `CONTRIBUTING.md` two-ways-to-contribute; onboarding/visual clarity.
- See `mddocs/release-notes/v0.6.0.md` for the full release notes.

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
