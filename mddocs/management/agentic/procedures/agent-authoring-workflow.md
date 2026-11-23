---
document_type: procedure
status: active
lifecycle: active
primary: true
domain: Management
category: Agentic
purpose: Author agent operation workflows
---

# Procedure: Agent Authoring Workflow

**Status:** Accepted
**Applies to:** AI toolchain (`.agentic/agents/`) and opencode (`.opencode/agents/`)

---

## Problem This Solves

Agent definitions exist in two tool-specific directories. If one is updated
without the other, the two tools diverge - the same agent behaves differently
depending on which tool is running. This workflow eliminates that risk by
maintaining a single canonical source for agent body content and a single
metadata file for tool-specific frontmatter.

---

## Directory Structure

```
<program>.01/
├── .agents/                        ← canonical source (single source of truth)
│   ├── _meta.yaml                  ← per-agent frontmatter config for both tools
│   ├── sync-agents.sh              ← sync script - run after any agent change
│   ├── ai-engineer.md              ← body content only, no tool-specific frontmatter
│   ├── baseline-steward.md
│   ├── docs-engineer.md
│   ├── docs-reviewer.md
│   ├── lead-engineer.md
│   ├── ops-engineer.md
│   ├── orchestrator.md
│   ├── release-engineer.md
│   ├── security-engineer.md
│   └── security-reviewer.md
│
├── .agentic/agents/                 ← generated - AI toolchain format
│   └── <name>.md                   ← AUTO-GENERATED - do not hand-edit
│
└── .opencode/agents/               ← generated - opencode format
    └── <name>.md                   ← AUTO-GENERATED - do not hand-edit
```

**Rule:** `.agentic/agents/` and `.opencode/agents/` are generated outputs.
Never hand-edit them. All changes go through `.agents/` and `sync-agents.sh`.

---

## _meta.yaml Schema

Each agent has an entry in `.agents/_meta.yaml`:

```yaml
<agent-name>:
  description: "<one sentence - what the agent does and when to invoke it>"
  opencode:
    name: <agent-name>
    # tools: [Read, Write, Edit, ...]  - restrict tool access if needed
  opencode:
    mode: primary | subagent
    # permission:                      - restrict tool access if needed
    #   edit: deny
    #   bash: deny
```

**`description`** is shared between both tools. It is the single most important
field - it controls when the agent is auto-selected. Front-load concrete trigger
keywords. Write in third person. Use "Use ONLY when..." for narrow-scope agents.

---

## AC Agent Roster

| Agent | Role |
|---|---|
| `orchestrator` | Routes complex multi-step tasks across agents |
| `baseline-steward` | Pattern A framework flavor - framework improvement lifecycle, versioning, scrubbing, release lifecycle |
| `lead-engineer` | Pattern A project flavor - task queue, bench lifecycle, agent coordination |
| `docs-engineer` | Runbooks, ADRs, and mddocs/ maintenance |
| `docs-reviewer` | Documentation quality gate - spell check, link check, style review before branch_ready |
| `ops-engineer` | Operational scripts, automation, and runbooks |
| `release-engineer` | CI/CD pipeline and tactical release execution (adopter project scope) |
| `security-engineer` | Security controls and hook logic |
| `security-reviewer` | Adversarial review of security-relevant changes |
| `ai-engineer` | AI agent configuration, MCP server development, and AI-assisted workflow integration |

---

## Workflow: Adding a New Agent

1. **Create the ticket first.**
   Add a task to `tasks.yaml` with the appropriate agent assignment.
   The ticket is the authorization to create the agent. No ticket = no agent.

2. **Write the body file.**
   Create `.agents/<name>.md` - body content only, no frontmatter.

   Required sections:
   - Role statement: one paragraph defining what this agent is and owns
   - `## Shared Practices` - project-wide practices this agent follows
   - `## Tool Usage` - which tools and how
   - `## Domain Scope` - what this agent owns (be specific)
   - `## Guardrails` - role boundaries, human gate, security pre-step, domain-specific rules
   - `## Response Style` - how this agent formats its output

