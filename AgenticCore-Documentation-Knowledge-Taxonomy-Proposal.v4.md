---
id: PROPOSAL-DKT-0001
title: AgenticCore Documentation and Knowledge Taxonomy — ADR Input Proposal
document_type: architecture-proposal
status: proposed
version: "0.4"
date: 2026-11-11
scope: management-and-adopted-projects
intended_audience:
  - baseline-steward
  - lead-engineer
  - docs-engineer
  - security-engineer
  - human-approver
adr_status: not-yet-created
---

# AgenticCore Documentation and Knowledge Taxonomy

> **Status: Proposal for governance review — not an approved ADR or implemented standard.**
>
> **Requested action:** Have AgenticCore review this proposal, reconcile it with current repository structure, adoption contracts, and existing ADRs, then create a new ADR through the authorized management-plane ticket and HIL approval workflow. Do not treat this document as authorization to change guardrails, permissions, existing paths, or customer source.

> **v0.3 reconciliation note:** The adopted deployment directory inventory supplied on 2026-11-11 is incorporated in Appendix A. Existing filesystem paths are observed facts; candidate placements are proposals only.
>
> **v0.4 execution gate:** Planning and implementation must use an authorized, isolated management working branch/worktree. The complete plan and proposed ADR must be presented to the HIL for explicit approval **before any implementation**, including additive structural changes. Approval to plan is not approval to implement. See Appendix B.

## 1. Executive decision request

Establish a **filesystem-authoritative, Git-versioned, purpose-first documentation and knowledge taxonomy** for AgenticCore. The taxonomy lives under one `mddocs/` root, containing `Management/` and `Projects/`. `Management/` documents the harness's design and governance; `Projects/` contains multiple named work contexts, including customer engineering, COE, AI Accelerator, investigations, and activities that may not involve software development.

An adopted AgenticCore deployment has its own harness Git repository and a versioned deployment identity (for example `0.1`). Its management controls and agent-team configuration are governed by the existing management-plane process. Customer code may be checked out separately beneath the adopted workspace in an independently owned Git repository (illustratively `MyCode/`), excluded from harness version control. The harness-owned documentation of work *about* that code is instead captured under `mddocs/Projects/<context>/`. This proposal **does not change** existing authorization or HIL controls.

The recommended model has four independent dimensions:

1. **Context:** Which project/work context owns the knowledge?
2. **Purpose:** Why does the artifact exist (runbook, analysis, COA, decision, reference architecture, presentation, etc.)?
3. **Format:** Which actual files express it (`.md`, `.drawio`, `.pptx`, `.py`, `.sh`, JSON, etc.)?
4. **Lifecycle:** Is it a draft, active, superseded, retired, or otherwise governed item?

**Core rule: classify by purpose, not file extension.** A logical artifact may be a *package* consisting of an `index.md` and any necessary native-format assets. The Markdown entry point holds its durable identity, purpose, metadata, and relationships.

## 2. Scope and boundaries

### In scope

- An explicit management-plane taxonomy and a reusable taxonomy contract for independently adopted project work contexts.
- Stable project, activity, and artifact identity; modest YAML frontmatter; discoverable relationships.
- Activity-local working files; promotion of reusable or durable results; Git-based retirement of obsolete activity content.
- Native supporting assets in Git when appropriate, with purpose-oriented packaging and an index.
- mdBook and prospective Obsidian compatibility, without making either viewer authoritative.
- Low-friction project/activity creation and proportionate validation.
- Independent tracking of harness source version, adopted deployment version, documentation taxonomy version, and optional published artifact version.

### Out of scope

- Redesigning agent roster, bench orchestration, management-plane governance, ticketing, HIL approval workflow, security architecture, or existing MCP/integration controls.
- Granting project agents write access to management-plane policy or customer-owned code.
- Replacing the customer's source-control, change-approval, and release processes.
- Moving existing files or renaming ADRs without a separately approved migration plan.
- Assuming an ignored nested repository is a security control.

### Trust/ownership boundary, explicitly retained

- The **harness repository** versions the management implementation, approved project documentation, activity records, and harness-owned artifacts, subject to existing scoped permissions.
- The **customer repository** is independently versioned, externally controlled, and accessible only via HIL-defined capabilities. Agents may have narrowly scoped read-only credentials. The customer's authoritative code and change process remain with the customer.
- A harness `.gitignore` entry for the nested customer checkout prevents its normally untracked files from being collected by ordinary harness Git operations; it does **not** block filesystem reads/writes, Git commands executed inside the nested repository, or access via other tools. Existing process identity, OS/sandbox boundaries, tool allowlists, credential scope, and approval gates enforce permissions. Avoid force-adding ignored customer content.
- Agent working-directory context informs authorization; changing directory is **not** itself a privilege boundary.
- Harness Git worktrees ordinarily contain harness-tracked files, **not ignored nested customer checkouts**. Worktree paths to customer sources must be explicit and separately authorized; no automatic customer-source replication is assumed.

## 3. Architectural principles (proposed invariants)

**P1. Filesystem authority.** The directory hierarchy under `mddocs/` is the authoritative organizational taxonomy. Frontmatter adds semantics and relationships but must not define a contradictory parallel hierarchy.

**P2. Context before classification.** `mddocs/Projects/<context>/` identifies a durable work context, which may be a software project, customer engagement, COE, AI Accelerator, research initiative, or other independently managed effort.

**P3. Purpose over format.** Directories and artifact identities describe what knowledge *does*, not merely its extension. Format is a property of each asset.

**P4. Stable logical identity.** Project contexts, traceable activities, and durable artifacts have unique stable IDs independent of title, path, or file type. Names and paths can change; identifiers remain stable.

**P5. Activity cohesion; durable-output separation.** Working material stays with its activity. A reusable or enduring result is promoted into a canonical project knowledge/operations/assurance/delivery location only when accepted. Do not duplicate authoritative content.

**P6. Controlled extensibility.** A small common structural contract is mandatory; specialized categories and child folders are optional and created as needed. New work types must not require top-level taxonomy changes.

**P7. Versioned evolution.** Git records revisions; harness source, adopted deployment, taxonomy schema, and published artifact versions are distinct identities. Applicability and effective dates matter when standards change.

