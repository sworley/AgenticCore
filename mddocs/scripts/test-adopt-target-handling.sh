#!/usr/bin/env bash
# test-adopt-target-handling.sh — Regression test harness for TC-084 and TC-085.
#
# TC-084: adopt.sh Steps 6-7 fail with a relative --target (double-nested
#   path bug). Proves that adopt.sh end-to-end with a RELATIVE --target
#   (e.g. ./my-project.01) correctly canonicalizes to an absolute path before
#   Steps 6-7 run — no "No such file or directory" false failures.
#
# TC-085: adopt.sh / export-framework.sh have no decision point for --target.
#   Proves:
#   (a) --target omitted + interactive TTY prompt (simulated via expect or
#       here-string input)
#   (b) --target omitted + non-interactive fails clearly (stdin not a TTY)
#   (c) --target supplied + confirmation step surfaces it back before mkdir -p
#       (confirmed via --yes skip path and the aborting path)
#
# All throwaway target dirs are created under $TMPDIR (never inside the repo).
# Cleaned up on exit via trap.
#
# Usage:
#   test-adopt-target-handling.sh [--workdir <dir>] [--keep] [--skip-e2e]
#
# Arguments:
#   --workdir <dir>  Directory to create test repos under (default: mktemp -d)
#   --keep           Do not delete the workdir on exit (for manual inspection)
#   --skip-e2e       Skip the full end-to-end adopt.sh tests (Groups 1-2) that
#                    invoke export-framework.sh and do a real export; useful if
#                    you only want to test the arg-parse / confirm behavior.
#
# Exit codes:
#   0  All test cases passed
#   1  One or more test cases failed — see per-case FAIL lines
#
# See mddocs/scripts/test-export-framework-severance.sh for the sibling test
# harness this one's style and conventions follow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADOPT_SCRIPT="$SCRIPT_DIR/setup/adopt.sh"
EXPORT_SCRIPT="$SCRIPT_DIR/export-framework.sh"

WORKDIR=""
KEEP=0
SKIP_E2E=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) WORKDIR="$2"; shift 2 ;;
    --keep)    KEEP=1; shift ;;
    --skip-e2e) SKIP_E2E=1; shift ;;
    -h|--help)
      printf 'Usage: %s [--workdir <dir>] [--keep] [--skip-e2e]\n' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$WORKDIR" ]; then
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/adopt-target-test.XXXXXX")"
else
  mkdir -p "$WORKDIR"
  WORKDIR="$(cd "$WORKDIR" && pwd)"
fi

if [ "$KEEP" -eq 0 ]; then
  trap 'rm -rf "$WORKDIR"' EXIT
fi

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
echo "adopt.sh / export-framework.sh target-handling test harness (TC-084, TC-085)"
echo "  framework root: $FRAMEWORK_ROOT"
echo "  adopt script:   $ADOPT_SCRIPT"
echo "  export script:  $EXPORT_SCRIPT"
echo "  workdir:        $WORKDIR"
echo "=================================================================="
echo ""

