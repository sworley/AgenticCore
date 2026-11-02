#!/usr/bin/env python3
"""
read-scope-guard.py — PreToolUse hook for the Read tool.

Blocks Read calls whose resolved path falls outside:

  1. The collection root (determined via `git rev-parse --show-toplevel`)
  2. The AI toolchain memory directory (~/.opencode/projects/)

Override: set READ_SCOPE_GUARD_DISABLED=1 in the session environment to
bypass the guard for the duration of that session.

Exit codes:
  0  — allow
  2  — block (JSON body on stdout consumed by the harness)

The hook is non-fatal on errors: malformed input, git failure, or any
unexpected exception is logged to stderr and exits 0 so agent work is
never silently killed by a hook error.
"""

import json
import os
import subprocess
import sys


def _collection_root() -> str:
    """Return the git collection root; fall back to parent of .core/hooks/."""
    script_dir = os.path.dirname(os.path.realpath(__file__))
    try:
        result = subprocess.run(
            ["git", "-C", script_dir, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            return os.path.realpath(result.stdout.strip())
    except Exception as exc:  # noqa: BLE001
        print(f"[read-scope-guard] git rev-parse failed: {exc}", file=sys.stderr)

    # Fallback: .core/hooks/ -> .agentic/ -> collection root
    return os.path.realpath(os.path.join(script_dir, "..", ".."))


def _memory_root() -> str:
    """Return the AI toolchain projects memory directory."""
    return os.path.realpath(os.path.expanduser("~/.opencode/projects"))


def _is_under(path: str, root: str) -> bool:
    """Return True if path is equal to or under root."""
    # Ensure trailing sep so /foo/bar doesn't match /foo/baz
    root_prefix = root if root.endswith(os.sep) else root + os.sep
    return path == root or path.startswith(root_prefix)


def main() -> None:
    # --- bypass override ---
    if os.environ.get("READ_SCOPE_GUARD_DISABLED") == "1":
        sys.exit(0)

    # --- parse stdin ---
    try:
        data = json.load(sys.stdin)
    except Exception as exc:  # noqa: BLE001
        print(f"[read-scope-guard] Could not parse stdin JSON: {exc}", file=sys.stderr)
        sys.exit(0)  # non-fatal

    tool_input = data.get("tool_input", {})
    raw_path = tool_input.get("file_path", "")

    if not raw_path:
        # No path provided — let the harness handle validation
        sys.exit(0)

    resolved = os.path.realpath(os.path.expanduser(raw_path))

    collection_root = _collection_root()
    memory_root = _memory_root()

    if _is_under(resolved, collection_root) or _is_under(resolved, memory_root):
        sys.exit(0)

    # Block
    block_msg = json.dumps({
        "decision": "block",
        "reason": (
            f"Read blocked: path is outside the collection root. "
            f"Requested: {resolved} | "
            f"Allowed root: {collection_root} | "
            f"Set READ_SCOPE_GUARD_DISABLED=1 to override for this session."
        ),
    })
    print(block_msg)
    sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print(f"[read-scope-guard] Unexpected error: {exc}", file=sys.stderr)
        sys.exit(0)  # non-fatal — never silently kill agent work
