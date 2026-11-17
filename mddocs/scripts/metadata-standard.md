---
id: STD-0001
title: Script Metadata Standard
document_type: standard
status: active
lifecycle: active
domain: Management
category: Governance
process: script-metadata
owner: lead-engineer
related:
  paths:
    - ../management/governance/decisions/ADR-0029-documentation-taxonomy-adoption.md
    - ../management/work/activities/act-dkt-0002-taxonomy-reconciliation/index.md
---

# Script Metadata Standard

**Purpose.** Codify the annotation contract established by **ADR-0029 D4**
(annotate-first, restructure-later) so that every executable and its companion
documentation under `mddocs/scripts/` is classified consistently, and so that
future scripts, tests, and seed data added to the framework follow the same
contract. Operating rule: **annotate now, restructure later.** Physical
relocation is governed by a future migration ADR, not by this standard.

**Authority.** This is the operational standard; `ADR-0029` is the governing
decision and `ACT-DKT-0002` is the reconciliation evidence.

---

## 1. Stable identifiers (IDs)

IDs are **stable and immutable once published** — independent of title or path
(principle P4). Do not reuse or renumber an ID; reassignment is a deliberate
reclassification (see §7).

| Kind | ID pattern | Example |
|---|---|---|
| Executable (`.sh`/`.py`/`.yaml`) | `SH-NNNN` | `SH-0001` |
| Script documentation sidecar | `<SH-NNNN>-doc` | `SH-0001-doc` |
| Index / overview doc | `SDX-NNN` | `SDX-001` |
| Reference doc | `REF-NNN` | `REF-0001` |
| Seed template | `SEED-<NAME>` | `SEED-BACKLOG` |
| Standard doc | `STD-NNN` | `STD-0001` |

Allocation: take the next free number in the sequence for the kind. The
registry in §8 is the navigation aid; each artifact's own `.meta.yaml` /
frontmatter is authoritative.

---

## 2. Executable metadata (`.meta.yaml` companion)

An executable that cannot carry YAML frontmatter natively (`.sh`, `.py`,
`.yaml`) gets a `.meta.yaml` companion in the **same directory**, using the
same field contract as frontmatter. The companion is clean single-document YAML
(no `---` delimiters).

| Field | Required | Value / enum |
|---|---|---|
| `id` | yes | `SH-NNNN` (stable) |
| `title` | yes | human-readable |
| `document_type` | yes | `script` |
| `status` | yes | `active` \| `template` \| `superseded` \| `retired` |
| `lifecycle` | yes | `active` \| `template` \| `shared` \| `superseded` \| `retired` |
| `domain` | yes | `Management` \| `Projects/<context>` |
| `category` | yes | `Operations` \| `Security` \| `Agentic` \| `Architecture` \| `Adoption` \| `Governance` \| `Testing` |
| `process` | yes | workflow slug it participates in |
| `owner` | yes | agent role from `.agents/_meta.yaml` |
| `allowed_in_adopter_repos` | yes | `true` \| `false` (default `false`) |
| `enforces` | no | `ADR-XXXX` — only for governance-enforcement scripts |
| `source_activity` | no | `ACT-XXXX` — only for project-activity scripts |
| `source_context` | no | `<context>` — only for project-activity scripts |
| `migrated_from` | no | path — only when `lifecycle: shared` |
| `related.paths` | no | relative paths to docs it is documented by or governs |

---

## 3. The four classes

Scripts are governed metadata, not directory placement. Each falls into one
class; the class drives the distinctive fields.

| Class | `domain` | `allowed_in_adopter_repos` | Distinctive fields |
|---|---|---|---|
| **1. Harness-owned tooling** | `Management` | `false` | — |
| **2. Harness-provided general-use** | `Management` | `true` | logically available to projects |
| **3. Project-activity script** | `Projects/<context>` | `false` | `source_activity`, `source_context`, `lifecycle: activity-scoped` or `shared` |
| **4. Governance enforcement** | governed by mandating ADR | `false` | `enforces: ADR-XXXX` as primary identity |

A project-activity script that graduates to general use becomes `lifecycle: shared`
with `migrated_from` recorded; the physical move is a metadata-lifecycle change,
not a new file.

---

## 4. `allowed_in_adopter_repos` semantics

- `true`: harness-provided, supported for use in an adopted workspace (ships as
  part of the adoption surface).
- `false`: not part of the shipped, supported adoption surface — harness
  orchestration, internal state, or a one-shot bootstrap not meant to be re-run
  from inside an adopted workspace.

**Important:** this is a **descriptive governance/documentation contract**, not
an access control or permission. It never forbids use. The *physical* gate for
what ships into an adopter repo is `export-framework.sh`'s
`FRAMEWORK_EXCLUDE_PATTERNS` — this flag does **not** currently drive shipping.

---

## 5. Companion documentation `document_type`

