#!/usr/bin/env bash
# test-provision-bench-substitution.sh — Smoke test for TC-081
# (provision-bench.sh AGENT.md placeholder substitution).
#
# Proves the two defects TC-081 fixed are actually gone:
#   Defect 1 (unescaped delimiter/special chars) — a --task value containing
#     `/`, `&`, or `\` must render completely and literally in the
#     generated AGENT.md, with no truncation and no interpreter error
#     (the old `sed "s/.../$TASK/.../"` form broke on `/` with
#     "sed: bad flag in substitute command" and mangled `&`/`\`).
#   Defect 2 (placeholder-ordering double-substitution) — the rendered
#     BRANCH line must equal the real branch, never the literal
#     "feat/AC-NNNN-short-slug" placeholder residue.
#
# Exercises render_bench_agent_md() directly, in isolation, by sourcing
# provision-bench.sh with PROVISION_BENCH_SOURCED=1 (see the guard at the
# top of that script). This is function-level and side-effect-free: no
# worktree, branch, or bench directory is created by the primary test
# groups below. See mddocs/scripts/test-export-framework-severance.sh for
# the sibling test harness this one's style/conventions follow.
#
# Group 5 additionally exercises the full provision-bench.sh CLI end to end
# against a real (but throwaway, self-cleaning) sibling worktree, to prove
# the fix holds through the actual call sites (Pattern A and Pattern W),
# not just the extracted function. It always tears itself down (worktree
# remove + branch delete), even on failure, via a trap.
#
# Usage:
#   test-provision-bench-substitution.sh [--skip-e2e]
#
# Arguments:
#   --skip-e2e  Skip Group 5 (the real-worktree end-to-end check). Useful
#               if the sibling bench numbers it uses (98, 99) are not free
#               in the caller's environment.
#
# Exit codes:
#   0  All test cases passed
#   1  One or more test cases failed — see per-case FAIL lines
#
# See mddocs/adr — TC-081 (no dedicated ADR; fix tracked by ticket only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISION_SCRIPT="$SCRIPT_DIR/provision-bench.sh"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKIP_E2E=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-e2e) SKIP_E2E=1; shift ;;
    -h|--help)
      printf 'Usage: %s [--skip-e2e]\n' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/provision-bench-substitution-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

PASS=0
FAIL=0
FAILED_CASES=()

pass_case() {
  printf 'PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail_case() {
  printf 'FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
  FAILED_CASES+=("$1")
}

echo "=================================================================="
echo "provision-bench.sh substitution test harness (TC-081)"
echo "  framework root: $FRAMEWORK_ROOT"
echo "  workdir:        $WORKDIR"
echo "=================================================================="
echo ""

# ---------------------------------------------------------------------------
# render() — invoke render_bench_agent_md in a fresh subshell, sourcing
# provision-bench.sh with PROVISION_BENCH_SOURCED=1 so the main argument-
# parse/worktree flow never runs. TICKET/BRANCH/TASK/output path are passed
# via environment so no value crosses a shell quoting boundary as literal
# script text (which would reintroduce exactly the class of bug this test
# proves is fixed, just at the test layer instead of the script layer).
#
# stderr is captured separately so callers can assert on the ABSENCE of any
# "sed: bad flag" (or other interpreter) error, not just on stdout content.
# ---------------------------------------------------------------------------
render() {
  # render <template> <output> <ticket> <branch> <task>
  local template="$1" output="$2" ticket="$3" branch="$4" task="$5"
  PROVISION_BENCH_SOURCED=1 TICKET="$ticket" BRANCH="$branch" TASK="$task" bash -c "
    . '$PROVISION_SCRIPT'
    render_bench_agent_md '$template' '$output'
  "
}

TEMPLATES=(
  "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-project"
  "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-framework"
  "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-w"
)

