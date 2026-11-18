# Session State — 2026-11-18 (taxonomy adoption / AC-0013 + AC-0014 completion)

Per-session resume note (tracked). Read at session open to restore focus before
checking `tasks.yaml`. See `.core/work/README.md` for the schema.

## Branch / position
- Repo: `/home/sworley/files/sandbox/AgenticCore.v1.01/AgenticCore`
- Branch: `feat/taxonomy-adoption` — **in sync** with `origin/feat/taxonomy-adoption` (HEAD `04cd780`)
- Working tree: clean; all AC-0013/AC-0014 commits GPG-signed (`[AC-0013]` / `[AC-0014]`)
- Integration target: `dev` (next release); `main` is merge-only (ADR-0004)

## Session outcome — taxonomy adoption (AC-0013) + shipping-gate wiring (AC-0014) complete
The documentation-and-knowledge taxonomy adoption (ADR-0029 Q5 / AC-0013) and the
`allowed_in_adopter_repos` → `export-framework.sh` shipping-gate wiring (AC-0014)
are complete on the feature branch:

- **AC-0013** — taxonomy adopted to a clean, merge-ready state.
  - ID namespaces retired (`DKT` / `ACT-` / `PROPOSAL-`);
    activities tie to `AC` tickets via `source_ticket`.
  - ADR-0030 forward-only + historical coexistence; ADR-0029 reconciled.
  - ADR-0031 (project contexts / `CTX-`), ADR-0032 (classification ID contracts),
    ADR-0033 (project context adoption / Q5 seeding) — all **accepted**.
  - `reconcile-metadata-registry.py` (SH-0028) + §8.1 classification-ID registry;
    `--check` gate. No-em-dash durable rule + repo-wide sweep.
- **AC-0014** — `allowed_in_adopter_repos` wired to shipping (**accepted**).
  - **Stage 1**: exclude one-shot bootstrap tools `setup/adopt.sh` +
    `export-framework.sh`. **Stage 2**: flag is authoritative/fail-closed.
  - Governance folded into **ADR-0015 D-9** (amendment, mirroring D-7/D-8);
    **ADR-0034** superseded (folded into D-9).
  - Reclassified 15 shipped scripts to class 2 / `true`; bootstrap + seed stay `false`.
  - **W1** (fail-closed gate), **W2** (honor `.md` script-doc frontmatter),
    **W3** (synced 12 stale doc frontmatter) all addressed; `reconcile-metadata-registry.py`
    now checks SH script-doc vs `.meta.yaml` drift.

## Commits this session (newest first)
| Commit | Scope |
|---|---|
| `04cd780` | fix(export): harden allowed_in_adopter_repos gate (W1/W2/W3) [AC-0014] |
| `72c9790` | docs(review): record AC-0014 review sign-off + accept [AC-0014] |
| `076045a` | docs(adr): fold AC-0014 Stage 2 into ADR-0015 D-9 (reconcile) [AC-0014] |
| `df1cb4c` | feat(export): allowed_in_adopter_repos authoritative (AC-0014 Stage 2) |
| `90fd06e` | feat(export): exclude adopt.sh + export-framework.sh (AC-0014 Stage 1) |
| `976306b` | docs(session): save AC-0013 session state |
| `fc64907` | docs(ac-0013): record review sign-off + accept ticket |
| `44827e2` | feat(metadata): extend registry reconcile to SDX/REF/STD/SEED |

Full history: `git log --oneline origin/dev..HEAD`.

## Recorded reviews
- **AC-0013**
  - docs-reviewer: `RR-2026-11-17-01` — **approved_with_notes** (5 notes resolved)
  - security-reviewer: `SR-2026-11-18-01` — **clean** (hooks sweep cosmetic, no secrets)
- **AC-0014**
  - docs-reviewer: `RR-2026-11-18-01` — **approved_with_notes** (ADR-0034 covered via index)
  - security-reviewer: `SR-2026-11-18-02` — **approved_with_notes** (Baseline/Tier 1;
    injection-safe, D-7 untouched, surface narrowed; W1/W2/W3 notes since resolved)

## Validation (all green)
- `check-links.sh` — 497 OK, 0 em-dashes
- `mdbook build` — passes
- `reconcile-metadata-registry.py --check` — exit 0 (28 SH + 20 SH script-docs + 8 classification IDs)
- `test-export-framework-severance.sh` — 39 PASS / 0 FAIL (excludes setup/adopt.md)
- `test-adopt-target-handling.sh` — 16 PASS / 0 FAIL
- typos on changed docs — clean; hooks `py_compile`, `bash -n`, YAML valid

## Open items / follow-ups (non-blocking)
1. **Taxonomy → `dev` integration PR** — branch is ready to integrate to `dev` for
   the next release (HIL-gated; `main` merge-only per ADR-0004). This is the next gate.
2. **ADR-0015 D-9 HIL note** — the D-9 amendment is recorded; acceptance was via the
   AC-0014 review runs (approved_with_notes, no blocking findings). If a separate
   ADR-0015 D-9 acceptance pass is required by governance, run it before the `dev` merge.

## Next steps (in order)
1. Prepare `feat/taxonomy-adoption → dev` PR for HIL review/merge.
2. Then `dev → main` release cutover via the release process.

## Notes
- GPG signing needs the key passphrase cached (pinentry; unlock with
  `echo test | gpg --clearsign >/dev/null`).
- Review ledger `findings.yaml` is gitignored (machine-local); `reviewer-log.yaml`
  is committed.
