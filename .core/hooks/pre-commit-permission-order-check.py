#!/usr/bin/env python3
# hook-class: git
"""
pre-commit-permission-order-check.py — git pre-commit hook.

When `opencode.json` or `opencode.json.template` is among the staged files,
verifies that the catch-all glob `"*"` is the FIRST key in every permission
object whose keys are glob patterns (e.g. `permission.bash`).

Failure mode this guards against:
  opencode evaluates permission rules with last-match-wins semantics. A catch-all
  `"*"` key that is not declared first silently overrides every more-specific rule
  declared before it — the broad rule wins because it matches last. This repo
  confirmed a live instance of that ordering bug (AP-036); this hook prevents a
  regression from reaching a commit produced by any tool or CLI.

Exit conventions:
  0 = git succeeded and reported no staged opencode config, or catch-all is
      first in every glob object.
  1 = a permission object has keys but `"*"` is not first — commit blocked; OR a
      git subprocess failed so staged state could not be determined — commit
      blocked to fail safe. The offending file / error is named on stderr.

Robustness:
  Template files may contain `${...}` substitution placeholders (e.g.
  `"${OPENCODE_MODEL}"`) that are not valid until instantiation. The permission
  block itself contains no placeholders, so before JSON parsing this hook replaces
  any `${...}` token with a neutral literal so the staged template still parses.

  This hook fails CLOSED on git errors. If `git diff --cached` cannot enumerate
  staged files, or `git show :<path>` cannot read a known-staged target's index
  content, the commit is blocked with a non-zero exit rather than silently
  allowed — a git error must not become a bypass of the ordering check. A commit
  can still be forced past a genuine tooling failure with `--no-verify`.
"""

import json
import re
import subprocess
import sys

# Files this hook inspects, relative to the repo root.
TARGET_FILES = ("opencode.json", "opencode.json.template")

# A permission object is "glob-shaped" if any of its keys look like a command
# glob (contains a wildcard or is the bare catch-all). This distinguishes
# permission objects (bash) from scalar permission entries (webfetch/websearch).
GLOB_KEY_RE = re.compile(r"[*?]")

# Substitution-placeholder pattern, e.g. ${OPENCODE_MODEL}. Replaced with a
# neutral literal so template files parse as JSON for the purpose of this check.
PLACEHOLDER_RE = re.compile(r"\$\{[^}]*\}")


class GitError(Exception):
    """Raised when a git subprocess fails so the hook must fail closed."""


def staged_files():
    """Return the list of staged file paths (added/copied/modified/renamed/type-changed).

    Raises GitError if `git diff --cached` cannot be run or exits non-zero — a git
    failure here means we cannot determine what is staged, so the caller must fail
    closed rather than assume nothing is staged. `--diff-filter=ACMRT` includes
    renames (R) and type-changes (T) so a pure rename into a target name is still
    order-checked; the index holds the new path, so `git show :<path>` still reads it.
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMRT"],
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise GitError(f"could not run `git diff --cached`: {exc}") from exc
    if result.returncode != 0:
        raise GitError(f"`git diff --cached` failed: {result.stderr.strip()}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def staged_content(path):
    """Return the staged (index) version of a file.

    Raises GitError if `git show :<path>` cannot be run or exits non-zero. Callers
    only pass paths already confirmed to be staged targets, so a failure to read the
    index content of such a file is a hard error that must fail closed.
    """
    try:
        result = subprocess.run(
            ["git", "show", f":{path}"],
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        raise GitError(f"could not run `git show :{path}`: {exc}") from exc
    if result.returncode != 0:
        raise GitError(f"`git show :{path}` failed: {result.stderr.strip()}")
    return result.stdout


def tolerant_load(text):
    """Parse JSON after neutralizing ${...} placeholders. Returns dict or None."""
    neutralized = PLACEHOLDER_RE.sub("__PLACEHOLDER__", text)
    try:
        return json.loads(neutralized)
    except (ValueError, TypeError):
        return None


def find_glob_objects(node, path):
    """
    Yield (dotted_path, dict) for every dict whose keys are glob-shaped.
    Recurses through nested dicts under the permission tree.
    """
    if not isinstance(node, dict):
        return
    keys = list(node.keys())
    if keys and any(GLOB_KEY_RE.search(k) for k in keys):
        yield path, node
    for key, value in node.items():
        if isinstance(value, dict):
            child_path = f"{path}.{key}" if path else key
            yield from find_glob_objects(value, child_path)


def check_file(path):
    """Return a list of human-readable violation strings for one file.

    `path` is already known to be a staged target, so a git failure reading its
    index content is a hard failure: it is reported as a violation (which blocks
    the commit), never silently treated as "no violations".
    """
    try:
        content = staged_content(path)
    except GitError as exc:
        return [
            f"{path}: could not read staged content ({exc}). A staged target must be "
            f"readable to be order-checked; blocking commit to fail safe."
        ]

    parsed = tolerant_load(content)
    if parsed is None:
        # Could not parse even after neutralizing placeholders. Report so a
        # malformed staged config is not silently waved through.
        return [f"{path}: staged content is not valid JSON (after placeholder substitution)"]

    permission = parsed.get("permission")
    if not isinstance(permission, dict):
        return []

    violations = []
    for obj_path, obj in find_glob_objects(permission, "permission"):
        first_key = next(iter(obj.keys()))
        if first_key != "*":
            violations.append(
                f"{path}: permission object `{obj_path}` — catch-all \"*\" is not the "
                f"first key (first key is \"{first_key}\"). Under last-match-wins, a "
                f"non-first \"*\" overrides every rule before it."
            )
    return violations


def main():
    try:
        staged = staged_files()
    except GitError as exc:
        print(
            "[permission-order-check] BLOCKED: could not determine staged files: "
            f"{exc}.",
            file=sys.stderr,
        )
        print(
            "  Blocking commit to fail safe — the ordering check could not run. "
            "Resolve the git error, or bypass with --no-verify if you understand "
            "the risk.",
            file=sys.stderr,
        )
        sys.exit(1)

    targets = [f for f in staged if f in TARGET_FILES]
    if not targets:
        sys.exit(0)

    all_violations = []
    for path in targets:
        all_violations.extend(check_file(path))

    if all_violations:
        print(
            "[permission-order-check] BLOCKED: catch-all ordering violation in staged "
            "opencode config.",
            file=sys.stderr,
        )
        for v in all_violations:
            print(f"  - {v}", file=sys.stderr)
        print(
            "  Fix: move \"*\" to the first position in the flagged permission object(s), "
            "then re-stage and commit.",
            file=sys.stderr,
        )
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