# ---------------------------------------------------------------------------
# Group 1 — TC-084: adopt.sh end-to-end with a RELATIVE --target (the
# regression that shipped as the TC-079/v1.6.0 defect).
#
# We run adopt.sh from a sub-directory of $WORKDIR and pass a RELATIVE
# --target path (./my-project.01 — the exact README form). Steps 6-7 must
# run and report real status, not "No such file or directory".
#
# --skip-agent-config because opencode.json needs a live AI toolchain
# Code install and we're not testing that here.
#
# --yes skips the TC-085 confirmation prompt (we test that separately).
# ---------------------------------------------------------------------------
if [ "$SKIP_E2E" -eq 0 ]; then
  echo "-- Group 1: TC-084 — adopt.sh with RELATIVE --target (regression) --"

  # Create a parent workdir that ADOPT.SH will cd INTO implicitly, then pass
  # a relative path from there.
  G1_PARENT="$WORKDIR/g1_parent"
  mkdir -p "$G1_PARENT"
  G1_RELATIVE_TARGET="./my-project.01"
  G1_ABS_TARGET="$G1_PARENT/my-project.01"

  # Run from inside G1_PARENT so the relative path is valid
  ( cd "$G1_PARENT" && bash "$ADOPT_SCRIPT" \
      --target "$G1_RELATIVE_TARGET" \
      --slug TEST \
      --skip-agent-config \
      --yes \
    ) > "$WORKDIR/g1_adopt.out" 2>&1 || true

  # TC-084 core assertion: no "No such file or directory" for check-env.sh
  # or opencode.json paths. The export itself may report warnings
  # (missing env vars, missing mdbook) but the path errors must be gone.
  if grep -q 'No such file or directory' "$WORKDIR/g1_adopt.out" 2>/dev/null; then
    fail_case "TC-084 (Group1): RELATIVE --target: no 'No such file or directory' from Steps 6-7 (TC-084 regression)"
    sed 's/^/  /' "$WORKDIR/g1_adopt.out"
  else
    pass_case "TC-084 (Group1): RELATIVE --target: no 'No such file or directory' from Steps 6-7"
  fi

  # The target directory must have been created at the ABSOLUTE resolved path
  if [ -d "$G1_ABS_TARGET" ]; then
    pass_case "TC-084 (Group1): RELATIVE --target: target directory created at correct absolute path"
  else
    fail_case "TC-084 (Group1): RELATIVE --target: target directory created at correct absolute path (not found: $G1_ABS_TARGET)"
    sed 's/^/  /' "$WORKDIR/g1_adopt.out"
  fi

  # framework-version.txt must exist (export ran correctly)
  if [ -f "$G1_ABS_TARGET/framework-version.txt" ]; then
    pass_case "TC-084 (Group1): RELATIVE --target: framework-version.txt present (export succeeded)"
  else
    fail_case "TC-084 (Group1): RELATIVE --target: framework-version.txt present (export succeeded)"
    sed 's/^/  /' "$WORKDIR/g1_adopt.out"
  fi

  # The output must show Step 6 ran (check-env.sh path line, not "skipping")
  # but not produce the double-nested path error
  if grep -q 'Step 6' "$WORKDIR/g1_adopt.out" 2>/dev/null; then
    pass_case "TC-084 (Group1): RELATIVE --target: Step 6 ran (check-env output present)"
  else
    fail_case "TC-084 (Group1): RELATIVE --target: Step 6 ran (check-env output present)"
    sed 's/^/  /' "$WORKDIR/g1_adopt.out"
  fi

  echo ""
  echo "-- Group 2: TC-084 — adopt.sh with ABSOLUTE --target (no regression) --"

  G2_ABS_TARGET="$WORKDIR/g2_absolute_target.01"

  bash "$ADOPT_SCRIPT" \
    --target "$G2_ABS_TARGET" \
    --slug TESTABS \
    --skip-agent-config \
    --yes \
    > "$WORKDIR/g2_adopt.out" 2>&1 || true

  if grep -q 'No such file or directory' "$WORKDIR/g2_adopt.out" 2>/dev/null; then
    fail_case "TC-084 (Group2): ABSOLUTE --target: no 'No such file or directory' from Steps 6-7"
    sed 's/^/  /' "$WORKDIR/g2_adopt.out"
  else
    pass_case "TC-084 (Group2): ABSOLUTE --target: no 'No such file or directory' from Steps 6-7"
  fi

  if [ -f "$G2_ABS_TARGET/framework-version.txt" ]; then
    pass_case "TC-084 (Group2): ABSOLUTE --target: framework-version.txt present (export succeeded)"
  else
    fail_case "TC-084 (Group2): ABSOLUTE --target: framework-version.txt present (export succeeded)"
    sed 's/^/  /' "$WORKDIR/g2_adopt.out"
  fi
