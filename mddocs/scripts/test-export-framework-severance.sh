#!/usr/bin/env bash
# test-export-framework-severance.sh — Confidentiality-control test harness
# for mddocs/scripts/export-framework.sh (ADR-0015 D-7).
#
# Proves the D-7.3 remote-severance assertion and D-7.5 history/refs/object
# scrub verification are real backstops, not decorative checks — the four
# severance-bypass cases (i)-(iv) must abort non-zero when checked directly,
# and the full script must produce a clean adopter repo end-to-end for both
# flows.
#
# This harness creates ALL throwaway test repos under a temp directory
# (default: mktemp -d under $TMPDIR, or --workdir <dir> to pin one, e.g. the
# pre-approved sandbox). It NEVER touches the framework checkout it tests
# against, other than reading from it (git rev-parse, remote inspection).
#
# Usage:
#   test-export-framework-severance.sh [--workdir <dir>] [--keep]
#
# Arguments:
#   --workdir <dir>  Directory to create test repos under (default: mktemp -d)
#   --keep           Do not delete the workdir on exit (for manual inspection)
#
# Exit codes:
#   0  All test cases passed (severance caught where expected, clean where expected)
#   1  One or more test cases failed — see per-case FAIL lines
#
# See mddocs/adr/adr-0015-framework-distribution-adoption-model.md D-7.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCRIPT="$SCRIPT_DIR/export-framework.sh"

WORKDIR=""
KEEP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) WORKDIR="$2"; shift 2 ;;
    --keep)    KEEP=1; shift ;;
    -h|--help)
      printf 'Usage: %s [--workdir <dir>] [--keep]\n' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$WORKDIR" ]; then
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/export-framework-test.XXXXXX")"
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

expect_exit() {
  # expect_exit <label> <expected_exit_code> -- <command...>
  local label="$1" expected="$2"
  shift 2
  [ "$1" = "--" ] && shift
  local actual=0
  "$@" > "$WORKDIR/.last_out.txt" 2>&1 || actual=$?
  if [ "$actual" -eq "$expected" ]; then
    pass_case "$label (exit $actual, expected $expected)"
  else
    fail_case "$label (exit $actual, expected $expected)"
    echo "  --- output ---"
    sed 's/^/  /' "$WORKDIR/.last_out.txt"
  fi
}

# Resolve the framework's own remote URL to build bypass fixtures against.
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FW_URL="$(git -C "$FRAMEWORK_ROOT" remote get-url origin 2>/dev/null || true)"
if [ -z "$FW_URL" ]; then
  echo "SKIP: framework repo has no 'origin' remote configured; bypass tests (i)-(iv) require one to build fixtures against." >&2
  FW_URL="https://example-framework-host.invalid/group/AgenticCore.git"
fi
# Derive an SSH-form equivalent for test (ii): git@host:group/repo.git
FW_HOST_PATH="$(printf '%s' "$FW_URL" | sed -E 's#^https?://([^@/]+@)?##; s#\.git$##')"
FW_HOST="${FW_HOST_PATH%%/*}"
FW_PATH="${FW_HOST_PATH#*/}"
FW_SSH="git@${FW_HOST}:${FW_PATH}.git"
# FW_ORG — the first path segment (e.g. "group" in group/repo.git). Used to
# build a PREFIX-form insteadOf base (SF-067 test) that covers the
# framework without being a full framework identity URL itself.
FW_ORG="${FW_PATH%%/*}"
# git:// protocol form and userinfo/token-in-URL form (SF-070 negative controls).
FW_GIT_PROTO="git://${FW_HOST_PATH}.git"
FW_USERINFO_URL="https://x-token-value@${FW_HOST_PATH}.git"

echo "=================================================================="
echo "export-framework.sh severance test harness"
echo "  framework root:  $FRAMEWORK_ROOT"
echo "  framework URL:    $FW_URL"
echo "  workdir:          $WORKDIR"
echo "=================================================================="
echo ""

# ---------------------------------------------------------------------------
# Group 1 — Flow A produces a clean repo
# ---------------------------------------------------------------------------
echo "-- Group 1: Flow A (empty-dir init) --"
FLOWA_DIR="$WORKDIR/flowA"
flowa_rc=0
bash "$EXPORT_SCRIPT" --target "$FLOWA_DIR" --slug ACME --yes > "$WORKDIR/flowA.out" 2>&1 || flowa_rc=$?
if [ "$flowa_rc" -eq 0 ] \
   && [ -f "$FLOWA_DIR/framework-version.txt" ] \
   && [ -z "$(git -C "$FLOWA_DIR" remote 2>/dev/null)" ] \
   && [ "$(git -C "$FLOWA_DIR" log --oneline | wc -l | tr -d ' ')" = "1" ] \
   && grep -q '^ACME$' "$FLOWA_DIR/AGENT.md" 2>/dev/null; then
  pass_case "Flow A: clean repo, framework-version.txt, slug, no remote, single commit"
else
  fail_case "Flow A: clean repo, framework-version.txt, slug, no remote, single commit"
  sed 's/^/  /' "$WORKDIR/flowA.out"
fi

# ---------------------------------------------------------------------------
# Group 2 — Flow B on a clean customer tree
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 2: Flow B (clean customer tree) --"
CUST_DIR="$WORKDIR/customer_clean"
mkdir -p "$CUST_DIR/src"
( cd "$CUST_DIR" && git init -q && echo "app" > src/app.py && echo "# readme" > README.md \
  && git add -A && git commit -q -m "initial customer commit" )

bash "$EXPORT_SCRIPT" --target "$CUST_DIR" --slug ACME --yes > "$WORKDIR/flowB.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] \
   && [ -z "$(git -C "$CUST_DIR" remote 2>/dev/null)" ] \
   && [ -z "$(git -C "$CUST_DIR" for-each-ref refs/remotes 2>/dev/null)" ] \
   && [ -z "$(git -C "$CUST_DIR" fsck --unreachable 2>/dev/null)" ] \
   && [ -f "$CUST_DIR/src/app.py" ] \
   && [ -f "$CUST_DIR/framework-version.txt" ]; then
  pass_case "Flow B: no framework remote, no framework history/objects, customer files preserved"
