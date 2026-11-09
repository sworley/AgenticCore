#!/bin/sh
# provision-bench.sh — Provision an ephemeral worker bench (git worktree)
#
# Usage:
#   ./scripts/provision-bench.sh --bench `<N>` --ticket `<ID>` --type `<type>` --slug `<slug>` [--flavor `<flavor>`] [--pattern `<pattern>`]
#   ./scripts/provision-bench.sh --pattern h
#
# Arguments:
#   --bench `<N>`        Bench number (e.g., 02, 03). Ignored for --pattern h (always 00).
#   --ticket `<ID>`      Ticket ID (e.g., TC-004). Not required for --pattern h.
#   --type `<type>`      Branch type: feat | fix | docs | security | poc | review | release. Not required for --pattern h.
#   --slug `<slug>`      Short branch slug (e.g., add-ci-pipeline). Not required for --pattern h.
#   --flavor `<flavor>`  Pattern A flavor: project | framework (default: project)
#   --pattern `<pattern>` Bench pattern: a | w | h (default: a)
#
# Example:
#   ./scripts/provision-bench.sh --bench 02 --ticket TC-004 --type feat --slug add-ci-pipeline
#   ./scripts/provision-bench.sh --bench 02 --ticket TC-004 --type feat --slug add-ci-pipeline --flavor framework
#   ./scripts/provision-bench.sh --bench 02 --ticket TC-004 --type feat --slug add-ci-pipeline --pattern w
#   ./scripts/provision-bench.sh --pattern h
#   # Pattern H provisions the .00 HIL worktree on branch workspace/owner — no --bench/--ticket/--type/--slug needed.
#
# Exit codes:
#   0  Success
#   1  Argument error
#   2  Bench already exists

set -eu

# render_bench_agent_md <template> <output>
#
# Strips the template's single-line header comment and substitutes the
# AC-NNNN / feat/AC-NNNN-short-slug / "Brief description of the task"
# placeholders with the real TICKET / BRANCH / TASK values (read from the
# caller's environment/globals — not passed positionally, matching this
# script's existing convention of reading BENCH/TICKET/BRANCH/etc. as
# globals rather than threading them through every function's arg list).
# Shared by the Pattern W and Pattern A blocks below (Pattern H's template
# has no placeholders and does not use this function — see its own inline
# comment where it strips its header with a plain `sed "1d"`).
#
# Defined ahead of the argument-parsing/main guard below (TC-081) so a test
# harness can `. provision-bench.sh` with PROVISION_BENCH_SOURCED=1 set and
# exercise this function directly, in isolation, with arbitrary
# TICKET/BRANCH/TASK values — without triggering worktree creation or any
# other main-flow side effect. See
# mddocs/scripts/test-provision-bench-substitution.sh.
#
# Substitution technique (TC-081): literal, non-regex string replacement in
# awk via a hand-rolled index()/substr() loop (litrepl), NOT sed and NOT
# awk's gsub().
#   - sed interpolates $TASK/$BRANCH/$TICKET directly into a sed PROGRAM (as
#     this script previously did). Any sed/regex-special character in those
#     values — most commonly `/` in a task description, but also `&`, `\`,
#     or the chosen delimiter — corrupts or breaks the sed command entirely
#     (e.g. "sed: bad flag in substitute command"), and the AGENT.md
#     overlay is written empty/partial.
#   - awk's gsub() has the same class of trap one level down: its SEARCH
#     argument is an ERE, and — the part that matters here — its REPLACEMENT
#     argument treats `&` as "insert the matched text" and backslash
#     specially. That is exactly the untrusted-injected-value problem this
#     function exists to fix, just moved from sed to awk instead of solved.
#   - litrepl() below never passes the injected value through anything that
#     interprets metacharacters: it locates the placeholder with index()
#     (a plain substring search, not a regex engine) and reassembles the
#     line with substr() concatenation. Values are inserted byte-for-byte.
#   - Values are threaded through via ENVIRON, not `awk -v`, because
#     `awk -v var=value` processes backslash escape sequences in `value`
#     (POSIX awk gives -v assignments the same escape-sequence handling as
#     string literals in the awk language), which would silently mangle a
#     value containing e.g. `\n` or `\t`. ENVIRON entries are used verbatim.
#
# Substitution ORDER also matters, independent of escaping (TC-081 defect
# 2): the feat/AC-NNNN-short-slug -> BRANCH replacement runs BEFORE the
# AC-NNNN -> TICKET replacement. Reversing the order rewrites the template's
# literal "AC-NNNN" inside "feat/AC-NNNN-short-slug" first, so the branch
# placeholder never matches on the later pass and BRANCH renders as the
# literal short-slug placeholder instead of the real branch name.
render_bench_agent_md() {
  _rbcm_template="$1"
  _rbcm_output="$2"
  TICKET="$TICKET" BRANCH="$BRANCH" TASK="$TASK" awk '
    function litrepl(s, target, repl,    out, idx, tlen) {
      tlen = length(target)
      out = ""
      while ((idx = index(s, target)) > 0) {
        out = out substr(s, 1, idx - 1) repl
        s = substr(s, idx + tlen)
      }
      return out s
    }
    NR == 1 { next }
    {
      line = $0
      line = litrepl(line, "feat/AC-NNNN-short-slug", ENVIRON["BRANCH"])
      line = litrepl(line, "AC-NNNN", ENVIRON["TICKET"])
      line = litrepl(line, "Brief description of the task", ENVIRON["TASK"])
      print line
    }
  ' "$_rbcm_template" > "$_rbcm_output"
  unset _rbcm_template _rbcm_output
}