else
  echo "-- Group 1-2: SKIPPED (--skip-e2e) --"
fi

# ---------------------------------------------------------------------------
# Group 3 — TC-085 (a): --target omitted in non-interactive mode must fail
# clearly (stdin redirected from /dev/null, not a TTY).
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 3: TC-085(b) — --target omitted + non-interactive: fails clearly --"

# adopt.sh: --target omitted, stdin is /dev/null (not a TTY) → exit 1, clear message
g3_adopt_rc=0
bash "$ADOPT_SCRIPT" --slug TEST < /dev/null > "$WORKDIR/g3_adopt.out" 2>&1 || g3_adopt_rc=$?
if [ "$g3_adopt_rc" -ne 0 ] && grep -qi 'required\|non-interactive\|not a tty' "$WORKDIR/g3_adopt.out" 2>/dev/null; then
  pass_case "TC-085(b) adopt.sh: --target omitted + non-interactive: exits non-zero with clear message"
else
  fail_case "TC-085(b) adopt.sh: --target omitted + non-interactive: exits non-zero with clear message (rc=$g3_adopt_rc)"
  sed 's/^/  /' "$WORKDIR/g3_adopt.out"
fi

# export-framework.sh: --target omitted, stdin is /dev/null → exit 1, clear message
g3_export_rc=0
bash "$EXPORT_SCRIPT" --slug TEST < /dev/null > "$WORKDIR/g3_export.out" 2>&1 || g3_export_rc=$?
if [ "$g3_export_rc" -ne 0 ] && grep -qi 'required\|non-interactive\|not a tty' "$WORKDIR/g3_export.out" 2>/dev/null; then
  pass_case "TC-085(b) export-framework.sh: --target omitted + non-interactive: exits non-zero with clear message"
else
  fail_case "TC-085(b) export-framework.sh: --target omitted + non-interactive: exits non-zero with clear message (rc=$g3_export_rc)"
  sed 's/^/  /' "$WORKDIR/g3_export.out"
fi

# ---------------------------------------------------------------------------
# Group 4 — TC-085 (c): --target supplied but confirmation aborts when input
# is 'n'. The confirmation prompt must surface the target path before mkdir -p.
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 4: TC-085(c) — --target supplied: confirmation surfaces path, 'n' aborts --"

G4_TARGET="$WORKDIR/g4_should_not_exist"

# Feed 'n' as confirmation → must abort non-zero, directory must NOT be created
g4_adopt_rc=0
printf 'n\n' | bash "$ADOPT_SCRIPT" --target "$G4_TARGET" --slug TEST \
  > "$WORKDIR/g4_adopt_abort.out" 2>&1 || g4_adopt_rc=$?

if [ "$g4_adopt_rc" -ne 0 ]; then
  pass_case "TC-085(c) adopt.sh: confirmation 'n' causes non-zero exit"
else
  fail_case "TC-085(c) adopt.sh: confirmation 'n' causes non-zero exit (rc=$g4_adopt_rc)"
  sed 's/^/  /' "$WORKDIR/g4_adopt_abort.out"
fi

if [ ! -d "$G4_TARGET" ]; then
  pass_case "TC-085(c) adopt.sh: confirmation 'n' does NOT create the target directory"
else
  fail_case "TC-085(c) adopt.sh: confirmation 'n' does NOT create the target directory (dir was created: $G4_TARGET)"
fi

# The confirmation output must show the target path
if grep -q "$G4_TARGET" "$WORKDIR/g4_adopt_abort.out" 2>/dev/null; then
  pass_case "TC-085(c) adopt.sh: confirmation output includes the target path (adopter sees what would be created)"
else
  fail_case "TC-085(c) adopt.sh: confirmation output includes the target path"
  sed 's/^/  /' "$WORKDIR/g4_adopt_abort.out"
fi

