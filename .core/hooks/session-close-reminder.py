#!/usr/bin/env python3
"""
session-close-reminder.py — Stop hook.

Fires at the end of every agent turn. Checks all git worktrees for uncommitted
changes and emits a warning when any are found. Also checks the dotfiles bare
repo (~/.dotfiles) for uncommitted config changes when it exists. Silent when
all worktrees and dotfiles are clean.

Complements the commit-early-commit-often and end-of-focus memory write practices
documented in mddocs/operations/runbooks/session-continuity.md.
"""

import json
import os
import subprocess
import sys


def get_worktrees():
    result = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return []
    paths = []
    for line in result.stdout.splitlines():
        if line.startswith("worktree "):
            paths.append(line.split(" ", 1)[1])
    return paths


def check_dirty(wt_path):
    result = subprocess.run(
        ["git", "-C", wt_path, "status", "--short"],
        capture_output=True, text=True
    )
    return result.stdout.strip()


def check_scratch(wt_path):
    scratch = os.path.join(wt_path, "_scratch")
    if not os.path.isdir(scratch):
        return []
    try:
        return os.listdir(scratch)
    except OSError:
        return []


def check_dotfiles():
    """Check ~/.dotfiles bare repo for uncommitted changes.

    Returns the count of uncommitted changes (int), or None if ~/.dotfiles does
    not exist, the check times out, or the command fails (silently skipped in
    all such cases). File paths are never returned — only the count — to avoid
    leaking sensitive home-directory filenames into hook output.
    """
    home = os.path.expanduser("~")
    dotfiles_dir = os.path.join(home, ".dotfiles")
    if not os.path.isdir(dotfiles_dir):
        return None

    try:
        result = subprocess.run(
            [
                "git",
                f"--git-dir={dotfiles_dir}",
                f"--work-tree={home}",
                "status",
                "--short",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired:
        return None

    if result.returncode != 0:
        return None

    count = sum(1 for line in result.stdout.splitlines() if line.strip())
    return count if count > 0 else None


def main():
    try:
        json.load(sys.stdin)
    except Exception:
        pass

    worktrees = get_worktrees()

    dirty = []
    for wt in worktrees:
        status = check_dirty(wt)
        if status:
            dirty.append((wt, status))

    scratch_nonempty = []
    for wt in worktrees:
        items = check_scratch(wt)
        if items:
            scratch_nonempty.append((wt, items))

    dotfiles_count = check_dotfiles()

    if not dirty and not scratch_nonempty and not dotfiles_count:
        sys.exit(0)

    if dirty:
        print("[session-close-reminder] WARNING — uncommitted changes detected:", file=sys.stderr)
        for wt, status in dirty:
            print(f"  {wt}:", file=sys.stderr)
            for line in status.splitlines():
                print(f"    {line}", file=sys.stderr)
        print(file=sys.stderr)
        print("[session-close-reminder] Commit before switching tasks or ending the session.", file=sys.stderr)
        print("  Also: write an end-of-focus memory note (task | status | next step | open questions).", file=sys.stderr)

    if scratch_nonempty:
        print(file=sys.stderr)
        print("[session-close-reminder] WARNING — non-empty _scratch/ detected:", file=sys.stderr)
        for wt, items in scratch_nonempty:
            print(f"  {wt}/_scratch/:", file=sys.stderr)
            for item in items:
                print(f"    {item}", file=sys.stderr)
        print("[session-close-reminder] Review _scratch/ contents — delete or promote before closing.", file=sys.stderr)

    if dotfiles_count:
        print(file=sys.stderr)
        print(f"[session-close-reminder] WARNING — dotfiles repo has {dotfiles_count} uncommitted change(s) — run: dot status", file=sys.stderr)
        print("[session-close-reminder] Run: dot add <file> && dot commit -m 'chore: <description>'", file=sys.stderr)
        print("  See: mddocs/operations/runbooks/dotfiles-management.md", file=sys.stderr)

    sys.exit(0)  # informational only — never block


if __name__ == "__main__":
    main()
