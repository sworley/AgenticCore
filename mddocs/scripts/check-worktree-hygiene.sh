#!/bin/sh
# check-worktree-hygiene.sh — Verify all git worktrees are clean
#
# Usage: ./scripts/check-worktree-hygiene.sh
#
# Prints a warning for each dirty worktree.
# Exit 1 if any worktrees have uncommitted changes.
#
# Exit codes:
#   0  All clean
#   1  One or more dirty
#
# Note: `git worktree list --porcelain` output is written to a temp file and
# read back into a `while read` loop in the CURRENT shell (not a pipe
# subshell), so that `found_dirty` set inside the loop is visible to the exit
# logic below. Piping directly into `while read` (or using bash-only process
# substitution `< <(...)`) would either run the loop in a subshell — silently
# discarding `found_dirty` — or require a non-POSIX shebang. Same pattern as
# bench-status.sh (TC-052).
#
# Note: the per-worktree status variable is named `wt_status`, not `status` —
# zsh reserves `status` as a read-only special variable (last exit code), so
# assigning to a plain `status` var fails with "read-only variable" under zsh.

set -u

worktree_tmp=$(mktemp)
trap 'rm -f "$worktree_tmp"' EXIT INT TERM

git worktree list --porcelain > "$worktree_tmp"

found_dirty=0
current_path=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*)
      current_path="${line#worktree }"
      ;;
    "")
      if [ -n "$current_path" ]; then
        wt_status=$(git -C "$current_path" status --short 2>/dev/null)
        if [ -n "$wt_status" ]; then
          echo "DIRTY: $current_path"
          echo "$wt_status" | sed 's/^/  /'
          found_dirty=1
        fi
        current_path=""
      fi
      ;;
  esac
done < "$worktree_tmp"

rm -f "$worktree_tmp"

if [ "$found_dirty" -eq 1 ]; then
  echo ""
  echo "WARN: one or more worktrees have uncommitted changes"
  echo "Run the session-close checklist before ending the session."
  exit 1
fi

echo "All worktrees clean."
exit 0
