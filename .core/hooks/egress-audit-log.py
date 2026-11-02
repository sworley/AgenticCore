#!/usr/bin/env python3
"""
egress-audit-log.py — PostToolUse hook for Bash, WebFetch, WebSearch.

Appends a JSON line to ~/.agentic/audit/session-<date>.jsonl for each
egress-relevant tool call. Never interrupts agent work on failure.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

INLINE_SECRET_RE = re.compile(
    r'(?:TOKEN|SECRET|PASSWORD|PASSWD|PAT|API_KEY|CLIENT_SECRET|VAULT_PASS)'
    r'\s*=\s*\S+',
    re.IGNORECASE,
)


def redact(text: str) -> str:
    """Replace inline secret assignments with [REDACTED]."""
    return INLINE_SECRET_RE.sub(lambda m: m.group(0).split('=')[0] + '=[REDACTED]', text)


def audit_dir() -> Path:
    d = Path.home() / '.agentic' / 'audit'
    d.mkdir(parents=True, exist_ok=True)
    return d


def log_line(record: dict) -> None:
    date_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    log_path = audit_dir() / f'session-{date_str}.jsonl'
    with open(log_path, 'a') as f:
        f.write(json.dumps(record) + '\n')


def main() -> None:
    data = json.load(sys.stdin)
    tool_name = data.get('tool_name', '')
    tool_input = data.get('tool_input', {})
    tool_response = data.get('tool_response', {})
    ts = datetime.now(timezone.utc).isoformat()

    if tool_name == 'Bash':
        command = tool_input.get('command', '')
        exit_code = None
        if isinstance(tool_response, dict):
            exit_code = tool_response.get('exit_code')
        record = {
            'ts': ts,
            'tool': 'Bash',
            'command': redact(command[:200]),
            'exit_code': exit_code,
        }
        log_line(record)

    elif tool_name == 'WebFetch':
        url = tool_input.get('url', '')
        record = {
            'ts': ts,
            'tool': 'WebFetch',
            'url': url,
            'web_allowed': os.environ.get('TOOLCHAIN_WEB_ALLOWED', 'unset'),
        }
        log_line(record)

    elif tool_name == 'WebSearch':
        query = tool_input.get('query', '')
        record = {
            'ts': ts,
            'tool': 'WebSearch',
            'query': query,
        }
        log_line(record)


try:
    main()
except Exception as e:
    print(f'egress-audit-log: {e}', file=sys.stderr)

sys.exit(0)