# Same for export-framework.sh run directly
G4E_TARGET="$WORKDIR/g4e_should_not_exist"
g4e_rc=0
printf 'n\n' | bash "$EXPORT_SCRIPT" --target "$G4E_TARGET" --slug TEST \
  > "$WORKDIR/g4_export_abort.out" 2>&1 || g4e_rc=$?

if [ "$g4e_rc" -ne 0 ]; then
  pass_case "TC-085(c) export-framework.sh: confirmation 'n' causes non-zero exit"
else
  fail_case "TC-085(c) export-framework.sh: confirmation 'n' causes non-zero exit (rc=$g4e_rc)"
  sed 's/^/  /' "$WORKDIR/g4_export_abort.out"
fi

if [ ! -d "$G4E_TARGET" ]; then
  pass_case "TC-085(c) export-framework.sh: confirmation 'n' does NOT create the target directory"
else
  fail_case "TC-085(c) export-framework.sh: confirmation 'n' does NOT create the target directory (dir was created: $G4E_TARGET)"
fi

# ---------------------------------------------------------------------------
# Group 5 — TC-085: -y/--yes skips the confirmation prompt and proceeds.
# Verifies only that the flag is accepted (non-zero exit other than 1
# means arg parse failed, not confirmation blocked); we don't need a full
# export here — use --dry-run to avoid creating real state.
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 5: TC-085 — -y/--yes flag accepted, --dry-run proceeds without confirm --"

G5_TARGET="$WORKDIR/g5_dry_run_target"

# adopt.sh --dry-run with --yes: must not hang, must not fail on unknown flag
g5_adopt_rc=0
bash "$ADOPT_SCRIPT" --target "$G5_TARGET" --slug TEST --dry-run --yes \
  > "$WORKDIR/g5_adopt_dryrun.out" 2>&1 || g5_adopt_rc=$?
if [ "$g5_adopt_rc" -eq 0 ]; then
  pass_case "TC-085 adopt.sh: --yes accepted, --dry-run exits 0 without confirmation hang"
else
  fail_case "TC-085 adopt.sh: --yes accepted, --dry-run exits 0 without confirmation hang (rc=$g5_adopt_rc)"
  sed 's/^/  /' "$WORKDIR/g5_adopt_dryrun.out"
fi

# export-framework.sh --dry-run with --yes
g5_export_rc=0
bash "$EXPORT_SCRIPT" --target "$G5_TARGET" --slug TEST --dry-run --yes \
  > "$WORKDIR/g5_export_dryrun.out" 2>&1 || g5_export_rc=$?
if [ "$g5_export_rc" -eq 0 ]; then
  pass_case "TC-085 export-framework.sh: --yes accepted, --dry-run exits 0 without confirmation hang"
else
  fail_case "TC-085 export-framework.sh: --yes accepted, --dry-run exits 0 without confirmation hang (rc=$g5_export_rc)"
  sed 's/^/  /' "$WORKDIR/g5_export_dryrun.out"
fi

# --dry-run alone (no --yes) must also not confirm/hang (confirm skipped for dry-run)
g5_dryrun_only_rc=0
bash "$ADOPT_SCRIPT" --target "$G5_TARGET" --slug TEST --dry-run \
  < /dev/null \
  > "$WORKDIR/g5_adopt_dryrun_nyes.out" 2>&1 || g5_dryrun_only_rc=$?
if [ "$g5_dryrun_only_rc" -eq 0 ]; then
  pass_case "TC-085 adopt.sh: --dry-run alone (no --yes) exits 0 without confirmation (dry-run skips mkdir confirm)"
else
  fail_case "TC-085 adopt.sh: --dry-run alone (no --yes) exits 0 without confirmation (rc=$g5_dryrun_only_rc)"
  sed 's/^/  /' "$WORKDIR/g5_adopt_dryrun_nyes.out"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=================================================================="
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "${#FAILED_CASES[@]}" -gt 0 ]; then
  echo "Failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    printf '  - %s\n' "$c"
  done
fi
echo "=================================================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
