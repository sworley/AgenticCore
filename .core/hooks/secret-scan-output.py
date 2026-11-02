#!/usr/bin/env python3
"""
secret-scan-output.py — PostToolUse hook for Read, Bash, and MCP filesystem tools.

Scans tool output for sensitive patterns and warns to stderr before the agent
acts on the content. Does not block access — always exits 0 (informational only).

The agent must not echo detected values back to the user, include them in
conversation text, write them into documentation, or commit them to any repository.
"""

import json
import re
import sys


def extract_text(obj):
    if isinstance(obj, str):
        return obj
    if isinstance(obj, dict):
        for key in ("content", "output", "result", "text", "tool_result"):
            if key in obj:
                return extract_text(obj[key])
        return json.dumps(obj)
    if isinstance(obj, list):
        return "\n".join(extract_text(i) for i in obj)
    return str(obj)


data = json.load(sys.stdin)
content = extract_text(data)

PATTERNS = [
    (
        r"glpat-[A-Za-z0-9_\-]{20,}",
        "Git personal access token (glpat-…)",
    ),
    (
        r"ghp_[A-Za-z0-9]{36}",
        "GitHub classic personal access token (ghp_…)",
    ),
    (
        r"github_pat_[A-Za-z0-9_]{82}",
        "GitHub fine-grained personal access token (github_pat_…)",
    ),
    (
        r"(?i)(?:client[_-]?secret|client[_-]?password|sp[_-]?secret)\s*[=:\"]\s*\S+",
        "client secret or SP password value",
    ),
    (
        r"(?i)(?:password|passwd)\s*[=:\"]\s*(?!null|true|false|<)[^\s\"',]{4,}",
        "password field with value",
    ),
    (
        r"(?i)(?:token|api[_-]?key|access[_-]?key|pat)\s*[=:\"]\s*[A-Za-z0-9+/\-_]{20,}",
        "token or API key value",
    ),
    (
        r"DefaultEndpointsProtocol=https?;AccountName=",
        "storage connection string",
    ),
    (
        r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----",
        "private key material",
    ),
]

findings = []
for pattern, label in PATTERNS:
    if re.search(pattern, content):
        findings.append(label)

if findings:
    labels = ", ".join(findings)
    print(
        f"[secret-scan-output] WARNING — sensitive content detected in tool output: {labels}.\n"
        f"  Do NOT echo these values back to the user, include them in conversation text,\n"
        f"  write them into documentation, or commit them to any repository.\n"
        f"  Reference resources by name or logical identifier only.",
        file=sys.stderr,
    )

sys.exit(0)