**P8. Explicit relationships.** Preserve links from durable results to originating activities, ADRs, tickets, source revisions, reviews, and evidence where applicable. Retired origins may be referenced via small retained tombstones/catalog entries.

**P9. Proportionate metadata.** Require rich metadata for an independently managed artifact *package*, not for every supporting Markdown paragraph or attachment. Make the ordinary path easy.

**P10. Existing authority prevails.** Taxonomy changes do not silently override existing AgenticCore ADRs, access boundaries, approval procedures, or source-ownership controls.

## 4. Proposed physical taxonomy

This is a **logical baseline**, not an instruction to create every empty directory or migrate immediately. The `Management/` taxonomy is **explicitly proposed below** (not assumed implemented). It must be reconciled with established AgenticCore paths before implementation.

```text
<adopted-workspace>/
├── .git/                             # Harness-owned Git repository
├── .gitignore                        # Excludes customer checkout(s), secrets, runtime output
├── .agents/                          # Existing harness structures (illustrative)
├── .core/
├── ...
├── mddocs/                           # One canonical documentation root
│   ├── index.md
│   ├── Management/                  # Harness-specific authority and knowledge
│   │   ├── index.md
│   │   ├── Work/                     # Harness improvement work and investigations
│   │   ├── Governance/               # ADRs, standards, policies, exceptions
│   │   ├── Architecture/             # Harness architecture and design
│   │   ├── Agentic/                  # Agent teams, personas, orchestration
│   │   ├── Security/                 # Trust boundaries and guardrail design
│   │   ├── Operations/               # Harness runbooks and procedures
│   │   ├── Assurance/                # Reviews, audits, evidence
│   │   ├── Delivery/                 # Releases and adoption guidance
│   │   └── Reference/                # Supporting knowledge and resources
│   └── Projects/                    # Portfolio of work contexts
│       ├── index.md
│       ├── MyCode/                   # Documentation about customer-code activities
│       │   ├── index.md
│       │   ├── Activities/
│       │   ├── Artifacts/
│       │   ├── Decisions/
│       │   ├── Evidence/
│       │   └── References/
│       ├── COE/
│       │   ├── index.md
│       │   ├── Activities/
│       │   └── Artifacts/
│       └── AI-Accelerator/
│           ├── index.md
│           ├── Activities/
│           └── Artifacts/
└── MyCode/                           # Customer-owned nested Git repository; ignored
    ├── .git/
    └── ...
```

### 4.1 Canonical management-plane taxonomy — explicit deliverable

**This management structure is part of the requested decision and implementation scope.** It is not a placeholder and must not be deferred by treating management documentation as already standardized. The management plane documents **AgenticCore itself**—the harness's engineering evolution, governance, policies, team architecture, security posture, operations, and adoption—not the customer work performed by adopted project benches. Actual enforcement artifacts (for example executable policies, agent definitions, runtime code, and tests) remain in their established harness locations; `mddocs/Management/` documents and references them, rather than duplicating executable authority.

```text
mddocs/Management/
├── index.md                         # Plane purpose, scope, ownership, navigation
├── Work/                            # Time-bounded harness-management work
│   ├── Activities/                  # TKT/ADR-linked enhancements and investigations
│   │   └── <activity-id>-<slug>/
│   │       ├── index.md
│   │       └── ...                   # COAs, experiments, analysis, review notes
│   └── Initiatives/                 # Optional multi-activity efforts
├── Governance/                      # Authoritative management *documentation*
│   ├── Decisions/                   # ADRs; retain existing canonical ADR paths
│   ├── Policies/                    # Policy intent, applicability and references
│   ├── Standards/                   # Required conventions and effective versions
│   └── Exceptions/                  # Approved deviations, scope, expiration
├── Architecture/                    # Design of the harness itself
│   ├── System/                      # Planes, integration and execution architecture
│   ├── Interfaces/                  # Contracts, adapters and integration boundaries
│   └── Patterns/                    # Reusable harness architectural approaches
├── Agentic/                         # Agent-team operating model
│   ├── Roles/                       # Role intent and authoritative config links
│   ├── Personas/                    # Persona behavior/ownership references
│   ├── Orchestration/               # Bench delegation and coordination
│   └── Context/                     # Context/memory and retrieval guidance
├── Security/                        # Management security architecture
│   ├── Trust-Boundaries/            # Scope, isolation and execution boundaries
│   ├── Guardrails/                  # Guardrail design and enforcement references
│   ├── Access-Control/              # Permissions, identity, credential scope
│   └── Threat-Models/               # Risks, mitigations and assumptions
├── Operations/                      # Running and maintaining the harness
│   ├── Runbooks/                    # Operator tasks and recovery
│   ├── Procedures/                  # Repeatable management processes
│   └── Observability/               # Telemetry, diagnostics, monitoring
├── Assurance/                       # Proof that controls and changes work
│   ├── Reviews/                     # Architecture/security/docs reviews
│   ├── Audits/                      # Audit planning and source reviews
│   ├── Evidence/                    # Verifiable validation/approval records
│   └── Findings/                    # Defects, risks and follow-up references
├── Delivery/                        # Harness distribution and adoption
│   ├── Releases/                    # Baselines, compatibility and change notes
│   ├── Adoption/                    # Adopt/re-home behaviors and contracts
│   └── Handoffs/                    # Operator and adoptee handoff packages
└── Reference/                       # External references, indexes, prior art
```

**Directory rules:** The displayed leaf folders are permitted categories, not an instruction to create them all immediately. `Management/index.md` is required; `index.md` is required for managed activities, initiatives, and artifact packages. Other category indexes are created when populated or needed for mdBook navigation. Management-specific standards, runbooks, research, diagrams, and release materials may be packaged as purpose-based artifacts within their owning category, with co-located native assets. If an additional `Artifacts/` collection is desired later, it must not create a second authoritative home for the same material.

**Management placement rules (deterministic examples):**

