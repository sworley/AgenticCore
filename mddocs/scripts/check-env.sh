#!/bin/sh
# check-env.sh — Validate the developer environment before starting a session
#
# Usage: ./mddocs/scripts/check-env.sh
#
# Required env vars are read from .env-required (one per line, blank lines and
# # comments ignored). If .env-required does not exist, only tool checks run.
#
# Example .env-required:
#   # Git credentials
#   GIT_HOST
#   GIT_TOKEN
#   # Project identifier
#   MY_PROJECT_ID
#
# Tool checks (always run): mdbook, jq, python3
#
# Exit codes:
#   0  All checks pass
#   1  One or more checks failed

set -u

failures=0

check() {
  label="$1"
  result="$2"
  if [ "$result" = "ok" ]; then
    printf "  [ok] %s\n" "$label"
  else
    printf "  [FAIL] %s — %s\n" "$label" "$result"
    failures=$((failures + 1))
  fi
}

echo "==> check-env: validating developer environment"

# --- Required env vars (configurable) ---
ENV_REQUIRED_FILE=".env-required"

if [ -f "$ENV_REQUIRED_FILE" ]; then
  echo ""
  echo "-- env vars ($ENV_REQUIRED_FILE) --"
  while IFS= read -r line; do
    # strip comments and blank lines
    line=$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')
    [ -z "$line" ] && continue
    eval "val=\${${line}:-}"
    if [ -n "$val" ]; then
      check "$line" "ok"
    else
      check "$line" "not set"
    fi
  done < "$ENV_REQUIRED_FILE"
else
  echo ""
  echo "-- env vars: no .env-required found; skipping (see session-open-checklist.md) --"
fi

# --- Tool checks (always run) ---
echo ""
echo "-- tools --"

if command -v mdbook >/dev/null 2>&1; then
  check "mdbook" "ok"
else
  check "mdbook" "not found — install with: cargo install mdbook"
fi

if command -v jq >/dev/null 2>&1; then
  check "jq" "ok"
else
  check "jq" "not found — install with: brew install jq"
fi

if command -v python3 >/dev/null 2>&1; then
  check "python3" "ok"
else
  check "python3" "not found — required for sync-agents.sh"
fi

if command -v uv >/dev/null 2>&1; then
  check "uv" "ok"
else
  check "uv" "not found — install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# --- MCP server presence checks ---
echo ""
echo "-- mcp servers --"

if [ -f "mcp/review-ledger/server.py" ]; then
  check "mcp/review-ledger/server.py" "ok"
else
  check "mcp/review-ledger/server.py" "not found — TC-026 MCP server missing; ensure mcp/review-ledger/ is present"
fi

if command -v jq >/dev/null 2>&1 && [ -f "opencode.json" ]; then
  if jq -e '.mcp["review-ledger-security"] and .mcp["review-ledger-reviews"]' opencode.json >/dev/null 2>&1; then
    check "opencode.json mcp wiring (review-ledger-security, review-ledger-reviews)" "ok"
  else
    check "opencode.json mcp wiring (review-ledger-security, review-ledger-reviews)" "not wired — TC-031 opencode.json mcp block missing review-ledger-security and/or review-ledger-reviews entries"
  fi
else
  check "opencode.json mcp wiring (review-ledger-security, review-ledger-reviews)" "skipped — jq or opencode.json not found"
fi

# --- Summary ---
echo ""
if [ "$failures" -eq 0 ]; then
  echo "==> All checks passed"
  exit 0
else
  echo "==> $failures check(s) failed — resolve before proceeding"
  exit 1
fi
