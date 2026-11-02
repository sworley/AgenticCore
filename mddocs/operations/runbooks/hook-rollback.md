# Runbook: Hook Rollback

**Category:** Platform & Developer Tooling
**Last Updated:** 2026-06-06
**Owner:** Platform Engineering

## Overview

Use this runbook when a AI toolchain hook is misbehaving, blocking valid commands,
or needs to be rolled back after a rule change. Covers three scenarios:

1. **Emergency disable** — unhook a script for the current session without touching git
2. **Revert a rule change** — restore a hook script to a prior state via a forward commit
3. **Validate before committing** — confirm blocked and safe cases behave as expected

For the general hook change strategy (per-hook circuit breakers, env var overrides,
staged rollout), see [ADR-0010: Hook Rollback Strategy](../../adr/adr-0010-hook-rollback-strategy.md).

---

## Prerequisites

- Working directory is a bench that has `.agentic/settings.local.json` generated
- Git access to the branch where the hook change was committed

---

## Hook Inventory

| Script | Event | Matcher(s) | Exits on block |
|--------|-------|------------|----------------|
| `secret-guard.py` | `PreToolUse` | `Bash` | 1 (blocks tool call) |
| `package-install-guard.py` | `PreToolUse` | `Bash` | 1 (blocks tool call) |
| `read-scope-guard.py` | `PreToolUse` | `Read` | 2 (block-with-reason JSON) |
| `secret-scan-output.py` | `PostToolUse` | `Bash`, `Read`, MCP filesystem | 0 (warns only) |
| `egress-audit-log.py` | `PostToolUse` | `Bash`, `WebFetch`, `WebSearch` | 0 (logs only) |
| `check-hook-wiring.py` | `PostToolUse` | — | 0 (warns only) |

`PreToolUse` hooks that exit 1 block the tool call. `read-scope-guard.py` exits 2
(block-with-reason JSON) — the harness consumes the JSON body and surfaces the reason
string to the agent rather than silently blocking. `PostToolUse` hooks always exit 0 —
they warn but never block.

---

## Scenario 1 — Emergency Disable (current session only)

Use this when a hook is blocking a command you need to run immediately and you do not
want to touch git.

### Option A — Circuit breaker (preferred, no restart required)

For hooks that support a circuit breaker env var, set it in the current session and
retry the command:

| Hook | Circuit breaker env var |
|------|------------------------|
| `secret-guard.py` | `export AGENT_SECRET_GUARD_DISABLED=1` |
| `read-scope-guard.py` | `export AGENT_READ_SCOPE_GUARD_DISABLED=1` |
| `package-install-guard.py` | none — unconditional by design (see [ADR-0010](../../adr/adr-0010-hook-rollback-strategy.md)) |

The env var takes effect immediately — no session restart needed. It does not persist
across sessions unless exported in `.envrc`. Clear it when done: `unset AGENT_SECRET_GUARD_DISABLED`.

`package-install-guard.py` has no circuit breaker by design — it is unconditional.
See [ADR-0010](../../adr/adr-0010-hook-rollback-strategy.md) for rationale.

### Option B — Edit settings.local.json (fallback, requires restart)

Use this when the hook does not have a circuit breaker, or when the circuit breaker
does not resolve the issue.

**Step 1.** Open `.agentic/settings.local.json` in an editor (not the template — the
live file):

```bash
$EDITOR .agentic/settings.local.json
```

**Step 2.** Find the hook entry under `PreToolUse` (or the relevant event) and remove
the command object for the offending script. Example — to disable `secret-guard.py`:

```json
// Before
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "python3 \".../.agentic/hooks/secret-guard.py\"" },
    { "type": "command", "command": "python3 \".../.agentic/hooks/package-install-guard.py\"" }
  ]
}

// After (secret-guard removed)
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "python3 \".../.agentic/hooks/package-install-guard.py\"" }
  ]
}
```

**Step 3.** Restart the AI toolchain session. Hooks are loaded at session start.

**Restore:** Re-run `bash mddocs/scripts/setup/opencode.json` to regenerate
`settings.local.json` from the template. This re-enables all hooks.

---

## Scenario 2 — Revert a Hook Script Change

Use this when a committed rule change introduced a regression and you need to restore
the script to a prior state. Always use a forward commit — never rewrite history.

**Step 1.** Identify the last known-good commit for the script:

```bash
git log --oneline -- .agentic/hooks/<script-name>.py
```

