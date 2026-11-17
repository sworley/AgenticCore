---
document_type: index
status: active
lifecycle: active
primary: true
domain: Projects
purpose: Portfolio plane — durable documentation about adopted work contexts
---

# Projects Plane

> **Plane purpose.** `projects/` holds documentation **about** work performed by
> independently adopted contexts — customer engineering, COE, AI Accelerator,
> investigations, and activities that may not involve software development. It
> is the second plane of the ADR-0029 two-plane taxonomy (`management/` is the
> first).

## Working model

AgenticCore is a **documentation-first, purpose-first** harness. This taxonomy
exists so that knowledge stays discoverable, versioned, and safely reusable as
work changes and historical activities are retired — not to dictate *how* work
is initiated.

You are **free to drive activities the way you want**: a ticket, a backlog item,
a direct initiative, a sprint, or an ad-hoc proof of concept. The framework only
requires that whatever you create is a **properly-identified, purpose-first
documentation object with a stable ID**, and that it sits under a context with
its `index.md`.

In other words, the harness governs **how knowledge is organized, identified,
and versioned** — not **how work originates or is approved**. Work initiation and
approval remain governed by the existing management-plane workflow and your own
process.

## Context grammar

Each adopted context is a directory under `projects/<context>/`:

| Sub-tree | Purpose |
|---|---|
| `index.md` | **Required.** Project identity and navigation |
| `activities/` | Self-contained units of work (`<activity-id>-<slug>/`) |
| `artifacts/` | Durable, purpose-based packages (`<purpose>/<slug>/`) |
| `decisions/` | Project-scoped decisions, as authorized |
| `Evidence/` | Retained assurance records |
| `References/` | Links and references — not copied authorities |

## Stand-up rules (context metadata)

A context's `index.md` uses `kind: context`:

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

## Repository boundary — what belongs in the harness Git repo

The harness repository is the **management layer**: it versions the framework's
own knowledge and tooling, plus the documentation the harness owns **about** a
context. It does **not** hold the customer's work product.

**Belongs in the harness Git repo (tracked, versioned):**

- Management-plane documentation and governance artifacts — ADRs, policies,
  standards, architecture, security, assurance, work activities.
- Harness-owned project documentation **about** a context — `projects/<context>/`
  indexes, activity records, durable artifacts, project decisions, evidence,
  and references.
- Harness tooling and executables (scripts, hooks, enforcement) and their
  companion documentation.
- Release notes, onboarding, reference, and other harness knowledge.

**Does NOT belong in the harness Git repo:**

- **Customer source code.** A customer checkout (e.g. `MyCode/`) is an
  independently owned Git repository, excluded from harness version control.
  Reference it by source location / commit SHA / links — **never** copy its files
  into the harness index.
- **Secrets and credentials.** Never commit credentials, private keys, or
  restricted content (ADR-0016; see the secret-guard runbook). Reference the
  secure store instead.
- **Generated build output.** `mddocs/book/` (mdBook HTML) is build output, not
  source — keep it out of the knowledge taxonomy.
- **Sensitive or bulky outputs.** Restricted customer content, large binaries, or
  runtime output — use Git LFS or approved external storage rather than
  committing them to make an artifact package "self-contained" (proposal §10).
- **Duplicated authorities.** Don't copy a document body that already has a
  canonical home; reference it instead.

## Boundaries

- **No speculative empty folders.** Create `projects/<slug>/index.md` only when a
  real context is adopted (ADR-0029 future action **Q5**). Never pre-create empty
  `activities/`, `artifacts/`, etc.
- **Context before classification (P2).** A context may be a software project,
  customer engagement, COE, AI Accelerator, research initiative, or other
  independently managed effort.
- **Management promotion.** When project results suggest a harness-level
  improvement, submit a proposal/ticket; promotion to management goes only
  through the management-authorized workflow.

## Current contexts

_None yet._ The first `projects/<slug>/` directory is created when the first
adopted context is live (ADR-0029 Q5).