# ---------------------------------------------------------------------------
# Group 1 — header comment stripped, well-formed output, plain case
# ---------------------------------------------------------------------------
echo "-- Group 1: header stripped, well-formed output (plain values) --"
for tmpl in "${TEMPLATES[@]}"; do
  base="$(basename "$tmpl")"
  out="$WORKDIR/plain_${base}.md"
  err_out="$WORKDIR/plain_${base}.err"
  if render "$tmpl" "$out" "TC-100" "feat/TC-100-plain-slug" "Plain task description" 2>"$err_out"; then
    header_line1="$(sed -n '1p' "$tmpl")"
    if [ -s "$out" ] \
       && ! grep -qxF "$header_line1" "$out" \
       && grep -q '^\*\*TICKET:\*\* TC-100$' "$out" \
       && grep -q '^\*\*BRANCH:\*\* feat/TC-100-plain-slug$' "$out" \
       && grep -q '^\*\*TASK:\*\* Plain task description$' "$out" \
       && [ ! -s "$err_out" ]; then
      pass_case "Group1 ($base): header stripped, TICKET/BRANCH/TASK lines correct, no stderr"
    else
      fail_case "Group1 ($base): header stripped, TICKET/BRANCH/TASK lines correct, no stderr"
      sed 's/^/  /' "$out" 2>/dev/null
      sed 's/^/  [stderr] /' "$err_out" 2>/dev/null
    fi
  else
    fail_case "Group1 ($base): render_bench_agent_md exited non-zero"
    sed 's/^/  [stderr] /' "$err_out" 2>/dev/null
  fi
done

# ---------------------------------------------------------------------------
# Group 2 — TC-081 Defect 1: TASK containing a slash must render complete
# and literal, with no sed/interpreter error. This is the exact repro from
# the ticket ("detect/offer ..." breaking with "sed: bad flag in substitute
# command").
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 2: TC-081 Defect 1 — TASK containing '/' --"
TASK_SLASH="detect/offer to fix formatting issues"
out="$WORKDIR/slash.md"
err_out="$WORKDIR/slash.err"
render "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-framework" "$out" \
  "TC-101" "fix/TC-101-slug" "$TASK_SLASH" 2>"$err_out"
if grep -qF "**TASK:** $TASK_SLASH" "$out" && [ ! -s "$err_out" ]; then
  pass_case "Group2: TASK containing '/' renders complete and literal, no stderr"
else
  fail_case "Group2: TASK containing '/' renders complete and literal, no stderr"
  sed 's/^/  /' "$out" 2>/dev/null
  sed 's/^/  [stderr] /' "$err_out" 2>/dev/null
fi
if ! grep -qi 'sed: bad flag' "$err_out" 2>/dev/null && ! grep -qi 'sed: bad flag' "$out" 2>/dev/null; then
  pass_case "Group2: no 'sed: bad flag' error anywhere in output"
else
  fail_case "Group2: no 'sed: bad flag' error anywhere in output"
fi

# ---------------------------------------------------------------------------
# Group 3 — TC-081 Defect 1: TASK containing '&' must render literally, not
# expanded as a sed/awk-gsub "matched text" backreference; and a TASK
# containing '/', '&', and backslash together (the worst-case combination)
# must still render byte-for-byte.
# ---------------------------------------------------------------------------
echo ""
printf '%s\n' "-- Group 3: TC-081 Defect 1 — TASK containing '&', backslash, and combinations --"
TASK_AMP='fix ports A & B'
out="$WORKDIR/amp.md"
err_out="$WORKDIR/amp.err"
render "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-framework" "$out" \
  "TC-102" "fix/TC-102-slug" "$TASK_AMP" 2>"$err_out"
if grep -qF "**TASK:** $TASK_AMP" "$out" && [ ! -s "$err_out" ]; then
  pass_case "Group3a: TASK containing '&' renders literally (not expanded as matched-text)"
else
  fail_case "Group3a: TASK containing '&' renders literally (not expanded as matched-text)"
  sed 's/^/  /' "$out" 2>/dev/null
fi

TASK_COMBO='handle a/b & c\d cases, retry & verify'
out="$WORKDIR/combo.md"
err_out="$WORKDIR/combo.err"
render "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-w" "$out" \
  "TC-103" "fix/TC-103-slug" "$TASK_COMBO" 2>"$err_out"
if grep -qF "**TASK:** $TASK_COMBO" "$out" && [ ! -s "$err_out" ]; then
  pass_case "Group3b: TASK combining '/', '&', '\\' renders byte-for-byte, no stderr"
