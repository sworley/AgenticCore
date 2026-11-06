#!/usr/bin/env bash
# toolchain.sh — Manage the docs/dev toolchain (validate + optional install).
#
# PURPOSE
#   The harness's non-Python dependencies (mdbook, mdbook-mermaid, typos-cli,
#   shellcheck, gh, jq) are resolved here. This is the toolchain analogue of
#   python-env.sh: a single, generic entry point that validates what is present
#   (and whether versions match the pinned standard), and can install/update
#   what is missing or drifted — without forcing installs on an adopter.
#
#   The framework does NOT blanket-install on an adopter's machine. The default
#   mode (--check) only VALIDATES and reports status + an install hint;
#   --install is the explicit, opt-in path that actually builds/updates it.
#
# USAGE
#   toolchain.sh [--check] [--install] [--dry-run] [-h]
#
#   --check     Validate every tool (default). Read-only; reports each tool's
#               status (ok / update / missing / optional) and an install hint.
#               Exit 1 if a REQUIRED tool is missing or a pinned version is
#               out of date. Optional drifts are warnings.
#   --install   Install/update missing or drifted tools via cargo/brew/apt
#               (best-effort; opt-in).
#   --dry-run   Report the actions --install would take, without running.
#   -h, --help  Show this help and exit.
#
# EXIT CODES
#   0  Every required tool is present at the pinned version (warnings OK)
#   1  A required tool is missing or out of date (--check), or an install failed
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
# Tool manifest. Each entry is  BIN|TIER|INSTALLER|VERSION|PKG
#   BIN       the binary name the tool exposes (as it appears on PATH / cargo bin)
#   TIER      required = needed for the framework's CI/gates; optional = docs/
#             authoring quality tooling that is nice to have
#   INSTALLER cargo | brew | apt | none (none = system tool, not installed here)
#   VERSION   the pinned standard used by --install / --check (empty = no pin)
#   PKG       the install package (differs from BIN only for some cargo tools,
#             e.g. the `typos-cli` package installs the `typos` binary)
#
# mdbook is pinned to 0.5.3 (the current standard), matching
# .github/workflows/ci.yml, phase2-dev-toolchain.sh, and README's "0.5.x"
# prerequisite. The custom check-links.sh (not mdbook-linkcheck) validates
# internal links and stays compatible with mdbook 0.5.x.
# ---------------------------------------------------------------------------
TOOLS=(
  "git|required|none||"
  "mdbook|required|cargo|0.5.3|mdbook"
  "jq|required|none||"
  "python3|required|none||"
  "uv|required|none||"
  "mdbook-mermaid|optional|cargo|0.17.0|mdbook-mermaid"
  "typos|optional|cargo|1.48.0|typos-cli"
  "shellcheck|optional|brew||"
  "gh|optional|brew||"
)

install_hint() {
  # $1 bin  $2 tier  $3 installer  $4 version  $5 pkg
  local pkg="${5:-$1}"
  case "$3" in
    cargo) echo "cargo install $pkg ${4:+--version $4}" ;;
    brew)  echo "brew install $1" ;;
    apt)   echo "apt-get install $1" ;;
    *)     echo "(system tool — install via your OS package manager)" ;;
  esac
}

