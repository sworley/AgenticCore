````markdown
## Bug: adoption does not propagate the adopted workspace identity into documentation

**Component:** Harness adoption / documentation generation  
**Suggested priority:** Medium  
**Status:** Confirmed in the adopted workspace  
**Example adopted name:** `AgenticTeam.v1`

### Summary

Adoption accepts a new project/workspace name, but the resulting documentation continues presenting itself as **AgenticCore** rather than the adopted workspace.

The documentation identity should be the capstone of adoption: a workspace adopted as `AgenticTeam.v1` should identify its documentation as **AgenticTeam.v1 documentation**.

### Observed evidence

In the newly adopted workspace:

| Location | Current content |
|---|---|
| `mddocs/book.toml` — title | `AgenticCore` |
| `mddocs/book.toml` — description | `Documentation for AgenticCore…` |
| `mddocs/index.md` — heading | `AgenticCore — Portable Agentic Framework` |
| `mddocs/index.md` — introduction | Describes the repository as the reusable framework rather than the adopted workspace |

The adoption script documents `--target` as the adopter’s **base project name**, then appends `.01` for the management bench. The documentation does not reflect that base identity.

### Reproduction

1. Adopt the harness with a base target name of `AgenticTeam.v1`.
2. Open the resulting `AgenticTeam.v1.01` workspace.
3. Inspect `mddocs/book.toml` and `mddocs/index.md`.
4. Observe that the documentation still identifies itself as AgenticCore.

### Expected behavior

For an adoption named `AgenticTeam.v1`:

- Book title: **AgenticTeam.v1 documentation**
- Book description: identifies the adopted workspace.
- Documentation landing page: **AgenticTeam.v1 documentation**
- Workspace-facing introductory text and navigation: consistently use the adopted identity.

The same behavior must apply to **whatever name was supplied at adoption**, not a hard-coded replacement.

The identity is the supplied **base name**, not:
- the `.01` management-bench name;
- the ticket slug, such as `ADST`;
- the source framework name.

### Impact

- Adoption appears incomplete.
- Users and agents can mistake adopted workspace documentation for framework-development documentation.
- Ownership and purpose of the documentation become ambiguous.
- The ambiguity complicates later project-documentation and migration decisions.

### Recommended patch approach

1. Capture the adopted base name **before** appending the management-bench suffix.
2. Make that value the canonical documentation display identity.
3. Render adopter-facing book metadata and landing-page text from templates using that identity.
4. Preserve the identity across subsequent framework refreshes.
5. Preserve genuine **AgenticCore** references where they describe framework provenance, specifications, historical decisions, or upstream components.

**Do not perform a global search-and-replace of `AgenticCore`.** Distinguish the adopted workspace’s identity from the framework it uses.

Illustrative resulting metadata:

```toml
[book]
title = "AgenticTeam.v1 documentation"
description = "Documentation for the AgenticTeam.v1 workspace."
src = "."
```

Illustrative landing page:

```markdown
# AgenticTeam.v1 documentation

Documentation for the AgenticTeam.v1 workspace, using the AgenticCore harness.
```

### Acceptance criteria

- [ ] Fresh adoption uses the supplied base name throughout adopter-facing documentation identity.
- [ ] `AgenticTeam.v1` produces **AgenticTeam.v1 documentation**, not `AgenticTeam.v1.01 documentation`.
- [ ] A base name that itself ends in `.01` retains that suffix; only the separately appended bench suffix is excluded.
- [ ] Project slug and display identity remain separate.
- [ ] Names are safely escaped for TOML and Markdown.
- [ ] Framework provenance and historical references remain accurate.
- [ ] Refreshing the harness does not restore upstream branding over the adopted identity or overwrite unrelated user documentation.
- [ ] Adoption dry-run remains non-mutating.
- [ ] Documentation builds successfully and changed links pass validation.

### Scope boundary

**This bug addresses adopted documentation identity only.**

Project taxonomy, migration destinations, and importing prior workspace content are separate decisions. Renaming the documentation does not, by itself, resolve those questions.

**Handoff status:** Diagnosis documented; recommended implementation approach supplied. No files changed or patch applied.
````
