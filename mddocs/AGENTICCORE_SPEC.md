# AgenticCore Specification

**Version:** v0.4
**License:** MIT
**Status:** Draft — pending HIL review

---

## 1. Identity

AgenticCore is a reference harness for orchestrating tool-use LLM agents in a team-based,
microservice-shaped architecture where specialists delegate to each other through a shared
orchestrator.

It is designed to be:

- **Provider-agnostic** — AI coding toolchains — including opencode and adapter-compatible
  tools — are pluggable adapters; swapping or adding them does not change agent logic.
- **Self-hosted** — designed to run on a local Kubernetes cluster (`harness-cluster`), not dependent
  on external AI services for its own control plane.
- **Opensource-ready** — no customer data, no internal URLs, no hardcoded credentials,
  no organization-specific metadata of any kind.
- **Each agentic team starts in its own repo** — agents commit their own state, push
  artifacts, open PRs on each other. The collaboration surface between agents is the
  version control platform (Git hosting), not a bespoke message bus.

AgenticCore provides the structural scaffolding. It does not provide the agents themselves
— those are defined per project using the harness.

---

## 2. What It Is Not

AgenticCore deliberately excludes the following from its scope:

| Not in scope | Reason |
|---|---|
| LLM inference provider | Inference is a plug — addressed via ExternalName service, managed outside the harness |
| CI/CD pipeline | General build/test/deploy is not an agent concern |
| Git hosting hosting or administration | Git hosting is an optional integration point consumed by agents, not managed by the harness |
| Identity provider / HBAC | Authentication and authorization are infrastructure concerns, not agent harness concerns |
| Secrets management | Credentials are injected at deploy-time via environment or vault; the harness does not handle them |
| Backup or geo-redundancy | State persistence and backup are storage/backup concerns outside the harness boundary |
| Customer-specific infrastructure of any kind | AgenticCore carries zero organizational or customer identity |
| Specific task implementations | The harness defines how agents are structured and coordinated, not what any particular agent does |

---

## 3. Core Abstractions

| Abstraction | Definition |
|---|---|
| **ADR** | Architecture Decision Record. A forward-only, append-only record that documents a significant decision, its context, consequences, and implementation notes. ADRs are the provenance backbone — they connect tasks to the rules that govern them. |
| **Bench** | A named git worktree of the harness repo. Benches are the isolation boundary for agent sessions. |
| **Agent** | A role definition consisting of a context file, a body (.md), metadata (_meta.yaml), and generated tool-specific output files. An agent has a purpose, a tool set, and HIL gate behavior. |
| **Task** | A unit of work recorded in `tasks.yaml`. Tasks have a lifecycle, acceptance criteria, and an assigned agent. |
| **Session** | One AI coding session running on one bench. A session reads the agent context, picks up a task, executes, and produces an artifact. |
| **HIL Gate** | An explicit human approval step before a reviewed artifact moves from `branch_ready` to `accepted`. No agent may approve its own work. |

---

## 4. Architecture

### 4.1 Tiered Agent Model

Agents are organized into operational tiers. The orchestrator routes requests based on
tier matching, not on ad-hoc decision making.

```
┌──────────────────────────────────────────────────────────────────┐
│                     Orchestrator (Tier 1)                         │
│                   Fast routing, generalist, HIL-proximate         │
└────────────┬──────────────────────────────┬───────────────────────┘
             │                              │
             ▼                              ▼
┌───────────────────────────┐   ┌──────────────────────────────────┐
│ Tier 2: Warm Service Pool │   │ Tier 3: Ephemeral Specialists    │
│ (Fixed Deployments)       │   │ (K8s Jobs, isolated execution)   │
│ Domain experts, heavy tools│   │ Greenfield R&D, custom sandbox   │
└───────────────────────────┘   └──────────────────────────────────┘
```

| Tier | Path | Profile | Scheduling |
|---|---|---|---|
| 1 | C — Shared Runtime | Generalist, prompt-driven, fast response | Long-running Deployment |
| 2 | B — Service Pool | Specialist, targeted tool set, known skills | Long-running Deployment, HPA-scalable |
| 3 | A — Ephemeral Jobs | Custom sandbox, isolated, greenfield | K8s Job, created on demand, cleaned up after |

