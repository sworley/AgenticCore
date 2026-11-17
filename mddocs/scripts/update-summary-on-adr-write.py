#!/usr/bin/env python3
"""
PostToolUse hook — auto-insert new ADR rows into the active ADR index.
Fires on Write tool calls targeting mddocs/management/governance/decisions/adr-*.md.
Under the forward-only model (ADR-0029 D1; ADR-0030), new ADRs live there and are
recorded in mddocs/management/governance/decisions/index.md (the active, primary-true
index). Historical ADRs (ADR-0000–0028) remain in mddocs/adr/ and are not touched here.
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

active_dir = project_root + "/mddocs/management/governance/decisions/"
active_index = active_dir + "index.md"

# Only fire for ADR docs in the forward-only active location
if not (fp.startswith(active_dir) and re.search(r"/adr-\d+.*\.md$", fp)):
    sys.exit(0)

name = pathlib.Path(fp).name
m = re.match(r"adr-(\d+).*\.md$", name)
if not m:
    sys.exit(0)
adr_id = m.group(1)

# Extract Title/Status/Date from the ADR header
title = pathlib.Path(fp).stem
status = "proposed"
date = ""
with open(fp) as f:
    for line in f:
        line = line.strip()
        if line.startswith("# "):
            title = line[2:]
        elif line.startswith("**Status:**"):
            status = line.split("**Status:**", 1)[1].strip()
        elif line.startswith("**Date:**"):
            date = line.split("**Date:**", 1)[1].strip()

row = "| [ADR-%s](%s) | %s | %s | %s |" % (adr_id, name, title, status, date)

with open(active_index) as f:
    content = f.read()

# Already present — nothing to do
if name in content:
    sys.exit(0)

lines = content.splitlines(keepends=True)
last_data_idx = -1
for i, line in enumerate(lines):
    if line.lstrip().startswith("| [ADR-"):
        last_data_idx = i
if last_data_idx == -1:
    # No data rows yet — insert right after the table separator row
    for i, line in enumerate(lines):
        if re.match(r"^\s*\|[-: ]+\|", line):
            last_data_idx = i
            break

if last_data_idx == -1:
    print("update-summary-on-adr-write: ERROR — could not find ADR table in active index", file=sys.stderr)
    sys.exit(0)

lines.insert(last_data_idx + 1, row + "\n")

with open(active_index, "w") as f:
    f.write("".join(lines))

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Active ADR index updated: added " + row.strip()
}}))
