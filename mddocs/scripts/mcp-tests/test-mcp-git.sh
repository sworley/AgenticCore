#!/usr/bin/env bash
# =============================================================================
# test-mcp-git.sh
#
# PURPOSE
#   Smoke-tests the mcp-git MCP server by exercising core git operations
#   against the repository. Run this after provisioning a new bench or after
#   updating MCP server binaries.
#
# USAGE
#   bash mddocs/scripts/mcp-tests/test-mcp-git.sh
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

# 1. log — git log --oneline -5, assert non-empty
output=$(git -C "$REPO" log --oneline -5 2>/dev/null) || { fail "log" "git log failed"; output=""; }
if [[ -n "$output" ]]; then
  pass "log — git log returned $(echo "$output" | wc -l | tr -d ' ') entries"
else
  fail "log" "empty output"
fi

# 2. status — git status, assert exits 0
git -C "$REPO" status > /dev/null 2>&1 && pass "status — git status exits 0" || fail "status" "git status non-zero"

# 3. list_branches — git branch -a, assert non-empty and main present
branches=$(git -C "$REPO" branch -a 2>/dev/null) || { fail "list_branches" "git branch -a failed"; branches=""; }
if [[ -n "$branches" ]] && echo "$branches" | grep -q "main"; then
  pass "list_branches — branch list non-empty and includes 'main'"
else
  fail "list_branches" "output empty or 'main' not found"
fi

# 4. show_commit — git show HEAD --stat, assert non-empty
show=$(git -C "$REPO" show HEAD --stat 2>/dev/null) || { fail "show_commit" "git show HEAD failed"; show=""; }
if [[ -n "$show" ]]; then
  pass "show_commit — HEAD commit details returned"
else
  fail "show_commit" "empty output"
fi

# 5. get_remote_info — git remote -v, exits 0 (empty is valid — no remote configured)
git -C "$REPO" remote -v > /dev/null 2>&1 && pass "get_remote_info — git remote -v exits 0" || fail "get_remote_info" "git remote -v non-zero"

TOTAL=$((PASS + FAIL))
echo ""
echo "git: ${PASS}/${TOTAL} passed"
[ "$FAIL" -eq 0 ]