### 4.2 Cluster Topology

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES (harness-cluster)                       │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Control Plane (etcd, API server, scheduler, controller-manager)   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Tier 1/2 Agent Pods ──┐                                                  │
│  Tier 3 Ephemeral Jobs ┤  run on harness-cluster as CPU-only workloads            │
│                        │                                                  │
│  ExternalName Service  │                                                  │
│  llm-inference-service │──────────────► inference-node-1:8000/v1                │
│                         │          (bare-metal inference, NoSchedule)        │
└─────────────────────────┼──────────────────────────────────────────────────┘
                          │
                          │ high-speed fabric (outside K8s CNI)
                          ▼
                ┌─────────────────────┐
                │  inference-node-2 (GPU node #2)│
                │  vLLM worker node   │
                └─────────────────────┘
```

| Node | Role | K8s Scheduler |
|---|---|---|
| `harness-cluster` | Control plane + sole K8s worker + shared storage | Accepts all Tier 1/2/3 pods |
| `inference-node-1` (GPU node #1) | Bare-metal vLLM head node — `<model-id>` node 1/2 | Tainted `NoSchedule` — inference only, outside K8s |
| `inference-node-2` (GPU node #2) | Bare-metal vLLM worker — `<model-id>` node 2/2 | Tainted `NoSchedule` — inference only, outside K8s |
| Operator workstation | Interactive dev seat, local orchestrator CLI | Outside K8s — API consumer only |

Both inference nodes are 100% committed to the distributed vLLM instance. Stopping or
interrupting vLLM breaks all AI routing across the network. Neither node has spare VRAM
or compute headroom for K8s workloads. The high-speed fabric interconnect is raw bare-metal
fabric and is not routable through K8s CNI.

### 4.3 Reference Archive Boundary

```
<reference-archive>/
└── <ref-archive>/     ← _ref/ — READ-ONLY, DO NOT MODIFY
    ├── AgenticCore/            ← AGENTICCORE_SPEC.md lives here
    ├── agents/
    ├── .agents/
    ├── tasks.yaml
    └── ...
```

All content under `<ref-archive>/` is the v0.4 reference archive preserved for
content audit and migration reference. AI sessions working in AgenticCore may read these
files but may not modify them. Any git operation that alters files under this path is a
hard violation.

### 4.4 Architecture Decision Records (ADRs)

ADRs are the load-bearing governance backbone of the harness. They are not optional
documentation — they are the mechanism by which behavioral rules, guardrails, and
architectural constraints acquire provenance, enforce continuity, and support continuous
improvement.

**Forward-only, append-only.** Once an ADR reaches `accepted` status, its text is never
edited. Changes to a governed decision produce a new ADR that `supersedes` the prior one,
with explicit linkage. This makes the history of every rule auditable: any ticket,
session, or artifact can trace its governing constraint to the ADR that enacted it.

**ADR-to-task provenance.** Every ticket in the task queue that implements, modifies, or
extends governed behavior carries a reference to the ADR(s) that authorize the change.
Agents may not execute a ticket whose scope involves governed behavior without confirming
the applicable ADR is `accepted`. Tickets that introduce new governed behavior carry the
proposed ADR as part of their acceptance criteria.

#### ADR Schema

```markdown
# ADR-NNNN: Short Title

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded | deprecated
**Supersedes:** ADR-XXXX (if applicable)
**Superseded by:** ADR-XXXX (if applicable)

## Context

Forces at play, constraints, options considered.

## Decision

Clear statement in active voice.

## Consequences

**Positive:**
- ...

**Negative / Trade-offs:**
- ...

**Neutral:**
- ...

## Implementation Notes

Optional. Reference scripts, runbooks, config files that implement this decision.

## Related

- ADR-XXXX — related decision
- `path/to/implementation/file` — artifact this ADR governs
```

#### ADR Lifecycle

```
proposed   — under discussion; not yet binding on agent behavior
  ↓ HIL accepts
accepted   — active; in effect; governs tickets and agent behavior
  ↓ superseded by later ADR
superseded — replaced; prior ADR text preserved; superseding ADR links to it
  ↓ no longer applicable (rare)
deprecated — removed from active consideration; reason recorded
```

**Only HIL transitions status.** No agent — including lead-engineer — may move an ADR
from `proposed` to `accepted`. Transition to `superseded` requires HIL approval and a
linking superseding ADR.

#### Core ADRs (load-bearing set)

The following eight ADRs are the load-bearing governance backbone of AgenticCore.
Their numbering matches the sequential index in `mddocs/adr/`:

| ADR | Title | AgenticCore relevance |
|---|---|---|
| ADR-0004 | `main` Branch Protection and Immutability | `main` is append-only, merge-only; roll-forward policy |
| ADR-0005 | Prompt Traceability and Session Logging | Every session produces a traceable log; provenance chain |
| ADR-0006 | External Content Gate Scope | Security gate triggers and content inspection rules |
| ADR-0007 | Bench Scope Isolation | Bench-to-bench isolation; no cross-bench writes |
| ADR-0008 | Orchestrator Subagent Routing Layer | Orchestrator as planning-only subagent; three-layer fidelity |
| ADR-0009 | Agent Portability Model | Toolchain-agnostic agent definition; the .agents/ pattern |
| ADR-0012 | Canonical/Generated Split | `.agents/` is canonical source; `<toolchain>-specific/` and `.opencode/` are generated |
| ADR-0015 | Framework Distribution and Adoption Model | `adopt.sh` severed-copy export; no upstream remote in adopted repos |

These eight are load-bearing. AgenticCore's initial ADR index is seeded from this set.
Additional ADRs are added as the harness evolves.

#### ADR Index

ADR-####-short-title.md files live in `mddocs/adr/`. The index file `mddocs/adr/index.md`
is the authoritative registry and is updated whenever an ADR changes status.

```markdown
| ID | Title | Status | Date |
|---|---|---|---|
| [ADR-0004](adr-0004-main-branch-protection.md) | ... | accepted | YYYY-MM-DD |
```

---

## 5. Tool Adapter Layer

AgenticCore supports multiple AI coding toolchains as pluggable adapters. Agent definitions
are written once in a canonical format and adapted to each toolchain's required format by a
sync script.

### Directory Layout

```
AgenticCore/
├── .agents/                      ← CANONICAL SOURCE — edit here only
│   ├── _meta.yaml                ← Frontmatter mapping per tool
│   ├── orchestrator.md           ← Agent body definitions
│   ├── docs-engineer.md
│   ├── security-engineer.md
│   └── ...
│
├── <toolchain>-agents/           ← AUTO-GENERATED by sync-agents.sh (toolchain-specific format)
├── .opencode/agents/             ← AUTO-GENERATED by sync-agents.sh (opencode format)
├── .codex/agents/                ← PLACEHOLDER — adapter deferred to backlog
│
└── .agents/sync-agents.sh        ← Single writer for all generated output
```

### Canonical Source (`.agents/`)

Each agent is defined by two files:

- `_meta.yaml` — one YAML entry per agent, containing description and per-tool frontmatter
- `<name>.md` — agent body in a vendor-neutral Markdown format

Adding a new agent requires editing only these two files, then running `sync-agents.sh`.

### sync-agents.sh Contract

```
Usage: .agents/sync-agents.sh [--dry-run] [--clean] [<agent-name>]

Output:
  <toolchain>-agents/<name>.md — toolchain-specific agent format
  .opencode/agents/<name>.md  — opencode agent format

Failure isolation:
  A failure in one tool's generation must not affect the others.
```

Policy distribution runs unconditionally:
- `_security-policy.md` → `core-context.md` (Standing Rules) and `.opencode/commit-push-gate.md`
- `_docs-policy.md` → injected into `.agents/docs-engineer.md` and `.agents/lead-engineer.md`

### Per-Tool Frontmatter in `_meta.yaml`

```yaml
<agent-name>:
  description: "<one sentence — what the agent does and when to invoke it>"
  <tool>:
    name: <agent-name>
    tools: [Read, Bash, ...]       # optional — omit for no restriction
  opencode:
    mode: primary | subagent
    model: <model-id>              # optional — omit for opencode.json default
    permission:                    # optional
      bash: ask | allow | deny
      edit: deny
  codex:
    # TO BE DEFINED — adapter not yet implemented
```

### Extending to a New Tool Runtime

The `_meta.yaml` schema supports additive tool blocks. To onboard a new runtime:

1. Add a key block under each agent entry in `_meta.yaml`
2. Add a generation function in `sync-agents.sh` for the new output format
3. Verify output loads correctly in the target tool before committing
4. Add the generated output directory to `.gitignore` unless the tool requires it tracked

`_ref/` reference: the reference archive `.agents/_meta.yaml` and `.agents/sync-agents.sh`
demonstrate the Core and opencode adapter implementations.

---

## 6. Bench Model

AgenticCore uses a numbered git worktree convention. All benches are worktrees of the
same repo, sharing `.git/` at the repo root.

```
AgenticCore/
├── .git/
├── .00/              ← HIL workbench (owner-controlled, oversight, approvals)
├── .01/              ← Lead-engineer bench (task queue, bench lifecycle, remote)
├── .02/              ← Worker bench (assigned task execution)
├── .03/              ← Worker bench
└── ...
```

| Bench | Path | Role | Notes |
|---|---|---|---|
| `.00` | `AgenticCore.00` | Owner workspace | IDE work, R&D, scratch — never assign agent tasks here |
| `.01` | `AgenticCore.01` | Baseline-steward + Lead-engineer | Owns `main`, remote, task queue, bench lifecycle |
| `.02`+ | `AgenticCore.02`, `.03` | Worker benches | Execute assigned tasks; do not merge, do not push |

**Rules:**
- `.01` provisions and coordinates. Worker benches execute.
- Agent task work never happens directly in `.01`.
- Bench lifecycle (create, assign, teardown) is owned by `.01`.
- Worktree teardown requires HIL authorization. Check `locked` field before `git worktree remove`.
- `.00` and `.01` are never torn down.

Bench state is tracked in `bench-registry.yaml`.

### bench-registry.yaml Schema

```yaml
benches:
  - path: .00
    role: owner
    agent: hil-assistant
    status: active
    locked: true

  - path: .01
    role: lead-engineer
    agent: lead-engineer
    status: active
    locked: true

  - path: .02
    role: worker
    agent: <assigned-agent>
    task: <task-id>
    status: active | idle | teardown_pending
    locked: false
```

---

## 7. Task Queue

### tasks.yaml Schema

The task queue is the single source of truth for all work. It is tool-agnostic and
consumed directly by any compatible AI coding toolchain.

```yaml
- id: AC-001
  title: "<human-readable title>"
  description: |
    <full description including scope, rationale, and any constraints>

  acceptance_criteria:
    - "<criterion 1>"
    - "<criterion 2>"

  adr: [ADR-XXXX]               # optional — ADR(s) authorizing this change; required if scope involves governed behavior
  priority: P0 | P1 | P2 | P3
  size: XS | S | M | L | XL
  labels: [docs, security, feature, chore]
  agent: <agent-name>
  status: backlog | ready | claimed | in_progress | branch_ready | awaiting_review | accepted | merged
  branch: ""
  bench: .02
  blocked_by: []
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
```

### ADR Provenance Rule

When a task's scope involves any governed behavior (task queue rules, bench model
structure, HIL gates, agent roster, security controls, branch protection), the `adr`
field must list the ADR(s) that authorize the change.

**Rules:**
- Changing governed behavior → `adr` field required; an `accepted` ADR must exist before the task moves to `in_progress`
- Proposing new governed behavior → `adr` field required; ticket includes the proposed ADR file as acceptance criteria; ADR moves to `accepted` before the task moves to `accepted`
- Non-governed work (documentation typo fix, non-structural refactor) → `adr` field omitted
- ADR status is authoritative: a ticket may not implement behavior governed by a `deprecated` ADR without a superseding `accepted` ADR

### Task Lifecycle

```
backlog
  → ready           (prioritized, unassigned)
    → claimed       (assigned to bench, not yet started)
      → in_progress (actively executing)
        → branch_ready    (artifact committed, awaiting review)
          → awaiting_review (reviewer assigned)
            → accepted    (HIL approved)
              → merged    (integrated to main)
```

**Rules:**
- Only `.01` (lead-engineer) writes to `tasks.yaml`.
- Agent task work never happens directly in `.01` — if a task requires building, running, or generating artifacts, assign it to a worker bench.
- A task moves from `in_progress` to `branch_ready` only when the artifact is committed and pushed.
- `accepted` requires explicit HIL approval — no agent may self-approve.

---

## 8. HIL Discipline

### Two-Role Gate Model

| Role | Purpose | May modify files? |
|---|---|---|
| **Implementer** | Produces the artifact | Yes — writes and edits |
| **Evaluator** | Reviews artifact quality before acceptance | No — verdict only |

This model applies to both documentation and security:

| Domain | Implementer | Evaluator |
|---|---|---|
| Documentation | `docs-engineer` | `docs-reviewer` |
| Security | `security-engineer` | `security-reviewer` |

**Verdict values:** `APPROVED`, `APPROVED WITH NOTES`, `BLOCKED`

No agent may approve its own work. An evaluator's `BLOCKED` verdict returns the task to
`in_progress` with remediation notes.

### ADR-Gated Routing

Before executing any multi-specialist routing plan, lead-engineer confirms the plan does
not contradict any `accepted` ADR. If the plan introduces new governed behavior, the task
is blocked until a proposed ADR is attached and moved to `accepted`.

### Routing Plan Five-Assertion Checklist

When the `orchestrator` agent produces a routing plan for multi-specialist tasks, the
lead-engineer validates five assertions before execution:

1. `sensitivity` field is present (`high` or `standard`)
2. All applicable invariants are listed in `invariants_applied`
3. Every step's `reason` maps to a recognized trigger condition for that specialist
4. `fallback_recommended` is a boolean (not omitted)
5. If `fallback_recommended: true`, `fallback_reason` is non-empty

This checklist validates structural well-formedness only. It is not a substitute for
security content inspection. Any routing plan step involving external content must still
pass through the security gate and Invariant 2 before execution.

### No Self-Approval

No agent — including `lead-engineer`, `baseline-steward`, and `orchestrator` — may move
a task from `branch_ready` to `accepted`. Acceptance is an exclusively human action.

---

## 9. Provider Agnosticism

### LLM Endpoint Abstraction

Agents must never hard-code inference endpoint addresses. The pattern is:

```yaml
# K8s ExternalName Service
apiVersion: v1
kind: Service
metadata:
  name: llm-inference-service
  namespace: default
spec:
  type: ExternalName
  externalName: <inference-ip>   # inference-node-1 head node fabric IP
```

Agents address inference as `http://llm-inference-service:8000/v1`. Changing the backend
(vLLM → Ollama → cloud provider) requires updating one K8s manifest. Zero agent code
changes.

**Hybrid evolution path:** When traffic diversifies, lightweight in-cluster models
(CPU-based Ollama or small GPU) may be introduced for trivial calls (JSON formatting,
classification, tool selection), reserving the external endpoint for complex multi-step
reasoning. This is an optional future deployment, not part of the initial harness.

### Tool Provider Abstraction

Agents are not bound to filesystem, database, or message queue implementations. Tool
definitions in agent context files use abstract operation descriptions. Concrete
tool implementations (bash commands, API calls, SDK methods) are resolved at session
start from environment configuration, not from agent definitions.

---

## 10. Repo Per Team Pattern

Each agentic team (each specialist role, each project) starts in its own repository under
a shared Git hosting organization.

```
<git-host>/
└── harness-cluster/
    ├── orchestrator/          ← orchestrator agent repo
    ├── docs-engineer/         ← docs-engineer agent repo
    ├── security-engineer/     ← security-engineer agent repo
    ├── task-<project-name>/   ← project-specific team repos
    └── ...
```

**Agent responsibilities within their repo:**

| Action | Mechanism |
|---|---|
| Read task assignment | Clone, check `tasks.yaml` for their `agent` field |
| Execute work | Write artifacts to working directory |
| Commit state | `git add`, `git commit`, `git push` to own repo |
| Open PRs on other agents | Git hosting API or git remote configured in environment |
| Record session state | Commit structured JSON/YAML to state path in repo |

**Git hosting's role:** collaboration surface between agents (PRs, issues, audit trail,
history). Git hosting is consumed by agents via API; it is not managed by the harness.

