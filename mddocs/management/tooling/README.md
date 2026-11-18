# Tooling

**Top:** [Documentation home](../../README.md)

**Last updated (UTC):** 2026-10-21T16:52Z

**Purpose:** Reusable framework tooling, implementation, schemas, tests,
dependency declarations/locks, documentation scripts, and rendering assets.
**Owner:** UNASSIGNED. Source: [taxonomy](../governance/policies/document-taxonomy.md).

Build and validation source views, commands, prerequisites, and limits are in
[documentation tooling](../runbooks/documentation-tooling.md).
The asset set supplies Mermaid and navigation behavior. Source: `book.toml`
under `[output.html]`; asset origin is recorded in
[creation provenance](../delivery/template-creation.md#provenance).

Exclude dependency directories, caches, generated books, customer collectors,
and historical migration scripts.

Place reusable components here unless another Management subsystem owns them,
such as MCP infrastructure under `management/mcp/`. Put project-specific tooling
under the corresponding project namespace. Installed environments and transient
artifacts stay in approved workspace-local state directories, not the maintained
corpus. This convention does not itself move existing root-level components.
