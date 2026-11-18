# Session State — 2026-11-18 (taxonomy adoption / AC-0013 + AC-0014 + pyyaml fix; pre-dev-PR)

Per-session resume note (tracked). Read at session open to restore focus before
checking `tasks.yaml`. See `.core/work/README.md` for the schema.

## Branch / position
- Repo: `/home/sworley/files/sandbox/AgenticCore.v1.01/AgenticCore`
- Branch: `feat/taxonomy-adoption` — **in sync** with `origin/feat/taxonomy-adoption` (HEAD `2128494`)
- Working tree: clean; all AC-0013/AC-0014 commits GPG-signed (`[AC-0013]` / `[AC-0014]`)
- Integration target: `dev` (next release); `main` is merge-only (ADR-0004)

## Session outcome — branch is merge-ready; next gate is the `dev` integration PR
The taxonomy adoption (AC-0013) and the `allowed_in_adopter_repos` → `export-framework.sh`
shipping-gate wiring (AC-0014) are complete and reviewed on the feature branch:

- **AC-0013** — taxonomy adopted (ID namespaces retired; ADR-0029/0030/0031/0032/0033;
  reconcile tool SH-0028; no-em-dash rule).
- **AC-0014** — `allowed_in_adopter_repos` wired to shipping (**accepted**).
  - Stage 1: exclude bootstrap tools; Stage 2: flag authoritative/fail-closed.
  - Governance folded into **ADR-0015 D-9**; **ADR-0034** superseded.
  - Reclassified 15 scripts → class 2/`true`; bootstrap + seed stay `false`.
  - Security-review notes **W1/W2/W3** addressed; `reconcile-metadata-registry.py`
    now checks SH script-doc vs `.meta.yaml` drift.
- **PyYAML dependency** — confirmed declared (`requirements.txt` `PyYAML==6.0.3`;
  `mcp/review-ledger/pyproject.toml` `pyyaml==6.0.3`; installed into `.venv` at
  `adopt.sh`, validated by `check-env.sh`). Fixed `bench-status.sh --stale` to use
  `.venv/bin/python` (was `uv run`/bare `python3`, so pyyaml was missed) + a latent
  `tasks.yaml` unwrap crash.

## Commits this session (newest first)
| Commit | Scope |
|---|---|
| `2128494` | fix(bench-status): use .venv for pyyaml + fix stale-detection crash [AC-0014] |
| `afe4873` | docs(session): update session state for AC-0014 completion [AC-0014] |
| `04cd780` | fix(export): harden allowed_in_adopter_repos gate (W1/W2/W3) [AC-0014] |
| `72c9790` | docs(review): record AC-0014 review sign-off + accept [AC-0014] |
| `076045a` | docs(adr): fold AC-0014 Stage 2 into ADR-0015 D-9 [AC-0014] |
| `df1cb4c` | feat(export): allowed_in_adopter_repos authoritative (AC-0014 Stage 2) |
| `90fd06e` | feat(export): exclude adopt.sh + export-framework.sh (AC-0014 Stage 1) |

Full history: `git log --oneline origin/dev..HEAD` (also AC-0013 commits `fbe1541`…`fc64907`).

## Recorded reviews
- **AC-0013** — `RR-2026-11-17-01` approved_with_notes (docs); `SR-2026-11-18-01` clean (sec).
- **AC-0014** — `RR-2026-11-18-01` approved_with_notes (docs); `SR-2026-11-18-02`
  approved_with_notes (sec, Baseline/Tier 1; W1/W2/W3 notes since resolved).

## Validation (all green)
- `check-links.sh` — 497 OK, 0 em-dashes; `mdbook build` passes
- `reconcile-metadata-registry.py --check` — exit 0 (28 SH + 20 SH script-docs + 8 classification IDs)
- `test-export-framework-severance.sh` — 39 PASS / 0 FAIL
- `test-adopt-target-handling.sh` — 16 PASS / 0 FAIL
- `bench-status.sh --stale` runs clean (uses `.venv`, no pyyaml WARN, no traceback)
- typos / `bash -n` / `py_compile` / YAML — clean

## Open items / follow-ups
1. **`feat/taxonomy-adoption → dev` integration PR — MERGED (#24, `f7aa58e`).**
   AC-0013 + AC-0014 + pyyaml fix are now on `dev`. Local checkout still on
   `feat/taxonomy-adoption`; next work should happen on `dev`.
2. **Release cutover (`dev → main`)** — the next step, via the release process.
3. **Projects-space / previous-art import (DEFERRED)** — the `projects/<context>/`
   (CTX-) plane and Q5 seed runbook exist and are wired into mdBook, but
   `Current contexts` is `_None yet_`. No real context adopted yet. When a real
   context is adopted, use `adopt-project-context.md`.
   - **Bench-model note (corrected):** `.01`, `.00`, `.02+` are git **worktrees on
     branches of one management repo** (ADR-0007). Customer repos are **cloned into
     `.00` and gitignored by `.01`** (ADR-0006/0028) — a nested, ignored checkout,
     not a separate repo.
   - **Customer binaries (SVG/.pptx) blocked by security-reviewer** is correct — do
     NOT commit them to `.01`/`main`. Keep customer work product in the `.00`
     customer checkout (gitignored), and reference (not copy) from `.01`.
     Seed only reviewable, harness-owned textual docs into `projects/<context>/`.
     `.00` content requires per-action HIL direction (Invariant 7). *Needs content
     classification + HIL direction before any work.*

## Next steps (in order)
1. `dev → main` release cutover via the release process (PR #24 landed on `dev`).
2. (Deferred) Projects-space migration when a real context is adopted (Q5).

## Notes
- GPG signing needs the key passphrase cached (pinentry; unlock with
  `echo test | gpg --clearsign >/dev/null`).
- Review ledger `findings.yaml` is gitignored (machine-local); `reviewer-log.yaml`
  is committed.