| `document_type` | Used for |
|---|---|
| `script-docs` | `.md` sidecar documenting a single executable (inherits domain/owner/category/process) |
| `index` | directory index / overview of a script group |
| `reference` | config / reference doc not tied to one executable |
| `backlog` | backlog seed template (D6, `primary: false` + `redirect`) |
| `seed-template` | provisioned-workspace template |
| `standard` | this standard / other governing reference |

---

## 6. Out of scope for this standard

- Physical relocation of scripts or docs (future migration ADR).
- Any change to `export-framework.sh` shipping behaviour.
- ADR-0015 (adoption model) semantics.
- `mddocs/scripts/seed/` provisioning templates' runtime behaviour.

---

## 7. Workflow: adding and reclassifying

### Add a new script
1. Create the script under the appropriate `mddocs/scripts/` subdirectory.
2. Allocate the next `SH-NNNN`.
3. Add a `.meta.yaml` companion (or frontmatter if natively supported).
4. Add an `SDX`/index entry if it belongs to a script group.
5. Reference it from the relevant runbook / `SUMMARY.md` if applicable.

### Reclassify a script (D3 — case-by-case)
1. Identify the change (class, `owner`, `category`, `allowed_in_adopter_repos`,
   `enforces`, `process`, etc.).
2. Edit the artifact's `.meta.yaml` / frontmatter on a branch.
3. Record the change and rationale (in the ticket/activity or a changelog).
4. Review and merge to `dev`. **No new ADR required** for a single
   reclassification — classification is adjustable data, not schema (see §9).
5. A change to the **schema/contract** itself (field set, enums, class set, or
   the meaning of a field) requires an **ADR amendment** to `ADR-0029`.

---

## 8. Registry (current allocation)

| ID | Executable | Class | Owner | `allowed_in_adopter_repos` | `enforces` |
|---|---|---|---|---|---|
| SH-0001 | `bench-status.sh` | 1 | ops-engineer | false | — |
| SH-0002 | `provision-bench.sh` | 2 | ops-engineer | true | — |
| SH-0003 | `check-env.sh` | 2 | ops-engineer | true | — |
| SH-0004 | `check-links.sh` | 2 | docs-engineer | true | — |
| SH-0005 | `check-worktree-hygiene.sh` | 1 | ops-engineer | false | — |
| SH-0006 | `git-sync.sh` | 2 | ops-engineer | true | — |
| SH-0007 | `export-framework.sh` | 4 | release-engineer | false | ADR-0015 |
| SH-0008 | `read-audit-log.sh` | 1 | security-engineer | false | — |
| SH-0009 | `statusline-command.sh` | 1 | orchestrator | false | — |
| SH-0010 | `sync-agent-config.sh` | 1 | lead-engineer | false | — |
| SH-0011 | `setup/adopt.sh` | 1 | release-engineer | false | — |
| SH-0012 | `setup/model-distribution.sh` | 2 | lead-engineer | true | — |
| SH-0013 | `setup/phase2-dev-toolchain.sh` | 1 | infra-engineer | false | — |
| SH-0014 | `setup/python-env.sh` | 2 | ops-engineer | true | — |
| SH-0015 | `setup/tool-adapter.sh` | 2 | lead-engineer | true | — |
| SH-0016 | `setup/toolchain.sh` | 2 | infra-engineer | true | — |
| SH-0017 | `setup/verify-toolchain.sh` | 2 | infra-engineer | true | — |
| SH-0018 | `mcp-tests/run-all.sh` | 1 | ops-engineer | false | — |
| SH-0019 | `mcp-tests/test-mcp-filesystem.sh` | 1 | ops-engineer | false | — |
| SH-0020 | `mcp-tests/test-mcp-git.sh` | 1 | ops-engineer | false | — |
| SH-0021 | `mcp-tests/test-mcp-rag-docs.py` | 1 | ops-engineer | false | — |
| SH-0022 | `update-summary-on-adr-write.py` | 1 | docs-engineer | false | — |
| SH-0023 | `test-adopt-target-handling.sh` | 1 | release-engineer | false | — |
| SH-0024 | `test-export-framework-severance.sh` | 1 | security-engineer | false | — |
| SH-0025 | `test-provision-bench-substitution.sh` | 1 | ops-engineer | false | — |
| SH-0026 | `seed/bench-registry.yaml` | 1 | ops-engineer | false | — |
| SH-0027 | `seed/tasks.yaml` | 1 | lead-engineer | false | — |

> Note: the generated per-file `.meta.yaml` metadata is authoritative over this
> table. Reconcile the table here whenever a classification changes.

---

## 9. References

- **ADR-0029** — `mddocs/management/governance/decisions/ADR-0029-documentation-taxonomy-adoption.md` (governing decision; D4).
- **ACT-DKT-0002** — `mddocs/management/work/activities/act-dkt-0002-taxonomy-reconciliation/index.md` (reconciliation evidence).