| Material | Canonical destination principle |
|---|---|
| Harness ADR | `Governance/Decisions/` **or existing canonical ADR path pending migration approval** |
| Guardrail requirement and effective date | `Governance/Policies/` or `Governance/Standards/`, depending on authority |
| Guardrail threat model or enforcement design | `Security/Threat-Models/` or `Security/Guardrails/` |
| Agent role/persona explanation | `Agentic/Roles/` or `Agentic/Personas/`; link to executable definitions |
| Bench orchestration design | `Agentic/Orchestration/`; reference implementation under harness config/runtime |
| Harness taxonomy standard | `Governance/Standards/` once approved; draft stays in authorized management work intake |
| Change to adoption workflow | `Delivery/Adoption/`; governance rationale remains in ADR |
| Harness operator runbook | `Operations/Runbooks/`, with supporting scripts in the same package if appropriate |
| Research into a new guardrail or architecture | `Work/Activities/<id>/` while exploratory; promote approved outputs by purpose |
| Review of a proposed management change | `Assurance/Reviews/`; controlled evidence in `Assurance/Evidence/` |

**Governance is not just another artifact type:** Management ADRs, policies, standards and exceptions may have established numbering, approval, effective-date and supersession contracts. This proposal adds a consistent *documentation taxonomy* without replacing those contracts. Management-plane agents must use the existing authorized ticket/HIL workflow for any structural changes; project-scoped agents cannot create or modify management objects merely because paths are visible.

**Management metadata illustration:**

```yaml
---
schema_version: "1.0"
id: MGT-ART-0001
kind: artifact
title: AgenticCore Adoption Operations Runbook
purpose: runbook
status: proposed
scope: management
owner: baseline-steward
relationships:
  decisions: []
  tickets: []
implementation_refs:
  - path: tooling/                 # Illustrative; resolve against actual repo
assets:
  - path: index.md
    format: markdown
    role: primary
---
```

`scope: management` is illustrative additional metadata; it never grants management authority. For approved governance objects, the corresponding ADR/policy standard determines any extra required fields and valid lifecycle statuses. The example ID is not an allocated ticket, ADR, or real existing artifact.

### 4.2 Cross-plane mapping and ownership

Management and Projects **share the metadata grammar and organizing principles**, not identical category trees or equal privileges.

| Knowledge concern | Management plane | Project work contexts |
|---|---|---|
| Time-bounded work | `Work/Activities/` | `<context>/Activities/` |
| Architectural knowledge | `Architecture/` (harness) | `<context>/Artifacts/Architecture/` (project) |
| Decisions | `Governance/Decisions/` (harness ADRs) | `<context>/Decisions/` (project-scoped decisions) |
| Runbooks/processes | `Operations/Runbooks/` and `Procedures/` | `<context>/Artifacts/Runbooks/` and `Processes/` |
| Evidence/reviews | `Assurance/` (harness assurance) | `<context>/Evidence/` and relevant activity artifacts |
| Research | `Work/Activities/` while exploratory; promoted by purpose | `<context>/Activities/` while exploratory; promoted by purpose |
| Distribution | `Delivery/` (harness releases/adoption) | `<context>/Artifacts/Deliverables/` or `Reports/` |
| References | `Reference/` | `<context>/References/` |

When project results suggest a harness-level improvement, the project may submit a **proposal** or ticket; management promotion must occur only through the management-authorized workflow. Do not place customer-specific records into Management by default, and do not put management policies under a customer project simply because a project uses them. Relationship metadata should reference the governing management object instead.

### 4.3 Management compatibility and migration gates

1. **Inventory first:** Identify actual existing locations for ADRs, reference architecture, runbooks, policies, agent definitions, mdBook pages and governance records. Distinguish tracked documentation from executable controls.
2. **Map rather than overwrite:** Produce an old-path → proposed-category mapping and identify ambiguous documents for HIL review. A suggested category is not approval to move a file.
3. **Honor approved paths:** If the current approved ADR taxonomy requires `mddocs/adr/` or another canonical path, continue using it until an authorized ADR/migration changes that contract. Do not silently fork ADRs into a parallel directory.
4. **Plan link and identity continuity:** Retain ADR IDs, ticket IDs, git provenance, relative links, mdBook `SUMMARY.md` entries, and cross-plane references; validate redirects or references where tools support them.
5. **Phase adoption:** Author the management taxonomy specification and templates first, introduce advisory validation, migrate approved categories in small reviewed changes, and only then enforce new-location rules for newly created management material.
6. **Keep authority intact:** A taxonomy migration must not change directory permissions, security controls, session boundaries, agent tool permissions, or HIL gate requirements. Management-only operations remain management-only.

**Minimum management-plane deliverables for the initial governance cycle:** an explicitly reviewed management tree, category placement rules, current-to-target mapping, documented compatibility exceptions, and management-specific validator tests. Project taxonomy approval by itself is **not** acceptance of the management taxonomy work.

### 4.4 Canonical project-context grammar

```text
mddocs/Projects/<context>/
├── index.md                  # Required project identity and navigation
├── Activities/               # Optional; self-contained units of work
│   └── <activity-id>-<slug>/
│       ├── index.md          # Required for traceable activity
│       ├── ...               # Activity-specific research, COAs, reviews, POCs
│       └── ...
├── Artifacts/                # Optional; durable, purpose-based knowledge packages
│   └── <purpose>/
│       └── <artifact-slug>/
│           ├── index.md      # Logical artifact identity and asset manifest
│           ├── ...           # Markdown + native assets
│           └── ...
├── Decisions/                # Optional; project-scoped decisions as authorized
├── Evidence/                 # Optional; retained assurance records
└── References/               # Optional; links and references, not copied authorities
```

Examples of **purpose** under `Artifacts/` include `Architecture/`, `Runbooks/`, `Processes/`, `Presentations/`, `Research/`, `Reports/`, `Templates/`, `Scripts/`, and `Deliverables/`. These are **examples, not a compulsory global list**. A runbook package may contain a shell script; a presentation package may contain Markdown and Draw.io files. Avoid splitting one logical artifact solely because its assets have different extensions.

An activity can have local subdirectories like `alternatives/`, `validation/`, `assets/`, `notes/`, or `reviews/`. For a COA comparison, use activity-local `COA-1.md`, `COA-2.md`, `comparison.md`, and `recommendation.md`; a selected and approved result can be promoted to a durable artifact or decision. Do not create a global `COAs/` folder solely to hold every alternative from unrelated activities.

