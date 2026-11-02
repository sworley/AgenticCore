#!/usr/bin/env bash
# run-all.sh — Run all MCP smoke tests and report pass/fail.
# Usage: bash mddocs/scripts/mcp-tests/run-all.sh
# Must be run from the repository root.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  shift
  echo "=== $name ==="
  if "$@"; then
    echo ""
    echo "[OK] $name passed"
    PASS=$((PASS + 1))
  else
    echo ""
    echo "[ERROR] $name failed"
    FAIL=$((FAIL + 1))
  fi
  echo ""
}

run_test "rag-docs" uv run "$SCRIPT_DIR/test-mcp-rag-docs.py"

TOTAL=$((PASS + FAIL))
echo "MCP tests: ${PASS}/${TOTAL} passed"
[[ $FAIL -eq 0 ]]
