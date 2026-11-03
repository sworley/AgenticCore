# Agent Roster

The complete agentic team. The source of truth is `.agents/_meta.yaml` (metadata) and
`.agents/<agent>.md` (body). Tool-specific files are generated from the canonical source
into `.opencode/agents/` (OpenCode) via `.agents/sync-agents.sh` — never hand-edit the
generated files.

Model IDs are placeholders (`provider/model-*`); set your real models per
[ADR-0020](../adr/adr-0020-default-model-selection.md) and
[ADR-0021](../adr/adr-0021-per-agent-model-tiering.md) (see
[Set Your Models](getting-started.md#set-your-models)).

---

## Primary Agents

These are session entry points — the HIL (or the lead-engineer) invokes them directly.

| Agent | Layer / Plane | Model tier | Default permission | Scope |
|---|---|---|---|---|
| `lead-engineer` | `.01` management repo | opus | bash: `ask` · edit: `allow` | Whole-space owner & facilitator — governance, task queue, bench lifecycle |
| `attendant` | `.00` customer/project plane (Pattern W) | sonnet | *(defaults)* | Customer/project facilitation for the HIL; relaxed, executes tasks autonomously |
| `hil-assistant` | `.00` HIL plane (Pattern H) | sonnet | *(defaults)* | HIL's personal collaborator in `.00` — scratch, oversight, coordination |

## Specialist Subagents

Invoked by the lead-engineer (at `.01`, or a `.02+` management workbench) for their
specialty. Authorities are bounded: implementers write, evaluators verdict-only.

| Agent | Model tier | Default permission | Invoked for |
|---|---|---|---|
| `orchestrator` | opus | bash: `deny` · edit: `deny` | Routing / subagent dispatch (plan only) |
| `baseline-steward` | opus | bash: `ask` · edit: `allow` | Framework improvement lifecycle — governance, versioning, release |
| `docs-engineer` | sonnet | bash: `deny` · edit: `allow` | mddocs: runbooks, ADRs, documentation |
| `docs-reviewer` | haiku | bash: `allow` · edit: `deny` | Docs quality gate — spell/link/status check (verdict only) |
| `code-reviewer` | sonnet | bash: `deny` · edit: `deny` | Code quality gate (verdict only) |
| `ops-engineer` | sonnet | bash: `ask` · edit: `allow` | Scripts, automation, dev tooling |
| `ai-engineer` | opus | bash: `ask` · edit: `allow` | Agent config, MCP servers, workflow integration |
| `release-engineer` | sonnet | bash: `ask` · edit: `allow` | CI/CD and tactical release execution |
| `security-engineer` | opus | bash: `ask` · edit: `allow` | Security controls, hooks, content inspection |
| `security-reviewer` | opus | bash: `deny` · edit: `deny` | Adversarial security review (verdict only) |
| `infra-engineer` | opus | bash: `ask` · edit: `allow` | Infrastructure, IaC, networking |
| `azure-cloud-engineer` | opus | bash: `ask` · edit: `allow` | Cloud architecture, Well-Architected, compliance |
| `ux-engineer` | sonnet | *(defaults)* | UI/UX, information architecture, accessibility, DX |

> `docs-reviewer`/`code-reviewer`/`security-reviewer` are evaluative only — they never fix;
> the corresponding implementer (`docs-engineer`/`ai-engineer`/`security-engineer`) applies
> fixes. See the two-role gate model in
> [`_context.md`](../../.core/agents/_context.md).

## How to Invoke

- **Primary agents** — the HIL starts a session as `lead-engineer` ("lead-engineer, session
  open"), or as `attendant` / `hil-assistant` in the `.00` plane.
- **Subagents** — the lead-engineer delegates: documentation → `docs-engineer`, quality
  gates → `docs-reviewer` / `code-reviewer` / `security-reviewer`, scripts → `ops-engineer`,
  releases → `release-engineer`, security → `security-engineer` / `security-reviewer`,
  cloud/infra → `azure-cloud-engineer` / `infra-engineer`, complex routing → `orchestrator`.

## How to Change

1. Edit the canonical source: `.agents/<name>.md` (body) and `.agents/_meta.yaml`
   (description/mode/model/permission).
2. Run `.agents/sync-agents.sh` to regenerate `.opencode/agents/`.
3. Verify the generated files load (`opencode agent list`).

See [Agent Authoring Workflow](../reference.architecture/agent-authoring-workflow.md) and
[Sync Agent Definitions](../operations/runbooks/sync-agent-definitions.md).

---

## Related

- [Visual Overview](visual-overview.md)
- [Agentic Workflow Overview](agentic-workflow-overview.md)
- [Shared Agent Context](../reference.architecture/shared-context.md)
