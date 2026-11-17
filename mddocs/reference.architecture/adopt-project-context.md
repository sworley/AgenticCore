# Adopt a Project Context

**Purpose:** Bring an existing project's harness-owned documentation into the
`projects/<context>/` plane (ADR-0029 Q5) without routing it through the heavy
management feature-task ceremony. This is the **"seed a project context"**
operation — distinct from adopting the *framework* into a project's repo
([Bootstrap New Project](bootstrap-new-project.md)).

**Audience:** HIL (boundary decision + LGTM), lead-engineer (coordinates),
docs-engineer (executes), docs-reviewer (gate).

**Governing decision:** [ADR-0033: Project Context Adoption / Q5 Seeding](../management/governance/decisions/ADR-0033-project-context-adoption-q5-seeding.md)

---

## When to use this

Use this when you have **existing project documentation** you want the harness to
own *about* a work context — a customer engagement, COE, AI Accelerator, or other
managed effort — and you're moving it into `projects/<context>/`.

Do **not** use this to:

- Adopt the **framework** into a project's repo. That is
  [Bootstrap New Project](bootstrap-new-project.md) (`export-framework.sh`,
  `--flow empty|rehome`). If you're adopting the framework into an existing
  customer repo *and* seeding its docs, **compose the two** — run the framework
  adoption first, then this runbook.
- Move **customer work product**. Customer source/tools stay in the customer's
  own Git repo (cloned under `.00`, gitignored by `.01` — ADR-0006, ADR-0028).
  This runbook moves *harness-owned documentation about* the context only.

## Step 0 — Classify the boundary (HIL decision)

Before anything moves, the HIL decides what each piece of content is. This is the
step that removes the friction: the content that sparked this whole issue sat on
the seam between "customer work product" and "harness-owned docs about the
context." Make the call explicitly.

| Content is... | Goes to | Nope, it stays... |
|---|---|---|
| **Harness-owned documentation** about the context (activity records, project decisions, durable artifacts, references, evidence) | `projects/<context>/` | — |
| **Customer work product** (source code, customer repo, tools the customer owns) | the customer's own Git repo (in `.00`) | `.01` is gitignored; never copied into the harness repo (ADR-0006) |
| **Harness internals** (framework scripts, governance, runbooks, ADRs) | `management/` | — (unchanged) |

**Rule of thumb:** the harness repo versions *knowledge about* the context, not
*the context's code*. Reference customer code by source location / commit SHA /
links — never copy its files in.

## Step 1 — Confirm the source is `projects/`-eligible and `.00`-governed

If the docs currently live under `.00` (the HIL plane), moving them into the
harness repo is a **per-action HIL direction** — Invariant 7 forbids any agent
from modifying `.00` without an explicit, in-conversation HIL instruction naming
the action. This is **not a wall**; it's a control with an exact next step:

> An agent that is asked to move/copy `.00` content must state the control
> (Invariant 7) and the concrete next step (HIL per-action direction to seed
> `projects/<context>/` via this runbook), then wait for that direction — rather
> than refusing outright or improvising.

If the docs are **already tracked in the harness repo** on a branch, no `.00`
content is involved and you can proceed directly with `git mv`.

## Step 2 — Pick the `CTX` slug

Use the project's existing slug (see ADR-0014 / `bootstrap-new-project.md` slug
rules). The context `index.md` carries `id: CTX-<SLUG>` (uppercase slug).

## Step 3 — Create the context index (lead-engineer)

As a **management-plane documentation operation**, create the context directory
and its mandatory `index.md`:

```yaml
---
schema_version: "1.0"
id: CTX-<SLUG>
kind: context
title: <Human-readable label>
purpose: <controlled term>
status: active
---
```

Required structure (ADR-0031):
- `index.md` — **required**
- `activities/`, `artifacts/`, `decisions/`, `evidence/`, `references/` — **only
  if real content exists**; never seed empty sub-trees speculatively.

## Step 4 — Populate the sub-trees

Route to `docs-engineer` for the actual file moves:

1. **Tracked sources** → `git mv` into the destination sub-tree. Preserve history.
2. **References** → record links, not copies (a referenced authority keeps its
   canonical home; don't duplicate the body).
3. **Activity records** → carry `source_ticket: AC-XXXX` (activities tie to `AC`
   tickets; the `ACT-` namespace is retired). Project-activity scripts carry
   `source_ticket` too (ADR-0032).
4. **Never** copy customer source, secrets, or bulky/sensitive outputs.

## Step 5 — Review (docs-reviewer + HIL LGTM — no bench session)

- The docs-policy standing rules require `docs-reviewer` on any branch that
  creates/modifies `.md` files — invoke it (runs `typos`).
- **No `.02+` worker bench and no "open a session in `.NN` to review" ceremony is
  required for this.** This is a documentation-plane operation, not feature task
  work. The HIL reviews the **diff / branch** and gives LGTM directly, rather than
  being asked to open a client/session in a specific bench to inspect a push.
- The lead-engineer does **not** need to route this as Pattern A feature work with
  a full agentic-team bench review cycle.

## Step 6 — Register and close

- Add the context to `projects/index.md` → **Current contexts** (`CTX-<SLUG>`).
- Confirm the harness repo boundary holds (no customer code, no secrets, no
  generated build output, no duplicated authorities).
- Commit (`[AC-NNNN]` or `[CTX-<SLUG>]`), push, and open/advance the PR for HIL
  acceptance.

## Why this is not a feature task

| | Feature/task work | Project-context seeding |
|---|---|---|
| **Flow** | Pattern A worker bench (`.02+`) | Management-plane documentation operation |
| **Where** | `.02+` bench, branched from `.01` | `.01` / docs branch |
| **Review** | docs-reviewer + agentic-team + HIL opens bench session | docs-reviewer verdict + HIL LGTM on the diff |
| **Owner** | bench-lead agent | HIL-directed, lead-engineer coordinates, docs-engineer executes |

## Related

- [Bootstrap New Project](bootstrap-new-project.md) — framework adoption (greenfield/brownfield); the repo-side prerequisite when adopting the framework into an existing project
- [Projects Plane](../projects/index.md) — the `projects/<context>/` contract and repository boundary
- [ADR-0031](../management/governance/decisions/ADR-0031-project-contexts-ctx-identifiers.md) — context contract and `CTX-` identity
- [ADR-0033](../management/governance/decisions/ADR-0033-project-context-adoption-q5-seeding.md) — the governing decision for this operation