# ---------------------------------------------------------------------------
# Main — guarded so this script can be `.`-sourced by a test harness to
# exercise render_bench_agent_md (above) in isolation, without triggering
# argument validation, worktree creation, or any other side effect. See
# mddocs/scripts/test-provision-bench-substitution.sh and the analogous
# guard in mddocs/scripts/export-framework.sh.
# ---------------------------------------------------------------------------
if [ "${PROVISION_BENCH_SOURCED:-0}" = "1" ]; then
  # shellcheck disable=SC2317
  # `return` succeeds when this script is `.`-sourced (the intended use of
  # this guard); `exit` is the POSIX-sh fallback for the (unsupported, but
  # harmless-to-guard-against) case of direct execution with the sourced
  # flag set, where `return` outside a function/dot-script fails.
  return 0 2>/dev/null || exit 0
fi

BENCH=""
TICKET=""
TYPE=""
SLUG=""
TASK=""
FLAVOR="project"
PATTERN="a"

while [ $# -gt 0 ]; do
  case "$1" in
    --bench)   BENCH="$2";   shift 2 ;;
    --ticket)  TICKET="$2";  shift 2 ;;
    --type)    TYPE="$2";    shift 2 ;;
    --slug)    SLUG="$2";    shift 2 ;;
    --task)    TASK="$2";    shift 2 ;;
    --flavor)  FLAVOR="$2";  shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    *)         echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Pattern H (.00 HIL worktree) has a fixed bench number and branch — --bench,
# --ticket, --type, and --slug are irrelevant and not required.
if [ "$PATTERN" != "h" ]; then
  if [ -z "$BENCH" ] || [ -z "$TICKET" ] || [ -z "$TYPE" ] || [ -z "$SLUG" ]; then
    echo "ERROR: --bench, --ticket, --type, and --slug are all required" >&2
    echo "Usage: $0 --bench 02 --ticket TC-004 --type feat --slug short-slug [--task 'Brief description'] [--flavor project|framework] [--pattern a|w]" >&2
    exit 1
  fi
fi

# Validate pattern
case "$PATTERN" in
  a|w|h) ;;
  *) echo "ERROR: --pattern must be one of: a w h" >&2; exit 1 ;;
esac

# Validate flavor (Pattern A only)
if [ "$PATTERN" = "a" ]; then
  case "$FLAVOR" in
    project|framework) ;;
    *) echo "ERROR: --flavor must be one of: project framework" >&2; exit 1 ;;
  esac
