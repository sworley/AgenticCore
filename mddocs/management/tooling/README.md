---
id: SDX-005
document_type: index
status: active
lifecycle: active
domain: Management
---

# Tooling

**Top:** [Management plane](../index.md)

**Purpose.** Canonical home for reusable framework tooling, implementation,
schemas, tests, documentation scripts, and rendering assets. Each artefact is
classified per the
[script metadata standard](../../scripts/metadata-standard.md), and the registry
(sections 8 and 8.1) is the navigation aid; each artefact's own frontmatter or
`.meta.yaml` companion is authoritative.

## Contents

- `scripts/` - mdBook validation and build helpers (`validate_book.py`,
  `build.sh`).
- `mddoc-assets/` - mdBook navigation rendering assets (collapsible sidebar and
  external-link behavior).
- `project_protection/` - project protection profile schema and its checks.

**Owner:** maintained by the harness. The shipped adoption surface is governed
by ADR-0015 D-9: what ships to an adopter workspace is the
`allowed_in_adopter_repos: true` set, so this tooling is part of the supported
surface.

**Rejected scope (ADR-0032).** The team-workspace provisioning toolchain
(`template-deploy.sh`, `team-adopt.sh`, `adoption_state.py`, `receipt_check.py`,
`create_venv.py`, `install_dependencies.py` and their tests), the git commit
guardrail (`git-hooks/`), the harness dependency locks
(`python/requirements/`), and the project-protection test-requirements pointer
were formally rejected and are not part of this home: they depend on harness
assets (a project `pyproject.toml` and generated lock files) that are not
present in this framework. Only the self-contained, functional artefacts above
were adopted.

Build and validation sources, commands, and prerequisites are in the
[mdBook build runbook](../runbooks/build-publish-mddocs.md).
Mermaid rendering stays wired at the `mddocs/` root per the taxonomy
reconciliation (AC-0013); this home's `mddoc-assets/` supply the sidebar and
external-link navigation behavior, referenced from `book.toml` under
`[output.html]`.

Exclude dependency directories, caches, generated books, customer collectors,
and historical migration scripts.

Place reusable components here unless another Management subsystem owns them,
such as MCP infrastructure under `management/mcp/`. Put project-specific tooling
under the corresponding project namespace. Installed environments and transient
artifacts stay in approved workspace-local state directories, not the maintained
corpus. This convention does not itself move existing root-level components.
