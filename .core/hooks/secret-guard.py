#!/usr/bin/env python3
"""
secret-guard.py — PreToolUse hook for Bash.

Blocks commands that would expand or print credential values in plaintext.
Triggered by:
  1. cat / head / tail on shell config or .env files
  2. grep on shell config or .env files without a redaction pipe
  3. Direct echo/printf expansion of known secret variable names
  4. env / printenv filtered to secret-adjacent terms

Safe alternatives are printed to stderr when a command is blocked.
"""

import json
import os
import re
import sys

# Circuit breaker — set SECRET_GUARD_DISABLED=1 to bypass for the current session.
# Naming convention: AGENTIC_<HOOKNAME>_DISABLED=1. Does not persist across sessions
# unless exported in .envrc. Clear when done.
if os.environ.get("SECRET_GUARD_DISABLED") == "1":
    sys.exit(0)

data = json.load(sys.stdin)
command = data.get("tool_input", {}).get("command", "")

# Files known to contain secrets
SECRET_FILES = r"(?:~/\.zshrc|~/\.bashrc|~/\.bash_profile|~/\.profile|\.env(?:\b|$)|\.envrc(?:\b|$)|settings\.local\.json)"

# Variable name fragments that indicate a secret
SECRET_VAR_NAMES = r"(?:TOKEN|SECRET|PASSWORD|PASSWD|PAT(?:\b|_)|API_KEY|CLIENT_SECRET|VAULT_PASS)"

# If the command pipes through explicit redaction, allow it
REDACTION_RE = re.compile(r"sed\s+['\"]s/=.*?/=\[REDACTED\]/['\"]", re.IGNORECASE)

if REDACTION_RE.search(command):
    sys.exit(0)

RULES = [
    (
        rf"(?:cat|head|tail)\b.*{SECRET_FILES}",
        "printing a shell config or secrets file will expose token values in plaintext",
        "grep 'SPECIFIC_KEY_NAME' ~/.zshrc | sed 's/=.*/=[REDACTED]/'",
    ),
    (
        rf"\bgrep\b.*{SECRET_FILES}",
        "grepping a shell config file may match and print token lines",
        "grep 'SPECIFIC_KEY_NAME' ~/.zshrc | sed 's/=.*/=[REDACTED]/'\n"
        "    Or check presence only: [ -n \"$VAR\" ] && echo 'SET' || echo 'NOT SET'",
    ),
    (
        rf"(?:echo|printf)\s.*\$\{{?[A-Z_]*{SECRET_VAR_NAMES}[A-Z_]*\}}?",
        "direct expansion of a secret variable into echo/printf prints its value",
        "[ -n \"$VAR\" ] && echo 'SET' || echo 'NOT SET'",
    ),
    (
        rf"(?:env|printenv)\b.*\|\s*grep.*{SECRET_VAR_NAMES}",
        "env | grep on secret-adjacent terms will print values",
        "[ -n \"$VAR\" ] && echo 'SET' || echo 'NOT SET'",
    ),
    (
        rf"\bprintenv\b\s+\S*{SECRET_VAR_NAMES}\S*",
        "printenv on a secret variable prints its value",
        "[ -n \"$VAR\" ] && echo 'SET' || echo 'NOT SET'",
    ),
]

for pattern, reason, alt in RULES:
    if re.search(pattern, command, re.IGNORECASE):
        print(
            f"[secret-guard] Blocked — command may expose credential values in plaintext.\n"
            f"  Reason  : {reason}\n"
            f"  Safe alt: {alt}\n"
            f"  To inspect config with redaction use: grep 'KEY' ~/.zshrc | sed 's/=.*/=[REDACTED]/'",
            file=sys.stderr,
        )
        sys.exit(1)

# pass show guard — block bare invocations; allow output-captured form $( pass show ... )
if re.search(r"\bpass\s+show\b", command, re.IGNORECASE):
    sanitized = re.sub(r"\$\(\s*pass\s+show\b", "__SAFE__", command, flags=re.IGNORECASE)
    if re.search(r"\bpass\s+show\b", sanitized, re.IGNORECASE):
        print(
            "[secret-guard] Blocked — bare `pass show` will print the secret to stdout.\n"
            "  Reason  : pass show without output capture prints the plaintext secret\n"
            "  Safe alt: VARNAME=\"$(pass show <path> 2>/dev/null)\"\n"
            "            The captured form assigns the value to a variable without printing it.",
            file=sys.stderr,
        )
        sys.exit(1)

sys.exit(0)