**Opensource migration path:** Since all meaningful content lives in the repo, going
public means mirroring selected repos to a public Git hosting platform and stripping internal config.
Git hosting's native push-mirror support makes this a single configuration change.

---

## 11. Scope Boundaries

| Concern | Owner | Relationship to AgenticCore |
|---|---|---|
| Git hosting (Git, PRs, issues, API) | Infrastructure team (optional integration) | Agents call Git hosting API; harness does not manage it |
| storage / backup | Infrastructure team | Runtime state, large artifacts, backup — outside harness |
| K8s cluster (harness-cluster) | Infrastructure team | Harness runs on it; harness does not manage the cluster lifecycle |
| Inference (vLLM on GPU node) | Infrastructure team | LLM endpoint accessed via ExternalName; harness does not manage it |
| Secrets / credentials | Infrastructure team | Injected via environment or vault at deploy-time |
| Harbor / private registry | Infrastructure team | Container images for agent pods; future step |

AgenticCore's boundary is the harness itself: agent definitions, the bench model, the task
queue, the sync layer, and the HIL discipline. Everything outside that boundary is
consumed via configuration, not managed by the harness.

---

## 12. Open Items / Backlog

| Item | Status | Notes |
|---|---|---|
| Codex CLI adapter | Backlog | `.codex/agents/` placeholder exists; adapter definition deferred until Codex format is known |
| Git hosting integration spec | Backlog | HBAC enforcement, agent credential model, repo provisioning automation |
| In-cluster Ollama hybrid path | Future | Trigger: agent traffic diversification; CPU or small GPU for trivial calls |
| GPU worker node addition | Future | Trigger: Tier 3 workload demands in-cluster GPU; requires new hardware |
| AgenticCore CI/CD via Git hosting | Future | Pipeline definition, container image build, release workflow |
| Provider fallback chain | Future | vLLM down → fallback to in-cluster Ollama or cloud provider |
| Session state persistence spec | Future | Structured state format, storage layout, checkpoint/recovery protocol |