### 4.5 Sample activity and promoted artifact

```text
mddocs/Projects/AI-Accelerator/
├── Activities/
│   └── ACT-0042-Agentic-Memory-POC/
│       ├── index.md
│       ├── problem.md
│       ├── research.md
│       ├── alternatives/
│       │   ├── COA-1.md
│       │   ├── COA-2.md
│       │   └── comparison.md
│       └── validation/
│           └── findings.md
└── Artifacts/
    └── Architecture/
        └── Agentic-Memory-Pattern/
            ├── index.md
            ├── architecture.drawio
            ├── executive-brief.pptx
            └── review.md
```

## 5. Lightweight metadata contract

Use **YAML frontmatter in Markdown `index.md`** as the default representation of metadata. Avoid requiring a second YAML file for the same object. Separate machine-readable manifest files may be added only where tool integration genuinely requires them. The schema should be versioned and validated.

### 5.1 Required at minimum

For an independently managed **context**, **activity**, or **artifact package**:

| Field | Required | Meaning |
|---|---|---|
| `schema_version` | Yes | Frontmatter contract version, independent of harness release |
| `id` | Yes | Stable unique identifier in the adopted workspace |
| `title` | Yes | Human-readable label |
| `kind` | Yes | `context`, `activity`, or `artifact` |
| `purpose` | Yes | Primary intent; concise controlled term with extension rules |
| `status` | Yes | Lifecycle state; defined by schema |

Additional optional fields: `project`, `owner`, `origin_activity`, `relationships`, `assets`, `version`, `effective_date`, `review_date`, `source`, and `tags`. `project` is inherited from the directory when unambiguous but may be explicit for references and exports. For controlled governance artifacts, additional required properties may be imposed by the relevant governance standard.

Do **not** require every note, supporting Markdown file, or binary asset to repeat package metadata. In an artifact package, the `index.md` is authoritative and asset entries carry format/role information.

### 5.2 Example project context

```yaml
---
schema_version: "1.0"
id: CTX-AI-ACCELERATOR
kind: context
title: AI Accelerator
purpose: innovation-work
status: active
---
```

### 5.3 Example activity

```yaml
---
schema_version: "1.0"
id: ACT-0042
kind: activity
title: Agentic Memory Proof of Concept
purpose: proof-of-concept
status: active
project: CTX-AI-ACCELERATOR
relationships:
  tickets: [TKT-0042]
  references: []
---
```

### 5.4 Example multi-format artifact package

```yaml
---
schema_version: "1.0"
id: ART-0042
kind: artifact
title: Agentic Memory Reference Architecture
purpose: architecture
status: active
project: CTX-AI-ACCELERATOR
origin_activity: ACT-0042
version: "1.0"                # Use for formally released/adopted artifacts
relationships:
  decisions: [ADR-0017]       # Validate against existing identifiers
assets:
  - path: architecture.drawio
    format: drawio
    role: primary
  - path: executive-brief.pptx
    format: pptx
    role: presentation
  - path: review.md
    format: markdown
    role: supporting
---
```

The artifact's **purpose** is `architecture`; its files have **formats** such as `drawio` and `pptx`. A `Scripts/` folder is appropriate when a script itself is the published reusable capability, not whenever a supporting script appears inside a runbook package.

### 5.5 Identity and link interoperability

- IDs are immutable once published; validate uniqueness across the scope of the repository.
- Prefer portable relative Markdown links for mdBook and standard Git rendering; Obsidian may consume these links. Wikilinks are optional and should not be required in core metadata because viewer compatibility differs.
- Relationship fields store stable identifiers; a generator or resolver maps IDs to paths and can create indexes/backlinks. Do not assume a raw ID automatically resolves in Obsidian.
- Moving a document requires updating the path index and any path-based links; its durable ID remains unchanged.
- `index.md` is required for meaningful, managed directory objects; ordinary organizational directories can use a lightweight `index.md` for navigation as useful.
- Validate mdBook `SUMMARY.md`/navigation where applicable without assuming mdBook auto-discovers filesystem directories.

## 6. Lifecycle, promotion, and historical retention

### Activity lifecycle

`proposed -> active -> completed -> promoted/closed -> retired` is a **conceptual workflow**, not necessarily a single flat status enum. A minimal status field may use `draft`, `active`, `completed`, `superseded`, and `retired`; promotion is a separately recorded action and can produce multiple durable artifacts.

1. **Create** activity under the owning context with `index.md`, ID, purpose, and optional ticket reference.
2. **Execute** with working research, alternatives, COAs, validation results, scripts, and supporting materials kept together.
3. **Review and promote** enduring outcomes into their canonical destination after the applicable project/management reviews; record origin and source revision.
4. **Close** with any necessary sign-off, status, and retention determination.
5. **Retire** the activity directory from the current Git tree when authorized, after checking retained dependencies and retention requirements.

Git history preserves historical versions **only while that history remains available and is retained**; rewriting history, removing refs, or deleting repositories can eliminate it. Git commit metadata alone is not proof of authenticated authorship or immutable evidence. Formal audit/legal evidence may require protected repositories, signed attestations, retention controls, and separate immutable storage.

### Minimal retirement reference (when needed)

For an activity that produced decisions, adopted patterns, customer-facing deliverables, or persistent links, retain a compact catalog/tombstone Markdown record containing: `id`, original path, last live commit SHA, retirement commit SHA, promotion targets, and retirement reason/date. Determine the final location using existing project reference conventions; do not impose a new permanent global `Catalog/` merely for tombstones.

Note: the deletion commit may be created *after* the pre-retirement content is recorded. A two-step commit or controlled post-commit catalog update can fill the final `retirement_commit` value. Ensure an activity isn't removed before references have been reconciled.

## 7. Versioning and adoption identifiers

Maintain four separate concepts:

| Identity | Example | Purpose |
|---|---|---|
| Harness source version | `AgenticCore 0.7.0` | Framework baseline from which the deployment was adopted |
| Adopted deployment version | `0.1` | Version/identity of the instantiated adopted workspace |
| Taxonomy schema version | `1.0` | Compatibility contract for project structures and metadata |
| Artifact release version | `1.0` | Optional version of a formally published artifact |