3. **Add the entry to `_meta.yaml`.**
   Fill in `description`, `opencode`, and `opencode` fields.
   For `opencode.mode`:
   - `primary` - for the lead-engineer and baseline-steward (entry point agents)
   - `subagent` - for all specialist agents (invoked by lead-engineer)

4. **Run the sync script.**
   ```zsh
   cd <program>.01
   .agents/sync-agents.sh
   ```
   This writes both `.agentic/agents/<name>.md` and `.opencode/agents/<name>.md`
   with the correct frontmatter for each tool prepended to the shared body.

5. **Verify the output.**
   ```zsh
   head -10 .agentic/agents/<name>.md
   head -10 .opencode/agents/<name>.md
   ```
   Confirm frontmatter is correct for each tool. Confirm body content is identical.

6. **Update the agent roster** in `.agents/lead-engineer.md` and re-run sync
   to regenerate lead-engineer in both tool directories.

7. **Commit all changes together** on the task branch:
   - `.agents/<name>.md` - new body file
   - `.agents/_meta.yaml` - updated metadata
   - `.agentic/agents/<name>.md` - generated output
   - `.opencode/agents/<name>.md` - generated output
   - `.agentic/agents/lead-engineer.md` - roster update (generated)
   - `.opencode/agents/lead-engineer.md` - roster update (generated)

   ```zsh
   git add .agents/ .agentic/agents/ .opencode/agents/
   git commit -m "feat(AC-NNNN): add <name> agent"
   ```

---

## Workflow: Editing an Existing Agent

1. **Edit the body file only.**
   Make changes in `.agents/<name>.md`.
   Never edit `.agentic/agents/<name>.md` or `.opencode/agents/<name>.md` directly.

2. **Edit `_meta.yaml` if frontmatter changes.**
   Frontmatter changes (description, mode, permissions) go in `_meta.yaml`.

3. **Run the sync script.**
   ```zsh
   .agents/sync-agents.sh
   ```

4. **Commit the source and both generated outputs together.**
   ```zsh
   git add .agents/ .agentic/agents/ .opencode/agents/
   git commit -m "chore(AC-NNNN): update <name> agent - <what changed>"
   ```

---

## Workflow: Removing an Agent

1. **Delete the body file and `_meta.yaml` entry.**
2. **Run the sync script** - it will not write generated files for agents
   no longer present in `_meta.yaml`. Delete the old generated files manually.
3. **Remove the agent from the lead-engineer roster** in `.agents/lead-engineer.md`.
4. **Run sync again** to regenerate lead-engineer.
5. **Commit all deletions and updates.**

---

## sync-agents.sh Contract

The sync script:
- Reads `.agents/_meta.yaml` for the agent list and per-tool frontmatter
- For each agent, reads `.agents/<name>.md` as the body
- Writes `.agentic/agents/<name>.md` with AI toolchain frontmatter prepended
- Writes `.opencode/agents/<name>.md` with opencode frontmatter prepended
- Prepends an `AUTO-GENERATED` HTML comment to each output file
- Exits non-zero if any source file is missing
- Accepts `--dry-run` to preview without writing

The script does **not** commit. Commit is always a human or lead-engineer action
after reviewing the diff.

**When adding a new agent, also add it to:**
- `agents/<project-name>/_context.md` Agent Roster table
- `AGENT.md` Agent Team table
- `PROCESS.md` Agent Team table (§10)

---

## Guard Against Manual Edits

Both generated files open with this comment to signal their origin:

```
<!-- AUTO-GENERATED by .agents/sync-agents.sh - do not hand-edit -->
<!-- Source: .agents/<name>.md + .agents/_meta.yaml -->
<!-- Run .agents/sync-agents.sh to regenerate -->
```