fi

# Default TASK to ticket ID if not supplied
if [ -z "$TASK" ]; then
  TASK="$TICKET"
fi

# Validate branch type (not applicable to Pattern H)
if [ "$PATTERN" != "h" ]; then
  case "$TYPE" in
    feat|fix|docs|security|poc|review|release) ;;
    *) echo "ERROR: --type must be one of: feat fix docs security poc review release" >&2; exit 1 ;;
  esac
fi

# Derive paths
REPO_ROOT="$(git rev-parse --show-toplevel)"
# Derive the base project name by stripping the trailing .NN bench suffix
# (e.g. AgenticCore.01 -> AgenticCore, AgenticCore.v0.02.01 -> AgenticCore.v0.02).
# This matches git-sync.sh and the documented ".01 management plane, benches are
# siblings (<base>.00/.02)" convention. (Was previously stripping a .vNN version
# suffix, which broke versioned base names like AgenticCore.v0.02.)
PROJECT_NAME="$(basename "$REPO_ROOT" | sed 's/\.[0-9]*$//')"
PARENT_DIR="$(dirname "$REPO_ROOT")"

if [ "$PATTERN" = "h" ]; then
  # Pattern H is the .00 HIL worktree — fixed bench number and branch name.
  BENCH="00"
  BRANCH="workspace/owner"
  TICKET="${TICKET:-N/A}"
  TASK="${TASK:-HIL management plane}"
fi

BENCH_SUFFIX=$(printf "%02d" "$BENCH" 2>/dev/null || echo "$BENCH")
BENCH_DIR="${PARENT_DIR}/${PROJECT_NAME}.${BENCH_SUFFIX}"
if [ "$PATTERN" != "h" ]; then
  BRANCH="${TYPE}/${TICKET}-${SLUG}"
fi

# Normalize pattern label for display/records
case "$PATTERN" in
  a) PATTERN_LABEL="A" ;;
  w) PATTERN_LABEL="W" ;;
  h) PATTERN_LABEL="H" ;;
esac

# Check bench doesn't already exist
if [ -d "$BENCH_DIR" ]; then
  echo "ERROR: bench directory already exists: $BENCH_DIR" >&2
  exit 2
fi

echo "==> provision-bench"
echo "    bench:  $BENCH_DIR"
echo "    branch: $BRANCH"
echo ""

# Pattern H requires jq for the opencode.json default_agent flip. Check before
# creating any worktree so a missing jq fails cleanly with no partial state.
if [ "$PATTERN" = "h" ] && ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required for --pattern h (opencode.json default_agent flip)" >&2
  exit 1
fi

# Create the worktree on a new branch cut from the current branch (the .01
# integration branch — its name is the adopter's choice; this script does not
# assume 'main' or 'dev').
# Pattern H targets workspace/owner, which may already exist as a branch in a
# real deployment (e.g. after a prior .00 was torn down and reprovisioned) —
# reuse it if present rather than failing on -b.
if [ "$PATTERN" = "h" ] && git show-ref --verify --quiet refs/heads/workspace/owner; then
  git worktree add "$BENCH_DIR" workspace/owner
else
  git worktree add "$BENCH_DIR" -b "$BRANCH"
fi

# --- Disk-local bench record (.bench/assignment.md) ---
# Gitignored, regenerable, worktree-local convenience file read by the
# attendant/tools inside this live worktree. Never staged or committed —
# bench-registry.yaml is the canonical, durable, queryable per-bench
# provenance record (TC-056, ADR-0012 amendment).
mkdir -p "$BENCH_DIR/.bench"
cat > "$BENCH_DIR/.bench/assignment.md" << EOF
# Bench Assignment

**TICKET:** $TICKET
**BRANCH:** $BRANCH
**PATTERN:** $PATTERN_LABEL
**TASK:** $TASK
EOF

