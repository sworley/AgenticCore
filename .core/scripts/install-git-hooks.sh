#!/usr/bin/env zsh
# .core/scripts/install-git-hooks.sh
# Install the tracked git-native pre-commit checks into this repo's git hooks
# directory. Install-only — there is no check mode.
#
# The tracked pre-commit checks are chained through a single `pre-commit`
# dispatcher, each guarded by its own idempotent marker so re-running is safe
# and any pre-existing/foreign pre-commit hook is preserved:
#   1. permission-order-check (AP-035, ADR-0022) — catch-all-first ordering in
#      staged opencode config.
#   2. credential-identity-check (AP-068) — rejects commits whose author or
#      committer identity (name/email) matches a credential pattern (glpat-, …).
#
# What it does:
#   1. Resolves the correct hooks directory (worktree-safe via
#      `git rev-parse --git-path hooks`).
#   2. Copies each tracked hook into the hooks dir under a stable name.
#   3. Installs or idempotently updates a `pre-commit` dispatcher that runs both
#      checks. An existing (foreign) pre-commit hook is preserved; each check's
#      dispatch line is appended only if its marker is not already present.
#   4. Makes the installed hooks executable.
#
# Usage:
#   install-git-hooks.sh
#
# This script must be run explicitly by an authorized operator. Installing git
# hooks is a privileged, per-repo action — see ADR-0022 and Invariant #10.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve repo root and the tracked hook sources
# ---------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERMISSION_HOOK_SRC="${REPO_ROOT}/.core/hooks/pre-commit-permission-order-check.py"
IDENTITY_HOOK_SRC="${REPO_ROOT}/.core/hooks/pre-commit-credential-identity-check.py"

for src in "$PERMISSION_HOOK_SRC" "$IDENTITY_HOOK_SRC"; do
  if [[ ! -f "$src" ]]; then
    print "ERROR: hook source not found: $src" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Resolve the hooks directory — worktree-safe.
# `git rev-parse --git-path hooks` returns the git-common-dir hooks path, which
# is correct whether run from the main working tree or a linked worktree.
# ---------------------------------------------------------------------------
HOOKS_DIR="$(git rev-parse --git-path hooks)"
# --git-path may return a path relative to the current directory; make it absolute.
case "$HOOKS_DIR" in
  /*) ;;
  *)  HOOKS_DIR="$(cd "$(dirname "$HOOKS_DIR")" 2>/dev/null && pwd)/$(basename "$HOOKS_DIR")" ;;
esac

mkdir -p "$HOOKS_DIR"
PRECOMMIT="${HOOKS_DIR}/pre-commit"
INSTALLED_PERMISSION_CHECK="${HOOKS_DIR}/permission-order-check.py"
INSTALLED_IDENTITY_CHECK="${HOOKS_DIR}/credential-identity-check.py"

print "[install] repo root : ${REPO_ROOT}"
print "[install] hooks dir  : ${HOOKS_DIR}"

# ---------------------------------------------------------------------------
# Copy each tracked hook source into the hooks dir under a stable name, so the
# dispatcher pre-commit can call them without depending on the working tree path.
# ---------------------------------------------------------------------------
cp "$PERMISSION_HOOK_SRC" "$INSTALLED_PERMISSION_CHECK"
chmod +x "$INSTALLED_PERMISSION_CHECK"
print "[install] copied hook -> ${INSTALLED_PERMISSION_CHECK}"

cp "$IDENTITY_HOOK_SRC" "$INSTALLED_IDENTITY_CHECK"
chmod +x "$INSTALLED_IDENTITY_CHECK"
print "[install] copied hook -> ${INSTALLED_IDENTITY_CHECK}"

# ---------------------------------------------------------------------------
# Install or update the pre-commit dispatcher.
#   - No existing pre-commit  -> write a dispatcher that runs both checks.
#   - Existing pre-commit     -> append each check's dispatch block only if its
#                                marker is not already present (idempotent;
#                                preserves any foreign pre-commit content).
# ---------------------------------------------------------------------------
PERMISSION_MARKER="# >>> permission-order-check (AP-035) >>>"
PERMISSION_BLOCK="${PERMISSION_MARKER}
\"${INSTALLED_PERMISSION_CHECK}\" || exit \$?
# <<< permission-order-check (AP-035) <<<"

IDENTITY_MARKER="# >>> credential-identity-check (AP-068) >>>"
IDENTITY_BLOCK="${IDENTITY_MARKER}
\"${INSTALLED_IDENTITY_CHECK}\" || exit \$?
# <<< credential-identity-check (AP-068) <<<"

# Ensure the dispatcher file exists with a shell header.
if [[ ! -f "$PRECOMMIT" ]]; then
  {
    print '#!/usr/bin/env zsh'
    print 'set -euo pipefail'
    print ""
  } > "$PRECOMMIT"
  chmod +x "$PRECOMMIT"
  print "[install] created pre-commit dispatcher -> ${PRECOMMIT}"
fi

# Append each check's block idempotently, guarded by its own marker.
append_check() {
  local marker="$1" block="$2" label="$3"
  if grep -qF "$marker" "$PRECOMMIT" 2>/dev/null; then
    print "[install] pre-commit already dispatches to ${label} — no change"
  else
    {
      print ""
      print "$block"
    } >> "$PRECOMMIT"
    print "[install] appended ${label} dispatch -> ${PRECOMMIT}"
  fi
}

append_check "$PERMISSION_MARKER" "$PERMISSION_BLOCK" "permission-order-check"
append_check "$IDENTITY_MARKER" "$IDENTITY_BLOCK" "credential-identity-check"

chmod +x "$PRECOMMIT"

print "[install] done. pre-commit permission-order-check and credential-identity-check are active for this repo."
exit 0
