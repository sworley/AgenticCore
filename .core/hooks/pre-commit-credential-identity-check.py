#!/usr/bin/env python3
# hook-class: git
"""
pre-commit-credential-identity-check.py — git pre-commit hook.

Rejects any commit whose AUTHOR or COMMITTER identity (name or email) matches a
credential pattern — most importantly a Git personal access token (`glpat-`),
plus a conservative set of other well-known token/secret shapes.

Failure mode this guards against:
  A misconfigured local git `user.email` (or `user.name`) that embeds a
  credential leaks that credential into every commit's immutable author/committer
  metadata. This repo confirmed a live instance (SF-096, surfaced during AP-056):
  a `glpat-` token was carried in historical commit author-email metadata by a
  malformed `user.email`. The token was later verified dead (expired, HTTP 401),
  but commit identity metadata is immutable without a history rewrite — which
  ADR-0004 (main is append-only/merge-only) forbids. The only structural defense
  is to stop such an identity from ever reaching a commit in the first place.
  This hook is that forward-looking prevention (AP-068). It performs no history
  rewrite and honors ADR-0004.

Surface:
  A git-native pre-commit hook fires on every commit to this repo regardless of
  which tool or CLI produced it — a human at a terminal, opencode's git usage, an
  editor's git integration, or CI. That is the correct surface for a commit-time
  identity invariant, parallel to the AI toolchain PreToolUse hooks (see ADR-0022
  for the same rationale applied to the permission-order check).

Secrets hygiene (HARD REQUIREMENT):
  This hook NEVER echoes the matched credential value. The whole point is to avoid
  leaking the credential further. Error output names WHICH identity field matched
  and the credential CLASS only — never the value, never a partial substring.

Exit conventions:
  0 = neither author nor committer identity matches a credential pattern.
  1 = a credential pattern was found in author/committer name or email (commit
      blocked, redacted message on stderr); OR a git subprocess failed so the
      identity could not be determined (fail closed — a git error must not become
      a bypass). A commit can still be forced past a genuine tooling failure with
      `--no-verify`.
"""

import re
import subprocess
import sys

# ---------------------------------------------------------------------------
# Credential patterns. Kept CONSERVATIVE to avoid false positives on legitimate
# names and emails. Each entry is (compiled_regex, human_readable_class).
#
# `glpat-` is the primary target (SF-096). The remaining shapes are common,
# high-signal token prefixes with enough length/charset constraint that they do
# not collide with ordinary identity strings. We deliberately do NOT include a
# bare high-entropy heuristic here: author identity fields are short and a
# generic entropy rule would false-positive on legitimate emails/usernames.
# ---------------------------------------------------------------------------
CREDENTIAL_PATTERNS = [
    (re.compile(r"glpat-[A-Za-z0-9_-]{20,}"), "Git personal access token (glpat-)"),
    (re.compile(r"gldt-[A-Za-z0-9_-]{20,}"), "Git deploy token (gldt-)"),
    (re.compile(r"glrt-[A-Za-z0-9_-]{20,}"), "Git runner token (glrt-)"),
    (re.compile(r"ghp_[A-Za-z0-9]{36}"), "GitHub classic PAT (ghp_)"),
    (re.compile(r"gho_[A-Za-z0-9]{36}"), "GitHub OAuth token (gho_)"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{82}"), "GitHub fine-grained PAT (github_pat_)"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "Slack token (xox…-)"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key id (AKIA…)"),
    (re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"), "private key material"),
    (re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"), "JWT (eyJ…)"),
]


class GitError(Exception):
    """Raised when a git subprocess fails so the hook must fail closed."""


def git_var(name):
    """Return the value of a git identity var (e.g. GIT_AUTHOR_IDENT).

    Raises GitError if the subprocess cannot run or exits non-zero. Identity must
    be determinable to be checked; a failure here fails closed rather than allowing
    an unchecked commit.
    """
    try:
        result = subprocess.run(
            ["git", "var", name],
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise GitError(f"could not run `git var {name}`: {exc}") from exc
    if result.returncode != 0:
        raise GitError(f"`git var {name}` failed: {result.stderr.strip()}")
    return result.stdout.strip()


def scan_identity(ident):
    """Return the set of matched credential-class labels for one identity string.

    `ident` is a raw `git var` identity line of the form
    `Name <email> <unixtime> <tz>`. We scan the WHOLE line (name and email
    together) — the name field is as capable of carrying a leaked token as the
    email field. Never returns or logs the matched value, only the class labels.
    """
    matched = set()
    for pattern, label in CREDENTIAL_PATTERNS:
        if pattern.search(ident):
            matched.add(label)
    return matched


def main():
    # Map of the identity role -> the git var that reports it.
    idents = {
        "author": "GIT_AUTHOR_IDENT",
        "committer": "GIT_COMMITTER_IDENT",
    }

    try:
        resolved = {role: git_var(var) for role, var in idents.items()}
    except GitError as exc:
        print(
            "[credential-identity-check] BLOCKED: could not determine commit "
            f"identity: {exc}.",
            file=sys.stderr,
        )
        print(
            "  Blocking commit to fail safe — the identity check could not run. "
            "Resolve the git error, or bypass with --no-verify if you understand "
            "the risk.",
            file=sys.stderr,
        )
        sys.exit(1)

    # role -> sorted list of matched credential-class labels (value never stored).
    violations = {}
    for role, ident in resolved.items():
        matched = scan_identity(ident)
        if matched:
            violations[role] = sorted(matched)

    if violations:
        print(
            "[credential-identity-check] BLOCKED: commit author/committer identity "
            "matches a credential pattern — rejected.",
            file=sys.stderr,
        )
        for role in sorted(violations):
            # Redacted: report the role and credential CLASS only. Never the value.
            classes = "; ".join(violations[role])
            print(
                f"  - {role} identity (name or email) matches: {classes}",
                file=sys.stderr,
            )
        print(
            "  A credential must never be embedded in git identity metadata — commit "
            "metadata is immutable without a history rewrite (forbidden by ADR-0004).",
            file=sys.stderr,
        )
        print(
            "  Fix: correct your git user.email / user.name so it carries no token, "
            "then re-commit. See the credential-identity-guard runbook. Rotate the "
            "exposed credential if it was ever real.",
            file=sys.stderr,
        )
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