# get_version — print the semver token from a tool's `--version`, or empty.
get_version() {
  local out
  out="$("$1" --version 2>/dev/null | head -1)"
  printf '%s' "$out" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# find_bin — resolve the binary across PATH and the common cargo bin dirs.
find_bin() {
  local name="$1" installer="$2" bin
  bin="$(command -v "$name" 2>/dev/null || echo "")"
  if [ -z "$bin" ] && [ "$installer" = "cargo" ]; then
    for d in "$CARGO_BIN" "$HOME/.cargo/bin"; do
      if [ -x "$d/$name" ]; then bin="$d/$name"; break; fi
    done
  fi
  printf '%s' "$bin"
}

usage() {
  cat >&2 << 'EOF'
Usage: toolchain.sh [--check] [--install] [--dry-run] [-h]

Manage the docs/dev toolchain (validate + optional install). The default mode
(--check) is read-only and reports each tool's status and an install hint.

  --check     Validate every tool is present at the pinned version (default)
  --install   Install/update missing or drifted tools via cargo/brew/apt (opt-in)
  --dry-run   Report the install/update actions without running them
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

OK_COUNT=0; UPDATE_REQ=0; MISSING_REQ=0; OPT_MISSING=0; OPT_UPDATE=0

# tool_status: classify a single tool and record its status.
# args: bin tier installer version pkg
tool_status() {
  local name="$1" tier="$2" installer="$3" version="$4" pkg="$5"
  local bin inst_ver
  bin="$(find_bin "$name" "$installer")"

  if [ -z "$bin" ]; then
    if [ "$tier" = "required" ]; then
      MISSING_REQ=$((MISSING_REQ+1))
      log "  [MISSING] $name (required) — install: $(install_hint "$name" "$tier" "$installer" "$version" "$pkg")"
    else
      OPT_MISSING=$((OPT_MISSING+1))
      log "  [optional] $name — missing. Install: $(install_hint "$name" "$tier" "$installer" "$version" "$pkg")"
    fi
    return
  fi

  if [ -n "$version" ]; then
    inst_ver="$(get_version "$bin")"
    if [ -n "$inst_ver" ] && [ "$inst_ver" != "$version" ]; then
      if [ "$tier" = "required" ]; then
        UPDATE_REQ=$((UPDATE_REQ+1))
        log "  [UPDATE]  $name — installed $inst_ver, pinned $version. Update: $(install_hint "$name" "$tier" "$installer" "$version" "$pkg")"
      else
        OPT_UPDATE=$((OPT_UPDATE+1))
        log "  [warn]    $name — installed $inst_ver, pinned $version (optional). Update: $(install_hint "$name" "$tier" "$installer" "$version" "$pkg")"
      fi
      return
    fi
  fi

  OK_COUNT=$((OK_COUNT+1))
  log "  [ok]   $name${version:+ ($version)}"
}

do_install() {
  local name="$1" tier="$2" installer="$3" version="$4" pkg="$5"
  local bin inst_ver
  bin="$(find_bin "$name" "$installer")"
  # Skip if present and (unpinned, or already at the pinned version).
  if [ -n "$bin" ]; then
    if [ -z "$version" ]; then
      log "  [skip] $name — already present"
      return 0
    fi
    inst_ver="$(get_version "$bin")"
    if [ "$inst_ver" = "$version" ]; then
      log "  [skip] $name — already $version"
      return 0
    fi
  fi
  log "  [install] ${pkg:-$name}${version:+ $version}"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "      would run: $(install_hint "$name" "$tier" "$installer" "$version" "$pkg")"
    return 0
  fi
  case "$installer" in
    cargo) export PATH="$CARGO_BIN:$HOME/.cargo/bin:$PATH"; cargo install "$pkg" ${version:+--version "$version"} ;;
    brew)  brew install "$name" ;;
    apt)   sudo apt-get install -y "$name" ;;
    *)     warn "$name — no managed installer; install manually" ;;
  esac
}

echo "==> toolchain: managing docs/dev toolchain in $REPO_ROOT"

if [ "$DO_CHECK" -eq 1 ]; then
  echo "-- status --"
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name tier installer version pkg <<< "$entry"
    tool_status "$name" "$tier" "$installer" "$version" "$pkg"
  done
  echo ""
  echo "  ok: $OK_COUNT   update-required: $UPDATE_REQ   missing-required: $MISSING_REQ   optional-missing: $OPT_MISSING   optional-update: $OPT_UPDATE"
  if [ "$MISSING_REQ" -gt 0 ] || [ "$UPDATE_REQ" -gt 0 ]; then
    echo ""
    warn "one or more REQUIRED tools are missing or out of date — resolve before proceeding (see hints above)"
    exit 1
  fi
  if [ "$OPT_MISSING" -gt 0 ] || [ "$OPT_UPDATE" -gt 0 ]; then
    echo ""
    warn "optional tools missing or out of date (advisory) — no required dependency is affected"
    exit 2
  fi
fi

if [ "$DO_INSTALL" -eq 1 ]; then
  echo "-- install/update --"
  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r name tier installer version pkg <<< "$entry"
    do_install "$name" "$tier" "$installer" "$version" "$pkg"
  done
  echo ""
  echo "==> toolchain: install/update complete. Re-run --check to verify."
fi

echo "==> toolchain: done"
exit 0