Any agent session that reads a generated file and sees this comment must not
edit the file directly - it must edit the source and re-run the sync script.

---

## Adding a New Tool (third agent consumer)

If a third tool is adopted alongside AI toolchain and opencode:

1. Add a new top-level key to each `_meta.yaml` entry (e.g., `cursor:`, `gemini:`).
2. Extend `sync-agents.sh` to write to the new tool's agent directory.
3. Document the new tool's frontmatter schema in this file under a new section.

The body content in `.agents/` does not change - only the metadata and the
sync script need updating.

---

## Authoring-Agent Execution Model

Authoring agents (`docs-engineer`) are execution-light by design - they hold no
`bash`/`git` capability. The Lead (`lead-engineer` / `baseline-steward`) runs their
mandatory gates (`mdbook build`, link check) and commits on their behalf (ADR-0027).

## Add or Modify a Hook

`.core/hooks/` holds two distinct classes of hook:

| Class | Fired by | Wired where | Example |
|---|---|---|---|
| **AI-tool hook** | The AI tool's event system (`PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`) | `AGENT.md` | `secret-guard.py` |
| **Git hook** | Git, installed into `.git/hooks/` via `.core/scripts/install-git-hooks.sh` (ADR-0022) | Never in `settings.json.template` | `pre-commit-permission-order-check.py` |

`check-hook-wiring.py` enforces wiring for **AI-tool hooks only**. A git hook self-declares
its class with an explicit sentinel token near the top of the file:

```python
# hook-class: git
```

The check excludes any file carrying that sentinel. It is an exact-token declaration, not
free prose - a hook that merely *mentions* git hooks in its docstring is still treated as an
AI-tool hook. A file that does *not* carry the sentinel is treated as an AI-tool hook and
flagged if unwired - the check fails safe.

The steps below apply to **AI-tool hooks**. An AI-tool hook must be wired into
`AGENT.md` to take effect; adding a hook file without updating the
template is a silent no-op. For git hooks, see `.core/scripts/install-git-hooks.sh` and ADR-0022.

### Step 1 - Write or update the hook

Create or edit `.core/hooks/<name>.py`. Follow the existing hook conventions:
- Read tool input from `json.load(sys.stdin)`
- PreToolUse hooks: exit 1 to block, exit 0 to allow
- PostToolUse hooks: always exit 0 (informational only)
- Include a `AGENT_<HOOKNAME>_DISABLED=1` circuit breaker for conditional hooks
- Unconditional safety hooks (e.g. `package-install-guard.py`) must not have a circuit breaker

### Step 2 - Wire into settings.json.template

Open `AGENT.md` and add the hook under the correct event
(`PreToolUse` or `PostToolUse`) with the appropriate `matcher`.

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "python3 \"${REPO_ROOT}/.core/hooks/<name>.py\"",
      "statusMessage": "<short description>..."
    }
  ]
}
```

### Step 3 - Verify wiring

Run the hook audit check to confirm no hooks are unwired:

```sh
python3 .core/scripts/check-hook-wiring.py
```

### Step 4 - Test the hook

```sh
# PreToolUse - pipe a simulated tool call to the hook directly
echo '{"tool_input": {"command": "your test command"}}' | python3 .core/hooks/<name>.py
echo "exit: $?"
```

### Step 5 - Commit both files together

Hook files and `settings.json.template` are coupled artifacts - always commit them
in the same commit:

```sh
git add .core/hooks/<name>.py AGENT.md
git commit -m "feat: add <name> hook [AC-NNNN]"
```

## Related

- `.agents/_meta.yaml` - per-agent frontmatter configuration
- `.agents/sync-agents.sh` - the sync script
- [Configure Agent Namespace](configure-agents.md) - full agent namespace setup and MCP configuration
- [Runbook: Sync Agent Definitions](sync-agent-definitions.md) - operational sync procedure