Record the **exact source commit SHA** when available; a tag or human-readable version may move or be reused in some workflows. Git commit history tracks ordinary file revisions. Do not increment deployment or artifact release versions for every documentation edit unless an established release policy requires it.

Illustrative adoption metadata (location and actual fields must be reconciled with the existing AgenticCore adoption contract):

```yaml
project:
  slug: ADS
  deployment_version: "0.1"
framework:
  name: AgenticCore
  source_version: "0.7.0"
  source_commit: "<resolved-source-commit-sha>"
documentation:
  root: mddocs/Projects
  taxonomy_version: "1.0"
```

This example documents *desired identity semantics* and is **not** a replacement for an existing adoption manifest or its controls.

## 8. Low-friction authoring and adoption workflow

Success depends on **making the default path easy**. The harness should provide operations conceptually equivalent to:

1. **Adopt framework:** Create a versioned, governed workspace; initialize the harness Git repository; install the standard `mddocs/Management/` and `mddocs/Projects/` baseline consistent with approved adoption contracts. Do not clone or import customer source into the harness Git index.
2. **Create context:** Given a slug and title (`COE`, `AI-Accelerator`, `MyCode`), create `mddocs/Projects/<slug>/index.md` with minimum validated frontmatter. Create no speculative empty child folders.
3. **Create activity:** Given context, title, and purpose, allocate a stable ID and create one self-contained directory with `index.md`. Ticket reference and workflow approvals remain governed by existing AgenticCore requirements.
4. **Create artifact:** Given context, purpose, and optional originating activity, generate an `Artifacts/<purpose>/<slug>/index.md`; register native assets when added.
5. **Promote:** Review a result, place it in one canonical location, record provenance and relationships, and update references. Avoid duplicate authorities.
6. **Retire:** Validate dependents, evidence retention, and approval; record a minimal historical locator when needed; commit deletion under the existing workflow.

**Developer experience target:** The smallest useful operation should require only *context + title + purpose* (and any existing mandatory ticket/approval parameters). Other fields should be derived or optional whenever safe. Prefer templates and validators over agents repeatedly improvising schemas.

## 9. Validation strategy and measurable acceptance criteria

Implement validation in phases. Do not immediately fail existing content for newly introduced rules before migration and approvals.

### Management-specific acceptance tests

1. Inventory current management documentation and produce an old-to-target path map without moving any files.
2. Classify a management ADR, an agent-role reference, an adoption runbook, a guardrail design and a harness improvement experiment without overlapping authoritative homes.
3. Verify approved ADR numbering, existing canonical ADR paths, and management-only approvals remain intact.
4. Package a management runbook with Markdown and a native script/diagram using one primary purpose.
5. Verify no project-scoped agent gains management write access from metadata, links, taxonomy validation, or working-directory changes.
6. Validate mdBook navigation and cross-plane links for approved management changes.

### Phase 1 — Advisory

- Detect unexpected taxonomy paths or missing required `index.md` files for managed objects.
- Check required metadata and valid schema version/status/purpose.
- Detect duplicate IDs; verify registered asset paths exist and stay inside authorized package boundaries.
- Flag broken relative links, unresolved relationship IDs, and mdBook navigation problems.
- Report a migration inventory of existing management and project documents without moving them.

### Phase 2 — Enforced for new/changed objects

- Enforce schema on newly created contexts, activities, and artifact packages.
- Ensure project-scoped agents write only to authorized project documentation and workspace paths; rely on existing hardened enforcement rather than the metadata validator for security.
- Require explicit review for promotion to management-governed shared standards/patterns.
- Apply effective-date and compatibility rules to avoid retroactive invalidation of grandfathered historical content unless an authorized decision specifies otherwise.

### Phase 3 — Lifecycle and relationship automation

- Generate indexes/catalog views from canonical directory content, without creating a second authority.
- Provide promotion and retirement checks and persistent Git history locators.
- Verify that a newly adopted context can be indexed by mdBook and browsed in Obsidian without breaking ordinary Markdown/Git use.

### Acceptance tests

1. Create three contexts (`MyCode`, `COE`, `AI-Accelerator`) with only required metadata and no forced empty sections.
2. Create an activity containing a COA comparison and a POC; find all its working files together.
3. Promote a multi-format architecture package containing Markdown, Draw.io, and PowerPoint under **one purpose-based artifact location**.
4. Confirm asset format metadata and logical artifact identity remain distinct.
5. Record and resolve activity, artifact, ticket, ADR, and source-revision relationships.
6. Retire an activity in Git while preserving accepted durable outputs and a traceable historical locator where required.
7. Confirm a harness Git worktree doesn't contain the ignored customer repository checkout by default.
8. Validate that source content remains outside the harness Git index and unauthorized agent execution lacks customer write/push capability (using existing security controls, not only `.gitignore`).
9. Verify baseline schema compatibility with existing ADRs, **the explicit management taxonomy**, management paths, mdBook navigation, and approved adoption flow.
10. Verify normal authoring requires only the smallest required inputs and produces valid, readable Markdown.

Useful quality measures: number of required user inputs per new activity, schema validation pass rate, duplicate-ID count, broken-link count, unresolved-reference count, artifact promotion traceability, and time to locate a source revision. These measure adoption and quality without making raw document count a goal.

## 10. Migration, compatibility, and decisions not yet settled

Before implementation, the authorized management team should:

1. Inventory actual AgenticCore paths, **current management taxonomy and documentation**, approved ADRs, mdBook configuration, adoption scripts, bench/worktree behavior, and existing project metadata. **Use repository contents as authority over examples in this proposal.**
2. Identify existing canonical management paths (for example, an established ADR directory). Preserve compatibility and stable links; propose aliases or redirects rather than immediate unapproved moves.
3. Confirm which project-level decisions need separate ADRs, which require management review, and which can remain task-level decisions.
4. Confirm namespace rules for `ACT`, `ART`, `CTX`, `ADR`, `TKT` identifiers and whether they are repository-global or prefixed by project context.
5. Define a small controlled purpose vocabulary and an approved extension mechanism; do not hard-code an exhaustive list of work types.
6. Decide whether artifact `status` should be a minimal common enum with type-specific extensions.
7. Confirm whether the adoption contract already records deployment/source/taxonomy versions and how its authoritative metadata is maintained.
8. Define the exact threshold and approval path for promoting project output to management-governed shared knowledge.
9. Define which historical locators/tombstones are mandatory, and how to preserve essential evidence for regulated work.
10. Review handling of binary assets, large files, and secrets: use Git LFS or approved external storage when needed; do not commit credentials, restricted customer content, or sensitive outputs merely to make an artifact package self-contained.

