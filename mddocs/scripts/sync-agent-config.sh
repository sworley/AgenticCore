#!/usr/bin/env bash
# Sync AGENT.md files between _config/ (repo archive) and on-disk parent-dir locations.
#
# Idempotent: yes — copies only when content differs; --check never modifies files.
#
# NOT idempotent: none — all modes are safe to run multiple times.
#
# Usage:
#   sync-agent-config.sh --deploy   # _config/ → parent dirs  (repo → filesystem)
#   sync-agent-config.sh --collect  # parent dirs → _config/  (filesystem → repo)
#   sync-agent-config.sh --check    # diff only; exits 1 if any pair is out of sync
#
# Use --check in CI or pre-session audits to verify deployed config matches committed config.
#
# To add a new AGENT.md pair: append a "sync_pair `<archive>` `<target>`" line in the
# Registered pairs section below, following the commented example pattern.
set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: not inside a git repository" >&2
  exit 1
}

usage() {
  echo "Usage: $(basename "$0") --deploy | --collect | --check" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage
mode="$1"
[[ "$mode" == "--deploy" || "$mode" == "--collect" || "$mode" == "--check" ]] || usage

drift=0
copied=0
skipped=0

# ---------------------------------------------------------------------------
# sync_pair <archive_file> <on_disk_target>
# Add a new line here when new org-level AGENT.md files are added.
# ---------------------------------------------------------------------------
process_pair() {
  local archive_file="$1"
  local target_file="$2"

  case "$mode" in
    --deploy)  src="$archive_file"; dst="$target_file"; src_lbl="_config/ (repo)"; dst_lbl="on-disk" ;;
    --collect) src="$target_file";  dst="$archive_file"; src_lbl="on-disk"; dst_lbl="_config/ (repo)" ;;
    --check)   src="$archive_file"; dst="$target_file"; src_lbl="_config/ (repo)"; dst_lbl="on-disk" ;;
  esac

  if [[ ! -f "$src" ]]; then
    echo "MISSING  ${src_lbl}: $src"
    drift=$((drift + 1))
    return
  fi

  if [[ "$mode" == "--check" ]]; then
    if [[ ! -f "$dst" ]]; then
      echo "MISSING  ${dst_lbl}: $dst"
      drift=$((drift + 1))
    elif diff -q "$src" "$dst" > /dev/null 2>&1; then
      echo "OK       $(basename "$src")"
    else
      echo "DRIFT    $(basename "$src")"
      echo "         ${src_lbl}: $src"
      echo "         ${dst_lbl}: $dst"
      diff --unified "$src" "$dst" | head -20 || true
      drift=$((drift + 1))
    fi
  else
    if [[ -f "$dst" ]] && diff -q "$src" "$dst" > /dev/null 2>&1; then
      echo "SKIP     $(basename "$src") — already in sync"
      skipped=$((skipped + 1))
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      echo "COPIED   $(basename "$src") → $dst"
      copied=$((copied + 1))
    fi
  fi
}

# --- Registered pairs ---
# Add process_pair lines here to register AGENT.md pairs for your workspace.
# Example pattern (fill in with your actual paths):
#
# process_pair \
#   "${GIT_ROOT}/_config/repos-AGENT.md" \
#   "${HOME}/files/repos/AGENT.md"
# --- End registered pairs ---

echo ""
if [[ "$mode" == "--check" ]]; then
  if [[ $drift -gt 0 ]]; then
    echo "RESULT: $drift file(s) out of sync — run with --deploy or --collect to resolve"
    exit 1
  else
    echo "RESULT: all files in sync"
    exit 0
  fi
else
  echo "RESULT: $copied copied, $skipped already in sync"
fi