else
  fail_case "Group3b: TASK combining '/', '&', '\\' renders byte-for-byte, no stderr"
  sed 's/^/  /' "$out" 2>/dev/null
  sed 's/^/  [stderr] /' "$err_out" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# Group 4 — TC-081 Defect 2: placeholder-ordering double-substitution. The
# rendered BRANCH line must equal the real branch, never the literal
# "feat/AC-NNNN-short-slug" placeholder (which is what the old
# TICKET-before-BRANCH substitution order produced, since it rewrote the
# AC-NNNN inside the branch placeholder before the branch rule ever ran).
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 4: TC-081 Defect 2 — placeholder-ordering (BRANCH line correctness) --"
REAL_BRANCH="fix/TC-081-provision-bench-substitution"
out="$WORKDIR/order.md"
render "$FRAMEWORK_ROOT/.agents/bootstrap/bench-AGENT.md.pattern-a-framework" "$out" \
  "TC-081" "$REAL_BRANCH" "Fix provision-bench.sh substitution" 2>"$WORKDIR/order.err"
branch_line="$(grep '^\*\*BRANCH:\*\*' "$out" || true)"
if [ "$branch_line" = "**BRANCH:** $REAL_BRANCH" ]; then
  pass_case "Group4: BRANCH line equals real branch exactly"
else
  fail_case "Group4: BRANCH line equals real branch exactly"
  echo "  got: $branch_line"
fi
if ! grep -q 'short-slug' "$out"; then
  pass_case "Group4: no residual 'short-slug' placeholder text in output"
else
  fail_case "Group4: no residual 'short-slug' placeholder text in output"
  grep 'short-slug' "$out" | sed 's/^/  /'
fi
# TICKET substitution must still have happened everywhere else (proves the
# fix didn't just stop substituting TICKET to dodge the ordering bug).
ticket_hits="$(grep -c 'TC-081' "$out" || true)"
if [ "${ticket_hits:-0}" -ge 2 ]; then
  pass_case "Group4: AC-NNNN -> TICKET substitution still applied elsewhere (TICKET line + BRANCH)"
else
  fail_case "Group4: AC-NNNN -> TICKET substitution still applied elsewhere (TICKET line + BRANCH)"
fi

# ---------------------------------------------------------------------------
# Group 5 — end-to-end CLI smoke test against a real, throwaway, self-
# cleaning sibling worktree. Exercises the actual Pattern A and Pattern W
# call sites (not just the extracted function), with a --task containing
# '/' and '&'. Uses high bench numbers (98, 99) unlikely to collide with
# real benches (.00-.02 reserved). Always tears down, even on failure.
# ---------------------------------------------------------------------------
if [ "$SKIP_E2E" -eq 1 ]; then
  echo ""
  echo "-- Group 5: SKIPPED (--skip-e2e) --"
