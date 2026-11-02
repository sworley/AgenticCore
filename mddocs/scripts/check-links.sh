#!/bin/sh
# check-links.sh — Validate internal markdown links within mddocs/
#
# Scans all .md files in the mddocs/ directory tree and checks that every
# relative link target resolves to an existing file. Does not perform HTTP
# requests for external (http/https) URLs. Anchor-only links (#section) are
# skipped. .html links are resolved to their .md equivalent.
#
# Usage:
#   ./mddocs/scripts/check-links.sh [options]
#
# Options:
#   --dir <path>    Root directory to scan, relative to repo root (default: mddocs)
#   --verbose       Print every link checked, not just failures
#   --external      Also report external URLs found (no HTTP check performed)
#   --summary-only  Print only the final pass/fail count line
#   -h, --help      Show this help and exit
#
# Exit codes:
#   0  All internal links resolve
#   1  One or more broken links found

set -u

# --- Defaults ---
SCAN_DIR="mddocs"
VERBOSE=0
EXTERNAL=0
SUMMARY_ONLY=0

# --- Argument parsing ---
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)      SCAN_DIR="$2"; shift 2 ;;
    --verbose)  VERBOSE=1; shift ;;
    --external) EXTERNAL=1; shift ;;
    --summary-only) SUMMARY_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,2\}//'
      exit 0 ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2; exit 1 ;;
  esac
done

# Resolve paths relative to repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCAN_ABS="$REPO_ROOT/$SCAN_DIR"

if [ ! -d "$SCAN_ABS" ]; then
  printf "error: scan directory not found: %s\n" "$SCAN_ABS" >&2
  exit 1
fi

# Temp file to accumulate results (avoids subshell counter loss)
RESULTS="$(mktemp /tmp/check-links.XXXXXX)"
trap 'rm -f "$RESULTS"' EXIT

[ "$SUMMARY_ONLY" -eq 0 ] && printf "==> check-links: scanning %s\n\n" "$SCAN_DIR"

# --- Process each .md file ---
find "$SCAN_ABS" -name "*.md" | sort | while IFS= read -r mdfile; do
  rel_file="${mdfile#$REPO_ROOT/}"
  dir="$(dirname "$mdfile")"

  # Extract all markdown link targets from this file
  # Strip fenced code blocks and inline code spans before scanning
  awk '/^```/{in_fence=!in_fence; next} in_fence{next} {print}' "$mdfile" 2>/dev/null | \
  sed 's/`[^`]*`//g' | \
  grep -oE '\[([^]]*)\]\(([^)]+)\)' | \
    sed 's/^\[.*\](\(.*\))$/\1/' | \
  while IFS= read -r raw_target; do

    # Strip trailing whitespace/quotes
    target="$(printf '%s' "$raw_target" | sed 's/[[:space:]]*$//' | sed 's/".*$//')"

    # Skip anchor-only links
    case "$target" in \#*) continue ;; esac

    # Handle external URLs
    case "$target" in
      http://*|https://*)
        printf "external\n" >> "$RESULTS"
        if [ "$EXTERNAL" -eq 1 ] && [ "$SUMMARY_ONLY" -eq 0 ]; then
          printf "  [external] %s\n             %s\n" "$rel_file" "$target"
        fi
        continue ;;
    esac

    # Strip anchor fragment
    fragment=""
    case "$target" in
      *\#*)
        fragment="#${target#*#}"
        target="${target%%#*}"
        ;;
    esac

    # .html → .md (mdbook renders .md as .html)
    case "$target" in
      *.html) target="$(printf '%s' "$target" | sed 's/\.html$/.md/')" ;;
    esac

    # Skip empty target (was anchor-only after stripping)
    [ -z "$target" ] && continue

    # Resolve path relative to source file's directory
    case "$target" in
      /*) resolved="$REPO_ROOT$target" ;;
      *)  resolved="$dir/$target" ;;
    esac

    # Normalize: walk the path to resolve ../
    resolved_dir="$(dirname "$resolved")"
    resolved_base="$(basename "$resolved")"
    if norm="$(cd "$resolved_dir" 2>/dev/null && pwd)"; then
      resolved="$norm/$resolved_base"
    fi

    printf "checked\n" >> "$RESULTS"

    if [ -e "$resolved" ]; then
      if [ "$VERBOSE" -eq 1 ] && [ "$SUMMARY_ONLY" -eq 0 ]; then
        printf "  [ok]     %s\n           %s%s\n" "$rel_file" "$target" "$fragment"
      fi
    else
      printf "broken\n" >> "$RESULTS"
      if [ "$SUMMARY_ONLY" -eq 0 ]; then
        printf "  [BROKEN] %s\n           link: %s%s\n" "$rel_file" "$target" "$fragment"
      fi
    fi

  done
done

# --- Tally results ---
checked=$(grep -c "^checked$" "$RESULTS" 2>/dev/null); checked=${checked:-0}
broken=$(grep -c "^broken$" "$RESULTS" 2>/dev/null); broken=${broken:-0}
external=$(grep -c "^external$" "$RESULTS" 2>/dev/null); external=${external:-0}

[ "$SUMMARY_ONLY" -eq 0 ] && printf "\n"

if [ "$broken" -eq 0 ]; then
  printf "==> check-links: all links OK (%d checked" "$checked"
  [ "$external" -gt 0 ] && printf ", %d external skipped" "$external"
  printf ")\n"
  exit 0
else
  printf "==> check-links: %d broken link(s) found (%d checked" "$broken" "$checked"
  [ "$external" -gt 0 ] && printf ", %d external skipped" "$external"
  printf ")\n"
  exit 1
fi
