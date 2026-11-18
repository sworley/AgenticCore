# ADR-0034: allowed_in_adopter_repos as the Authoritative Shipping Gate

**Date:** 2026-11-18
**Status:** proposed
**Supersedes:** -
**Superseded by:** -

## Context

`allowed_in_adopter_repos` (metadata-standard section 4) documents which
framework scripts form the supported adoption surface, but it was descriptive
only: `export-framework.sh`'s `FRAMEWORK_EXCLUDE_PATTERNS` ignored it, so
`allowed_in_adopter_repos: false` artifacts still shipped to adopters. AC-0014
Stage 1 excluded the one-shot bootstrap tools (`setup/adopt.sh`,
`export-framework.sh`); Stage 2 makes the flag authoritative.

Making the flag authoritative required re-checking every `false` script. Most
were misclassified: they are referenced by shipped agent definitions and
runbooks (e.g., `lead-engineer.md` runs `bench-status.sh --stale` at session
open), so excluding them would ship a surface whose instructions reference
missing tools.

## Decision

1. **The flag is authoritative.** `export-framework.sh` excludes from the
   adopter tree every artifact whose `.meta.yaml` declares
   `allowed_in_adopter_repos: false`. The supported adoption surface is the
   `true` set (ADR-0015 D-1/D-7 adoption surface; metadata-standard section
   3/4).
2. **Reclassification (15 -> class 2 / `true`).** The following are part of the
   shipped, supported surface: `bench-status.sh`, `check-worktree-hygiene.sh`,
   `read-audit-log.sh`, `statusline-command.sh`, `sync-agent-config.sh`,
   `setup/phase2-dev-toolchain.sh`, `update-summary-on-adr-write.py`,
   `reconcile-metadata-registry.py`, `mcp-tests/run-all.sh`,
   `mcp-tests/test-mcp-filesystem.sh`, `mcp-tests/test-mcp-git.sh`,
   `mcp-tests/test-mcp-rag-docs.py`, `test-adopt-target-handling.sh`,
   `test-export-framework-severance.sh`, `test-provision-bench-substitution.sh`.
3. **Keep `false` (excluded / not shipped):** the one-shot bootstrap tools
   `setup/adopt.sh` and `export-framework.sh`, and the seed data
   `seed/tasks.yaml` / `seed/bench-registry.yaml`.
4. **No change to the adoption model.** ADR-0015 D-1/D-7 confidentiality
   controls (remote severance, history/refs/object scrub) are unchanged; only
   the shipped-surface mechanism now honors the metadata contract.

## Consequences

**Positive:**
- The flag is authoritative and self-consistent; the shipped surface matches the
  documented classification.
- Bootstrap tools cannot be re-run to re-adopt an already-adopted environment.

**Negative / Trade-offs:**
- The shipped script set is now driven by metadata, so a future reclassification
  has shipping consequences and must be reviewed.

**Neutral:**
- No change to ADR-0015 (adoption model) or the D-7 confidentiality controls.

## Implementation Notes

- `export-framework.sh` computes the excludes from `.meta.yaml` at source time,
  so the same authoritative `FRAMEWORK_EXCLUDE_PATTERNS` array drives the tar
  copy, the manifest walk, and the test harness (which sources it directly).
- `metadata-standard.md` section 4 documents the authoritative semantics; the
  section 8 registry reflects the reclassifications.
- Ticket: AC-0014 (Stage 1 done, Stage 2 done; metadata-driven shipping).