else
  echo ""
  echo "-- Group 5: end-to-end CLI smoke test (real throwaway worktree) --"

  PARENT_DIR="$(dirname "$FRAMEWORK_ROOT")"
  PROJECT_NAME="$(basename "$FRAMEWORK_ROOT" | sed 's/\.[0-9]*$//')"
  E2E_BENCH_A="98"
  E2E_BENCH_W="99"
  E2E_DIR_A="${PARENT_DIR}/${PROJECT_NAME}.${E2E_BENCH_A}"
  E2E_DIR_W="${PARENT_DIR}/${PROJECT_NAME}.${E2E_BENCH_W}"
  E2E_BRANCH_A="fix/TC-081-e2e-smoke-a"
  E2E_BRANCH_W="fix/TC-081-e2e-smoke-w"

  cleanup_e2e() {
    if [ -d "$E2E_DIR_A" ]; then
      git -C "$FRAMEWORK_ROOT" worktree remove --force "$E2E_DIR_A" 2>/dev/null || rm -rf "$E2E_DIR_A"
    fi
    git -C "$FRAMEWORK_ROOT" branch -D "$E2E_BRANCH_A" >/dev/null 2>&1 || true
    if [ -d "$E2E_DIR_W" ]; then
      git -C "$FRAMEWORK_ROOT" worktree remove --force "$E2E_DIR_W" 2>/dev/null || rm -rf "$E2E_DIR_W"
    fi
    git -C "$FRAMEWORK_ROOT" branch -D "$E2E_BRANCH_W" >/dev/null 2>&1 || true
  }
  trap 'cleanup_e2e; rm -rf "$WORKDIR"' EXIT

  if [ -e "$E2E_DIR_A" ] || [ -e "$E2E_DIR_W" ]; then
    fail_case "Group5: pre-flight collision check (bench .98/.99 must be free before e2e test runs)"
    echo "  refusing to run e2e group — one of $E2E_DIR_A / $E2E_DIR_W already exists"
  else
    # --- Pattern A ---
    e2e_a_out="$WORKDIR/e2e_a.out"
    e2e_a_rc=0
    ( cd "$FRAMEWORK_ROOT" && sh mddocs/scripts/provision-bench.sh \
        --bench "$E2E_BENCH_A" --ticket TC-081 --type fix --slug e2e-smoke-a \
        --task "detect/offer & fix e2e things" ) >"$e2e_a_out" 2>&1 || e2e_a_rc=$?

    a_branch_line="$(grep '^\*\*BRANCH:\*\*' "$E2E_DIR_A/AGENT.md" 2>/dev/null || true)"
    a_task_line="$(grep '^\*\*TASK:\*\*' "$E2E_DIR_A/AGENT.md" 2>/dev/null || true)"
    a_status="$(git -C "$E2E_DIR_A" status --short 2>/dev/null || echo "MISSING")"

    if [ "$e2e_a_rc" -eq 0 ] \
       && [ "$a_branch_line" = "**BRANCH:** fix/TC-081-e2e-smoke-a" ] \
       && [ "$a_task_line" = "**TASK:** detect/offer & fix e2e things" ] \
       && [ -z "$a_status" ] \
       && ! grep -qi 'sed: bad flag' "$e2e_a_out"; then
      pass_case "Group5a: Pattern A e2e — BRANCH correct, TASK complete with '/' and '&', clean git status, no sed error"
    else
      fail_case "Group5a: Pattern A e2e — BRANCH correct, TASK complete with '/' and '&', clean git status, no sed error"
      echo "  rc=$e2e_a_rc branch_line=[$a_branch_line] task_line=[$a_task_line] status=[$a_status]"
      sed 's/^/  /' "$e2e_a_out"
    fi

    # --- Pattern W ---
    e2e_w_out="$WORKDIR/e2e_w.out"
    e2e_w_rc=0
    ( cd "$FRAMEWORK_ROOT" && sh mddocs/scripts/provision-bench.sh \
        --bench "$E2E_BENCH_W" --ticket TC-081 --type fix --slug e2e-smoke-w \
        --task "handle a/b & c\\d cases" --pattern w ) >"$e2e_w_out" 2>&1 || e2e_w_rc=$?

    w_branch_line="$(grep '^\*\*BRANCH:\*\*' "$E2E_DIR_W/AGENT.md" 2>/dev/null || true)"
    w_task_line="$(grep '^\*\*TASK:\*\*' "$E2E_DIR_W/AGENT.md" 2>/dev/null || true)"

    if [ "$e2e_w_rc" -eq 0 ] \
       && [ "$w_branch_line" = "**BRANCH:** fix/TC-081-e2e-smoke-w" ] \
       && [ "$w_task_line" = '**TASK:** handle a/b & c\d cases' ] \
       && ! grep -qi 'sed: bad flag' "$e2e_w_out"; then
      pass_case "Group5b: Pattern W e2e — BRANCH correct, TASK complete with '/', '&', '\\', no sed error"
    else
      fail_case "Group5b: Pattern W e2e — BRANCH correct, TASK complete with '/', '&', '\\', no sed error"
      echo "  rc=$e2e_w_rc branch_line=[$w_branch_line] task_line=[$w_task_line]"
      sed 's/^/  /' "$e2e_w_out"
    fi
  fi

  cleanup_e2e
  trap 'rm -rf "$WORKDIR"' EXIT
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================="
echo "  PASS: $PASS   FAIL: $FAIL"
echo "=================================================================="
if [ "$FAIL" -gt 0 ]; then
  echo "Failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