---

## 13. Migration Path

### From v0.4 reference archive to AgenticCore

| Content | Action |
|---|---|
| `.agents/` layer (canonical source, `_meta.yaml`, `sync-agents.sh`) | Carry forward verbatim — pattern is correct |
| `tasks.yaml` schema | Carry forward, sanitize task IDs and labels |
| `PROCESS.md` role model | Carry forward, strip org-specific references |
| Bench model (`.00`, `.01`, `.02+`) | Carry forward — SWE convention is universal |
| HIL gate pattern (two-role implementer/evaluator) | Carry forward — universal value |
| Core ADRs (§4.4, eight from v0.4) | Carry forward verbatim with same IDs into `mddocs/adr/`; build new index |
| `mddocs/` documentation structure | Carry forward pattern, rewrite content for opensource audience |
| `<toolchain>-specific/` and `.opencode/agents/` | Regenerate from `.agents/` via `sync-agents.sh` |
| `README.md` | Rewrite — remove customer-specific references |
| `core-context.md` | Rewrite — remove org-specific standing rules |
| `opencode.json` | Sanitize — remove internal model IDs, environment-specific URLs |
| `_config/` | Review — keep credential-identity policy, remove org-specific content |
| `CHANGELOG.md`, `release-notes/` | Truncate to relevant public history or start fresh at v0.4 |
| Customer-specific remote URLs | Remove entirely — replace with `<git-host>/<org>/<repo>` template in `adopt.sh` |
| Cloud-provider-specific references | Remove entirely |
| Customer project identifiers | Remove — replace with generic project naming |
| Customer-specific standing rules in `_config/` | Remove |
| Non-core ADRs (the v0.4 reference archive's remaining ADR records) | Review individually; adopt if still relevant; drop if tied to removed content |

### Migration Discipline

- All migration is done by **building forward from this spec**, not by editing v0.4 in place.
- v0.4 `<ref-archive>/` is the `_ref/` archive — read-only, never modified.
- Each deliverable is a single commit. Task queue enforces atomicity per session.
- No AI session attempts more than one deliverable.

---

*Agents reading this document: this spec is the authoritative definition of AgenticCore.
When in doubt between spec and convention, the spec governs. Deviations require HIL
approval and a corresponding update to this document.*
