#!/usr/bin/env python3
"""
block-web-tools.py — PreToolUse hook for WebFetch and WebSearch.

Blocks all web tool calls unless TOOLCHAIN_WEB_ALLOWED=1 is set.
Exit 1 = block the tool call.
"""
import json
import os
import sys

input_data = json.load(sys.stdin)

if os.environ.get("TOOLCHAIN_WEB_ALLOWED") == "1":
    sys.exit(0)

tool = input_data.get("tool_name", "unknown")
print(
    f"[block-web-tools] {tool} is blocked by default. "
    "Set TOOLCHAIN_WEB_ALLOWED=1 to allow web access in this session.",
    file=sys.stderr,
)
sys.exit(1)