else
  fail_case "Flow B: no framework remote, no framework history/objects, customer files preserved"
  sed 's/^/  /' "$WORKDIR/flowB.out"
fi

# ---------------------------------------------------------------------------
# Group 3 — D-7.3 severance-bypass detection (direct assertion, unremediated)
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 3: D-7.3 severance-bypass detection (assertion catches, unremediated) --"

# Invoked indirectly via `expect_exit ... -- run_assertion_only <repo>` below.
# shellcheck disable=SC2329
run_assertion_only() {
  # Sources export-framework.sh (guarded by EXPORT_FRAMEWORK_SOURCED) to call
  # assert_remote_severance directly against a fixture repo, WITHOUT running
  # sever_framework_remotes first. Proves the assertion itself is the
  # backstop, independent of the auto-remediation step.
  local repo="$1"
  EXPORT_FRAMEWORK_SOURCED=1 bash -c "
    source '$EXPORT_SCRIPT' --target '$repo'
    assert_remote_severance '$repo'
  "
}

# (i) plain https remote
BP_I="$WORKDIR/bypass_i_https"
mkdir -p "$BP_I"; ( cd "$BP_I" && git init -q && git remote add sneaky "$FW_URL" )
expect_exit "(i) plain https remote survives severance -> assertion aborts" 5 -- run_assertion_only "$BP_I"

# (ii) SSH-form remote
BP_II="$WORKDIR/bypass_ii_ssh"
mkdir -p "$BP_II"; ( cd "$BP_II" && git init -q && git remote add sneaky "$FW_SSH" )
expect_exit "(ii) SSH-form remote survives severance -> assertion aborts" 5 -- run_assertion_only "$BP_II"

# (iii) insteadOf rewrite
BP_III="$WORKDIR/bypass_iii_insteadof"
mkdir -p "$BP_III"
( cd "$BP_III" && git init -q \
  && git remote add origin "https://example.com/customer/repo.git" \
  && git config url."$FW_SSH".insteadOf "https://example.com/customer/repo.git" )
expect_exit "(iii) insteadOf rewrite to framework survives -> assertion aborts" 5 -- run_assertion_only "$BP_III"

# (iv) remote.pushDefault
BP_IV="$WORKDIR/bypass_iv_pushdefault"
mkdir -p "$BP_IV"
( cd "$BP_IV" && git init -q \
  && git remote add fw "$FW_URL" \
  && git remote add cust "https://example.com/customer/repo.git" \
  && git config remote.pushDefault fw )
expect_exit "(iv) remote.pushDefault resolves to framework -> assertion aborts" 5 -- run_assertion_only "$BP_IV"

# (v) PREFIX-form insteadOf, DORMANT (no live remote uses the rewrite yet).
# SF-067 negative control. url.<base>.insteadOf performs PREFIX substitution
# — a base that is only a partial host/path fragment (never a full framework
# identity URL by itself) still redirects any remote whose URL starts with
# that base into the framework. This must be caught even with zero remotes
# configured, because the rule survives severance until an operator later
# adds a remote that happens to trigger it.
BP_V="$WORKDIR/bypass_v_prefix_insteadof_dormant"
mkdir -p "$BP_V"
( cd "$BP_V" && git init -q \
  && git config url."git@${FW_HOST}:${FW_ORG}/".insteadOf "custom-dormant:" )
expect_exit "(v) prefix-form insteadOf, dormant rule, no live remote -> assertion aborts" 5 -- run_assertion_only "$BP_V"

