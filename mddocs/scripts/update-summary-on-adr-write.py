#!/usr/bin/env python3
"""
PostToolUse hook — auto-insert new ADR entries into mddocs/SUMMARY.md.
Fires on Write tool calls targeting mddocs/adr/adr-*.md files.
Exits 0 silently on no-match or already-present.

Deploy: reference this script in .opencode/settings.json (or opencode.json)
under hooks.PostToolUse for the Write tool event.
"""
import sys
import json
import re
import subprocess
import pathlib

data = json.load(sys.stdin)
fp = data.get("tool_input", {}).get("file_path", "")

# Resolve repository root dynamically — no hardcoded paths
try:
    project_root = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        stderr=subprocess.DEVNULL,
        text=True
    ).strip()
except Exception:
    sys.exit(0)

summary_path = project_root + "/mddocs/SUMMARY.md"
adr_dir = project_root + "/mddocs/adr/"

# Only fire for files that look like ADR docs
if not (fp.startswith(adr_dir) and re.search(r"/adr-\d+.*\.md$", fp)):
    sys.exit(0)

rel = "adr/" + pathlib.Path(fp).name

# Extract the H1 title from the ADR file
try:
    with open(fp) as f:
        for line in f:
            line = line.strip()
            if line.startswith("# "):
                title = line[2:]
                break
        else:
            title = pathlib.Path(fp).stem
except Exception:
    title = pathlib.Path(fp).stem

entry = "  - [" + title + "](" + rel + ")"

with open(summary_path) as f:
    content = f.read()

# Already present — nothing to do
if rel in content:
    sys.exit(0)

lines = content.splitlines(keepends=True)
last_adr_idx = -1
for i, line in enumerate(lines):
    if re.search(r"adr/adr-", line):
        last_adr_idx = i

if last_adr_idx == -1:
    print("update-summary-on-adr-write: ERROR — could not find ADR section in SUMMARY.md", file=sys.stderr)
    sys.exit(0)

lines.insert(last_adr_idx + 1, entry + "\n")

with open(summary_path, "w") as f:
    f.write("".join(lines))

print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "SUMMARY.md updated: added " + entry.strip()}}))
