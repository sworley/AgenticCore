# Session State — 2026-11-18 (taxonomy adoption / AC-0013 completion)

Per-session resume note (tracked). Read at session open to restore focus before
checking `tasks.yaml`. See `.core/work/README.md` for the schema.

## Branch / position
- Repo: `/home/sworley/files/sandbox/AgenticCore.v1.01/AgenticCore`
- Branch: `feat/taxonomy-adoption` — **in sync** with `origin/feat/taxonomy-adoption` (HEAD `fc64907`)
- Working tree: clean; all commits GPG-signed `[AC-0013]`
- Integration target: `dev` (next release); `main` is merge-only (ADR-0004)

## Session outcome — taxonomy adoption carried to a clean, merge-ready state
The documentation-and-knowledge taxonomy adoption (ADR-0029 Q5 / AC-0013) is
complete on the feature branch:

- **ID namespaces retired**: `DKT` / `ACT-` / `PROPOSAL-`; activities tie to `AC`
  tickets via `source_ticket`.
- **ADR-0030** forward-only + historical coexistence; **ADR-0029** reconciled;
  change-discipline + management guardrails codified in `CONTRIBUTING.md`.
- **management/** + **projects/** planes (lowercase), hooks/indexes aligned.
- **ADR-0031** (project contexts / `CTX-`), **ADR-0032** (classification ID
  contracts), **ADR-0033** (project context adoption / Q5 seeding) — all **accepted**.
- **Adopt-a-project-context** runbook + plane-boundary guidance (resolves the
  import-friction gap: no `.02+` bench, actionable Invariant 7).
- **Metadata registry reconcile tool** (`reconcile-metadata-registry.py`, SH-0028)
  + §8.1 classification-ID registry; `--check` gate.
- **No-em-dash durable rule** + repo-wide sweep (2,344 → 0); `check-links.sh`
  em-dash guard.

## Commits this session (newest first)
| Commit | Scope |
|---|---|
| `fc64907` | docs(ac-0013): record review sign-off + accept ticket |
| `44827e2` | feat(metadata): extend registry reconcile to SDX/REF/STD/SEED |
| `5c5c88a` | chore(docs): no-em-dash rule + repo-wide sweep |
| `fbe1541` | feat(metadata): add metadata registry reconcile tool (SH-0028) |
| `25343c0` | docs(contract): resolve docs-review findings (5 notes) |
| `560a093` | docs(tasks): correct AC-0013 acceptance criteria (adopt.sh, sidecars) |
| `0745152` | docs(adr): HIL-accept ADR-0033 |
| `56aa8fc` / `0eb3170` | ADR-0033 + Adopt-a-project-context runbook |

Full history: `git log --oneline origin/dev..HEAD`.

## Recorded reviews (AC-0013)
- docs-reviewer: `RR-2026-11-17-01` — **approved_with_notes** (5 notes resolved)
- security-reviewer: `SR-2026-11-18-01` — **clean** (hooks sweep cosmetic, no secrets)

## Validation (all green)
- `check-links.sh` — 496 OK, 0 em-dashes
- `mdbook build` — passes
- `reconcile-metadata-registry.py --check` — exit 0 (28 SH + 8 classification IDs)
- typos on changed docs — clean; hooks `py_compile`, `bash -n`, YAML valid

## Open items / follow-ups (non-blocking)
1. **`allowed_in_adopter_repos` not wired to enforcement** — `export-framework.sh`'s
   `FRAMEWORK_EXCLUDE_PATTERNS` doesn't yet exclude `adopt.sh` (descriptive metadata
   only; operational idempotency concern, not a vuln). Candidate: AC-0014.
2. **Taxonomy → `dev` integration PR** — branch is ready to integrate to `dev` for
   the next release (HIL-gated; `main` merge-only per ADR-0004).

## Next steps (in order)
1. (optional) File AC-0014 to wire `allowed_in_adopter_repos` to `export-framework.sh`
   exclusion.
2. Prepare `feat/taxonomy-adoption → dev` PR for HIL review/merge.
3. Then `dev → main` release cutover via the release process.

## Notes
- GPG signing needs the key passphrase cached (pinentry; unlock with
  `echo test | gpg --clearsign >/dev/null`).
- Review ledger `findings.yaml` is gitignored (machine-local); `reviewer-log.yaml`
  is committed.