## 11. Proposed ADR framing

**Candidate title:** *Filesystem-Authoritative, Purpose-First Documentation and Knowledge Taxonomy for AgenticCore*.

**Status:** Proposed. Final ADR number assigned by the existing management process.

**Context:** AgenticCore supports a management plane and independently adopted project work contexts. The existing folder labels mix work types, disciplines, artifact purposes, and file formats. Work ranges from code review and customer-support research to COE initiatives, AI Accelerator POCs, runbooks, presentations, and COA evaluations. Knowledge must remain discoverable, versioned, and safely reusable as work changes and historical activities are retired.

**Decision requested:** Adopt the principles in Section 3, the **explicit management-plane taxonomy and cross-plane mapping** plus the canonical project-context grammar in Section 4, minimum metadata contract in Section 5, lifecycle in Section 6, and independent version identifiers in Section 7, subject to validation and compatibility review.

**Considered alternatives:**

- **A. Flat discipline folders at project root:** Simple initially, but scatters one activity across Research/Reports/Runbooks and mixes classification dimensions.
- **B. File-format-only folders:** Convenient by extension, but breaks logical multi-format artifacts and fails to capture primary purpose.
- **C. All outputs remain in activity folders indefinitely:** Preserves context, but makes reuse and eventual retirement difficult.
- **D. Metadata-only virtual taxonomy:** Flexible, but contradicts the requirement that the physical filesystem visibly represent the taxonomy.
- **Recommended E. Purpose-first filesystem with activity cohesion, durable artifact packages, and lightweight metadata:** Balances navigability, portability, reuse, and governance.

**Consequences/tradeoffs:** Stable authoring conventions and automation improve consistency; metadata, link validation, and promotion workflows add some maintenance. Git records history but does not replace security authorization or formal evidence-retention controls. mdBook and Obsidian consumers may require indexing/link adaptation.

**Rollback:** Keep current paths and workflows until migration is approved; introduce validators in advisory mode. Reverting templates/validators does not require rewriting historical commits.

## 12. Requested work package for AgenticCore

On ingest, the authorized agentic team should:

1. Open a management-plane ticket using the existing process and associate it with this proposal.
2. Inventory the **existing management-plane structure**; compare it against Section 4.1, produce a proposed management category map and assess conflicts with approved ADRs, current taxonomy, existing agent roles, and adoption scripts.
3. Draft an ADR **without assigning an arbitrary number**; use the established ADR allocation and HIL approval process. Perform proposal authoring only in an authorized management-scoped branch/worktree, if permitted by existing controls.
4. Split implementation into scoped, reversible tasks: **management taxonomy specification and mapping**; schema/template specification; context/activity/artifact scaffolding; validators; mdBook/Obsidian compatibility; adoption integration; migration planning; tests.
5. Preserve customer-source boundaries, management-plane authority, and all existing HIL checkpoints.
6. Provide an impact assessment, branch/worktree and rollback plan, proposed test evidence, and the complete implementation plan for **explicit HIL plan approval** before implementation. Following approval, execute only the approved scope on the authorized branch, validate, and seek any additional existing review/merge approvals.

**Definition of done for this initial step:** A documented HIL decision on the proposed plan (approval, rejection, or requested changes) and an ADR proposal, **explicit reviewed management-plane taxonomy and placement rules**, reviewed project taxonomy standard draft, management current-to-target mapping, compatibility inventory, and implementation plan exist under the authorized management process. **No automatic repository restructuring or policy relaxation is implied by importing this document.**


---

## Appendix A. Adopted deployment inventory and migration constraints (v0.3)

**Evidence basis:** The directory tree supplied by the operator on 2026-11-11 is the *current adopted output sample*. It has not been interpreted as an exhaustive inventory of hidden files, `.gitignore` contents, actual permissions, the runtime behavior of scripts, or the original upstream repository. Any operational claim requiring inspection of those files must be verified by the authorized AgenticCore session. This appendix supersedes illustrative path assumptions elsewhere in this proposal where they disagree with the supplied tree.

### A.1 Observed structure and implications

- The adopted repository currently has one `mddocs/` root with `SUMMARY.md`, `book.toml`, `index.md`, and `AGENTICCORE_SPEC.md`. **Neither `mddocs/Management/` nor `mddocs/Projects/` appears in the supplied tree.** Both are proposed target constructs, not existing deployed directories.
- Management-relevant documentation already exists at `mddocs/adr/`, `mddocs/reference.architecture/`, `mddocs/onboarding/`, `mddocs/operations/`, `mddocs/examples/`, `mddocs/faq/`, `mddocs/mcp/`, `mddocs/release-notes/`, and various top-level `.md` pages.
- `mddocs/adr/` includes `adr-0000-template.md` and decisions numbered `adr-0001` through `adr-0028`; `mddocs/adr/index.md` is present. **Do not presume the next ADR number**, and do not renumber, rename, move, or duplicate existing ADRs without the established ticket/HIL process.
- `mddocs/book/` appears to contain mdBook-generated HTML, scripts, fonts, and assets. Treat it as a **build-output candidate** pending verification of the actual build configuration and Git tracking. Do not move generated output into the knowledge taxonomy or migrate it as if it were source Markdown.
- `mddocs/scripts/` contains runnable `.sh` and `.py` files, tests, and seed/setup tooling. These are **executable implementation assets**, even though located under the documentation root. Do not rename or relocate them merely to tidy the taxonomy; identify script consumers and path dependencies first.
- Harness-root `tasks.yaml`, `bench-registry.yaml`, `framework-version.txt`, `opencode.json`, `_config/`, `mcp/review-ledger/`, `AGENT.md`, and `PROCESS.md` are established runtime/configuration/process anchors. **The taxonomy change must not redefine or move them by implication.**
- The supplied tree does **not** display the ignored `MyCode/` customer checkout or an existing project-documentation subtree. Their absence from the exported tree is not proof that such paths cannot exist at runtime; verify the adopted workspace and ignore rules before any checks involving customer code.