# --- Tool-specific AGENT.md / opencode.json ---
if [ "$PATTERN" = "h" ]; then
  # Pattern H: overlay the hil-assistant AGENT.md and flip default_agent in
  # opencode.json to hil-assistant. Both files are tracked-but-overlaid via
  # skip-worktree — never committed in the .00 worktree. (jq availability was
  # verified before worktree creation.)

  PATTERN_TEMPLATE="$REPO_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-h"

  # Strip the single-line header comment from the pattern file. The pattern-h
  # template has no AC-NNNN/branch/task placeholders, so no substitution is needed.
  sed "1d" "$PATTERN_TEMPLATE" > "$BENCH_DIR/AGENT.md"
  git -C "$BENCH_DIR" update-index --skip-worktree AGENT.md

  # Write via a temp file and mv-on-success so a malformed canonical opencode.json
  # (jq exits non-zero) never leaves a truncated/empty file in the .00 worktree.
  jq '.default_agent = "hil-assistant"' "$REPO_ROOT/opencode.json" > "$BENCH_DIR/opencode.json.tmp"
  mv "$BENCH_DIR/opencode.json.tmp" "$BENCH_DIR/opencode.json"
  git -C "$BENCH_DIR" update-index --skip-worktree opencode.json

  echo ""
  echo "==> Bench provisioned successfully"
  echo ""
  echo "Next steps:"
  echo "  1. AGENT.md overlaid with hil-assistant persona (not committed — excluded from git)"
  echo "  2. opencode.json overlaid with default_agent=hil-assistant (not committed — excluded from git)"
  echo "  3. .bench/assignment.md written to disk (gitignored, not committed) — provenance in bench-registry.yaml"
  echo "  4. Register in bench-registry.yaml — this is the HIL plane; set locked: true"
  echo "  5. Open agentic session in: $BENCH_DIR (opens as hil-assistant)"
elif [ "$PATTERN" = "w" ]; then
  # Pattern W: select pattern-w template, commit AGENT.md (no skip-worktree)
  PATTERN_TEMPLATE="$REPO_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-w"

  # Strip the single-line header comment from the pattern file, substitute placeholders
  render_bench_agent_md "$PATTERN_TEMPLATE" "$BENCH_DIR/AGENT.md"

  git -C "$BENCH_DIR" add AGENT.md
  git -C "$BENCH_DIR" commit -m "chore: add bench AGENT.md [$TICKET]"

  echo ""
  echo "==> Bench provisioned successfully"
  echo ""
  echo "Next steps:"
  echo "  1. AGENT.md generated and committed (Pattern W)"
  echo "  2. .bench/assignment.md written to disk (gitignored, not committed) — provenance in bench-registry.yaml"
  echo "  3. Update bench-registry.yaml"
  echo "  4. Update tasks.yaml: status=in_progress, bench=$BENCH_SUFFIX, branch=$BRANCH"
  echo "  5. Open agentic session in: $BENCH_DIR"
else
  # Pattern A: select template based on flavor, apply skip-worktree
  PATTERN_TEMPLATE="$REPO_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-${FLAVOR}"

  # Strip the single-line header comment from the pattern file, substitute placeholders
  render_bench_agent_md "$PATTERN_TEMPLATE" "$BENCH_DIR/AGENT.md"

  # Prevent AGENT.md changes from appearing in git status for this worktree.
  # AGENT.md is tracked on the .01 integration branch (the .01 persona file) so
  # info/exclude is not enough — skip-worktree tells git to ignore divergence
  # between the index and working tree.
  git -C "$BENCH_DIR" update-index --skip-worktree AGENT.md

  echo ""
  echo "==> Bench provisioned successfully"
  echo ""
  echo "Next steps:"
  echo "  1. AGENT.md generated (not committed — excluded from git)"
  echo "  2. .bench/assignment.md written to disk (gitignored, not committed) — provenance in bench-registry.yaml"
  echo "  3. Update bench-registry.yaml"
  echo "  4. Update tasks.yaml: status=in_progress, bench=$BENCH_SUFFIX, branch=$BRANCH"
  echo "  5. Open agentic session in: $BENCH_DIR"
fi