**Step 2.** Restore the file from that commit:

```bash
git checkout <commit-sha> -- .agentic/hooks/<script-name>.py
```

**Step 3.** Validate the restored script (see Scenario 3 below).

**Step 4.** Commit the revert as a forward change:

```bash
git add .agentic/hooks/<script-name>.py
git commit -m "fix(AP-NNN): revert <script-name>.py to <commit-sha> — <reason>"
```

---

## Scenario 3 — Validate Before Committing

Test any hook script change by feeding synthetic tool input directly to the script.
The hook reads a JSON object from stdin — the same structure AI toolchain sends at runtime.

### Testing a PreToolUse hook

```bash
# Pattern: exit 1 + stderr message = blocked; exit 0 + no output = allowed

# Test a command that SHOULD be blocked
echo '{"tool_name":"Bash","tool_input":{"command":"<command-to-test>"}}' \
  | python3 .agentic/hooks/<script-name>.py 2>&1; echo "Exit: $?"

# Test the safe alternative that SHOULD pass
echo '{"tool_name":"Bash","tool_input":{"command":"<safe-form>"}}' \
  | python3 .agentic/hooks/<script-name>.py 2>&1; echo "Exit: $?"
```

### Testing a PostToolUse hook (secret-scan-output.py)

`PostToolUse` hooks receive tool output, not input:

```bash
# Should trigger a WARNING on stderr (exit 0)
echo '{"tool_output":"glpat-ABCDEFGHIJ1234567890extra"}' \
  | python3 .agentic/hooks/secret-scan-output.py 2>&1; echo "Exit: $?"

# Should produce no output (exit 0)
echo '{"tool_output":"no sensitive content here"}' \
  | python3 .agentic/hooks/secret-scan-output.py 2>&1; echo "Exit: $?"
```

### Baseline test suite for secret-guard.py

Run this block in full after any `secret-guard.py` change:

```bash
BASE='{"tool_name":"Bash","tool_input":{"command":'

# ── SHOULD BLOCK ─────────────────────────────────────────────
echo "$BASE\"cat ~/.zshrc\"}}" | python3 .agentic/hooks/secret-guard.py 2>/dev/null; \
  [ $? -eq 1 ] && echo "PASS: cat .zshrc blocked" || echo "FAIL: cat .zshrc should block"

echo "$BASE\"pass show vault/x/y\"}}" | python3 .agentic/hooks/secret-guard.py 2>/dev/null; \
  [ $? -eq 1 ] && echo "PASS: bare pass show blocked" || echo "FAIL: bare pass show should block"

echo "$BASE\"echo \$AZURE_CLIENT_SECRET\"}}" | python3 .agentic/hooks/secret-guard.py 2>/dev/null; \
  [ $? -eq 1 ] && echo "PASS: echo secret var blocked" || echo "FAIL: echo secret var should block"

# ── SHOULD PASS ──────────────────────────────────────────────
echo "$BASE\"VARNAME=\\\"\$(pass show vault/x/y 2>/dev/null)\\\"\"}}" \
  | python3 .agentic/hooks/secret-guard.py 2>/dev/null; \
  [ $? -eq 0 ] && echo "PASS: captured pass show allowed" || echo "FAIL: captured pass show should pass"

echo "$BASE\"grep TOKEN ~/.zshrc | sed 's\/=.*\/=[REDACTED]\/'\"}}" \
  | python3 .agentic/hooks/secret-guard.py 2>/dev/null; \
  [ $? -eq 0 ] && echo "PASS: redaction pipe allowed" || echo "FAIL: redaction pipe should pass"
```

All lines should print `PASS`. Any `FAIL` line identifies a regression.

---

## Rollback

If this runbook's own steps produce an unexpected state:

```bash
# Regenerate settings.local.json from the committed template
bash mddocs/scripts/setup/opencode.json

# Restore a hook script to HEAD
git checkout HEAD -- .agentic/hooks/<script-name>.py
```

---

## Related

- [secret-guard Hook](secret-guard.md) — per-rule documentation, safe alternatives, and update guide
- [ADR-: Agentic Agent Enforcement Posture](../../adr/adr-0022-git-pre-commit-permission-order-check.md)
- [ADR-0010: Hook Rollback Strategy](../../adr/adr-0010-hook-rollback-strategy.md) — circuit breakers, env var naming convention, staged rollout, companion script