### A.2 Current-to-proposed management documentation map

This mapping gives AgenticCore a concrete initial classification so that the agent team need not rediscover or redesign categories. A target column denotes a **logical owner**, not approval to move content immediately.

| Current path (observed) | Proposed management category | Safe initial handling |
|---|---|---|
| `mddocs/adr/` | `Management/Governance/Decisions/` | **Preserve canonical directory and ADR filenames**; link/index into proposed taxonomy before approved relocation |
| `mddocs/AGENTICCORE_SPEC.md` | `Management/Architecture/` and governance references | Keep source canonical; classify by actual contents after review |
| `mddocs/reference.architecture/` | `Management/Architecture/`, `Operations/`, `Delivery/`, `Agentic/` | Classify per document purpose; do **not** bulk-move a mixed directory |
| `mddocs/onboarding/` | `Management/Agentic/`, `Operations/Procedures/`, `Delivery/Adoption/` | Preserve existing entry points and onboarding links |
| `mddocs/operations/` | `Management/Operations/` | Candidate for straightforward mapping; verify runbook links |
| `mddocs/examples/` | Primarily `Management/Reference/` or adjacent purpose categories | Keep examples discoverable; preserve cross-links |
| `mddocs/faq/` | `Management/Reference/` or `Operations/` | Maintain the user-facing FAQ as an indexed collection |
| `mddocs/mcp/` | `Management/Architecture/Interfaces/` and `Agentic/` | Distinguish MCP documentation from root `mcp/` implementation |
| `mddocs/release-notes/` | `Management/Delivery/Releases/` | Preserve release/version identities and existing links |
| `mddocs/backlog.md` | `Management/Work/` (reference/index only) | Do not displace authoritative `tasks.yaml` |
| `mddocs/configuration.md` | `Management/Operations/Procedures/` or `Architecture/` | Categorize after reviewing content and callers |
| `mddocs/scripts/` | Implementation tooling, **not automatically documentation** | Keep in place until path/packaging impact is approved |
| `mddocs/book/` | Generated mdBook output (to verify) | Exclude from source taxonomy; confirm Git ignore/tracking/build rules |
| `mddocs/SUMMARY.md`, `mddocs/book.toml`, `mddocs/index.md` | Documentation build/navigation infrastructure | Retain in canonical mdBook locations; update navigation deliberately |
| `mddocs/mermaid-init.js`, `mddocs/mermaid.min.js` | Documentation-rendering assets | Retain until asset loading and rendering verified |

**Decision rule:** A mixed legacy directory can remain intact during transition while an authoritative index maps its documents to their proposed purpose categories. Avoid duplicating document bodies in two locations. If canonical relocation is subsequently approved, update all links, manifests, tests, and consumers as a separately reviewed migration.

### A.3 Project-plane introduction in the existing deployment

The adoption output does not currently show a populated `mddocs/Projects/` tree. Introduce project contexts as an **additive capability**, independently of the management migration:

```text
mddocs/
├── SUMMARY.md                   # Existing mdBook navigation
├── adr/                        # Existing canonical ADRs (preserved initially)
├── reference.architecture/     # Existing canonical documents (preserved initially)
├── ...                         # Other established documentation/tool paths
├── Management/                 # New taxonomy entry and classification indexes;
│   └── index.md                # no implied authority to move protected content
└── Projects/
    ├── index.md
    ├── MyCode/                  # Documentation ABOUT separately owned customer code
    │   ├── index.md
    │   ├── Activities/
    │   ├── Artifacts/
    │   ├── Decisions/
    │   ├── Evidence/
    │   └── References/
    ├── COE/
    │   └── index.md            # Categories created only when needed
    └── AI-Accelerator/
        └── index.md
```

These context names are examples for project-adoption testing, not an instruction to instantiate all three automatically. `MyCode` beneath `mddocs/Projects/` is harness-controlled documentation; an independently owned checkout at repository root `MyCode/` (if configured) is **not** this directory. An ignored checkout must remain outside the harness Git index and subject to separate access controls.

### A.4 mdBook, Obsidian, and script compatibility gates

Before approving any move or new validator enforcement, the management agent must inspect and report:

1. The canonical mdBook source root, `book.toml` configuration, generated output destination, and whether `mddocs/book/` is tracked, ignored, or both in different revisions.
2. All `SUMMARY.md` links, relative Markdown links, images, Mermaid references, and ADR link-update automation, including `mddocs/scripts/update-summary-on-adr-write.py` and any hook that invokes it.
3. The actual paths used by `export-framework.sh`, bench provisioning, session open/close procedures, setup/seed scripts, documentation-build checks, link checks, and tests; classify whether each expects its path to remain fixed.
4. Whether `mddocs/scripts/` is deliberately distributed as executable adoption tooling. If so, **do not** turn it into an artifact-format bucket or move it under a taxonomy category without updating executable contracts and passing tests.
5. The Obsidian vault boundary and treatment of generated `book/`, customer checkouts, runtime files, and duplicate references. Obsidian is a consumer, not a source of filesystem or authorization authority.
6. The intended customer/project documentation audience and the actual agent write scopes. A `Projects/` subtree inside the harness repository **does not by itself grant** project agents permission to write it; approved execution controls must explicitly permit it.

### A.5 Revised implementation sequence designed to avoid guardrail deadlock

**Stage 0 — Evidence and authority check (read-only):** Identify current ADR constraints (particularly decisions on project slug governance, adoption, permission boundaries, customer-plane provisioning, and write protection), relevant tickets, controlling scripts, and current filesystem permission rules. Output a conflict matrix. No filesystem moves or policy edits.

