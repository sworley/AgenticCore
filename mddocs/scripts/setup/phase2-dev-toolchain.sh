#!/bin/bash
# =============================================================================
# phase2-dev-toolchain.sh
#
# PURPOSE
#   Installs and verifies the Phase 2 docs and developer toolchain for an
#   AgenticCore development environment on macOS (Apple Silicon M1+).
#   Safe to re-run — all steps are idempotent.
#
# WHAT IT INSTALLS
#   mdbook, mdbook-mermaid   — docs site builder (via cargo)
#   typos-cli                — spell checker for source files (via cargo)
#   shellcheck               — shell script linter (via brew)
#   gh                       — GitHub/Git CLI (via brew)
#   jq                       — JSON processor (via brew)
#
# WHAT IT DOES NOT DO
#   gh auth login            — interactive; run manually after this script
#
# PREREQUISITES
#   Homebrew installed at /opt/homebrew
#   Rust/Cargo installed; ~/.local/share/cargo/bin in PATH (set in ~/.zshrc)
#
# USAGE
#   bash mddocs/scripts/setup/phase2-dev-toolchain.sh
#
# EXIT CODES
#   0  — all tools installed successfully
#   1  — a required prerequisite is missing or an install step failed
#
# NOTE
#   chmod +x mddocs/scripts/setup/phase2-dev-toolchain.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BOLD}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*" >&2; exit 1; }

require() {
  command -v "$1" &>/dev/null || fail "Required tool not found: $1 — install it before running this script."
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."
require brew
require cargo

CARGO_BIN="$HOME/.local/share/cargo/bin"
if [[ ":$PATH:" != *":$CARGO_BIN:"* ]]; then
  warn "~/.local/share/cargo/bin is not in PATH. Adding for this session."
  export PATH="$CARGO_BIN:$PATH"
fi

# ---------------------------------------------------------------------------
# Step 2.1 — mdbook + mdbook-mermaid + typos-cli (cargo)
# ---------------------------------------------------------------------------
info "Step 2.1 — Installing mdbook, mdbook-mermaid, and typos-cli via cargo..."
cargo install mdbook --version 0.5.3
cargo install mdbook-mermaid --version 0.17.0
cargo install typos-cli --version 1.48.0
ok "mdbook $(mdbook --version) | mdbook-mermaid $(mdbook-mermaid --version) | typos $(typos --version)"

# ---------------------------------------------------------------------------
# Step 2.2 — shellcheck, gh, jq (brew)
# ---------------------------------------------------------------------------
info "Step 2.2 — Installing shellcheck, gh, jq via brew..."
brew install shellcheck gh jq
ok "shellcheck $(/opt/homebrew/bin/shellcheck --version | awk '/version/{print $2}' | head -1)"
ok "gh $(/opt/homebrew/bin/gh --version | awk '{print $3}' | head -1)"
ok "jq $(/opt/homebrew/bin/jq --version)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Phase 2 complete.${NC}"
echo ""
echo "  mdbook                $(mdbook --version)"
echo "  mdbook-mermaid        $(mdbook-mermaid --version)"
echo "  typos                 $(typos --version)"
echo "  shellcheck            $(/opt/homebrew/bin/shellcheck --version | grep version | head -1)"
echo "  gh                    $(/opt/homebrew/bin/gh --version | head -1)"
echo "  jq                    $(/opt/homebrew/bin/jq --version)"
echo ""
warn "Remaining manual step: gh auth login"
echo "  Run: gh auth login"
echo "  Select: GitHub.com (or your Git instance) → HTTPS → Login with a web browser"
echo ""
info "Verify the docs build:"
echo "  mdbook build $REPO_ROOT/mddocs"
