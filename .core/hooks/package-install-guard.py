#!/usr/bin/env python3
"""
package-install-guard.py — PreToolUse hook for Bash.

Blocks three high-risk patterns unconditionally:
  1. curl/wget piped to sh/bash/zsh (pipe-to-shell)
  2. eval $(curl ...) (eval-of-download)
  3. bash <(curl ...) (process substitution download)

Exit 1 = block. No override flag — these are unconditional.
"""
import json
import re
import sys

input_data = json.load(sys.stdin)
command = input_data.get("tool_input", {}).get("command", "")

BLOCKED_PATTERNS = [
    (r"(curl|wget)\s+.*\|\s*(ba?sh|zsh|sh)", "pipe-to-shell download"),
    (r"eval\s*\$\(\s*(curl|wget)", "eval-of-download"),
    (r"ba?sh\s+<\(\s*(curl|wget)", "process-substitution download"),
]

for pattern, label in BLOCKED_PATTERNS:
    if re.search(pattern, command, re.IGNORECASE):
        print(
            f"[package-install-guard] BLOCKED: {label} pattern detected.\n"
            f"  Command: {command[:120]}",
            file=sys.stderr,
        )
        sys.exit(1)

sys.exit(0)