**Stage 1 — Management decision (HIL gate):** Prepare the ADR draft and implementation plan in an authorized management-scoped feature branch/worktree (subject to existing controls), then submit for explicit HIL **plan approval** via the management workflow. Ask for a narrow approval scope: taxonomy specification and additive documentation indexes first. No taxonomy implementation, migration, or guardrail change before approval. If an existing guardrail prohibits branch creation, proposal authoring, or a planned change, report the exact conflict and stop; do not repeatedly retry under different sessions or working directories.

**Stage 2 — Additive pilot:** After the HIL explicitly approves the plan and scope, and only on the authorized management feature branch/worktree, add `mddocs/Management/index.md` as a taxonomic navigation entry and `mddocs/Projects/index.md` plus one test project context, with purpose-based frontmatter and mdBook `SUMMARY.md` navigation. Legacy documentation remains at established paths. Do not alter `tasks.yaml`, bench registry, ADR numbering, executable controls, or customer checkout permissions.

**Stage 3 — Advisory checks:** Add validation for stable IDs, purpose metadata, package indexes, assets, broken relationships, and links. Initially warn rather than block established files lacking new metadata. Test mdBook build, ADR link updating, export/adoption, and bench provisioning.

**Stage 4 — Controlled categorization:** Migrate individually approved management source documents only after verifying downstream references; classify mixed directories document by document. Introduce governed promotion/retirement and approved enforcement on **new or changed** objects before considering any retroactive requirement.

**Stop rule:** Any activity requiring privilege expansion, a guarded-path modification, changes to customer repository access, or revision of an existing ADR needs an explicit management ticket and HIL disposition. No agent is authorized to infer approval from this proposal.

### A.6 Additional acceptance criteria grounded in the deployed tree

- **A1:** Existing ADR-0000 through ADR-0028 retain their identifiers and remain discoverable throughout the pilot; none is silently renumbered or duplicated.
- **A2:** The mdBook navigation/build works with `Management/` and `Projects/` added, without breaking established pages or Mermaid assets.
- **A3:** Existing executable scripts, Git hooks, bench provisioning, exports, and ADR navigation automation pass their applicable tests without unapproved path changes.
- **A4:** Generated `book/` content is correctly distinguished from authored source and does not become a canonical knowledge-object location.
- **A5:** A `COE` or `AI-Accelerator` activity can be created with minimal required metadata, along with a multi-format artifact, without requiring a software repository.
- **A6:** A `MyCode` documentation context can reference a customer source commit without copying its tracked files into the harness Git index, and without granting write/push capability.
- **A7:** Existing management authorization checks prevent a project-context session from writing protected management paths, while explicitly authorized project paths permit intended project documentation work.
- **A8:** The management agent produces an old-to-new mapping and a precise list of **approved**, **deferred**, and **blocked** changes before restructuring source directories.


## Appendix B. Mandatory branch isolation and HIL approval gates (v0.4)

**Applicability:** This section governs the taxonomy change itself, including management documentation, project taxonomy scaffolding, metadata templates, validators, adoption integration, and future legacy-document migrations. Existing AgenticCore ADRs, branch protection, ticket controls, and HIL policy take precedence where stricter. This proposal grants no new permissions.

### B.1 Required execution order

1. **Read-only discovery and ticket:** Confirm the authorized management context, controlling ADRs, existing ticket, effective permissions, base revision, and branch/worktree policy. Do not modify protected files or customer code.
2. **Isolated planning branch:** Use a management-authorized, task-specific feature branch/worktree, created through the existing approved mechanism, for the proposed ADR, change inventory, mapping, and implementation plan. Do not author or implement the taxonomy directly on `main`, a release branch, or a customer-code branch. If branch creation or writing the plan is blocked by a guardrail, stop and request HIL disposition instead of bypassing the control.
3. **Present an approval packet:** Deliver the management and project taxonomy targets, current-to-target paths, existing ADR conflicts, precise file/change scope, risk and access assessment, backwards-compatibility measures, test plan, phased execution order, rollback procedure, and branch/commit references. Identify every potentially protected path or operation.
4. **HIL gate — approve the plan:** Obtain explicit, recorded HIL approval of the plan and authorized scope **before any implementation change**. Silence, ticket creation, drafting an ADR, or opening a branch/worktree does not constitute approval. Approval may be conditional; record those conditions and stop on unresolved conditions.
5. **Implement only approved work:** On the authorized feature branch/worktree, perform incremental, reversible changes within existing permissions. Preserve the customer-code boundary. A material deviation, newly discovered guardrail conflict, scope expansion, or need to alter an existing ADR/security control triggers a new HIL disposition before proceeding.
6. **Validate and seek integration approval:** Run the existing applicable security, mdBook, link, export/adoption, bench/worktree, schema, and regression checks. Summarize changes and evidence. Do not merge, push to protected branches, release, or deploy without the independent approvals already required by AgenticCore. HIL plan approval does **not** imply merge or release approval.

### B.2 Minimum HIL approval record

Record at least: management ticket ID; proposed ADR reference; branch/worktree and base commit; document/proposal version; bounded change list; explicit exclusions (management controls not authorized for modification, and customer-owned code); identified risks and tests; approver and decision; approval date/time; conditions; and whether a subsequent merge/release gate is required. Retain the record using AgenticCore's existing authoritative ticket/review mechanism rather than creating a parallel approval system.

### B.3 Stop conditions and acceptance tests

- **B1:** No taxonomy implementation starts before an explicit HIL-approved plan is recorded.
- **B2:** All proposal/implementation changes are confined to an authorized management feature branch/worktree; protected branches remain unchanged pending approved integration.
- **B3:** A blocked branch, protected path, or conflicting ADR generates a documented escalation; agents do not route around the guardrail by changing role, session, or working directory.
- **B4:** Approval scope and implementation diff are reconciled before review; out-of-scope changes are not silently included.
- **B5:** Passing tests does not replace HIL approval, and plan approval does not replace merge/release authorization.
- **B6:** Customer-controlled `MyCode/` remains outside the taxonomy migration and is not added to the harness Git index or modified by the taxonomy effort.

**Requested immediate outcome:** Produce the proposal/ADR and full plan on the authorized management branch, then **stop for HIL plan approval**. Only after that approval may the scoped implementation phase begin.
