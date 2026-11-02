#!/usr/bin/env python3
"""
session-logger.py — Append-only session reasoning log.

Handles three hook events:
  UserPromptSubmit — captures user intent (the NLU layer)
  PostToolUse      — captures significant agent actions (Agent, Workflow, Bash, Edit, Write)
  Stop             — marks end of each session turn

Output: _scratch/sessions/YYYY-MM-DD_<session_id[:8]>.log

WHY THIS EXISTS:
  The runtime.auto-compact and context-window compression preserve outcome (what
  changed) but discard reasoning — WHY decisions were made, what alternatives were
  rejected, what the user's intent was. That NLU layer is what allows a new session
  to understand rather than just re-execute.

  This hook captures those signals continuously into a plain-text log that lives on
  disk, survives auto-compact, and can be read at the top of any follow-on session to
  restore context without replaying the full conversation history.

AGENT vs WORKFLOW:
  Agent tool calls appear as:  AGENT(<subagent_type>) [background|foreground]: <description>
  Workflow tool calls appear as: WORKFLOW: <name or script excerpt>

  Note: agents spawned INSIDE a workflow (via agent() calls in the script) are NOT
  captured here — they run inside the workflow runtime and never pass through the
  main session's hook layer. A workflow that spawns 50 subagents will show as a
  single WORKFLOW entry. Only top-level Agent tool calls from the main session appear
  individually.
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Relative to this hook file: ../../_scratch/sessions/
_HOOK_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _HOOK_DIR.parent.parent
LOG_DIR = _REPO_ROOT / "_scratch" / "sessions"

# Tools that carry reasoning signal — everything else is noise (Read, LSP, mcp__filesystem__, etc.)
SIGNAL_TOOLS = {"Agent", "Workflow", "Bash", "Edit", "Write", "NotebookEdit"}

# UUID pattern fragment reused across several entries below
_UUID_RE = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

# Secret patterns to redact from logged strings.
# Mirrors coverage from secret-scan-output.py with additions for CLI flag forms.
# Order: more-specific patterns before less-specific ones.
_SECRET_PATTERNS = [
    # CLI flag forms with UUID values
    (re.compile(r'--tenant\s+' + _UUID_RE, re.IGNORECASE),
     '--tenant [REDACTED]'),
    (re.compile(r'--client-id\s+' + _UUID_RE, re.IGNORECASE),
     '--client-id [REDACTED]'),
    # CLI flag forms with arbitrary values
    (re.compile(r'--password\s+\S+', re.IGNORECASE),
     '--password [REDACTED]'),
    (re.compile(r'--client-secret\s+\S+', re.IGNORECASE),
     '--client-secret [REDACTED]'),
    (re.compile(r'--secret\s+\S+', re.IGNORECASE),
     '--secret [REDACTED]'),
    # Named-key environment variable forms (export optional, more-specific first)
    (re.compile(r'(export\s+SP_CLIENT_SECRET\s*=\s*)\S+', re.IGNORECASE),
     r'\1[REDACTED]'),
    (re.compile(r'(SP_CLIENT_SECRET\s*=\s*)\S+', re.IGNORECASE),
     r'\1[REDACTED]'),
    (re.compile(r'(AZURE_CLIENT_SECRET\s*=\s*)\S+', re.IGNORECASE),
     r'\1[REDACTED]'),
    (re.compile(r'(VM_ADMIN_PASSWORD\s*=\s*)\S+', re.IGNORECASE),
     r'\1[REDACTED]'),
    # GIT_TOKEN — bare and quoted key=value forms
    (re.compile(r'(GIT_TOKEN\s*=\s*)\S+', re.IGNORECASE),
     r'\1[REDACTED]'),
    # Git PAT literal tokens (mirrors secret-scan glpat pattern)
    (re.compile(r'glpat-[A-Za-z0-9_\-]{20,}'),
     'glpat-[REDACTED]'),
    # Azure subscription IDs in resource paths
    (re.compile(r'/subscriptions/' + _UUID_RE, re.IGNORECASE),
     '/subscriptions/[SUB-REDACTED]'),
    # Entra ID / Azure object GUIDs on named secret-adjacent keys
    # Mirrors secret-scan "id"/object-id/group-id pattern; uses capture group for prefix.
    (re.compile(
        r'(?i)((?:object[_-]?id|group[_-]?id|--object-id|--group-id)\s*[=:\s]+)' + _UUID_RE),
     r'\1[UUID-REDACTED]'),
]

# Parent directory containing all bench copies (AgenticCore.v1, AgenticCore.00, ...)
# Paths under this parent are shortened to <bench-name>/rest/of/path
_BENCH_PARENT = _REPO_ROOT.parent


def _redact(text: str) -> str:
    if not text:
        return text
    for pattern, replacement in _SECRET_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


def _truncate(text: str, max_len: int = 300) -> str:
    if len(text) <= max_len:
        return text
    return text[:max_len] + f" … [{len(text) - max_len} chars]"


def _shorten_path(path: str) -> str:
    """Shorten any path under the bench parent to <bench-name>/rest/of/path."""
    try:
        p = Path(path)
        rel = p.relative_to(_BENCH_PARENT)
        parts = rel.parts
        if len(parts) > 1:
            return f"{parts[0]}/{'/'.join(parts[1:])}"
        return str(rel)
    except ValueError:
        return path


def _get_log_path(session_id: str) -> Path:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    short_id = (session_id or "unknown")[:8]
    return LOG_DIR / f"{date_str}_{short_id}.log"


def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%H:%M:%SZ")


def _append(log_path: Path, line: str) -> None:
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def _write_header(log_path: Path, session_id: str) -> None:
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    _append(log_path, f"=== SESSION: {session_id} | {date_str} ===")
    _append(log_path, "")


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

def _handle_user_prompt(data: dict, log_path: Path) -> None:
    if not log_path.exists():
        _write_header(log_path, data.get("session_id", "unknown"))

    prompt = _truncate(_redact(data.get("prompt", "").strip()), 600)
    # Strip embedded newlines to prevent log-injection attacks
    prompt = prompt.replace('\n', ' ').replace('\r', '')
    _append(log_path, f"[{_ts()}] USER: {prompt}")
    _append(log_path, "")


def _handle_post_tool_use(data: dict, log_path: Path) -> None:
    tool_name = data.get("tool_name", "")
    if tool_name not in SIGNAL_TOOLS:
        return

    # Ensure header exists if UserPromptSubmit didn't fire (e.g. tool-only session)
    if not log_path.exists():
        _write_header(log_path, data.get("session_id", "unknown"))

    ts = _ts()
    inp = data.get("tool_input", {}) or {}

    if tool_name == "Agent":
        subagent = inp.get("subagent_type", "general-purpose")
        description = inp.get("description", "")
        bg = "bg" if inp.get("run_in_background", True) else "fg"
        # Strip newlines from prompt preview to prevent log-injection
        prompt_preview = _truncate(inp.get("prompt", ""), 200)
        prompt_preview = prompt_preview.replace('\n', ' ').replace('\r', '')
        _append(log_path, f"[{ts}] AGENT({subagent}) [{bg}]: {description}")
        if prompt_preview:
            _append(log_path, f"  prompt: {prompt_preview}")
        _append(log_path, "")

    elif tool_name == "Workflow":
        name = inp.get("name", "")
        script_path = inp.get("scriptPath", "")
        script_raw = inp.get("script", "")
        script_name = ""
        if script_raw:
            for line in script_raw.splitlines():
                if "name:" in line:
                    m = re.search(r"name:\s*['\"]?([^'\"},\s]+)", line)
                    if m:
                        script_name = m.group(1)
                    break
        label = name or script_path or script_name or _truncate(script_raw, 120)
        _append(log_path, f"[{ts}] WORKFLOW: {label}")
        _append(log_path, "  note: agents spawned inside this workflow are not individually logged")
        _append(log_path, "")

    elif tool_name == "Bash":
        cmd = _truncate(_redact(inp.get("command", "")), 250)
        # Strip embedded newlines to prevent log-injection attacks
        cmd = cmd.replace('\n', ' ').replace('\r', '')
        bg = " [bg]" if inp.get("run_in_background", False) else ""
        resp = data.get("tool_response", {})
        exit_part = ""
        if isinstance(resp, dict) and "exit_code" in resp:
            exit_part = f" → exit:{resp['exit_code']}"
        elif isinstance(resp, str) and resp.startswith("Error"):
            exit_part = " → ERROR"
        _append(log_path, f"[{ts}] BASH{bg}: {cmd}{exit_part}")
        _append(log_path, "")

    elif tool_name in ("Edit", "Write"):
        fp = _shorten_path(inp.get("file_path", ""))
        _append(log_path, f"[{ts}] {tool_name.upper()}: {fp}")
        _append(log_path, "")

    elif tool_name == "NotebookEdit":
        fp = _shorten_path(inp.get("notebook_path", ""))
        _append(log_path, f"[{ts}] NOTEBOOK_EDIT: {fp}")
        _append(log_path, "")


def _handle_stop(data: dict, log_path: Path) -> None:
    if log_path.exists():
        _append(log_path, f"[{_ts()}] STOP — turn end")
        _append(log_path, "")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    session_id = data.get("session_id", "unknown")
    log_path = _get_log_path(session_id)
    event = data.get("hook_event_name", "")

    try:
        if event == "UserPromptSubmit":
            _handle_user_prompt(data, log_path)
        elif event == "PostToolUse":
            _handle_post_tool_use(data, log_path)
        elif event == "Stop":
            _handle_stop(data, log_path)
    except Exception:
        pass  # Never block the session

    sys.exit(0)


if __name__ == "__main__":
    main()
