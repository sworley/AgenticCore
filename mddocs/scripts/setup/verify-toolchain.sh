#!/bin/bash
# =============================================================================
# verify-toolchain.sh
#
# PURPOSE
#   End-state verification for an AgenticCore development environment.
#   Checks every tool required for docs authoring, scripting, MCP server
#   operation, and agent workflow. Reports PASS / WARN / FAIL for each item
#   and prints a summary at the end. Does not install anything — read-only.
#
# USAGE
#   bash mddocs/scripts/setup/verify-toolchain.sh
#
# EXIT CODES
#   0  — all required tools present (warnings do not cause non-zero exit)
#   1  — one or more required tools are missing
#
# NOTE
#   chmod +x mddocs/scripts/setup/verify-toolchain.sh
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0; WARN=0; FAIL=0

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; (( PASS++ )) || true; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; (( WARN++ )) || true; }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; (( FAIL++ )) || true; }

check_cmd() {
  local label="$1"; local cmd="$2"; local version_flag="${3:---version}"
  local bin
  bin=$(command -v "$cmd" 2>/dev/null || echo "")
  if [[ -z "$bin" ]]; then
    fail "$label — not found (command: $cmd)"
  else
    local ver
    ver=$("$bin" $version_flag 2>&1 | head -1) || ver="(version check failed)"
    pass "$label — $ver"
  fi
}

check_file() {
  local label="$1"; local path="$2"
  if [[ -f "$path" ]]; then
    pass "$label — $path"
  else
    fail "$label — not found: $path"
  fi
}

check_dir() {
  local label="$1"; local path="$2"
  if [[ -d "$path" ]]; then
    pass "$label — $path"
  else
    fail "$label — directory not found: $path"
  fi
}

CARGO_BIN="$HOME/.local/share/cargo/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== Core Version Control ===${NC}"
# ---------------------------------------------------------------------------
check_cmd   "git"                     git

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== Docs Toolchain ===${NC}"
# ---------------------------------------------------------------------------
check_cmd   "mdbook"                  "$CARGO_BIN/mdbook"
check_cmd   "mdbook-mermaid"          "$CARGO_BIN/mdbook-mermaid"
check_cmd   "typos"                   "$CARGO_BIN/typos"
check_cmd   "shellcheck"              shellcheck
check_cmd   "jq"                      jq              "--version"

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== CLI Tools ===${NC}"
# ---------------------------------------------------------------------------
check_cmd   "gh"                      gh              "--version"

GH_AUTH=$(gh auth status 2>&1 | grep "Logged in to" || echo "")
if [[ -n "$GH_AUTH" ]]; then
  pass "gh — $GH_AUTH"
else
  warn "gh — not authenticated (run: gh auth login)"
fi

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== MCP Server Dependencies ===${NC}"
# ---------------------------------------------------------------------------
# rust-mcp-filesystem and mcp-git — installed via cargo
bin_fs="$CARGO_BIN/rust-mcp-filesystem"
if [[ -x "$bin_fs" ]]; then
  pass "rust-mcp-filesystem — $("$bin_fs" --version 2>&1 | head -1)"
else
  fail "rust-mcp-filesystem — not found at $bin_fs (run: cargo install rust-mcp-filesystem)"
fi

bin_git="$CARGO_BIN/mcp-git"
if [[ -x "$bin_git" ]]; then
  pass "mcp-git — $("$bin_git" --version 2>&1 | head -1)"
else
  fail "mcp-git — not found at $bin_git (run: cargo install mcp-git)"
fi

# uv — required for mcp-rag-docs Python server
UV_BIN="$HOME/.local/share/uv/bin/uv"
if [[ -x "$UV_BIN" ]]; then
  pass "uv — $("$UV_BIN" --version 2>&1 | head -1)"
else
  fail "uv — not found at $UV_BIN (see: https://docs.astral.sh/uv/getting-started/installation/)"
fi

# python3 — required for hooks and MCP scripts
check_cmd   "python3"                 python3         "--version"

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== Workspace ===${NC}"
# ---------------------------------------------------------------------------
check_dir   "Agent source files (.agents/)"        "$REPO_ROOT/.agents"
check_dir   "opencode agents (.opencode/agents/)"  "$REPO_ROOT/.opencode/agents"
check_file  ".mcp.json"                            "$REPO_ROOT/.mcp.json"

# Cargo bin in PATH
if [[ ":$PATH:" == *":$CARGO_BIN:"* ]]; then
  pass "Cargo bin in PATH — $CARGO_BIN"
else
  fail "Cargo bin NOT in PATH — add: export PATH=\"\$HOME/.local/share/cargo/bin:\$PATH\" to ~/.zshrc"
fi

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}=== Summary ===${NC}"
# ---------------------------------------------------------------------------
TOTAL=$(( PASS + WARN + FAIL ))
echo -e "  ${GREEN}PASS${NC}: $PASS / $TOTAL"
[[ $WARN -gt 0 ]] && echo -e "  ${YELLOW}WARN${NC}: $WARN / $TOTAL"
[[ $FAIL -gt 0 ]] && echo -e "  ${RED}FAIL${NC}: $FAIL / $TOTAL"
echo ""

if (( FAIL > 0 )); then
  echo -e "${RED}Environment is not fully configured. Resolve FAIL items above.${NC}"
  exit 1
elif (( WARN > 0 )); then
  echo -e "${YELLOW}Environment is mostly configured. Review WARN items above.${NC}"
  exit 0
else
  echo -e "${GREEN}All checks passed. Environment is ready.${NC}"
  exit 0
fi
