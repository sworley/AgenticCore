#!/usr/bin/env bash
# toolchain.sh — Manage the docs/dev toolchain (validate + optional install).
#
# PURPOSE
#   The harness's non-Python dependencies (mdbook, mdbook-mermaid, typos-cli,
#   shellcheck, gh, jq) are resolved here. This is the toolchain analogue of
#   python-env.sh: a single, generic entry point that validates what is present
#   and can install what is missing — without forcing installs on an adopter.
#   It is tool-agnostic and idempotent.
#
#   The framework does NOT blanket-install on an adopter's machine. The default
#   mode (--check) only VALIDATES and reports how to install anything missing;
#   --install is the explicit, opt-in path that actually builds the toolchain.
#
# USAGE
#   toolchain.sh [--check] [--install] [--dry-run] [-h]
#
#   --check     Validate every tool is present (default). Read-only; reports
#               PASS/FAIL/WARN and prints an install hint for each missing tool.
#   --install   Install missing tools via cargo/brew (best-effort; may prompt
#               for the absolute check of THE user's environment).
#   --dry-run   Report the actions that --install would take, without running.
#   -h, --help  Show this help and exit.
#
# EXIT CODES
#   0  All requested checks pass (warnings do not fail)
#   1  A required tool is missing (--check) or an install step failed
#
# SEE ALSO
#   python-env.sh   — the Python (.venv / requirements.txt) analogue
#   verify-toolchain.sh / phase2-dev-toolchain.sh — legacy macOS-specific variants
#   mddocs/reference.architecture/bootstrap-new-project.md  — where this is invoked

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate the repo root (mddocs/scripts/setup/toolchain.sh -> repo root).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

CARGO_BIN="${CARGO_BIN:-$HOME/.local/share/cargo/bin}"

DO_CHECK=0
DO_INSTALL=0
DRY_RUN=0

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Tool manifest.
#
# Each entry is  NAME|TIER|INSTALLER|VERSION
#   NAME      binary the tool exposes (as it appears on PATH / cargo bin)
#   TIER      required = needed for the framework's CI/gates; optional = docs/
#             authoring quality tooling that is nice to have
#   INSTALLER cargo | brew | apt | none (none = system tool, not installed here)
#   VERSION   pin used by --install (empty = no pin)
#
# mdbook is pinned to 0.4.40 to match .github/workflows/ci.yml and README's
# "0.4.x" prerequisite. NOTE: phase2-dev-toolchain.sh pins 0.5.3, which is out
# of sync (mdbook 0.5.x breaks mdbook-linkcheck — see TC-017 / AGENT.md).
# ---------------------------------------------------------------------------
TOOLS=(
  "git|required|none|"
  "mdbook|required|cargo|0.4.40"
  "jq|required|none|"
  "python3|required|none|"
  "uv|required|none|"
  "mdbook-mermaid|optional|cargo|0.17.0"
  "typos-cli|optional|cargo|1.48.0"
  "shellcheck|optional|brew|"
  "gh|optional|brew|"
)

install_hint() {
  case "$3" in
    cargo) echo "cargo install $1 ${4:+--version $4}" ;;
    brew)  echo "brew install $1" ;;
    apt)   echo "apt-get install $1" ;;
    *)     echo "(system tool — install via your OS package manager)" ;;
  esac
}

usage() {
  cat >&2 << 'EOF'
Usage: toolchain.sh [--check] [--install] [--dry-run] [-h]

Manage the docs/dev toolchain (validate + optional install). The default mode
(--check) is read-only and only reports what's missing and how to install it.

  --check     Validate every tool is present (default)
  --install   Install missing tools via cargo/brew (opt-in)
  --dry-run   Report the install actions without running them
  -h, --help  Show this help and exit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   DO_CHECK=1;   shift ;;
    --install) DO_INSTALL=1; shift ;;
    --dry-run) DRY_RUN=1;    shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 1 ;;
  esac
done

# No explicit action flags -> default to --check.
if [ "$DO_CHECK" -eq 0 ] && [ "$DO_INSTALL" -eq 0 ]; then
  DO_CHECK=1
fi

FOUND=0; MISSING=0; WARN_COUNT=0

check_tool() {
  local name="$1" tier="$2" installer="$3" version="$4" bin
  bin="$(command -v "$name" 2>/dev/null || echo "")"
  if [ -z "$bin" ]; then
    # rust tools may live in CARGO_BIN even if not on PATH
    if [ "$installer" = "cargo" ] && [ -x "$CARGO_BIN/$name" ]; then
      bin="$CARGO_BIN/$name"
    fi
  fi
  if [ -n "$bin" ]; then
    FOUND=$((FOUND+1))
    log "  [ok]   $name${version:+ ($version)}"
  elif [ "$tier" = "required" ]; then
    MISSING=$((MISSING+1))
    log "  [FAIL] $name — missing. Install: $(install_hint "$name" "$tier" "$installer" "$version")"
  else
    WARN_COUNT=$((WARN_COUNT+1))
    log "  [warn] $name — optional, missing. Install: $(install_hint "$name" "$tier" "$installer" "$version")"
  fi
}

install_tool() {
  local name="$1" tier="$2" installer="$3" version="$4"
  if command -v "$name" >/dev/null 2>&1 || [ -x "$CARGO_BIN/$name" ]; then
    log "  [skip] $name — already present"
    return 0
  fi
  log "  [install] $name${version:+ $version}"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "      would run: $(install_hint "$name" "$tier" "$installer" "$version")"
    return 0
  fi
  case "$installer" in
    cargo)
      export PATH="$CARGO_BIN:$PATH"
      cargo install "$name" ${version:+--version "$version"} ;;
    brew)
      brew install "$name" ;;
    apt)
      sudo apt-get install -y "$name" ;;
    *)
      warn "$name — no managed installer; install manually" ;;
  esac
}

echo "==> toolchain: managing docs/dev toolchain in $REPO_ROOT"

if [ "$DO_CHECK" -eq 1 ]; then
  echo "-- check --"
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name tier installer version <<< "$entry"
    check_tool "$name" "$tier" "$installer" "$version"
  done
  echo ""
  echo "  found: $FOUND   missing: $MISSING   optional-missing: $WARN_COUNT"
  if [ "$MISSING" -gt 0 ]; then
    echo ""
    warn "one or more REQUIRED tools are missing — resolve before proceeding (see hints above)"
    exit 1
  fi
fi

if [ "$DO_INSTALL" -eq 1 ]; then
  echo "-- install --"
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name tier installer version <<< "$entry"
    install_tool "$name" "$tier" "$installer" "$version"
  done
  echo ""
  echo "==> toolchain: install complete. Re-run --check to verify."
fi

echo "==> toolchain: done"
exit 0
