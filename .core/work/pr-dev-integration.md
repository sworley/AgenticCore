# feat(taxonomy): documentation & knowledge taxonomy adoption + authoritative shipping gate [AC-0013, AC-0014]

**Integrates AC-0013 (taxonomy adoption) and AC-0014 (authoritative, fail-closed adopter shipping gate) for the next release. Both tickets accepted + review-signed; all validation green.**

**Scope:** 280 files changed (+6,135 / −3,640). Targets `dev` (`main` is merge-only, ADR-0004).

## Includes
- **AC-0013** — taxonomy adoption: retired `DKT`/`ACT-`/`PROPOSAL-`; new ADRs 0029–0033; `management/` + `projects/` planes with mdBook nav; Q5 project-context seeding runbook; metadata registry reconcile tool; no-em-dash rule.
- **AC-0014** — `allowed_in_adopter_repos` is now the authoritative, fail-closed shipping gate (bootstrap tools excluded; 15 scripts reclassified `true`; `.md` + `.meta.yaml` honored). Governance folded into **ADR-0015 D-9** (ADR-0034 superseded). W1/W2/W3 fixed.
- **PyYAML** — `bench-status.sh --stale` uses the adopt-time `.venv`; fixed a `tasks.yaml` crash.

## Review
AC-0013: `RR-2026-11-17-01` ✓ approved_with_notes, `SR-2026-11-18-01` ✓ clean.
AC-0014: `RR-2026-11-18-01` ✓ approved_with_notes, `SR-2026-11-18-02` ✓ approved_with_notes.

## Validation
Links 497 OK / 0 em-dashes · mdBook builds · `reconcile --check` clean (28 SH + 20 script-docs + 8 IDs) · severance 39/0 · adopt 16/0 · `bench-status --stale` clean.

## Notes
Large, mostly additive/renaming doc change. `.00` customer content intentionally not imported (customer repos cloned into `.00` and gitignored by `.01`; binaries referenced, not copied). Projects-space migration deferred — `Current contexts: _None yet_`.

## References
- **Governed by:** ADR-0029 (taxonomy adoption), ADR-0015 **D-9** (authoritative shipping gate)
- **Added:** ADR-0030 (forward-only/coexistence), ADR-0031 (`CTX-`), ADR-0032 (classification contracts), ADR-0033 (Q5 seeding); ADR-0034 (superseded → ADR-0015 D-9)
- **Boundary/process:** ADR-0004 (`main` merge-only), ADR-0006/ADR-0028 (customer plane), ADR-0019 (review ledger)
