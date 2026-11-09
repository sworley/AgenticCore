# Agent Authoring Workflow

**Purpose:** Create or modify agent definitions using the canonical source in `.agents/`.

**Audience:** AI engineers and lead-engineers adapting the agent team.

---

## Overview

Agent definitions follow a two-layer model:
1. **Canonical source** — `.agents/<name>.md` + `.agents/_meta.yaml`
2. **Generated outputs** — `.opencode/agents/<name>.md` (and future tool targets)

Never hand-edit the generated outputs. All changes go to the canonical source first,
then `sync-agents.sh` propagates to tool-specific directories.

**Authoring-agent execution model.** Authoring agents (`docs-engineer`) are
execution-light by design — they hold no `bash`/`git` capability. The Lead
(`lead-engineer` / `baseline-steward`) runs their mandatory gates (`mdbook build`, link
check) and commits on their behalf (ADR-0027).

---

## Procedure: Add a New Agent

### Step 1 — Write the agent body

Create `.agents/<name>.md` with the agent's persona, responsibilities, and guardrails.

Structure:
```markdown
# Agent Name

You are the **<role>** for this project. <One-sentence purpose.>

## Responsibilities
- ...

## Standards
- ...

## Guardrails
- ...
```

### Step 2 — Register in _meta.yaml

Add an entry to `.agents/_meta.yaml`:
```yaml
- name: your-agent
  description: "One sentence for opencode agent description field"
  mode: subagent        # primary | subagent
  permission:
    bash: ask           # allow | ask | deny
    edit: allow
```

### Step 3 — Run sync-agents.sh

```sh
chmod +x .agents/sync-agents.sh
.agents/sync-agents.sh
```

Verify the generated file:
```sh
cat .opencode/agents/your-agent.md
```

### Step 4 — Test the agent

Open a session and invoke the agent:
```
@your-agent Hello, confirm you can read your instructions.
```

### Step 5 — Document the addition

Write or update an ADR if the new agent represents a significant architectural
decision (e.g., adding a domain-specific specialist).

Commit:
```sh
git add .agents/ .opencode/agents/
git commit -m "feat: add your-agent definition [AC-NNNN]"
```

---

## Procedure: Modify an Existing Agent

1. Edit `.agents/<name>.md`
2. If the change affects metadata (mode, permissions, description), edit `_meta.yaml`
3. Run `.agents/sync-agents.sh`
4. Review the diff in `.opencode/agents/<name>.md`
5. Test the agent
6. Commit both canonical source and generated output

---

## Procedure: Remove an Agent

1. Delete `.agents/<name>.md`
2. Remove the entry from `.agents/_meta.yaml`
3. Run `.agents/sync-agents.sh --clean` (removes orphaned generated files)
4. Update `AGENT.md` and any runbooks referencing the agent
5. Commit

---

## Procedure: Add or Modify a Hook

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
free prose — a hook that merely *mentions* git hooks in its docstring is still treated as an
AI-tool hook. A file that does *not* carry the sentinel is treated as an AI-tool hook and
flagged if unwired — the check fails safe.

The steps below apply to **AI-tool hooks**. An AI-tool hook must be wired into
`AGENT.md` to take effect; adding a hook file without updating the
template is a silent no-op. For git hooks, see `.core/scripts/install-git-hooks.sh` and ADR-0022.

### Step 1 — Write or update the hook

Create or edit `.core/hooks/<name>.py`. Follow the existing hook conventions:
- Read tool input from `json.load(sys.stdin)`
- PreToolUse hooks: exit 1 to block, exit 0 to allow
- PostToolUse hooks: always exit 0 (informational only)
- Include a `AGENT_<HOOKNAME>_DISABLED=1` circuit breaker for conditional hooks
- Unconditional safety hooks (e.g. `package-install-guard.py`) must not have a circuit breaker

### Step 2 — Wire into settings.json.template

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

### Step 3 — Verify wiring

Run the hook audit check to confirm no hooks are unwired:

```sh
python3 .core/scripts/check-hook-wiring.py
```

### Step 4 — Test the hook

```sh
# PreToolUse — pipe a simulated tool call to the hook directly
echo '{"tool_input": {"command": "your test command"}}' | python3 .core/hooks/<name>.py
echo "exit: $?"
```

### Step 5 — Commit both files together

Hook files and `settings.json.template` are coupled artifacts — always commit them
in the same commit:

```sh
git add .core/hooks/<name>.py AGENT.md
git commit -m "feat: add <name> hook [AC-NNNN]"
```

---

## sync-agents.sh Flags

```sh
.agents/sync-agents.sh             # generate all agents
.agents/sync-agents.sh --dry-run   # preview without writing
.agents/sync-agents.sh --clean     # remove orphaned generated files
.agents/sync-agents.sh <name>      # generate single agent only
```
