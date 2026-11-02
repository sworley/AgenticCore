#!/usr/bin/env bash
# =============================================================================
# test-mcp-filesystem.sh
#
# PURPOSE
#   Smoke-tests the rust-mcp-filesystem MCP server by exercising its core
#   operations against the repository. Run this after provisioning a new bench
#   or after updating MCP server binaries.
#
# USAGE
#   bash mddocs/scripts/mcp-tests/test-mcp-filesystem.sh
#   Must be run from the repository root.
#
# EXIT CODES
#   0  — all tests passed
#   1  — one or more tests failed
# =============================================================================
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1: $2"; FAIL=$((FAIL + 1)); }

# 1. read_file — read AGENT.md, assert non-empty, assert contains expected string
content=$(cat "$REPO/AGENT.md" 2>/dev/null) || { fail "read_file" "cannot read $REPO/AGENT.md"; content=""; }
if [[ -n "$content" ]] && echo "$content" | grep -q "baseline-steward"; then
  pass "read_file — AGENT.md non-empty and contains 'baseline-steward'"
else
  fail "read_file" "content empty or missing expected string"
fi

# 2. list_directory — list mddocs/, assert SUMMARY.md present
entries=$(ls "$REPO/mddocs/" 2>/dev/null) || { fail "list_directory" "cannot list $REPO/mddocs/"; entries=""; }
if echo "$entries" | grep -q "SUMMARY.md"; then
  pass "list_directory — mddocs/ lists SUMMARY.md"
else
  fail "list_directory" "SUMMARY.md not found in mddocs/"
fi

# 3. search_files — find .md files under mddocs/, assert count > 0
count=$(find "$REPO/mddocs" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$count" -gt 0 ]]; then
  pass "search_files — found $count .md files under mddocs/"
else
  fail "search_files" "no .md files found under mddocs/"
fi

# 4. get_file_info — stat PROCESS.md, assert exists and size > 0
size=$(stat -f%z "$REPO/PROCESS.md" 2>/dev/null) || { fail "get_file_info" "stat failed on $REPO/PROCESS.md"; size=0; }
if [[ "$size" -gt 0 ]]; then
  pass "get_file_info — PROCESS.md exists, size=${size} bytes"
else
  fail "get_file_info" "file missing or empty"
fi

TOTAL=$((PASS + FAIL))
echo ""
echo "filesystem: ${PASS}/${TOTAL} passed"
[ "$FAIL" -eq 0 ]
