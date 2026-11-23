#!/bin/sh
# validate-docs.sh - Run the mddocs documentation gates in a single pass.
#
# Operator convenience wrapper around the three mandatory docs gates:
#   1. reconcile-metadata-registry.py --check   (registry + document_type vocab conformance)
#   2. check-links.sh --summary-only            (internal links + em-dash guard)
#   3. mdbook build                             (SUMMARY nav + structure, zero warnings)
#
# PURPOSE: reduce the recall/runtime cost of remembering and running three
# separate commands. It does not change what is enforced; it only runs the
# governed gates and reports a single verdict.
#
# NOTE: This is an operator convenience artifact, NOT a governed/classified
# SH script. It carries no `.meta.yaml` and is intentionally not registered in
# the metadata registry (section 8). Adding/classifying it is out of scope here;
# it just calls the governed gates.
#
# Usage:
#   ./mddocs/scripts/validate-docs.sh
#
# Exit codes:
#   0  All gates pass
#   1  One or more gates failed

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fail=0

run() {
  label="$1"
  shift
  echo "==> ${label}"
  if "$@"; then
    echo "    ok"
  else
    echo "    FAILED"
    fail=1
  fi
}

run "metadata registry + vocabulary reconcile" \
  python3 "${REPO_ROOT}/mddocs/scripts/reconcile-metadata-registry.py" --check
run "link + em-dash check" \
  "${REPO_ROOT}/mddocs/scripts/check-links.sh" --summary-only
run "mdbook build" \
  sh -c "cd '${REPO_ROOT}/mddocs' && mdbook build"

echo
if [ "${fail}" -eq 0 ]; then
  echo "==> validate-docs: ALL GATES PASS"
else
  echo "==> validate-docs: ONE OR MORE GATES FAILED"
fi
exit "${fail}"