# (vi) relative-path local remote. SF-068 negative control. Git stores a
# relative remote URL verbatim; it must resolve against the ADOPTER repo
# (repo_dir), not the export script's own process CWD. This fixture builds a
# self-contained "framework mirror" (a throwaway repo carrying a copy of
# export-framework.sh, used only as FRAMEWORK_ROOT for this probe — it is
# NOT cloned or fetched, only its config/self-location logic runs) and an
# adopter sibling directory with a remote pointing at it via a short
# relative path, then verifies the assertion catches it even when invoked
# from a THIRD, unrelated directory (proving CWD-independence).
BP_VI_MIRROR="$WORKDIR/bypass_vi_mirror"
BP_VI_ADOPTER="$WORKDIR/bypass_vi_adopter"
mkdir -p "$BP_VI_MIRROR/mddocs/scripts" "$BP_VI_ADOPTER"
cp "$EXPORT_SCRIPT" "$BP_VI_MIRROR/mddocs/scripts/export-framework.sh"
( cd "$BP_VI_MIRROR" && git init -q && git commit --allow-empty -q -m seed )
# Short, realistic relative form an operator would type from inside the
# adopter tree: ../<mirror-dirname> (mirror and adopter are siblings under
# $WORKDIR).
( cd "$BP_VI_ADOPTER" && git init -q && git remote add fw "../$(basename "$BP_VI_MIRROR")" )
# shellcheck disable=SC2329
run_relpath_assertion_from_elsewhere() {
  # Invoke from a directory that is neither the mirror nor the adopter tree,
  # to prove the check does not depend on the script's own CWD.
  local mirror="$1" adopter="$2"
  ( cd "$WORKDIR" && EXPORT_FRAMEWORK_SOURCED=1 bash -c "
      source '$mirror/mddocs/scripts/export-framework.sh' --target '$adopter'
      assert_remote_severance '$adopter'
    " )
}
expect_exit "(vi) relative-path local remote, invoked from unrelated CWD -> assertion aborts" 5 -- run_relpath_assertion_from_elsewhere "$BP_VI_MIRROR" "$BP_VI_ADOPTER"

# (vii) pushurl distinct from fetch url. Fetch URL is benign (customer); only
# the PUSH URL is redirected to the framework via `git remote set-url --push`.
BP_VII="$WORKDIR/bypass_vii_pushurl"
mkdir -p "$BP_VII"
( cd "$BP_VII" && git init -q \
  && git remote add origin "https://example.com/customer/repo.git" \
  && git remote set-url --push origin "$FW_URL" )
expect_exit "(vii) pushurl redirected to framework, fetch url benign -> assertion aborts" 5 -- run_assertion_only "$BP_VII"

# (viii) branch.<name>.pushRemote positive case (a real branch pushRemote
# pointing at a framework-resolving remote name — Group 3's test (iv) only
# exercises remote.pushDefault; this exercises the per-branch override).
BP_VIII="$WORKDIR/bypass_viii_branchpush"
mkdir -p "$BP_VIII"
( cd "$BP_VIII" && git init -q && git commit --allow-empty -q -m seed \
  && git remote add fw "$FW_URL" \
  && git remote add cust "https://example.com/customer/repo.git" \
  && git config branch."$(git symbolic-ref --short HEAD)".pushRemote fw )
expect_exit "(viii) branch.<name>.pushRemote resolves to framework -> assertion aborts" 5 -- run_assertion_only "$BP_VIII"

# (ix) git:// protocol form.
BP_IX="$WORKDIR/bypass_ix_gitproto"
mkdir -p "$BP_IX"
( cd "$BP_IX" && git init -q && git remote add sneaky "$FW_GIT_PROTO" )
expect_exit "(ix) git:// protocol form survives severance -> assertion aborts" 5 -- run_assertion_only "$BP_IX"

# (x) userinfo/token-in-URL form (user:token@host).
BP_X="$WORKDIR/bypass_x_userinfo"
mkdir -p "$BP_X"
( cd "$BP_X" && git init -q && git remote add sneaky "$FW_USERINFO_URL" )
expect_exit "(x) userinfo/token-in-URL form survives severance -> assertion aborts" 5 -- run_assertion_only "$BP_X"

# (xi) SF-073 — bare-HOST-only insteadOf rewrite must NOT be flagged. A
# customer hosting their own repos on the SAME git host as the framework
# may legitimately configure a host-level convenience rewrite unrelated to
# the framework (e.g. a short-URL alias for their own org). The effective
# target of such a rewrite normalizes to the bare host with no org/group
# segment — this must PASS severance (not be falsely flagged/severed).
BP_XI="$WORKDIR/nobypass_xi_barehost_insteadof"
mkdir -p "$BP_XI"
( cd "$BP_XI" && git init -q && git config url."https://${FW_HOST}/".insteadOf "custom-host:" )
expect_exit "(xi) SF-073 bare-host-only insteadOf (customer same-host convenience rewrite) -> NOT flagged, passes" 0 -- run_assertion_only "$BP_XI"

# (xii) SF-073 negative control / no-weakening proof — an insteadOf rewrite
# that reaches at least the framework's HOST *and* ORG/GROUP segment
# (host/org, no repo needed) must STILL abort. This proves SF-073 only
# excluded the bare-host case, not genuine framework-org-covering rewrites.
BP_XII="$WORKDIR/bypass_xii_orgreach_insteadof"
mkdir -p "$BP_XII"
( cd "$BP_XII" && git init -q && git config url."https://${FW_HOST}/${FW_ORG}/".insteadOf "custom-org:" )
expect_exit "(xii) SF-073 host+org-reaching insteadOf still survives severance -> assertion aborts" 5 -- run_assertion_only "$BP_XII"

# ---------------------------------------------------------------------------
# Group 4 — Allowlist correctness: customer remote preserved
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 4: allowlist correctness (customer remote preserved, framework severed) --"
ALLOW_DIR="$WORKDIR/allowlist"
mkdir -p "$ALLOW_DIR"
( cd "$ALLOW_DIR" && git init -q && echo c > c.txt && git add c.txt && git commit -q -m "customer commit" \
  && git remote add origin "https://example.com/customer-org/customer-repo.git" \
  && git remote add framework-tmp "$FW_URL" )

bash "$EXPORT_SCRIPT" --target "$ALLOW_DIR" --slug ACME --yes > "$WORKDIR/allowlist.out" 2>&1
rc=$?
remaining_remotes="$(git -C "$ALLOW_DIR" remote 2>/dev/null || true)"
if [ "$rc" -eq 0 ] \
   && [ "$remaining_remotes" = "origin" ] \
   && [ "$(git -C "$ALLOW_DIR" remote get-url origin 2>/dev/null)" = "https://example.com/customer-org/customer-repo.git" ]; then
  pass_case "allowlist: customer 'origin' preserved, framework 'framework-tmp' severed"
else
  fail_case "allowlist: customer 'origin' preserved, framework 'framework-tmp' severed"
  sed 's/^/  /' "$WORKDIR/allowlist.out"
  echo "  remaining remotes: $remaining_remotes"
fi

# ---------------------------------------------------------------------------
# Group 5 — D-7.2 dirty-tree guard + bounded --force
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 5: D-7.2 dirty-tree guard --"
DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
( cd "$DIRTY_DIR" && git init -q && echo committed > a.txt && git add a.txt && git commit -q -m "initial" \
  && echo uncommitted >> a.txt && echo untracked > untracked.txt )

before_files="$(find "$DIRTY_DIR" -type f | sort)"
before_log="$(git -C "$DIRTY_DIR" log --oneline)"

expect_exit "dirty tree, no --force -> aborts (D-7.2)" 4 -- bash "$EXPORT_SCRIPT" --target "$DIRTY_DIR" --slug ACME --yes

after_files="$(find "$DIRTY_DIR" -type f | sort)"
after_log="$(git -C "$DIRTY_DIR" log --oneline)"
if [ "$before_files" = "$after_files" ] && [ "$before_log" = "$after_log" ]; then
  pass_case "dirty tree, no --force -> zero changes made"
else
  fail_case "dirty tree, no --force -> zero changes made"
fi

bash "$EXPORT_SCRIPT" --target "$DIRTY_DIR" --slug ACME --force --yes > "$WORKDIR/force.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'proceeding because --force was given' "$WORKDIR/force.out"; then
  pass_case "dirty tree with --force -> proceeds with warning"
else
  fail_case "dirty tree with --force -> proceeds with warning"
  sed 's/^/  /' "$WORKDIR/force.out"
fi

# ---------------------------------------------------------------------------
# Group 6 — --dry-run zero side effects
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 6: --dry-run zero side effects --"
DRY_EMPTY="$WORKDIR/dry_empty"
bash "$EXPORT_SCRIPT" --target "$DRY_EMPTY" --slug ACME --dry-run > "$WORKDIR/dry_empty.out" 2>&1
if [ ! -e "$DRY_EMPTY" ]; then
  pass_case "dry-run on empty target (Flow A) -> target not created"
else
  fail_case "dry-run on empty target (Flow A) -> target not created"
fi

DRY_CUST="$WORKDIR/dry_customer"
mkdir -p "$DRY_CUST"
( cd "$DRY_CUST" && git init -q && echo c > c.txt && git add c.txt && git commit -q -m "customer commit" )
before_files="$(find "$DRY_CUST" -type f | sort)"
before_status="$(git -C "$DRY_CUST" status --porcelain)"
bash "$EXPORT_SCRIPT" --target "$DRY_CUST" --slug ACME --dry-run > "$WORKDIR/dry_customer.out" 2>&1
after_files="$(find "$DRY_CUST" -type f | sort)"
after_status="$(git -C "$DRY_CUST" status --porcelain)"
if [ "$before_files" = "$after_files" ] && [ "$before_status" = "$after_status" ]; then
  pass_case "dry-run on clean customer tree (Flow B) -> zero side effects"
else
  fail_case "dry-run on clean customer tree (Flow B) -> zero side effects"
fi

# ---------------------------------------------------------------------------
# Group 7 — D-7.6 target-identity guard
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 7: D-7.6 target-identity guard --"
expect_exit "target IS the framework repo -> aborts (D-7.6)" 3 -- bash "$EXPORT_SCRIPT" --target "$FRAMEWORK_ROOT" --slug ACME --yes
expect_exit "target nested inside framework repo -> aborts (D-7.6)" 3 -- bash "$EXPORT_SCRIPT" --target "$FRAMEWORK_ROOT/mddocs" --slug ACME --yes

# ---------------------------------------------------------------------------
# Group 8 — D-7.1 flow-detection ambiguity
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 8: D-7.1 flow-detection ambiguity --"
AMBIG_DIR="$WORKDIR/ambiguous"
mkdir -p "$AMBIG_DIR"
echo "not a git repo" > "$AMBIG_DIR/file.txt"
expect_exit "non-empty non-git target, no --flow -> ambiguous, aborts" 2 -- bash "$EXPORT_SCRIPT" --target "$AMBIG_DIR" --slug ACME --yes

bash "$EXPORT_SCRIPT" --target "$AMBIG_DIR" --flow empty --slug ACME --yes > "$WORKDIR/ambig_explicit.out" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && [ -f "$AMBIG_DIR/framework-version.txt" ]; then
  pass_case "explicit --flow empty overrides ambiguity -> succeeds"
else
  fail_case "explicit --flow empty overrides ambiguity -> succeeds"
  sed 's/^/  /' "$WORKDIR/ambig_explicit.out"
fi

# ---------------------------------------------------------------------------
# Group 9 — TC-051 Flow B reconciliation: manifest-scoped staging + report
#
# Proves the blind `git add -A` this ticket replaced is actually gone:
# pre-existing customer content in the target must NOT be staged into the
# framework re-home commit, must be listed in a report-only provenance
# file, and .gitignore must never be auto-written. Also proves --dry-run
# still guarantees zero side effects with the new classification-preview
# logic added to that path.
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 9: TC-051 Flow B reconciliation (manifest-scoped staging + report) --"

RECON_DIR="$WORKDIR/reconcile"
mkdir -p "$RECON_DIR/custdir"
( cd "$RECON_DIR" && git init -q \
  && echo "customer tracked content" > custdir/tracked.txt \
  && git add -A && git commit -q -m "customer initial commit" \
  && echo "customer loose content" > "loose customer file.txt" \
  && mkdir -p node_modules && echo "dep" > node_modules/dep.js )

RECON_GITIGNORE_BEFORE="$(cat "$RECON_DIR/.gitignore" 2>/dev/null || true)"

bash "$EXPORT_SCRIPT" --target "$RECON_DIR" --slug ACME --force --yes > "$WORKDIR/reconcile.out" 2>&1
recon_rc=$?

REPORT_FILE="$RECON_DIR/.framework-rehome-report.txt"

# (9a) script succeeds and the report file exists
if [ "$recon_rc" -eq 0 ] && [ -f "$REPORT_FILE" ]; then
  pass_case "TC-051 (9a): script succeeds, reconciliation report file created"
else
  fail_case "TC-051 (9a): script succeeds, reconciliation report file created"
  sed 's/^/  /' "$WORKDIR/reconcile.out"
fi

# (9b) pre-existing customer file is NOT staged/committed into the
# framework re-home commit — still untracked after the script runs.
customer_status="$(git -C "$RECON_DIR" status --porcelain -- "loose customer file.txt" node_modules/dep.js 2>/dev/null || true)"
if printf '%s\n' "$customer_status" | grep -q '^?? "loose customer file.txt"$' \
   && printf '%s\n' "$customer_status" | grep -q '^?? node_modules/dep.js$'; then
  pass_case "TC-051 (9b): pre-existing customer files remain untracked, not staged into re-home commit"
else
  fail_case "TC-051 (9b): pre-existing customer files remain untracked, not staged into re-home commit"
  echo "  status: $customer_status"
fi

# (9c) the re-home commit itself does not contain the customer paths
commit_files="$(git -C "$RECON_DIR" show --name-only --pretty=format: HEAD 2>/dev/null || true)"
if ! printf '%s\n' "$commit_files" | grep -qx "loose customer file.txt" \
   && ! printf '%s\n' "$commit_files" | grep -qx "node_modules/dep.js"; then
  pass_case "TC-051 (9c): framework re-home commit does not contain customer paths"
else
  fail_case "TC-051 (9c): framework re-home commit does not contain customer paths"
fi

# (9d) framework content IS staged/committed (the commit is not empty of
# framework files — pick a file guaranteed to be part of every export).
if printf '%s\n' "$commit_files" | grep -qx "framework-version.txt"; then
  pass_case "TC-051 (9d): framework files ARE staged into the re-home commit"
else
  fail_case "TC-051 (9d): framework files ARE staged into the re-home commit"
  echo "  commit files (first 10): $(printf '%s\n' "$commit_files" | head -10)"
fi

# (9e) the reconciliation report lists the customer paths that were left
# untracked, by name.
if grep -qF "loose customer file.txt" "$REPORT_FILE" 2>/dev/null \
   && grep -qF "node_modules/dep.js" "$REPORT_FILE" 2>/dev/null; then
  pass_case "TC-051 (9e): reconciliation report lists pre-existing customer paths"
else
  fail_case "TC-051 (9e): reconciliation report lists pre-existing customer paths"
  sed 's/^/  /' "$REPORT_FILE" 2>/dev/null || echo "  (report file missing)"
fi

# (9f) .gitignore is not auto-modified by the script: it should be
# EXACTLY the framework's own .gitignore (the overlay legitimately writes
# the framework's .gitignore over the target's, same as any other
# manifest path — the assertion here is that no CUSTOMER-specific entry
# was appended to it as a side effect of reconciliation).
recon_gitignore_after="$(cat "$RECON_DIR/.gitignore" 2>/dev/null || true)"
framework_gitignore="$(cat "$FRAMEWORK_ROOT/.gitignore" 2>/dev/null || true)"
if [ "$recon_gitignore_after" = "$framework_gitignore" ] \
   && ! printf '%s\n' "$recon_gitignore_after" | grep -q "loose customer file"; then
  pass_case "TC-051 (9f): .gitignore not auto-modified with customer-specific entries"
else
  fail_case "TC-051 (9f): .gitignore not auto-modified with customer-specific entries"
fi
# Negative control: confirm the customer tree had NO .gitignore before
# this run, so (9f)'s "unchanged" comparison is meaningful (not vacuously
# true because both sides were already identical by coincidence).
if [ -z "$RECON_GITIGNORE_BEFORE" ]; then
  pass_case "TC-051 (9f-control): customer tree had no pre-existing .gitignore (comparison baseline is meaningful)"
else
  fail_case "TC-051 (9f-control): customer tree had no pre-existing .gitignore (comparison baseline is meaningful)"
fi

# (9g) --dry-run on a customer tree with pre-existing untracked content
# writes nothing (no report file, no staging, no commit) but still
# reports the classification preview to stdout.
RECON_DRY_DIR="$WORKDIR/reconcile_dryrun"
mkdir -p "$RECON_DRY_DIR/custdir"
( cd "$RECON_DRY_DIR" && git init -q \
  && echo "customer tracked content" > custdir/tracked.txt \
  && git add -A && git commit -q -m "customer initial commit" \
  && echo "customer loose content" > loose_customer.txt )

before_dry_files="$(find "$RECON_DRY_DIR" -type f | sort)"
before_dry_log="$(git -C "$RECON_DRY_DIR" log --oneline)"

bash "$EXPORT_SCRIPT" --target "$RECON_DRY_DIR" --slug ACME --dry-run --force > "$WORKDIR/reconcile_dryrun.out" 2>&1
dry_recon_rc=$?

after_dry_files="$(find "$RECON_DRY_DIR" -type f | sort)"
after_dry_log="$(git -C "$RECON_DRY_DIR" log --oneline)"

if [ "$dry_recon_rc" -eq 0 ] \
   && [ "$before_dry_files" = "$after_dry_files" ] \
   && [ "$before_dry_log" = "$after_dry_log" ] \
   && [ ! -f "$RECON_DRY_DIR/.framework-rehome-report.txt" ]; then
  pass_case "TC-051 (9g): --dry-run writes no report file, stages nothing, creates no commit"
else
  fail_case "TC-051 (9g): --dry-run writes no report file, stages nothing, creates no commit"
  sed 's/^/  /' "$WORKDIR/reconcile_dryrun.out"
fi

# (9h) --dry-run's classification preview still reports the framework vs.
# customer counts to stdout, even though nothing is written to disk.
if grep -q "classification preview:.*framework path" "$WORKDIR/reconcile_dryrun.out" \
   && grep -q "classification preview:.*customer path" "$WORKDIR/reconcile_dryrun.out" \
   && grep -q "loose_customer.txt" "$WORKDIR/reconcile_dryrun.out"; then
  pass_case "TC-051 (9h): --dry-run reports classification preview (framework/customer counts + paths) to stdout"
else
  fail_case "TC-051 (9h): --dry-run reports classification preview (framework/customer counts + paths) to stdout"
  sed 's/^/  /' "$WORKDIR/reconcile_dryrun.out"
fi

# (9i) RF-012 — `git add -f` overrides a pre-existing customer .gitignore
# rule that WOULD match a framework-manifest path. Proves the exact
# guarantee do_flow_rehome's `-f` rationale comment cites: the framework
# manifest is the authority on what is framework content, not the
# customer's pre-existing ignore rules. Negative control included so this
# is not a vacuous assertion (WITHOUT -f, git refuses to stage an ignored
# path at all).
GITIGNORE_OVERRIDE_DIR="$WORKDIR/gitignore_override"
mkdir -p "$GITIGNORE_OVERRIDE_DIR"
( cd "$GITIGNORE_OVERRIDE_DIR" && git init -q \
  && printf '*.txt\n' > .gitignore \
  && echo "seed" > tracked_seed.txt \
  && git add -f .gitignore tracked_seed.txt && git commit -q -m "customer initial commit with broad *.txt gitignore rule" )

# Negative control: without -f, git itself refuses to stage a path this
# .gitignore rule matches — proves the rule really would have blocked
# framework-version.txt (a .txt file) absent the -f override.
gitignore_control_rc=0
( cd "$GITIGNORE_OVERRIDE_DIR" && touch would-be-blocked.txt \
  && git add would-be-blocked.txt ) > "$WORKDIR/gitignore_control.out" 2>&1 || gitignore_control_rc=$?
rm -f "$GITIGNORE_OVERRIDE_DIR/would-be-blocked.txt"
if [ "$gitignore_control_rc" -ne 0 ] && grep -q "ignored by one of your .gitignore files" "$WORKDIR/gitignore_control.out"; then
  pass_case "TC-051 (9i-control): customer's *.txt gitignore rule genuinely blocks staging without -f"
else
  fail_case "TC-051 (9i-control): customer's *.txt gitignore rule genuinely blocks staging without -f"
  sed 's/^/  /' "$WORKDIR/gitignore_control.out"
fi

bash "$EXPORT_SCRIPT" --target "$GITIGNORE_OVERRIDE_DIR" --slug ACME --yes > "$WORKDIR/gitignore_override.out" 2>&1
gitignore_override_rc=$?
gitignore_override_commit_files="$(git -C "$GITIGNORE_OVERRIDE_DIR" show --name-only --pretty=format: HEAD 2>/dev/null || true)"
if [ "$gitignore_override_rc" -eq 0 ] \
   && printf '%s\n' "$gitignore_override_commit_files" | grep -qx "framework-version.txt"; then
  pass_case "TC-051 (9i): git add -f stages a framework path despite a matching customer .gitignore rule"
else
  fail_case "TC-051 (9i): git add -f stages a framework path despite a matching customer .gitignore rule"
  sed 's/^/  /' "$WORKDIR/gitignore_override.out"
fi

# (9j) RF-013 — a framework-manifest path CONTAINING A SPACE stages
# correctly through the NUL-delimited `git add --pathspec-from-file
# --pathspec-file-nul` mechanism write_framework_manifest's header comment
# claims. Exercised directly against write_framework_manifest and the
# actual staging command (not the real framework tree — injecting a
# spaced file into $FRAMEWORK_ROOT itself is out of scope for a test
# fixture and would pollute the framework checkout under test; a
# synthetic scratch tree exercises the identical code path
# write_framework_manifest / git add --pathspec-from-file --pathspec-file-nul
# run against in the real Flow B path, so this is a direct proof, not a
# weaker proxy).
SPACE_SCRATCH="$WORKDIR/space_scratch"
SPACE_TARGET="$WORKDIR/space_target"
mkdir -p "$SPACE_SCRATCH/sub dir"
echo "content" > "$SPACE_SCRATCH/sub dir/file with spaces.txt"
mkdir -p "$SPACE_TARGET"
( cd "$SPACE_TARGET" && git init -q && echo "seed" > seed.txt && git add -A && git commit -q -m "seed" )

SPACE_MANIFEST="$WORKDIR/space_manifest.nul"
space_rc=0
( EXPORT_FRAMEWORK_SOURCED=1 bash -c "
    source '$EXPORT_SCRIPT' --target '$SPACE_TARGET'
    write_framework_manifest '$SPACE_SCRATCH' '$SPACE_MANIFEST'
    mkdir -p '$SPACE_TARGET/sub dir'
    cp '$SPACE_SCRATCH/sub dir/file with spaces.txt' '$SPACE_TARGET/sub dir/file with spaces.txt'
    git -C '$SPACE_TARGET' add -f --pathspec-from-file='$SPACE_MANIFEST' --pathspec-file-nul --
  " ) > "$WORKDIR/space_test.out" 2>&1 || space_rc=$?

space_status="$(git -C "$SPACE_TARGET" status --porcelain 2>/dev/null || true)"
if [ "$space_rc" -eq 0 ] \
   && printf '%s\n' "$space_status" | grep -qF 'A  "sub dir/file with spaces.txt"'; then
  pass_case "TC-051 (9j): framework-manifest path containing a space stages via NUL pathspec"
else
  fail_case "TC-051 (9j): framework-manifest path containing a space stages via NUL pathspec"
  sed 's/^/  /' "$WORKDIR/space_test.out"
  echo "  status: $space_status"
fi

# ---------------------------------------------------------------------------
# Group 10 — SF-125 confidentiality assertion: exported target must be free
# of framework operational-state markers (ticket IDs, finding IDs, reviewer-
# run IDs, framework identity strings). This is the assertion that WOULD
# have caught SF-123 (bench-registry.yaml leaking framework AP-*/SF-*/RF-*
# ticket and finding IDs into the adopter tree) had it existed before that
# finding was filed. SF-127 extended the scope to mddocs/backlog.md (the
# human-readable mirror of tasks.yaml — same leak class).
#
# Deliberately SCOPED, not a blind whole-tree grep: mddocs/adr and other
# shipped reference docs LEGITIMATELY mention ADR numbers, historical
# rationale, and even example ticket IDs in prose (D-4/D-6 — ADRs are
# reference material that ships with every export). A whole-tree grep for
# `TC-0`/`SF-0`/`RF-0` would false-positive on those files immediately.
# Instead this scopes to exactly the files that MUST be adopter-clean
# per FRAMEWORK_EXCLUDE_PATTERNS/SEED_RELATIVE_PATHS: tasks.yaml, .security/,
# .reviews/, bench-registry.yaml, .core/agents/_context.md,
# mddocs/backlog.md — plus a direct existence check that .bench/,
# relay-pending.md, and .core/work/ never reached the adopter working tree at
# all (SF-124).
#
# Reuses FLOWA_DIR (Group 1, Flow A) and CUST_DIR (Group 2, Flow B) — both
# already-completed successful exports still on disk in $WORKDIR — rather
# than re-running the script, since this group only needs to inspect their
# resulting trees.
# ---------------------------------------------------------------------------
echo ""
echo "-- Group 10: SF-125 confidentiality assertion (adopter-clean scope) --"

# ---------------------------------------------------------------------------
# SF-128 — Source FRAMEWORK_EXCLUDE_PATTERNS and SEED_RELATIVE_PATHS
# directly from export-framework.sh rather than re-hardcoding them here.
#
# Prior to this hardening, Group 10's confidentiality assertion carried its
# OWN hardcoded `scoped_files` list — a second, hand-maintained mirror of
# the authoritative arrays already living in export-framework.sh. That is
# exactly the failure mode that let SF-123 and SF-127 originate: a file was
# added to the real exclude/seed machinery, but the separate test-side list
# was not updated in lockstep (nothing forces the two edits to travel
# together), so the new leak-class file shipped uncaught until a human
# reviewer happened to notice it in a later pass.
#
# read_export_array <array-name> sources export-framework.sh (guarded by
# EXPORT_FRAMEWORK_SOURCED=1, the same idiom run_assertion_only above already
# uses) in an isolated subshell and prints the named array's elements
# NUL-delimited. A throwaway, nonexistent --target satisfies the sourcing
# script's arg-parse path only — EXPORT_FRAMEWORK_SOURCED=1 skips the
# guarded main block entirely, so this placeholder path is never touched,
# read, or written.
# ---------------------------------------------------------------------------
read_export_array() {
  local array_name="$1"
  EXPORT_FRAMEWORK_SOURCED=1 bash -c "
    source '$EXPORT_SCRIPT' --target /nonexistent-sf128-probe
    printf '%s\0' \"\${${array_name}[@]}\"
  "
}

SOURCED_SEED_RELATIVE_PATHS=()
while IFS= read -r -d '' _p; do
  SOURCED_SEED_RELATIVE_PATHS+=("$_p")
done < <(read_export_array SEED_RELATIVE_PATHS)

SOURCED_FRAMEWORK_EXCLUDE_PATTERNS=()
while IFS= read -r -d '' _p; do
  SOURCED_FRAMEWORK_EXCLUDE_PATTERNS+=("$_p")
done < <(read_export_array FRAMEWORK_EXCLUDE_PATTERNS)
unset _p

# SF-128 sanity guard — if the sourcing plumbing above silently degrades
# (a future refactor of export-framework.sh renames these arrays, changes
# how they're declared, or otherwise breaks sourcing), Group 10 would
# quietly become vacuous — looping over nothing and passing trivially.
# Fail the whole harness loudly instead of passing silently.
if [ "${#SOURCED_SEED_RELATIVE_PATHS[@]}" -eq 0 ] || [ "${#SOURCED_FRAMEWORK_EXCLUDE_PATTERNS[@]}" -eq 0 ]; then
  echo "FATAL: SF-128 sourced-array plumbing returned an empty array from export-framework.sh — Group 10 would be vacuous. Aborting harness." >&2
  exit 1
fi

# SOURCED_EXCLUDE_ONLY_PATTERNS — set difference: entries present in
# FRAMEWORK_EXCLUDE_PATTERNS but NOT also (exactly, or as a directory
# ancestor of) an entry in SEED_RELATIVE_PATHS. These are excluded from the
# adopter export with NO adopter-generic replacement seeded in their
# place, so — unlike the seeded set, which is present but must be
# adopter-clean CONTENT — an exclude-only entry must be completely ABSENT
# from the exported tree.
#
# Directory-ancestor match (not exact-only) is required because some
# exclude entries are DIRECTORIES that are excluded wholesale but only
# PARTIALLY reconstructed by seeding — e.g. ".security" (the directory) is
# in FRAMEWORK_EXCLUDE_PATTERNS, while SEED_RELATIVE_PATHS seeds two files
# underneath it individually (".security/findings.yaml",
# ".security/reviewer-log.yaml"). An exact-match-only comparison would
# wrongly classify ".security" itself as exclude-only (nothing in
# SEED_RELATIVE_PATHS equals the literal string ".security"), which would
# then make the absence check below FALSE-FAIL on every real export (the
# directory legitimately exists post-seed, holding the two seeded files).
#
# ".git" is deliberately excluded from this derived set even though it IS
# in FRAMEWORK_EXCLUDE_PATTERNS (the framework's own .git must never be
# tar'd into the adopter tree): export-framework.sh recreates ".git" fresh
# via `git init` in both flows, so its post-export PRESENCE is expected and
# correct — it is verified by the D-7.5 history/refs/object scrub
# (assert_no_framework_history), not by an absence check here.
SOURCED_EXCLUDE_ONLY_PATTERNS=()
for _p in "${SOURCED_FRAMEWORK_EXCLUDE_PATTERNS[@]}"; do
  [ "$_p" = ".git" ] && continue
  _found=0
  for _s in "${SOURCED_SEED_RELATIVE_PATHS[@]}"; do
    if [ "$_p" = "$_s" ] || [ "${_s#"$_p"/}" != "$_s" ]; then
      _found=1
      break
    fi
  done
  [ "$_found" -eq 0 ] && SOURCED_EXCLUDE_ONLY_PATTERNS+=("$_p")
done
unset _p _s _found

echo "  SF-128 sourced from export-framework.sh:"
echo "    SEED_RELATIVE_PATHS (${#SOURCED_SEED_RELATIVE_PATHS[@]}): ${SOURCED_SEED_RELATIVE_PATHS[*]}"
echo "    exclude-only, no-seed, must-be-absent (${#SOURCED_EXCLUDE_ONLY_PATTERNS[@]}): ${SOURCED_EXCLUDE_ONLY_PATTERNS[*]}"

# assert_adopter_confidentiality <target_dir> <flow_label>
# Greps every SOURCED_SEED_RELATIVE_PATHS file for framework-identity
# markers, and checks every SOURCED_EXCLUDE_ONLY_PATTERNS entry is entirely
# absent. Both lists are sourced from export-framework.sh itself (above),
# not re-hardcoded here — see the SF-128 block above for why. Prints every
# offending marker/file or presence violation it finds; returns 0 only if
# none are found.
assert_adopter_confidentiality() {
  local target="$1" label="$2"
  local -a offenders=()

  # Marker patterns that indicate framework-internal identity/ticket/finding
  # state leaked through, rather than adopter-generic seed content.
  local -a markers=(
    'AP-[0-9]'
    'SF-[0-9]'
    'RF-[0-9]'
    'SR-[0-9]'
    'RR-[0-9]'
    'AgenticCore'
    'baseline-steward'
  )

  # SF-128 — iterate SOURCED_SEED_RELATIVE_PATHS (sourced directly from
  # export-framework.sh's SEED_RELATIVE_PATHS above), not a second
  # hardcoded list. Every seeded path is, by construction, exactly the set
  # of files that MUST be adopter-clean (excluded from the raw copy,
  # replaced with adopter-generic seed content) — a future addition to
  # SEED_RELATIVE_PATHS in export-framework.sh is picked up here with zero
  # additional edits to this test file.
  local f m hit
  for f in "${SOURCED_SEED_RELATIVE_PATHS[@]}"; do
    [ -f "$target/$f" ] || continue
    for m in "${markers[@]}"; do
      hit="$(grep -nE "$m" "$target/$f" 2>/dev/null || true)"
      if [ -n "$hit" ]; then
        offenders+=("$f matches /$m/: $(printf '%s' "$hit" | head -1)")
      fi
    done
  done

  # bench-registry.yaml specific: no torn_down history ENTRIES (an actual
  # `status: torn_down` field value) should survive into an adopter seed —
  # a torn_down entry is exactly where the real file's commit-SHA/finding-ID
  # teardown narrative lives (SF-123). Matches the field value specifically
  # (not a bare substring match), since the seed template's own explanatory
  # comment text legitimately contains the word "torn_down" in prose (e.g.
  # "never delete a torn_down entry") without that being a leaked entry.
  if [ -f "$target/bench-registry.yaml" ] && grep -qE '^\s*status:\s*torn_down\b' "$target/bench-registry.yaml" 2>/dev/null; then
    offenders+=("bench-registry.yaml contains a 'status: torn_down' entry (framework bench history survived)")
  fi

  # SF-124/SF-128 — every FRAMEWORK_EXCLUDE_PATTERNS entry with NO seeded
  # replacement (SOURCED_EXCLUDE_ONLY_PATTERNS, derived above) must be
  # completely ABSENT from the exported tree — not just marker-free. This
  # generalizes the original SF-124 .bench/relay-pending.md existence
  # checks: those two are now covered BY DERIVATION (they are exclude-only
  # entries with no seed), and any FUTURE exclude-only addition to
  # FRAMEWORK_EXCLUDE_PATTERNS is covered automatically too, without a
  # matching hand-written existence check ever needing to be added here.
  local ep
  for ep in "${SOURCED_EXCLUDE_ONLY_PATTERNS[@]}"; do
    if [ -e "$target/$ep" ]; then
      offenders+=("$ep present in adopter tree (exclude-only pattern with no seed — must be absent)")
    fi
  done

  if [ "${#offenders[@]}" -gt 0 ]; then
    echo "  CONFIDENTIALITY FAILURE ($label):"
    local o
    for o in "${offenders[@]}"; do
      echo "    - $o"
    done
    return 1
  fi
  return 0
}

# (10a) Flow A export (Group 1's FLOWA_DIR) is adopter-clean.
if [ -d "$FLOWA_DIR" ] && assert_adopter_confidentiality "$FLOWA_DIR" "Flow A"; then
  pass_case "SF-125 (10a): Flow A export contains no framework-identity/ticket/finding markers in scoped files"
else
  fail_case "SF-125 (10a): Flow A export contains no framework-identity/ticket/finding markers in scoped files"
fi

# (10b) Flow B export (Group 2's CUST_DIR) is adopter-clean.
if [ -d "$CUST_DIR" ] && assert_adopter_confidentiality "$CUST_DIR" "Flow B"; then
  pass_case "SF-125 (10b): Flow B export contains no framework-identity/ticket/finding markers in scoped files"
else
  fail_case "SF-125 (10b): Flow B export contains no framework-identity/ticket/finding markers in scoped files"
fi

# (10c) Negative control — proves (10a)/(10b) are not vacuously passing
# because the check itself is broken. Run the SAME assertion directly
# against the framework's OWN bench-registry.yaml (never exported to an
# adopter — this is the real, unseeded file this ticket is protecting
# against), which is known to carry AP-*/SF-*/RF-* markers and torn_down
# entries. The assertion MUST fail here, proving it actually detects the
# leak class SF-123 described instead of trivially passing on anything.
NEGATIVE_DIR="$WORKDIR/confidentiality_negative_control"
mkdir -p "$NEGATIVE_DIR"
cp "$FRAMEWORK_ROOT/bench-registry.yaml" "$NEGATIVE_DIR/bench-registry.yaml"
if assert_adopter_confidentiality "$NEGATIVE_DIR" "negative control"; then
  fail_case "SF-125 (10c-control): assertion fails to catch the framework's own unseeded bench-registry.yaml (check is broken)"
else
  pass_case "SF-125 (10c-control): assertion correctly catches the framework's own unseeded bench-registry.yaml (proves check is real, not vacuous)"
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
