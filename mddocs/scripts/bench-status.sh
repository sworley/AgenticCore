#!/bin/sh
# bench-status.sh — Show status of all git worktrees
#
# Usage: ./scripts/bench-status.sh [--check] [--stale]
#
# Options:
#   --check   Exit 1 if any bench is dirty (for use in automation)
#   --stale   Cross-reference branch names against tasks.yaml and flag benches
#             whose associated task is merged or cancelled (stale benches)
#
# Branch naming convention assumed: `<type>`/AC-NNNN-slug
# Task ID is extracted from the first AC-NNNN segment in the branch name.
#
# Also prints an advisory NOTICE (stdout, does not affect exit code) if no
# `.00` HIL worktree is found among the enumerated worktrees, along with the
# command to provision one. This is advisory only — the script never creates
# or modifies the `.00` worktree itself.
#
# Exit codes:
#   0  All benches clean / no stale benches (per flags used)
#   1  One or more benches dirty (--check) or stale (--stale)
#
# Note: the worktree table is built by reading `git worktree list --porcelain`
# output from a temp file into a `while read` loop in the current shell (not
# a pipe subshell), so that dirty_count accumulated in the loop is visible to
# the --check exit logic below. Piping directly into `while read` would run
# the loop in a subshell, silently discarding dirty_count (shellcheck
# SC2030/SC2031) and making `--check` always exit 0 regardless of dirty state.

set -u

CHECK_MODE=0
STALE_MODE=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_MODE=1 ;;
    --stale) STALE_MODE=1 ;;
  esac
done

dirty_count=0
stale_count=0

printf "%-20s %-40s %-8s %-6s %-8s\n" "BENCH" "BRANCH" "SHA" "DIRTY" "TASK"
printf "%s\n" "----------------------------------------------------------------------------------------------------"

# Write the worktree table rows to a temp file first, then read them back in
# the CURRENT shell (not a pipe subshell), so that dirty_count increments
# below survive to the exit logic at the bottom of the script. Piping
# directly into `while read` would run the loop in a subshell and any
# variable set there is lost when the subshell exits (shellcheck SC2030/SC2031).
worktree_tmp=$(mktemp)
trap 'rm -f "$worktree_tmp"' EXIT

git worktree list --porcelain | awk '
  /^worktree / { path=$2 }
  /^HEAD /     { sha=substr($2,1,7) }
  /^branch /   { branch=substr($2, index($2,"refs/heads/")+11) }
  /^$/         { print path "|" sha "|" branch; path=""; sha=""; branch="" }
  END          { if (path != "") print path "|" sha "|" branch }
' > "$worktree_tmp"

while IFS='|' read -r path sha branch; do
  if [ -z "$path" ]; then continue; fi

  dirty_files=$(git -C "$path" status --short 2>/dev/null | wc -l | tr -d ' ')
  dirty_label="-"
  if [ "$dirty_files" -gt 0 ]; then
    dirty_label="$dirty_files"
  fi

  bench_name=$(basename "$path")

  # Extract task ID from branch name (matches AC-NNNN pattern)
  task_id=$(echo "$branch" | grep -oE 'AC-[0-9]+' | head -1)
  task_label="${task_id:--}"

  printf "%-20s %-40s %-8s %-6s %-8s\n" \
    "$bench_name" \
    "${branch:-detached}" \
    "${sha:-unknown}" \
    "$dirty_label" \
    "$task_label"

  if [ "$dirty_files" -gt 0 ]; then
    dirty_count=$((dirty_count + 1))
  fi
done < "$worktree_tmp"

rm -f "$worktree_tmp"

# .00 HIL worktree presence check — advisory only, never creates or modifies .00.
# Re-queries worktree list rather than reusing the table loop above for
# simplicity/isolation — the table loop's temp file is scoped to that section.
if ! git worktree list --porcelain | grep -qE '^worktree .*\.00$'; then
  echo ""
  echo "NOTICE: no .00 HIL worktree found."
  echo "  The .00 management plane is the HIL's personal workspace (Pattern H, branch"
  echo "  workspace/owner). A fresh workspace does not have it until it is provisioned."
  echo "  On first startup the lead-engineer provisions it automatically — run:"
  echo "    ./mddocs/scripts/provision-bench.sh --pattern h"
  echo "  Then register .00 in bench-registry.yaml with \`locked: true\` so the"
  echo "  worktree-teardown guardrail protects it from day one."
fi

# Stale bench detection — requires python3 and tasks.yaml
if [ "$STALE_MODE" -eq 1 ]; then
  # Prefer uv run (has pyyaml in the project env), fall back to bare python3
  if command -v uv >/dev/null 2>&1; then
    PY="uv run python3"
  elif command -v python3 >/dev/null 2>&1; then
    PY="python3"
  else
    PY=""
  fi

  if [ -z "$PY" ]; then
    echo "WARN: python3 not found — skipping stale bench detection"
  elif [ ! -f "tasks.yaml" ]; then
    echo "WARN: tasks.yaml not found — skipping stale bench detection"
  else
    echo ""
    stale_output=$(eval "$PY" - <<'PYEOF'
import subprocess, re, sys
try:
    import yaml
except ImportError:
    print("WARN: pyyaml not installed — skipping stale bench detection")
    sys.exit(0)

with open("tasks.yaml") as f:
    tasks = yaml.safe_load(f) or []

terminal_ids = {
    t["id"] for t in tasks
    if t.get("status") in ("merged", "cancelled")
}

result = subprocess.run(
    ["git", "worktree", "list", "--porcelain"],
    capture_output=True, text=True
)

stale = []
path = branch = None
for line in result.stdout.splitlines():
    if line.startswith("worktree "):
        path = line.split(None, 1)[1]
    elif line.startswith("branch "):
        branch = line.split("refs/heads/", 1)[-1]
    elif line == "":
        if path and branch:
            match = re.search(r"AC-\d+", branch)
            if match and match.group(0) in terminal_ids:
                stale.append((path, branch, match.group(0)))
        path = branch = None

if stale:
    print(f"STALE BENCHES — {len(stale)} bench(es) on completed/cancelled tasks:")
    for p, b, tid in stale:
        print(f"  {tid}  {b}  ({p})")
    print("  Run session-close checklist to tear these down.")
    sys.exit(1)
else:
    print("No stale benches detected.")
    sys.exit(0)
PYEOF
    )
    stale_exit=$?
    echo "$stale_output"
    if [ "$stale_exit" -ne 0 ]; then
      stale_count=1
    fi
  fi
fi

# Exit logic
echo ""
exit_code=0
if [ "$CHECK_MODE" -eq 1 ] && [ "$dirty_count" -gt 0 ]; then
  echo "WARN: $dirty_count bench(es) have uncommitted changes"
  exit_code=1
fi
if [ "$STALE_MODE" -eq 1 ] && [ "$stale_count" -gt 0 ]; then
  exit_code=1
fi
exit "$exit_code"
