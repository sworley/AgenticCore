#!/usr/bin/env bash
# python-env.sh — Create the project-local Python virtualenv (.venv) and
# install/validate the harness's required Python packages.
#
# PURPOSE
#   Gives every adopted workspace an isolated, reproducible Python environment.
#   The harness's Python needs (MCP servers, review-ledger, rag-docs) are
#   declared in the committed requirements.txt. This script:
#     1. Creates <repo-root>/.venv (project-local, gitignored)
#     2. Sources it and pip-installs requirements.txt
#     3. Validates that the required modules import (mcp, yaml, fastmcp)
#
#   It is tool-neutral and idempotent — safe to re-run.
#
# USAGE
#   python-env.sh [--create] [--install] [--check] [--freeze] [--dry-run]
#
#   --create    Create .venv at the project root (skipped if it already exists)
#   --install   pip install -r requirements.txt (skipped if already satisfied)
#   --check     Validate required modules import; exit non-zero if any missing
#   --freeze    Regenerate requirements.txt from `pip freeze` (harness
#               maintenance — run in a CLEAN venv, then commit the result)
#   --dry-run   Report the actions without making changes
#
#   With no flags, it runs --create, --install, --check (the adoption default).
#
# EXIT CODES
#   0  All requested actions succeeded
#   1  A requested action failed (venv create, install, or validation)
#
# See also:
#   requirements.txt                       (harness Python dependency snapshot)
#   .envrc.template                        (sources .venv via `layout python`)
#   mddocs/reference.architecture/bootstrap-new-project.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate the repo root. This script lives at
# mddocs/scripts/setup/python-env.sh, so the repo root is three levels up.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

VENV_DIR="$REPO_ROOT/.venv"
REQUIREMENTS="$REPO_ROOT/requirements.txt"

# Modules the harness needs at runtime (must import cleanly after install).
# REQUIRED_MODULES is the human-readable form; REQUIRED_IMPORT is valid Python.
REQUIRED_MODULES="mcp yaml fastmcp"
REQUIRED_IMPORT="mcp, yaml, fastmcp"

DO_CREATE=0
DO_INSTALL=0
DO_CHECK=0
DO_FREEZE=0
DRY_RUN=0

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat >&2 << 'EOF'
Usage: python-env.sh [--create] [--install] [--check] [--freeze] [--dry-run]

Create the project-local Python virtualenv (.venv) and install/validate the
harness's required Python packages. With no flags: --create, --install, --check.

  --create    Create .venv at the project root if absent
  --install   pip install -r requirements.txt
  --check     Validate required modules import (mcp, yaml, fastmcp)
  --freeze    Regenerate requirements.txt via `pip freeze` (maintenance)
  --dry-run   Report actions without making changes
  -h, --help  Show this help and exit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --create)  DO_CREATE=1;  shift ;;
    --install) DO_INSTALL=1; shift ;;
    --check)   DO_CHECK=1;   shift ;;
    --freeze)  DO_FREEZE=1;  shift ;;
    --dry-run) DRY_RUN=1;    shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 1 ;;
  esac
done

# No explicit action flags -> adoption default (create + install + check).
if [ "$DO_CREATE" -eq 0 ] && [ "$DO_INSTALL" -eq 0 ] && [ "$DO_CHECK" -eq 0 ] && [ "$DO_FREEZE" -eq 0 ]; then
  DO_CREATE=1; DO_INSTALL=1; DO_CHECK=1
fi

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  err "python3 is required (not found on PATH)"
  exit 1
fi

if ! python3 -m venv --help >/dev/null 2>&1; then
  err "python3 -m venv is unavailable (ensure python3-venv is installed)"
  exit 1
fi

if [ ! -f "$REQUIREMENTS" ] && [ "$DO_INSTALL" -eq 1 ]; then
  err "requirements.txt not found at: $REQUIREMENTS (cannot install deps)"
  exit 1
fi

# ---------------------------------------------------------------------------
# venv_activate — set PATH so .venv/bin takes precedence; sources activate if
# present (robust across `bash` vs direct `python` invocation).
# ---------------------------------------------------------------------------
venv_activate() {
  if [ -f "$VENV_DIR/bin/activate" ]; then
    # shellcheck disable=SC1091
    . "$VENV_DIR/bin/activate"
  else
    export PATH="$VENV_DIR/bin:$PATH"
  fi
}

# ---------------------------------------------------------------------------
# Step 1 — create .venv
# ---------------------------------------------------------------------------
if [ "$DO_CREATE" -eq 1 ]; then
  if [ -d "$VENV_DIR" ]; then
    log "==> python-env: .venv already exists"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] would create: python3 -m venv $VENV_DIR"
  else
    log "==> python-env: creating $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    venv_activate
    # Ensure a sane pip inside the fresh venv (venv may not include one).
    "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip 2>/dev/null || true
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "  [dry-run] .venv actions complete (no changes made)"
fi

# ---------------------------------------------------------------------------
# Step 2 — install requirements.txt
# ---------------------------------------------------------------------------
if [ "$DO_INSTALL" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] would run: pip install -r $REQUIREMENTS"
  else
    if [ ! -d "$VENV_DIR" ]; then
      err "cannot install: $VENV_DIR does not exist (run without --dry-run, or --create first)"
      exit 1
    fi
    log "==> python-env: installing $REQUIREMENTS"
    if ! "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS"; then
      err "pip install failed — see output above"
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Step 3 — validate required modules import
# ---------------------------------------------------------------------------
if [ "$DO_CHECK" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] would validate imports: $REQUIRED_MODULES"
  else
    if [ ! -f "$VENV_DIR/bin/python" ]; then
      err "cannot validate: $VENV_DIR/bin/python not found"
      exit 1
    fi
    log "==> python-env: validating imports ($REQUIRED_MODULES)"
    if ! "$VENV_DIR/bin/python" -c "import $REQUIRED_IMPORT"; then
      err "one or more required modules failed to import — re-run python-env.sh --install, or check requirements.txt"
      exit 1
    fi
    log "    imports OK: $REQUIRED_MODULES"
  fi
fi

# ---------------------------------------------------------------------------
# Step 4 — --freeze: regenerate requirements.txt (harness maintenance)
# ---------------------------------------------------------------------------
if [ "$DO_FREEZE" -eq 1 ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] would run: pip freeze > $REQUIREMENTS"
  else
    if [ ! -f "$VENV_DIR/bin/pip" ]; then
      err "cannot freeze: $VENV_DIR/bin/pip not found"
      exit 1
    fi
    log "==> python-env: freezing requirements to $REQUIREMENTS"
    "$VENV_DIR/bin/pip" freeze | sort > "$REQUIREMENTS"
    log "    wrote $(wc -l < "$REQUIREMENTS") pinned packages"
  fi
fi

log "==> python-env: done"
exit 0
