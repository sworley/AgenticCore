# Runbook: secret-guard Hook

## Overview

`secret-guard` is a `PreToolUse` hook that runs before every Bash tool call in
AI toolchain sessions. It blocks commands that would expand or print credential
values in plaintext and prints a safe alternative to stderr.

The hook is a Python script at `.agentic/hooks/secret-guard.py`. It is wired
in `.agentic/settings.local.json` and fires automatically — no manual invocation
is needed.

---

## Blocked Patterns

### 1. `cat` / `head` / `tail` on shell config or `.env` files

```bash
# Blocked
cat ~/.zshrc
head ~/.bash_profile
tail .env
```

Safe alternative — grep for the specific key with value redacted:

```bash
grep 'SPECIFIC_KEY_NAME' ~/.zshrc | sed 's/=.*/=[REDACTED]/'
```

---

### 2. `grep` on shell config or `.env` files

```bash
# Blocked
grep TOKEN ~/.zshrc
grep -i secret .env
```

Safe alternatives:

```bash
# Redacted value
grep 'SPECIFIC_KEY_NAME' ~/.zshrc | sed 's/=.*/=[REDACTED]/'

# Presence check only
[ -n "$VAR" ] && echo 'SET' || echo 'NOT SET'
```

---

### 3. `echo` / `printf` expanding a known secret variable

Variable names containing `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `PAT`,
`API_KEY`, or `CLIENT_SECRET` are matched.

```bash
# Blocked
echo $SP_CLIENT_SECRET
printf "%s\n" "$AZURE_CLIENT_SECRET"
```

Safe alternative:

```bash
[ -n "$SP_CLIENT_SECRET" ] && echo 'SET' || echo 'NOT SET'
```

---

### 4. `env` / `printenv` piped through `grep` on secret-adjacent terms

```bash
# Blocked
env | grep SECRET
printenv | grep TOKEN
```

Safe alternative:

```bash
[ -n "$VAR" ] && echo 'SET' || echo 'NOT SET'
```

---

### 5. `printenv` on a named secret variable

```bash
# Blocked
printenv SP_CLIENT_SECRET
printenv AZURE_CLIENT_SECRET
```

Safe alternative:

```bash
[ -n "$SP_CLIENT_SECRET" ] && echo 'SET' || echo 'NOT SET'
```

---

### 6. Bare `pass show` invocation

`pass show` without output capture prints the plaintext secret to stdout.

```bash
# Blocked
pass show vault/platform/pat
pass show azure/sp-secret
```

Safe alternative — capture into a variable, never let the value reach stdout:

```bash
# Allowed — output captured inside $(...)
VARNAME="$(pass show vault/platform/pat 2>/dev/null)"
```

The guard strips all `$(pass show …)` occurrences from the command, then checks
whether any bare `pass show` remains. A command that mixes both forms is blocked.

---

## Bypass: Explicit Redaction Pipe

Any command that already pipes through `sed 's/=.*/=[REDACTED]/'` is allowed
through unconditionally:

```bash
# Allowed — redaction pattern detected
grep 'SP_CLIENT' ~/.zshrc | sed 's/=.*/=[REDACTED]/'
```

---

## Validation

Test a rule change before committing by feeding synthetic tool input directly to the script.
The hook reads a JSON object from stdin — the same structure AI toolchain sends at runtime.

```bash
# Should be BLOCKED (exit 1) — bare pass show
echo '{"tool_name":"Bash","tool_input":{"command":"pass show vault/x/y"}}' \
  | python3 .agentic/hooks/secret-guard.py 2>&1; echo "Exit: $?"

# Should PASS (exit 0) — output captured inside $()
echo '{"tool_name":"Bash","tool_input":{"command":"VARNAME=\"$(pass show vault/x/y 2>/dev/null)\""}}' \
  | python3 .agentic/hooks/secret-guard.py 2>&1; echo "Exit: $?"

# Should be BLOCKED (exit 1) — printenv on a secret variable
echo '{"tool_name":"Bash","tool_input":{"command":"printenv AZURE_CLIENT_SECRET"}}' \
  | python3 .agentic/hooks/secret-guard.py 2>&1; echo "Exit: $?"

# Should PASS (exit 0) — redaction pipe present
echo '{"tool_name":"Bash","tool_input":{"command":"grep TOKEN ~/.zshrc | sed '\''s/=.*/=[REDACTED]/'\'' "}}' \
  | python3 .agentic/hooks/secret-guard.py 2>&1; echo "Exit: $?"
```

Run these after every rule change. Confirm blocked cases exit `1` with a message on stderr
and safe cases exit `0` with no output.

---

## Rollback

See [Hook Rollback](hook-rollback.md) for the full procedure.

**Quick reference — revert a rule change:**

```bash
# Identify the last known-good commit for this file
git log --oneline -- .agentic/hooks/secret-guard.py

# Restore the file from that commit (creates a forward change, does not rewrite history)
git checkout <commit> -- .agentic/hooks/secret-guard.py
git commit -m "fix(AP-NNN): revert secret-guard.py to known-good state"
```

**Emergency disable for the current session only (no commit required):**

Edit `.agentic/settings.local.json` and remove or comment the `secret-guard.py` command
entry under `PreToolUse`. Restart the AI toolchain session. This does not affect the
template or any other session.

---

## Updating the Hook

The hook source is at `.agentic/hooks/secret-guard.py`. To add a new blocked
pattern, add a tuple to the `RULES` list:

```python
(
    r"<regex matching the command>",
    "reason shown to the agent",
    "safe alternative shown to the agent",
),
```

Re-deploy after editing:

```bash
bash mddocs/scripts/setup/opencode.json
```

---

## Related

- [Hook Rollback](hook-rollback.md) — emergency disable, revert, and full rollback procedure for all hooks
- [ADR-: Agentic Agent Enforcement Posture](../../adr/adr-0022-git-pre-commit-permission-order-check.md)
