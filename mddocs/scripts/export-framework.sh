#!/usr/bin/env bash
# export-framework.sh — Export AgenticCore release content into an
# adopter repository (ADR-0015 D-1, D-5, D-7).
#
# Implements two adoption flows:
#   Flow A (empty)  — target dir is empty/nonexistent. Copies release content,
#                      runs `git init`, produces a clean new repo (D-7.1).
#   Flow B (rehome) — target dir is an existing git repo with customer code.
#                      Overlays framework files into it and severs any
#                      framework remote/history (D-7.1).
#
# This script uses bash-only features ([[ ]], regex matching, arrays) and is
# intentionally NOT #!/bin/sh — do not attempt to run it under /bin/sh or
# dash. See ADR-0017 Convention 1 for the portability rule this follows.
#
# Usage:
#   export-framework.sh [--target `<dir>`] [--flow empty|rehome] [--slug `<SLUG>`]
#                        [--dry-run] [--force] [-y|--yes]
#
# Arguments:
#   --target `<dir>`   Target directory for the adopter repo. Optional when
#                     stdin is a TTY — the script prompts interactively with
#                     a suggested path derived from the TC-074 convention and
#                     requires explicit confirmation (y/N) before mkdir -p.
#                     Required (exit 1) in non-interactive mode (stdin not a
#                     tty). Pass -y/--yes to skip the confirmation prompt for
#                     scripted/non-interactive adoption.
#   --flow empty|rehome
#                     Explicit flow selection. Required when detection is
#                     ambiguous (D-7.1). If omitted, the script attempts to
#                     auto-detect: empty/nonexistent dir -> empty flow;
#                     existing git repo -> rehome flow.
#   --slug `<SLUG>`     Adopter project slug (D-5). Non-empty uppercase ASCII.
#                     Prompted interactively if omitted and stdin is a tty.
#   --dry-run         Report the flow, files, and config that would be
#                     touched. Zero side effects (D-7.4). Skips the mkdir
#                     confirmation prompt (confirmation is only for real runs).
#   --force           Override the Flow B dirty-tree guard ONLY (D-7.2).
#                     Does NOT weaken the D-7.3 severance assertion or the
#                     D-7.5 history-scrub verification — those are
#                     non-overridable on every invocation.
#   -y, --yes         Skip the --target confirmation prompt. Use for
#                     scripted/non-interactive adoption where --target is
#                     supplied by the caller and confirmation is not desired.
#
# Exit codes:
#   0  Success (including no-op / dry-run report)
#   1  Argument or usage error
#   2  Ambiguous flow detection — explicit --flow required
#   3  D-7.6 target-identity guard tripped (target is the framework itself
#      or a nested/parent framework worktree)
#   4  D-7.2 dirty-tree guard tripped (Flow B, target not clean, no --force)
#   5  D-7.3 remote-severance assertion failed (framework push path survives)
#   6  D-7.5 history/refs/object scrub verification failed
#   7  Slug validation failed
#
# See mddocs/adr/adr-0015-framework-distribution-adoption-model.md D-1, D-5, D-7.
# See mddocs/scripts/test-export-framework-severance.sh for the confidentiality
# assertion test harness (D-7.3 / D-7.5 proof).

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate the framework repo root (ADR-0017 Convention 1)
# SF-069 — pwd -P (physical, symlinks resolved) throughout this script's
# path-identity comparisons, so a symlinked invocation path (e.g. the
# script reached via a symlink) still canonicalizes to the same string a
# physically-reached path would produce.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# Resolved framework push targets (D-7.3 requires resolved-target comparison,
# not name-literal match). We resolve the *running* framework checkout's own
# remotes at invocation time, plus a fixed identity list of hostnames/paths
# this framework repo has been hosted under (per ADR-0015 D-7: "the project
# has been hosted as both AgenticCore and, after a Git rename,
# AgenticCore; identity is by repository, not by name string").
#
# We normalize every candidate URL (scheme, credentials, port, trailing
# slash/.git, case) to a bare "host/path" form and compare against this set.
FRAMEWORK_IDENTITY_URLS=()
if git -C "$FRAMEWORK_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r remote_name; do
    [ -z "$remote_name" ] && continue
    url="$(git -C "$FRAMEWORK_ROOT" remote get-url "$remote_name" 2>/dev/null || true)"
    [ -n "$url" ] && FRAMEWORK_IDENTITY_URLS+=("$url")
    push_url="$(git -C "$FRAMEWORK_ROOT" remote get-url --push "$remote_name" 2>/dev/null || true)"
    [ -n "$push_url" ] && FRAMEWORK_IDENTITY_URLS+=("$push_url")
  done < <(git -C "$FRAMEWORK_ROOT" remote 2>/dev/null || true)
fi

# The framework's own git-common-dir (absolute). A remote whose URL is a
# LOCAL filesystem path (not a network URL) is resolved against this so a
# `git remote add fw /path/to/AgenticCore` (or any worktree of it) is
# caught even though it never appears as one of the framework's OWN remote
# URLs above. This closes the local-clone/local-path blind spot that a
# pure URL-identity-list check misses.
FRAMEWORK_COMMON_DIR=""
if git -C "$FRAMEWORK_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  _fw_common="$(git -C "$FRAMEWORK_ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
  case "$_fw_common" in
    /*) FRAMEWORK_COMMON_DIR="$_fw_common" ;;
    *)  FRAMEWORK_COMMON_DIR="$FRAMEWORK_ROOT/$_fw_common" ;;
  esac
  # SF-069 — pwd -P (physical, symlinks resolved) so a candidate path that
  # reaches the framework through a symlinked component canonicalizes to
  # the same string as this side, and vice versa. `pwd` alone (logical)
  # would preserve symlink components and silently miss the match.
  FRAMEWORK_COMMON_DIR="$(cd "$(dirname "$FRAMEWORK_COMMON_DIR")" 2>/dev/null && pwd -P)/$(basename "$FRAMEWORK_COMMON_DIR")"
fi

# ---------------------------------------------------------------------------
# Defaults / arg parsing
# ---------------------------------------------------------------------------
TARGET=""
FLOW=""
SLUG=""
DRY_RUN=0
FORCE=0
YES=0   # TC-085: -y/--yes skips the --target confirmation prompt

usage() {
  cat >&2 << 'EOF'
Usage: export-framework.sh [--target <dir>] [--flow empty|rehome] [--slug <SLUG>]
                            [--dry-run] [--force] [-y|--yes]

  --target <dir>       Target directory for the adopter repo.
                       Prompted interactively if omitted and stdin is a TTY
                       (following TC-074's convention:
                       <workdir>/<toolset>/<host>/<group>/<project>).
                       ALWAYS confirmed before mkdir -p (skippable with -y).
  --flow empty|rehome  Explicit flow selection (required if detection is ambiguous)
  --slug <SLUG>        Adopter project slug (non-empty uppercase ASCII)
  --dry-run            Report only — zero side effects
  --force              Override the Flow B dirty-tree guard ONLY
  -y, --yes            Skip the --target confirmation prompt (non-interactive
                       / scripted adoption)

See mddocs/adr/adr-0015-framework-distribution-adoption-model.md D-7.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)  TARGET="$2";  shift 2 ;;
    --flow)    FLOW="$2";    shift 2 ;;
    --slug)    SLUG="$2";    shift 2 ;;
    --dry-run) DRY_RUN=1;    shift ;;
    --force)   FORCE=1;      shift ;;
    -y|--yes)  YES=1;        shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -n "$FLOW" ]; then
  case "$FLOW" in
    empty|rehome) ;;
    *) echo "ERROR: --flow must be one of: empty rehome" >&2; exit 1 ;;
  esac
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }

dry_note() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  fi
}

# ---------------------------------------------------------------------------
# TC-085: --target prompt / confirm decision point.
#
# prompt_for_target — interactive prompt when --target is omitted (mirrors
# prompt_for_slug's exact pattern). Fails clearly in non-interactive mode.
#
# confirm_target — echoes the resolved --target and requires explicit y/N
# before any mkdir -p runs. Called for BOTH flag-supplied and prompted values,
# so doc example values ("./my-project.01") are never silently treated as real
# adopter intent. Skippable with -y/--yes for scripted/non-interactive use.
#
# TC-074 convention for --target:
#   <workdir>/<toolset>/<host>/<group>/<project>
# e.g. ~/dev/git/git.example.com/acme-group/acme-project
# ---------------------------------------------------------------------------
prompt_for_target() {
  if [ -n "$TARGET" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    err "--target is required in non-interactive mode (stdin is not a tty)"
    exit 1
  fi
  local _suggested
  _suggested="$(pwd)/$(basename "$(pwd)").01"
  printf '\n' >&2
  printf 'No --target supplied. Where should the adopter project directory be created?\n' >&2
  printf '\n' >&2
  printf 'TC-074 convention:  <workdir>/<toolset>/<host>/<group>/<project>\n' >&2
  printf 'Example (full):     ~/dev/git/git.example.com/acme-group/my-project.01\n' >&2
  printf 'Example (minimal):  ~/dev/my-project.01\n' >&2
  printf '\n' >&2
  printf 'Suggested path:     %s\n' "$_suggested" >&2
  printf '\n' >&2
  printf 'Target directory (press Enter to accept suggestion): ' >&2
  read -r TARGET
  if [ -z "$TARGET" ]; then
    TARGET="$_suggested"
  fi
}

confirm_target() {
  printf '\n' >&2
  printf 'Target directory:   %s\n' "$TARGET" >&2
  printf '\n' >&2
  printf 'This directory will be created (mkdir -p) and populated with the\n' >&2
  printf 'framework export. Confirm? [y/N] ' >&2
  read -r _confirm
  case "$_confirm" in
    y|Y|yes|YES) return 0 ;;
    *)
      printf 'Aborted — re-run with --target <correct-path> to choose a different directory.\n' >&2
      exit 1
      ;;
  esac
}

# NOTE: prompt_for_target / confirm_target are called inside the
# EXPORT_FRAMEWORK_SOURCED guard (main block below), not here — so sourcing
# this script for function-level unit tests never triggers interactive prompts
# or side effects from the TC-085 decision point.

# ---------------------------------------------------------------------------
# URL normalization — reduce any remote URL form to a bare "host/path"
# string for resolved-target comparison (D-7.3). Handles:
#   https://[user@]host[:port]/path[.git]
#   git@host:path[.git]              (SSH shorthand)
#   ssh://[user@]host[:port]/path[.git]
# ---------------------------------------------------------------------------
normalize_url() {
  local u="$1"
  u="${u%/}"
  u="${u%.git}"
  if [[ "$u" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    # Has an explicit scheme (https://, ssh://, etc.) — strip scheme +
    # optional userinfo, then strip a port number after the host.
    u="$(printf '%s' "$u" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^@/]+@)?##')"
    u="$(printf '%s' "$u" | sed -E 's#^([^/:]+):[0-9]+/#\1/#')"
  elif [[ "$u" =~ ^[A-Za-z0-9._-]+@([A-Za-z0-9._-]+):(.+)$ ]]; then
    # SSH shorthand: git@host:path (no scheme)
    u="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

resolve_rewrite_base_effective_target() {
  # SF-067 — Resolve a url.<base>.insteadOf/pushInsteadOf BASE to its
  # effective push target by letting git's own resolution engine apply the
  # rewrite, rather than normalizing the base string in isolation. `git
  # remote get-url` only follows insteadOf/pushInsteadOf against a
  # remote's OWN stored URL when that remote already exists; it never
  # answers the question this check needs ("what does this rewrite BASE
  # itself expand into, including any further chained rewrite hop, absent
  # any live remote using it yet?"). A dormant rewrite rule — configured
  # but not yet matched by any remote URL — survives severance until an
  # operator later adds a remote whose URL happens to start with the
  # base. The assertion must catch the rule itself, not wait for that
  # remote to exist.
  #
  # We answer this by creating a throwaway scratch repo (never touches
  # repo_dir — safe to call during --dry-run), copying ONLY the url.*
  # rewrite config from repo_dir into it, adding a probe remote whose URL
  # is exactly the rewrite base, and asking git to resolve it. This lets
  # git apply prefix substitution and any further chained rewrite hop
  # exactly as it would for a real remote, with zero hand-rolled prefix
  # substitution logic to get wrong.
  local repo_dir="$1" base="$2"
  local scratch resolved
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/export-framework-rwprobe.XXXXXX")" || return 1
  # SF-074 — RETURN trap (matching do_flow_rehome's throwaway-dir cleanup
  # pattern) so the scratch dir is removed on ANY function return, not only
  # the normal fall-through path. Without this, an unexpected failure after
  # mktemp but before the end of the function (e.g. git init failing) would
  # leak the scratch dir under set -euo pipefail.
  trap 'rm -rf "$scratch"' RETURN
  git init -q "$scratch" >/dev/null 2>&1
  while IFS= read -r cfg_line; do
    [ -z "$cfg_line" ] && continue
    local k v
    k="${cfg_line%% *}"
    v="${cfg_line#* }"
    git -C "$scratch" config --add "$k" "$v" >/dev/null 2>&1
  done < <(git -C "$repo_dir" config --get-regexp 'url\..*\.(insteadof|pushinsteadof)' 2>/dev/null || true)
  git -C "$scratch" remote add __rwprobe__ "$base" >/dev/null 2>&1
  resolved="$(git -C "$scratch" remote get-url --push "__rwprobe__" 2>/dev/null || true)"
  printf '%s' "$resolved"
}

rewrite_target_covers_framework() {
  # SF-067 — A rewrite BASE's effective resolved target is, by definition,
  # only ever a PARTIAL host/path fragment when the rule is prefix-form
  # (the whole point of insteadOf prefix substitution is that a suffix is
  # appended after substitution — see resolve_rewrite_base_effective_target).
  # Testing that fragment with url_resolves_to_framework (which requires an
  # EXACT full-identity match) always misses a dormant prefix-form rule,
  # because there is no live remote yet to supply the suffix that would
  # complete an exact match. The correct question for a rewrite target is:
  # "would ANY remote whose URL starts with this base land inside the
  # framework?" — i.e. is the effective target equal to, or a
  # path-segment-bounded PREFIX of, a framework identity URL.
  #
  # Path-segment-bounded: comparison is done on '/'-delimited segments
  # after normalize_url, so "host/dev-user-lab" (missing the 's') does NOT
  # falsely match "host/example-group/...".
  #
  # SF-073 — the prefix branch additionally requires the effective target
  # to span at least the framework's HOST *and* ORG/GROUP segment
  # (>= 2 path segments, e.g. "host/org") — a BARE HOST alone (1 segment,
  # just "host") is no longer sufficient to flag. Rationale: the framework
  # is hosted on a shared enterprise git host
  # (git.example.com/example-group/AgenticCore); an
  # adopter who hosts their OWN repos on that same shared host and
  # configures an unrelated, legitimate host-level convenience rewrite
  # (e.g. `url."https://<shared-host>/".insteadOf "gl:"` for their own
  # short-URL convenience) has an effective target that normalizes to the
  # bare host — which, under the pre-SF-073 logic, was a "/"-bounded prefix
  # of the framework identity and was falsely flagged and severed. That is
  # over-severance of a legitimate customer control, not a security gap.
  # A rewrite reaching at least "host/org" (the framework's own
  # organization/group) is still in-scope for severance — anything nested
  # under the framework's org is a genuine framework push path — only the
  # bare-host case (which says nothing framework-specific at all) is
  # excluded. The EXACT full-identity match branch below is unchanged and
  # untouched by this restriction: if a framework identity URL somehow
  # normalized to a bare host with no org (not the case for the real
  # framework remote, which is always host/org/repo), an effective target
  # that is ALSO exactly that bare host still matches via exact-match, so
  # a genuinely degenerate identity does not silently stop being covered —
  # only the PREFIX-widening of a bare host is disallowed.
  local effective="$1" norm_effective identity norm_identity suffix
  [ -z "$effective" ] && return 1
  norm_effective="$(normalize_url "$effective")"
  norm_effective="${norm_effective%/}"
  [ -z "$norm_effective" ] && return 1
  for identity in "${FRAMEWORK_IDENTITY_URLS[@]:-}"; do
    [ -z "$identity" ] && continue
    norm_identity="$(normalize_url "$identity")"
    if [ "$norm_effective" = "$norm_identity" ]; then
      return 0
    fi
    # SF-073 — only consider the prefix branch when norm_effective itself
    # already spans >= 2 segments (host/org at minimum). A norm_effective
    # with no '/' at all is a bare host and is excluded here; it can still
    # match above via exact-match against a (real-world nonexistent)
    # bare-host identity.
    case "$norm_effective" in
      */*)
        suffix="${norm_identity#"$norm_effective"/}"
        if [ "$suffix" != "$norm_identity" ]; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

url_resolves_to_framework() {
  # SF-068 — base_dir (2nd arg) is the repo the candidate URL/path was READ
  # FROM (i.e. $repo_dir at every call site in assert_remote_severance /
  # sever_framework_remotes). Git stores a relative local-path remote
  # verbatim, resolved relative to the repo that configured it — NOT
  # relative to wherever this script's own process happens to be running
  # from. `git remote add fw ../AgenticCore` run inside the adopter
  # tree stores the literal string "../AgenticCore"; that string only
  # resolves to the framework when evaluated with the ADOPTER repo as the
  # base, never the script's ambient CWD (which is typically the framework
  # checkout itself, or an operator's shell CWD — neither is correct).
  # Every caller must pass its own repo_dir as base_dir so a relative
  # candidate is resolved from the right place.
  local candidate norm_candidate identity norm_identity base_dir
  candidate="$1"
  base_dir="${2:-$PWD}"
  [ -z "$candidate" ] && return 1

  # Local filesystem path candidate (no scheme, no SSH shorthand, not a bare
  # hostname/path) — resolve it as a path (relative candidates against
  # base_dir, absolute candidates as-is) and compare git-common-dir against
  # the framework's own git-common-dir. This catches `git remote add fw
  # /path/to/AgenticCore` or `git remote add fw ../AgenticCore`
  # (or any worktree of it) even though such a remote never appears in
  # FRAMEWORK_IDENTITY_URLS (which only enumerates the framework's OWN
  # configured remote URLs, not arbitrary local paths an operator might
  # point at it).
  if [[ "$candidate" != *://* ]] && [[ "$candidate" != *@*:* ]]; then
    local resolved_path
    case "$candidate" in
      /*) resolved_path="$candidate" ;;
      *)  resolved_path="$base_dir/$candidate" ;;
    esac
    if [ -e "$resolved_path" ]; then
      local cand_common
      cand_common="$(git -C "$resolved_path" rev-parse --git-common-dir 2>/dev/null || true)"
      if [ -n "$cand_common" ] && [ -n "$FRAMEWORK_COMMON_DIR" ]; then
        case "$cand_common" in
          /*) : ;;
          *) cand_common="$resolved_path/$cand_common" ;;
        esac
        # SF-069 — pwd -P (physical) on both this side and FRAMEWORK_COMMON_DIR
        # so a symlinked path component on either side still canonicalizes to
        # the same string as the physical path on the other side.
        cand_common="$(cd "$(dirname "$cand_common")" 2>/dev/null && pwd -P)/$(basename "$cand_common")"
        if [ "$cand_common" = "$FRAMEWORK_COMMON_DIR" ]; then
          return 0
        fi
      fi
    fi
  fi

  norm_candidate="$(normalize_url "$candidate")"
  for identity in "${FRAMEWORK_IDENTITY_URLS[@]:-}"; do
    [ -z "$identity" ] && continue
    norm_identity="$(normalize_url "$identity")"
    if [ "$norm_candidate" = "$norm_identity" ]; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# D-7.6 — Target-identity guard. Refuse to operate on the framework repo
# itself or a nested/parent framework worktree. Independent of dirty-tree
# check; runs before flow detection.
# ---------------------------------------------------------------------------
guard_target_identity() {
  local target_abs
  # Resolve target to an absolute path without requiring it to exist yet.
  # SF-069 — pwd -P (physical) so a symlinked target path canonicalizes to
  # the same string FRAMEWORK_ROOT would (which is also now pwd -P).
  if [ -d "$TARGET" ]; then
    target_abs="$(cd "$TARGET" && pwd -P)"
  else
    local parent
    parent="$(dirname "$TARGET")"
    if [ -d "$parent" ]; then
      target_abs="$(cd "$parent" && pwd -P)/$(basename "$TARGET")"
    else
      target_abs="$TARGET"
    fi
  fi

  # Case 1: target path is the framework root itself, or nested inside it.
  case "$target_abs" in
    "$FRAMEWORK_ROOT")
      err "target-identity guard: target IS the framework repository root ($FRAMEWORK_ROOT). Refusing to operate."
      exit 3
      ;;
    "$FRAMEWORK_ROOT"/*)
      err "target-identity guard: target is nested inside the framework repository ($FRAMEWORK_ROOT). Refusing to operate."
      exit 3
      ;;
  esac

  # Case 2: target is itself a framework worktree (git-common-dir points to
  # the same repository, e.g. a sibling .NN bench of THIS framework checkout).
  # SF-069 — pwd -P (physical) on both sides here too.
  if [ -d "$target_abs" ] && git -C "$target_abs" rev-parse --git-common-dir >/dev/null 2>&1; then
    local target_common fw_common
    target_common="$(cd "$target_abs" && git rev-parse --git-common-dir 2>/dev/null || true)"
    case "$target_common" in
      /*) : ;;
      *) target_common="$target_abs/$target_common" ;;
    esac
    target_common="$(cd "$(dirname "$target_common")" && pwd -P)/$(basename "$target_common")"
    fw_common="$(git -C "$FRAMEWORK_ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
    case "$fw_common" in
      /*) : ;;
      *) fw_common="$FRAMEWORK_ROOT/$fw_common" ;;
    esac
    fw_common="$(cd "$(dirname "$fw_common")" && pwd -P)/$(basename "$fw_common")"
    if [ -n "$target_common" ] && [ "$target_common" = "$fw_common" ]; then
      err "target-identity guard: target is a worktree of the same framework repository ($FRAMEWORK_ROOT). Refusing to operate."
      exit 3
    fi

    # NOTE: we deliberately do NOT treat "target has a remote that resolves
    # to the framework" as a D-7.6 identity violation. A customer tree that
    # accidentally carries a framework-pointing remote (the exact TC-050
    # field scenario) is precisely what D-7.3 severance exists to fix, not
    # a signal that the target IS the framework repository. D-7.6 is scoped
    # to path/worktree identity only; D-7.3 (assert_remote_severance /
    # sever_framework_remotes) is the control that handles a polluted
    # customer tree.
  fi
}

# ---------------------------------------------------------------------------
# Slug validation and write (D-5)
# ---------------------------------------------------------------------------
validate_slug() {
  local s="$1"
  if [ -z "$s" ]; then
    err "slug must not be empty"
    return 1
  fi
  if ! [[ "$s" =~ ^[A-Z]+$ ]]; then
    err "slug must be non-empty uppercase ASCII letters only (got: '$s')"
    return 1
  fi
  return 0
}

prompt_for_slug() {
  if [ -n "$SLUG" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    err "--slug is required in non-interactive mode (stdin is not a tty)"
    exit 7
  fi
  while true; do
    printf 'Adopter project slug (uppercase ASCII, e.g. ACME): ' >&2
    read -r SLUG
    if validate_slug "$SLUG"; then
      break
    fi
  done
}

# TC-063 (D-8) — the framework's own root AGENT.md is the baseline-steward
# persona and carries framework-release-specific dev-staging / curated-release
# git discipline (ADR-0026) that adopters do NOT inherit. Ship the
# lead-engineer-flavored adopter template as the adopter's root AGENT.md
# instead. The template's shared security/docs policy blocks are single-sourced
# via sync-agents.sh marker injection, so this swap never drifts from canonical
# policy. Runs AFTER framework content is copied into the target and BEFORE
# write_slug_files, so slug injection then applies to the swapped file normally.
# Honors DRY_RUN (D-7.4 zero-side-effects): reports the swap, changes nothing.
swap_adopter_root_agent() {
  local repo_dir="$1"
  local template="$FRAMEWORK_ROOT/.agents/bootstrap/adopter-root-AGENT.md"

  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would overwrite $repo_dir/AGENT.md with adopter lead-engineer template (.agents/bootstrap/adopter-root-AGENT.md)"
    return 0
  fi

  if [ ! -f "$template" ]; then
    err "adopter root AGENT.md template not found: $template"
    return 1
  fi

  cp "$template" "$repo_dir/AGENT.md"
}

write_slug_files() {
  local repo_dir="$1" slug="$2"

  # AGENT.md — add/replace a "## Project Slug" section near the top.
  if [ -f "$repo_dir/AGENT.md" ]; then
    if grep -q '^## Project Slug' "$repo_dir/AGENT.md"; then
      # Replace the existing section's value line (first non-blank line after heading)
      awk -v slug="$slug" '
        BEGIN { in_section=0 }
        /^## Project Slug/ { print; in_section=1; next }
        in_section==1 && /^##[^#]/ { in_section=0; print; next }
        in_section==1 && $0 != "" { print slug; in_section=2; next }
        { print }
      ' "$repo_dir/AGENT.md" > "$repo_dir/AGENT.md.tmp"
      mv "$repo_dir/AGENT.md.tmp" "$repo_dir/AGENT.md"
    else
      { printf '\n## Project Slug\n\n%s\n' "$slug"; cat "$repo_dir/AGENT.md"; } > "$repo_dir/AGENT.md.tmp"
      # Prepend after the first line (title) rather than before it
      { head -n1 "$repo_dir/AGENT.md"; printf '\n## Project Slug\n\n%s\n' "$slug"; tail -n +2 "$repo_dir/AGENT.md"; } > "$repo_dir/AGENT.md.tmp"
      mv "$repo_dir/AGENT.md.tmp" "$repo_dir/AGENT.md"
    fi
  fi

  # tasks.yaml — SF-117/SF-122: tasks.yaml is now excluded from
  # copy_framework_content and SEEDED by seed_adopter_state() instead (which
  # runs before this function — see the do_flow_empty/do_flow_rehome call
  # order). The seed template's `# Task Queue — __SLUG__` HEADER comment
  # already carries the slug via seed_adopter_state's __SLUG__ substitution,
  # so there is nothing left for this function to inject.
  #
  # Deliberately NOT inserting a top-level `slug:` field here (as an earlier
  # version of this function did): tasks.yaml's body is a bare top-level
  # YAML list (`- id: ...`) preceded by a `---` document-separator line: a
  # top-level `slug: <value>` mapping key inserted ABOVE that `---` makes
  # the file a two-document YAML stream (a mapping document, then a `---`
  # starting a second, list-only document), which
  # `yaml.safe_load()` — used by every consumer, including the
  # review-ledger MCP server's task-adjacent tooling and bench-status.sh's
  # stale-bench check — rejects with `ComposerError: expected a single
  # document in the stream`. Confirmed by direct reproduction. tasks.yaml
  # has never carried a `slug:` field in the framework's own repo (grep
  # confirms) — the header-comment convention is the correct, parseable
  # place for it, not a `slug:` YAML key.

  # PROCESS.md — update the branch-naming example to use the active slug
  if [ -f "$repo_dir/PROCESS.md" ]; then
    sed -i.bak -E "s#Branch naming: \`<type>/<ticket-id>-<short-slug>\`#Branch naming: \`<type>/${slug}-NNNN-<short-slug>\`#" "$repo_dir/PROCESS.md" 2>/dev/null || true
    rm -f "$repo_dir/PROCESS.md.bak"
  fi
}

# ---------------------------------------------------------------------------
# framework-version.txt generation (D-1)
# ---------------------------------------------------------------------------
resolve_release_version() {
  # Prefer an exact tag on the framework's current HEAD; fall back to
  # nearest-tag description; fall back to short SHA.
  local v
  v="$(git -C "$FRAMEWORK_ROOT" describe --tags --exact-match 2>/dev/null || true)"
  if [ -z "$v" ]; then
    v="$(git -C "$FRAMEWORK_ROOT" describe --tags 2>/dev/null || true)"
  fi
  if [ -z "$v" ]; then
    v="$(git -C "$FRAMEWORK_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi
  printf '%s' "$v"
}

write_version_file() {
  local repo_dir="$1" version="$2" export_date="$3"
  cat > "$repo_dir/framework-version.txt" << EOF
framework: AgenticCore
release: $version
exported: $export_date
EOF
}

# ---------------------------------------------------------------------------
# D-7.3 — Remote-severance assertion (allowlist, resolved-push-target).
# The allowlist here is implicit: any remote whose resolved push target does
# NOT match the framework's identity is allowed (it is, by definition, the
# adopter's own remote — export-framework.sh never adds a remote on its own
# initiative, so any remote present belongs to the adopter). Only remotes
# that resolve to the framework are offenders.
# Runs on EVERY invocation (including dry-run/no-op) in report-only or
# enforcing form. NON-OVERRIDABLE by --force or any flag.
# ---------------------------------------------------------------------------
assert_remote_severance() {
  local repo_dir="$1"
  local -a offenders=()

  if [ ! -d "$repo_dir/.git" ] && ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
    # No repo yet (e.g. dry-run pre-init on empty flow) — nothing to assert.
    return 0
  fi

  # 1. Every [remote "<name>"] url and every pushurl (fetch + push, --all).
  while IFS= read -r rname; do
    [ -z "$rname" ] && continue
    while IFS= read -r rurl; do
      [ -z "$rurl" ] && continue
      if url_resolves_to_framework "$rurl" "$repo_dir"; then
        offenders+=("remote.$rname (push target) = $rurl")
      fi
    done < <(git -C "$repo_dir" remote get-url --push --all "$rname" 2>/dev/null || true)
    fetch_url="$(git -C "$repo_dir" remote get-url "$rname" 2>/dev/null || true)"
    if [ -n "$fetch_url" ] && url_resolves_to_framework "$fetch_url" "$repo_dir"; then
      offenders+=("remote.$rname (fetch url) = $fetch_url")
    fi
  done < <(git -C "$repo_dir" remote 2>/dev/null || true)

  # 2. url.<base>.insteadOf / pushInsteadOf rewrite rules whose EFFECTIVE
  #    resolved target reaches the framework (SF-067). A rewrite base by
  #    itself is frequently a partial host/path fragment (that is the
  #    entire point of prefix substitution) — normalizing and comparing
  #    the base string in isolation misses any base whose resolution
  #    depends on prefix substitution or a further chained rewrite hop.
  #    We let git itself apply the rewrite (see
  #    resolve_rewrite_base_effective_target) and test whether that
  #    resolved target is, or is a path-bounded prefix of, the framework
  #    identity (rewrite_target_covers_framework — see its header comment
  #    for why an exact-match check is the wrong test for a rewrite
  #    target), so a dormant rule is caught even with no live remote
  #    currently using it.
  while IFS= read -r cfg_line; do
    [ -z "$cfg_line" ] && continue
    local key val base effective
    key="${cfg_line%% *}"
    val="${cfg_line#* }"
    base="${key#url.}"
    base="${base%.insteadof}"
    base="${base%.pushinsteadof}"
    effective="$(resolve_rewrite_base_effective_target "$repo_dir" "$base")"
    if [ -n "$effective" ] && rewrite_target_covers_framework "$effective"; then
      offenders+=("$key -> $val (effective resolved target = $effective, resolves to framework)")
    elif url_resolves_to_framework "$base" "$repo_dir"; then
      # Belt-and-suspenders: base string itself is already a full framework
      # identity (no prefix substitution needed to see it).
      offenders+=("$key -> $val (base resolves to framework)")
    fi
  done < <(git -C "$repo_dir" config --get-regexp 'url\..*\.(insteadof|pushinsteadof)' 2>/dev/null || true)

  # 3. remote.pushDefault — check the DEFAULT remote's resolved push target.
  local push_default
  push_default="$(git -C "$repo_dir" config --get remote.pushDefault 2>/dev/null || true)"
  if [ -n "$push_default" ]; then
    local pd_url
    pd_url="$(git -C "$repo_dir" remote get-url --push "$push_default" 2>/dev/null || true)"
    if [ -n "$pd_url" ] && url_resolves_to_framework "$pd_url" "$repo_dir"; then
      offenders+=("remote.pushDefault = $push_default (resolves to $pd_url)")
    fi
  fi

  # 4. branch.<name>.pushRemote — same resolved-target check, per branch.
  while IFS= read -r cfg_line; do
    [ -z "$cfg_line" ] && continue
    local key val
    key="${cfg_line%% *}"
    val="${cfg_line#* }"
    local br_url
    br_url="$(git -C "$repo_dir" remote get-url --push "$val" 2>/dev/null || true)"
    if [ -n "$br_url" ] && url_resolves_to_framework "$br_url" "$repo_dir"; then
      offenders+=("$key = $val (resolves to $br_url)")
    fi
  done < <(git -C "$repo_dir" config --get-regexp '^branch\..*\.pushremote$' 2>/dev/null || true)

  if [ "${#offenders[@]}" -gt 0 ]; then
    err "D-7.3 remote-severance assertion FAILED — a push path to the framework repository survives:"
    local o
    for o in "${offenders[@]}"; do
      err "  - $o"
    done
    return 5
  fi
  return 0
}

sever_framework_remotes() {
  local repo_dir="$1"

  if [ "$DRY_RUN" -eq 1 ]; then
    while IFS= read -r rname; do
      [ -z "$rname" ] && continue
      rurl="$(git -C "$repo_dir" remote get-url "$rname" 2>/dev/null || true)"
      if [ -n "$rurl" ] && url_resolves_to_framework "$rurl" "$repo_dir"; then
        dry_note "would remove remote '$rname' ($rurl) — resolves to framework"
      fi
    done < <(git -C "$repo_dir" remote 2>/dev/null || true)
    return 0
  fi

  # Remove any remote whose fetch OR any push URL resolves to the framework.
  while IFS= read -r rname; do
    [ -z "$rname" ] && continue
    local should_remove=0
    fetch_url="$(git -C "$repo_dir" remote get-url "$rname" 2>/dev/null || true)"
    if [ -n "$fetch_url" ] && url_resolves_to_framework "$fetch_url" "$repo_dir"; then
      should_remove=1
    fi
    while IFS= read -r purl; do
      [ -z "$purl" ] && continue
      if url_resolves_to_framework "$purl" "$repo_dir"; then
        should_remove=1
      fi
    done < <(git -C "$repo_dir" remote get-url --push --all "$rname" 2>/dev/null || true)
    if [ "$should_remove" -eq 1 ]; then
      log "  severing remote: $rname"
      git -C "$repo_dir" remote remove "$rname" 2>/dev/null || true
    fi
  done < <(git -C "$repo_dir" remote 2>/dev/null || true)

  # Clear insteadOf/pushInsteadOf rewrite rules whose base resolves to the
  # framework, and remote.pushDefault / branch.*.pushRemote if they point
  # at a (now-removed or still-present) framework-resolving target.
  # SF-067 — use the same effective-resolved-target check as detection
  # (resolve_rewrite_base_effective_target / rewrite_target_covers_framework)
  # so a dormant prefix-form rewrite rule is cleared here too, not only
  # flagged by the assertion.
  while IFS= read -r cfg_line; do
    [ -z "$cfg_line" ] && continue
    key="${cfg_line%% *}"
    base="${key#url.}"
    base="${base%.insteadof}"
    base="${base%.pushinsteadof}"
    effective="$(resolve_rewrite_base_effective_target "$repo_dir" "$base")"
    if { [ -n "$effective" ] && rewrite_target_covers_framework "$effective"; } \
       || url_resolves_to_framework "$base" "$repo_dir"; then
      log "  removing url rewrite section for base: $base"
      git -C "$repo_dir" config --remove-section "url.$base" 2>/dev/null || true
    fi
  done < <(git -C "$repo_dir" config --get-regexp 'url\..*\.(insteadof|pushinsteadof)' 2>/dev/null || true)

  push_default="$(git -C "$repo_dir" config --get remote.pushDefault 2>/dev/null || true)"
  if [ -n "$push_default" ]; then
    pd_url="$(git -C "$repo_dir" remote get-url --push "$push_default" 2>/dev/null || true)"
    if [ -z "$pd_url" ] || url_resolves_to_framework "$pd_url" "$repo_dir"; then
      log "  removing remote.pushDefault ($push_default)"
      git -C "$repo_dir" config --unset remote.pushDefault 2>/dev/null || true
    fi
  fi

  while IFS= read -r cfg_line; do
    [ -z "$cfg_line" ] && continue
    key="${cfg_line%% *}"
    val="${cfg_line#* }"
    br_url="$(git -C "$repo_dir" remote get-url --push "$val" 2>/dev/null || true)"
    if [ -z "$br_url" ] || url_resolves_to_framework "$br_url" "$repo_dir"; then
      log "  removing $key"
      git -C "$repo_dir" config --unset "$key" 2>/dev/null || true
    fi
  done < <(git -C "$repo_dir" config --get-regexp '^branch\..*\.pushremote$' 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# D-7.5 — History/refs/object scrub + verification.
# Approach (a) (preferred, SF-066): Flow A always uses this naturally
# (fresh `git init`, no clone). Flow B uses this by construction too — see
# do_flow_rehome — content is copied out of a throwaway WORKING-TREE COPY
# (a plain `tar` extraction of $FRAMEWORK_ROOT into a scratch dir, NOT a
# `git clone` — see copy_framework_content, which excludes `.git` entirely)
# into the EXISTING adopter repo's working tree; the adopter's OWN .git is
# never touched by anything framework-related, so no framework GIT OBJECT
# is ever created, let alone introduced into the adopter object store. This
# is stronger than SF-066 approach (a) as literally described (a throwaway
# clone would still momentarily create framework objects on disk in the
# scratch dir; this implementation never creates a framework .git at all).
# This function is therefore a verification-only assertion in the normal
# path (approach (a) never needs the scrub itself), but it must catch a
# framework ref/object that arrives by ANY means (e.g. an operator manually
# adding the framework as a remote and fetching before running this script).
# ---------------------------------------------------------------------------
assert_no_framework_history() {
  local repo_dir="$1"

  # SF-114/SF-116 — scope every git operation in this assertion to the
  # TARGET's own .git only; never let git's upward repository discovery
  # resolve to an ANCESTOR .git. The prior guard
  # (`[ ! -d "$repo_dir/.git" ] && ! git -C "$repo_dir" rev-parse --git-dir`)
  # let `rev-parse --git-dir` walk up past the target when the target had
  # no `.git` of its own, so on a --dry-run against an empty target nested
  # under an ancestor git repo (e.g. this test harness's own workdir, or
  # any target created under an existing checkout) the guard's SECOND
  # condition (rev-parse succeeds, resolving to the ancestor) made the
  # overall AND false, so execution fell through to `git fsck
  # --unreachable` against the ANCESTOR's object store — a false-positive
  # D-7.5 failure (SF-114) whenever that ancestor happened to carry any
  # unreachable object.
  #
  # GIT_CEILING_DIRECTORIES set to the target's PARENT (exported only for
  # this function via `local -x`, never leaking to the caller) stops git's
  # repository discovery at that boundary: if the target is not yet its
  # own repository, discovery fails cleanly instead of silently resolving
  # upward to an ancestor.
  local repo_parent=""
  if [ -e "$repo_dir" ]; then
    repo_parent="$(cd "$repo_dir/.." 2>/dev/null && pwd -P)" || repo_parent=""
  fi
  local -x GIT_CEILING_DIRECTORIES=""
  [ -n "$repo_parent" ] && GIT_CEILING_DIRECTORIES="$repo_parent"

  # SF-116 — a bare `return 0` here is a SILENT skip, indistinguishable
  # from a pass, defeating the ADR-0015 D-7.4/D-7.5 "runs on every
  # invocation, non-overridable" guarantee. Every path that treats the
  # scrub as not-applicable must say so explicitly via `log`.
  if [ ! -e "$repo_dir" ]; then
    log "D-7.5 scrub: target does not exist yet — nothing to scrub (N/A)."
    return 0
  fi

  local toplevel target_real
  toplevel="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$toplevel" ]; then
    log "D-7.5 scrub: target is not yet a git repo — nothing to scrub (N/A)."
    return 0
  fi
  target_real="$(cd "$repo_dir" && pwd -P)"
  if [ "$toplevel" != "$target_real" ]; then
    # Ceiling-scoped discovery still resolved to something other than the
    # target itself. With GIT_CEILING_DIRECTORIES pinned above this should
    # not happen for an ANCESTOR match (discovery is capped at the target's
    # parent), but treat any mismatch conservatively as N/A rather than
    # proceeding against a repo that is not verifiably the target's own.
    log "D-7.5 scrub: target is not yet its own git repo (resolved toplevel '$toplevel') — nothing to scrub (N/A)."
    return 0
  fi

  local -a offenders=()

  # refs/remotes/* — any surviving remote-tracking ref at all is suspect
  # once remotes have been severed; check it doesn't point into framework
  # history by cross-referencing against known framework commit SHAs is not
  # tractable without a framework history somewhere to diff against, so the
  # authoritative check is: no refs/remotes/* should exist at all after
  # severance (a severed remote leaves no tracking refs).
  local remote_refs
  remote_refs="$(git -C "$repo_dir" for-each-ref refs/remotes 2>/dev/null || true)"
  if [ -n "$remote_refs" ]; then
    offenders+=("refs/remotes/* still present: $remote_refs")
  fi

  # FETCH_HEAD referencing a framework-resolving URL
  local common_dir fetch_head
  common_dir="$(git -C "$repo_dir" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ]; then
    case "$common_dir" in
      /*) : ;;
      *) common_dir="$repo_dir/$common_dir" ;;
    esac
    fetch_head="$common_dir/FETCH_HEAD"
    if [ -f "$fetch_head" ] && [ -s "$fetch_head" ]; then
      offenders+=("FETCH_HEAD non-empty: $(cat "$fetch_head" 2>/dev/null | head -1)")
    fi
  fi

  # Unreachable objects surviving in the object store (dangling commits from
  # a since-removed remote's fetched history).
  # SF-071 — known limitation, deliberately conservative: this check cannot
  # distinguish a FRAMEWORK unreachable object from an unrelated CUSTOMER
  # unreachable object (e.g. Flow B's pre-existing customer repo may
  # legitimately carry dangling objects from amended commits or dropped
  # stashes that have nothing to do with the framework) — there is no
  # framework history available locally to diff against once severed. Any
  # unreachable object at all is treated as an offender. This trades a
  # possible false-positive abort on a customer repo with pre-existing
  # dangling objects for never missing a real framework object; scrub_-
  # framework_history runs `gc --prune=now` immediately before this check in
  # the normal flow, which clears ordinary dangling objects first, so a
  # false positive here should be rare in practice. Do not loosen this
  # check to reduce false positives without an alternative that preserves
  # the "never miss a framework object" guarantee.
  local fsck_out
  fsck_out="$(git -C "$repo_dir" fsck --unreachable 2>/dev/null || true)"
  if [ -n "$fsck_out" ]; then
    offenders+=("unreachable objects present: $(printf '%s' "$fsck_out" | tr '\n' '; ')")
  fi

  if [ "${#offenders[@]}" -gt 0 ]; then
    err "D-7.5 history/refs/object scrub verification FAILED — framework-reachable state survives:"
    local o
    for o in "${offenders[@]}"; do
      err "  - $o"
    done
    return 6
  fi
  return 0
}

scrub_framework_history() {
  local repo_dir="$1"

  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would expire reflog, remove FETCH_HEAD, gc --prune=now to scrub any residual framework objects"
    return 0
  fi

  local common_dir fetch_head
  common_dir="$(git -C "$repo_dir" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ]; then
    case "$common_dir" in
      /*) : ;;
      *) common_dir="$repo_dir/$common_dir" ;;
    esac
    fetch_head="$common_dir/FETCH_HEAD"
    [ -f "$fetch_head" ] && rm -f "$fetch_head"
  fi

  git -C "$repo_dir" reflog expire --expire=now --all >/dev/null 2>&1 || true
  git -C "$repo_dir" gc --prune=now -q >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Framework file manifest — what gets copied into the adopter repo.
# Excludes framework-internal-only artifacts that should not travel with
# every export (bench worktrees, in-progress work state, build output).
# ---------------------------------------------------------------------------
FRAMEWORK_EXCLUDE_PATTERNS=(
  ".git"
  "_poc"
  ".work"
  "mddocs/book"
  # SF-117/SF-122 — framework LIVE OPERATIONAL STATE must never land in the
  # adopter tree: the framework's own task queue (69 AP-* tickets) and the
  # framework's own populated shared-context file. These are excluded here
  # and SEEDED with adopter-generic empty starting files by
  # seed_adopter_state() below (see seed_adopter_state's own header for the
  # seed-template inventory). The review ledgers (`.security`/`.reviews`)
  # were reconciled to `.core/review-ledger/{security,reviews}`, which ship
  # wired via .gitkeep and are NOT excluded (the framework's authoring does
  # not use them, so there is no operational state to scrub). mddocs/adr is
  # deliberately NOT excluded — ADRs are reference material that must
  # continue to ship (D-4/D-6).
  "tasks.yaml"
  ".core/agents/_context.md"
  # SF-123 — bench-registry.yaml is the framework's own LIVE bench-provenance
  # record: it names internal AP-* ticket IDs, security/review finding IDs
  # (SF-*, RF-*), reviewer-run IDs (SR-*, RR-*), commit SHAs, and teardown
  # narrative for every bench this framework repo has ever provisioned for
  # itself. Same leak class as tasks.yaml/.core/agents/_context.md above —
  # excluded here and SEEDED with an adopter-generic template by
  # seed_adopter_state() below (see mddocs/scripts/seed/bench-registry.yaml).
  "bench-registry.yaml"
  # SF-124 — .bench/ and relay-pending.md are ON-DISK framework operational
  # state (bench assignment, cross-bench relay notes). Both are already
  # gitignored (never reach the framework's OWN git history), but `tar -c .`
  # in _copy_framework_content_raw below walks the WORKING TREE, not git's
  # index, so gitignore rules do not protect against them being copied into
  # the adopter tree. .bench/assignment.md holds the LIVE framework
  # ticket/branch assignment for whichever bench happens to be running this
  # export. These are EXCLUDED ONLY — not seeded: an adopter has no bench
  # assignment or relay note at bootstrap, so there is nothing adopter-
  # generic to seed in their place (contrast bench-registry.yaml above,
  # which IS seeded because the adopter needs the schema/scaffold to start
  # registering their own benches).
  ".bench"
  "relay-pending.md"
  # SF-127 — mddocs/backlog.md is the human-readable MIRROR of tasks.yaml
  # (its own preamble says so verbatim: "mirrors the current state of
  # tasks.yaml"): it carries the same framework AP-* ticket IDs,
  # per-ticket status/priority, and internal agent role names (including
  # "baseline-steward") as tasks.yaml itself — same leak class as
  # SF-117/SF-122 (tasks.yaml) and SF-123 (bench-registry.yaml). mddocs/ is
  # deliberately NOT excluded wholesale (ADRs and other reference docs
  # under mddocs/ are meant to ship — D-4/D-6), so this single nested path
  # is excluded specifically, following the exact working pattern already
  # used for the other nested exclusion above:
  # ".core/agents/_context.md". Seeded with an adopter-generic
  # empty scaffold by seed_adopter_state() below — see
  # mddocs/scripts/seed/mddocs/backlog.md.
  "mddocs/backlog.md"
)

# _copy_framework_content_raw — the actual tar-based extraction, with no
# DRY_RUN gate. Only ever called against a THROWAWAY SCRATCH directory
# (never against the adopter --target directly), so calling it during
# --dry-run to build a manifest preview (TC-051, see do_flow_rehome) does
# not violate D-7.4 zero-side-effects-on-target: the scratch dir this
# writes into is not the target and is removed by its caller.
_copy_framework_content_raw() {
  local dest="$1"
  mkdir -p "$dest"
  local -a tar_excludes=()
  local p
  for p in "${FRAMEWORK_EXCLUDE_PATTERNS[@]}"; do
    tar_excludes+=(--exclude="$p")
  done
  ( cd "$FRAMEWORK_ROOT" && tar -c "${tar_excludes[@]}" . ) | ( cd "$dest" && tar -x )
}

copy_framework_content() {
  local dest="$1"

  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would copy framework release content from $FRAMEWORK_ROOT to $dest"
    dry_note "excluding: ${FRAMEWORK_EXCLUDE_PATTERNS[*]}"
    return 0
  fi

  _copy_framework_content_raw "$dest"
}

# ---------------------------------------------------------------------------
# SF-117/SF-122/SF-123/SF-127 — Adopter state seeding.
#
# The paths excluded from copy_framework_content above that carry an
# adopter-generic replacement (tasks.yaml, .core/agents/_context.md,
# bench-registry.yaml — SF-123 added this one, mddocs/backlog.md — SF-127
# added this one) are the framework's own LIVE OPERATIONAL STATE and must
# never land in an adopter tree verbatim. seed_adopter_state() replaces
# them with adopter-generic, EMPTY (or schema-only) starting files from
# mddocs/scripts/seed/ — one seed template per excluded path, mirrored at
# the same relative path under seed/ as it has in the adopter target (e.g.
# seed/.core/agents/_context.md -> <target>/.core/agents/_context.md), so
# the mapping here is a straight relative-path copy, not a lookup table.
# (.bench and relay-pending.md are excluded too but NOT seeded — see their
# FRAMEWORK_EXCLUDE_PATTERNS entries above for why.)
#
# NOTE — the review ledgers (`.security`, `.reviews`) are NOT seeded. The
# ledgers were reconciled to `.core/review-ledger/{security,reviews}` and
# ship wired via their .gitkeep placeholders; the framework's own authoring
# does not use them, so there is no framework operational state to scrub
# and nothing to seed in their place.
#
# Every seed template uses the `__SLUG__` placeholder token (same
# convention as the pre-existing mddocs/scripts/seed/tasks.yaml), which
# this function substitutes for the validated adopter slug with `sed`.
#
# Honors DRY_RUN (D-7.4 zero-side-effects): emits a dry_note per path and
# writes nothing when DRY_RUN=1 — mirrors the copy_framework_content gate
# above.
# ---------------------------------------------------------------------------
SEED_RELATIVE_PATHS=(
  "tasks.yaml"
  ".core/agents/_context.md"
  # SF-123 — bench-registry.yaml (see FRAMEWORK_EXCLUDE_PATTERNS above).
  "bench-registry.yaml"
  # SF-127 — mddocs/backlog.md (see FRAMEWORK_EXCLUDE_PATTERNS above).
  "mddocs/backlog.md"
)

seed_adopter_state() {
  local repo_dir="$1" slug="$2"
  local seed_dir="$FRAMEWORK_ROOT/mddocs/scripts/seed"
  local rel dest

  if [ "$DRY_RUN" -eq 1 ]; then
    for rel in "${SEED_RELATIVE_PATHS[@]}"; do
      dry_note "would seed $repo_dir/$rel from $seed_dir/$rel (placeholder __SLUG__ -> $slug)"
    done
    return 0
  fi

  for rel in "${SEED_RELATIVE_PATHS[@]}"; do
    if [ ! -f "$seed_dir/$rel" ]; then
      err "seed template not found: $seed_dir/$rel"
      return 1
    fi
    dest="$repo_dir/$rel"
    mkdir -p "$(dirname "$dest")"
    sed "s/__SLUG__/$slug/g" "$seed_dir/$rel" > "$dest"
  done
}

# ---------------------------------------------------------------------------
# TC-051 — Framework manifest capture (Flow B reconciliation).
#
# write_framework_manifest walks a directory tree (the throwaway scratch
# copy produced by copy_framework_content, BEFORE it is overlaid into the
# adopter target and removed) and writes every regular file's path,
# relative to that directory and with the leading "./" stripped, to
# $manifest_file as NUL-delimited entries. NUL-delimited output (not
# newline-delimited) is required so a path containing a space or other
# shell-metacharacter round-trips exactly — this manifest is later consumed
# by `git add --pathspec-from-file=... --pathspec-file-nul`, which requires
# matching delimiter discipline.
#
# This manifest is the AUTHORITATIVE definition of "framework content" for
# the running export: every path it lists came directly out of the
# scratch copy of $FRAMEWORK_ROOT (already exclude-filtered by
# copy_framework_content), so classification of framework-vs-customer is a
# deterministic set-membership test against this file, never a heuristic
# guess about what "looks like" framework content.
# ---------------------------------------------------------------------------
write_framework_manifest() {
  local scratch_dir="$1" manifest_file="$2"
  : > "$manifest_file"
  local raw=""
  raw="$(mktemp "${TMPDIR:-/tmp}/export-framework-manifest-raw.XXXXXX")"
  # RF-008 — RETURN trap (matching the SF-074 idiom used elsewhere in this
  # file, e.g. resolve_rewrite_base_effective_target) so $raw is removed on
  # ANY function return, not only the normal fall-through path. Without
  # this, a failure between mktemp and the `rm -f` below (e.g. the `find`
  # pipeline failing) would leak $raw under set -euo pipefail. Cleared with
  # `trap - RETURN` on the normal path (after this function's own manual
  # `rm -f`) so the trap does not remain armed and fire again — spuriously,
  # against an out-of-scope $raw — on the CALLER's next return event.
  trap 'rm -f "$raw" 2>/dev/null || true' RETURN
  ( cd "$scratch_dir" && find . -type f -print0 ) > "$raw"
  local f
  while IFS= read -r -d '' f; do
    printf '%s\0' "${f#./}" >> "$manifest_file"
  done < "$raw"
  rm -f "$raw"
  trap - RETURN
}

# manifest_contains_path — exact-match membership test against a
# NUL-delimited manifest file (see write_framework_manifest). Uses
# `grep -z -F -x` (fixed-string, whole-"line"/NUL-record match) rather than
# a bash loop over the manifest for every candidate path, since Flow B
# targets can carry large customer trees and this test runs once per
# untracked entry.
manifest_contains_path() {
  local manifest_file="$1" candidate="$2"
  grep -zqFx "$candidate" "$manifest_file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# TC-051 — Reconciliation report (Flow B). Report-only: never writes
# .gitignore, never decides tracked-vs-ignored on the operator's behalf.
#
# collect_customer_entries computes the set of untracked paths in $repo_dir
# that are NOT in the framework manifest — i.e. pre-existing customer
# content the overlay did not introduce and this script will not stage.
# Writes one path per line to $out_file (plain newline-delimited is fine
# here; this file is a human-readable report artifact, not a git pathspec
# input).
# ---------------------------------------------------------------------------
collect_customer_entries() {
  local repo_dir="$1" manifest_file="$2" out_file="$3"
  : > "$out_file"
  local status_z=""
  status_z="$(mktemp "${TMPDIR:-/tmp}/export-framework-statusz.XXXXXX")"
  # RF-008 — RETURN trap (same idiom as write_framework_manifest above and
  # resolve_rewrite_base_effective_target/SF-074 elsewhere in this file) so
  # $status_z is removed on ANY function return, not only the normal
  # fall-through path. Cleared with `trap - RETURN` after this function's
  # own manual `rm -f` on the normal path, so it does not remain armed and
  # fire again against an out-of-scope $status_z on the caller's next
  # return event.
  trap 'rm -f "$status_z" 2>/dev/null || true' RETURN
  git -C "$repo_dir" status --porcelain=v1 -z --untracked-files=all > "$status_z" 2>/dev/null || true
  local entry prefix path
  while IFS= read -r -d '' entry; do
    [ -z "$entry" ] && continue
    prefix="${entry:0:2}"
    path="${entry:3}"
    if [ "$prefix" = "??" ] && ! manifest_contains_path "$manifest_file" "$path"; then
      printf '%s\n' "$path" >> "$out_file"
    fi
  done < "$status_z"
  rm -f "$status_z"
  trap - RETURN
}

# write_reconciliation_report — durable provenance report for the operator.
# Lists every pre-existing customer entry left untracked after the
# manifest-scoped commit, with explicit instructions that classification
# (gitignore vs. track) is the operator's decision, not this script's.
# The report file itself is intentionally left OUT of the framework
# commit (it describes customer content, not framework content) and is
# NOT added to .gitignore — it surfaces in `git status` as an ordinary
# untracked file the operator reads, then deletes or commits at their own
# discretion.
write_reconciliation_report() {
  local repo_dir="$1" report_file="$2" version="$3" export_date="$4" customer_entries_file="$5"
  local count
  count="$(wc -l < "$customer_entries_file" | tr -d ' ')"

  {
    printf '# Framework Re-Home Reconciliation Report\n\n'
    printf 'framework: AgenticCore\n'
    printf 'release: %s\n' "$version"
    printf 'exported: %s\n\n' "$export_date"
    printf 'This report was generated by export-framework.sh during a Flow B\n'
    printf 're-home (overlay into an existing repository). It is provenance for\n'
    printf 'the operator, not a record consumed by the script itself.\n\n'
    printf '## What happened\n\n'
    printf 'Only files known to belong to the AgenticCore release (the\n'
    printf 'framework manifest — every path copied from the framework working\n'
    printf 'tree during this export) were staged into the re-home commit.\n'
    printf 'Everything else already present in this repository was left\n'
    printf 'exactly as it was — untouched, unstaged, and unclassified.\n\n'
    printf '## Pre-existing content requiring your classification (%s entries)\n\n' "$count"
    if [ "$count" -eq 0 ]; then
      printf '(none — no untracked pre-existing content was found outside the\n'
      printf 'framework manifest)\n\n'
    else
      printf 'The following paths existed in this repository before the framework\n'
      printf 'was re-homed into it, and are NOT part of the framework release.\n'
      printf 'They were intentionally NOT staged into the framework re-home\n'
      printf 'commit. Review each and decide:\n\n'
      printf '  (a) if it should NOT be tracked in git — add it to .gitignore\n'
      printf '      yourself; this script does not write .gitignore for you.\n'
      printf '  (b) if you DO want it tracked — run "git add <path>" yourself.\n\n'
      printf 'Paths:\n\n'
      sed 's/^/  - /' "$customer_entries_file"
      printf '\n'
    fi
    printf '## Required next step\n\n'
    printf 'Classify every path listed above (gitignore or git add) before your\n'
    printf 'first commit on top of this framework re-home. This report file is\n'
    printf 'not part of framework or customer history — read it, act on it, then\n'
    printf 'delete it (or commit it as a team record, if you prefer).\n'
  } > "$report_file"
}

# ---------------------------------------------------------------------------
# Flow A — empty-dir init (D-7.1)
# ---------------------------------------------------------------------------
do_flow_empty() {
  local target="$1"
  log "==> Flow A (empty-dir init): $target"

  local already_init=0
  if [ -d "$target/.git" ] && [ -f "$target/framework-version.txt" ]; then
    already_init=1
  fi

  if [ "$already_init" -eq 1 ]; then
    log "Target already initialized (framework-version.txt + .git present) — no-op (D-7.4 idempotence)."
    cat "$target/framework-version.txt" 2>/dev/null || true
    assert_remote_severance "$target" || return $?
    assert_no_framework_history "$target" || return $?
    log "Existing baseline verified clean (D-7.3, D-7.5 assertions pass)."
    return 0
  fi

  prompt_for_slug
  if ! validate_slug "$SLUG"; then
    exit 7
  fi

  local version export_date
  version="$(resolve_release_version)"
  export_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] would create: $target"
    copy_framework_content "$target"
    seed_adopter_state "$target" "$SLUG"
    swap_adopter_root_agent "$target"
    dry_note "would run: git init in $target"
    dry_note "would write framework-version.txt (release=$version, exported=$export_date)"
    dry_note "would write slug '$SLUG' to AGENT.md and PROCESS.md (tasks.yaml slug is set via seed_adopter_state's header substitution)"
    dry_note "would create initial commit recording release $version"
    assert_remote_severance "$target" || return $?
    assert_no_framework_history "$target" || return $?
    log "[dry-run] zero side effects — report only."
    return 0
  fi

  copy_framework_content "$target"
  git -C "$target" init -q
  write_version_file "$target" "$version" "$export_date"
  seed_adopter_state "$target" "$SLUG"
  swap_adopter_root_agent "$target"
  write_slug_files "$target" "$SLUG"

  # D-7.3 / D-7.5 run before the initial commit too — a fresh git init has
  # no remotes and no history, so this should always pass; it is here to
  # keep the "every invocation" guarantee uniform across flows.
  assert_remote_severance "$target"
  scrub_framework_history "$target"
  assert_no_framework_history "$target"

  git -C "$target" add -A
  git -C "$target" commit -q -m "feat: initialize adopter repo from AgenticCore release $version [$SLUG]"

  log "Flow A complete. Adopter repo initialized at: $target"
  log "  release: $version"
  log "  slug:    $SLUG"
}

# ---------------------------------------------------------------------------
# Flow B — re-home into existing customer tree (D-7.1, D-7.2, D-7.5 approach a)
# ---------------------------------------------------------------------------
do_flow_rehome() {
  local target="$1"
  log "==> Flow B (re-home into existing tree): $target"

  if [ ! -d "$target" ] || ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    err "Flow B requires an existing git repository at --target"
    exit 1
  fi

  # D-7.4 idempotence: already re-homed?
  if [ -f "$target/framework-version.txt" ]; then
    log "Target already carries framework-version.txt — no-op (D-7.4 idempotence)."
    cat "$target/framework-version.txt" 2>/dev/null || true
    assert_remote_severance "$target" || return $?
    assert_no_framework_history "$target" || return $?
    log "Existing baseline verified clean (D-7.3, D-7.5 assertions pass)."
    return 0
  fi

  # D-7.2 — dirty-tree guard (Flow B only; --force overrides THIS ONLY)
  local status_output
  status_output="$(git -C "$target" status --porcelain 2>/dev/null || true)"
  if [ -n "$status_output" ]; then
    if [ "$FORCE" -eq 1 ]; then
      warn "target working tree is not clean; proceeding because --force was given (D-7.2 dirty-tree guard override ONLY — this does not weaken D-7.3 or D-7.5)."
    else
      err "D-7.2 safety interlock: target working tree is not clean (uncommitted changes or untracked files). Aborting with NO changes made."
      err "Dirty status:"
      printf '%s\n' "$status_output" | sed 's/^/  /' >&2
      err "Re-run with --force to override this guard only, after reviewing the above."
      exit 4
    fi
  fi

  prompt_for_slug
  if ! validate_slug "$SLUG"; then
    exit 7
  fi

  local version export_date
  version="$(resolve_release_version)"
  export_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would copy framework release content from $FRAMEWORK_ROOT into $target (overlay, no clobber of tracked customer files outside framework paths)"
    dry_note "would write framework-version.txt (release=$version, exported=$export_date)"
    dry_note "would write slug '$SLUG' to AGENT.md and PROCESS.md (tasks.yaml slug is set via seed_adopter_state's header substitution)"
    dry_note "would sever any framework-resolving remote/config in $target"

    # TC-051 — classification preview. Build the framework manifest from a
    # scratch copy (never touches $target) and report what WOULD be staged
    # as framework content vs. what pre-existing customer content WOULD be
    # left for the operator to classify. Zero side effects on $target:
    # only a throwaway scratch dir is created/removed, and the
    # classification report below is printed, never written to disk.
    local dr_scratch dr_manifest dr_customer
    dr_scratch="$(mktemp -d "${TMPDIR:-/tmp}/export-framework-dryrun-manifest.XXXXXX")"
    dr_manifest="$(mktemp "${TMPDIR:-/tmp}/export-framework-dryrun-manifest-list.XXXXXX")"
    dr_customer="$(mktemp "${TMPDIR:-/tmp}/export-framework-dryrun-customer-list.XXXXXX")"
    trap 'rm -rf "$dr_scratch"; rm -f "$dr_manifest" "$dr_customer"' RETURN
    _copy_framework_content_raw "$dr_scratch"
    write_framework_manifest "$dr_scratch" "$dr_manifest"
    collect_customer_entries "$target" "$dr_manifest" "$dr_customer"
    local dr_fw_count dr_cust_count
    # RF-011 — `grep -zc` prints the count AND exits 1 when that count is
    # zero (an empty manifest has zero NUL-delimited records to match).
    # The previous `|| echo 0` fallback fired on that exit-1-with-0-output
    # case too, appending a SECOND "0" line on top of the "0" grep already
    # printed, corrupting $dr_fw_count into a two-line "0\n0" string.
    # `|| true` avoids ever writing to stdout on the fallback path — grep's
    # own count line (0 or otherwise) is the only thing $() ever captures,
    # regardless of grep's exit code.
    dr_fw_count="$(grep -zc '' "$dr_manifest" 2>/dev/null || true)"
    dr_cust_count="$(wc -l < "$dr_customer" | tr -d ' ')"
    dry_note "classification preview: $dr_fw_count framework path(s) would be staged"
    dry_note "classification preview: $dr_cust_count pre-existing customer path(s) would be left untracked for operator classification"
    if [ "$dr_cust_count" -gt 0 ]; then
      dry_note "customer paths (would need gitignore-or-add decision):"
      sed 's/^/    /' "$dr_customer" >&2
    fi
    dry_note "would write .framework-rehome-report.txt listing the above for the operator (report-only; NOT written in dry-run)"
    seed_adopter_state "$target" "$SLUG"
    swap_adopter_root_agent "$target"
    dry_note "would create a commit recording release $version, staged to framework manifest paths ONLY (never a blind 'git add -A')"
    assert_remote_severance "$target" || return $?
    assert_no_framework_history "$target" || return $?
    log "[dry-run] zero side effects — report only."
    return 0
  fi

  # SF-066 approach (a), implemented even more strongly than literally
  # described: copy_framework_content does a plain `tar` extraction of
  # $FRAMEWORK_ROOT's WORKING TREE into this scratch dir, excluding `.git`
  # entirely (see copy_framework_content's exclude_patterns) — there is no
  # `git clone` here, throwaway or otherwise, and no framework .git is ever
  # created anywhere in this flow. This guarantees the adopter's existing
  # object store is never touched by a framework git object at all, so
  # D-7.5 never has "framework objects introduced" to scrub in the normal
  # path — the assertion below is a verification of that guarantee, not a
  # remediation of expected pollution. (SF-071: earlier comments in this
  # file described this scratch dir as a "throwaway clone" — corrected;
  # it never had a .git of its own.)
  #
  # RF-009 — all three temp paths this function creates (throwaway,
  # manifest_file, customer_entries_file) are covered by ONE combined
  # RETURN trap set up front, declared local with empty-string defaults so
  # the trap body (which references all three) never trips `set -u` before
  # each is actually assigned. This protects every early exit in this
  # function — including `assert_remote_severance "$target"` /
  # `assert_no_framework_history "$target"` below, which abort via
  # set -e/D-7.3/D-7.5 non-zero return with no `|| return` guard — not just
  # the final success path. `rm -rf`/`rm -f` on an empty or already-removed
  # path is a harmless no-op, so this trap firing after this function's own
  # manual cleanup already ran (the normal path) does no damage.
  local throwaway="" manifest_file="" customer_entries_file=""
  # RF-014 — self-disarming trap: `trap - RETURN` inside the body clears the
  # RETURN trap as its first action so it fires exactly once and does not stay
  # globally armed after do_flow_rehome returns. This gives parity with
  # write_framework_manifest / collect_customer_entries (which clear their trap
  # on their single return path) and closes the latent case where a leftover
  # armed trap could fire again in a caller's scope — referencing these now
  # out-of-scope locals — and abort under `set -u`. Reachable only via
  # unsupported direct-sourcing; fixed here for consistency regardless.
  trap 'trap - RETURN; rm -rf "$throwaway" 2>/dev/null || true; rm -f "$manifest_file" "$customer_entries_file" 2>/dev/null || true' RETURN

  throwaway="$(mktemp -d "${TMPDIR:-/tmp}/export-framework-rehome.XXXXXX")"

  copy_framework_content "$throwaway"

  # TC-051 — capture the framework manifest from the scratch copy BEFORE it
  # is overlaid into the target and removed. This is the authoritative,
  # deterministic definition of "framework content" for this export — see
  # write_framework_manifest's header comment. Must happen before the
  # `rm -rf "$throwaway"` below.
  manifest_file="$(mktemp "${TMPDIR:-/tmp}/export-framework-manifest.XXXXXX")"
  write_framework_manifest "$throwaway" "$manifest_file"

  # Overlay: copy framework files into the existing adopter tree. This is a
  # working-tree file copy only — no git object transfer of any kind.
  ( cd "$throwaway" && tar -c . ) | ( cd "$target" && tar -x )
  rm -rf "$throwaway"
  throwaway=""

  write_version_file "$target" "$version" "$export_date"
  seed_adopter_state "$target" "$SLUG"
  swap_adopter_root_agent "$target"
  write_slug_files "$target" "$SLUG"

  # TC-051 — extend the manifest with the generated files this script
  # writes directly into $target. framework-version.txt is genuinely new
  # (never part of $FRAMEWORK_ROOT, so write_framework_manifest above could
  # not have seen it). AGENT.md / PROCESS.md are DIFFERENT — RF-010: they
  # already exist in $FRAMEWORK_ROOT and are not in
  # FRAMEWORK_EXCLUDE_PATTERNS, so write_framework_manifest's `find` walk
  # already picked them up; write_slug_files only edits their CONTENT
  # in-place (slug insertion), it does not create new paths. Re-adding
  # them here is therefore defensive/idempotent, not a fix for an absence —
  # `git add --pathspec-from-file` tolerates a duplicate path in the list
  # (harmless no-op on the second occurrence), so this costs nothing and
  # guards against a future change to write_slug_files ever creating one
  # of these files where it didn't already exist.
  #
  # SF-117/SF-122/SF-123/SF-127 — the seed_adopter_state() paths (tasks.yaml,
  # .core/agents/_context.md, bench-registry.yaml, mddocs/backlog.md) are
  # DIFFERENT again: they ARE in
  # FRAMEWORK_EXCLUDE_PATTERNS, so
  # write_framework_manifest's walk of the throwaway scratch copy never
  # saw them at all (they were tar --exclude'd before the scratch copy was
  # even created) — unlike AGENT.md/PROCESS.md, these paths are genuinely
  # absent from the manifest and MUST be added here or the subsequent
  # manifest-scoped `git add -f --pathspec-from-file` silently drops them
  # from the re-home commit despite having just written them to disk.
  printf 'framework-version.txt\0' >> "$manifest_file"
  local _slugfile
  for _slugfile in AGENT.md PROCESS.md; do
    if [ -f "$target/$_slugfile" ]; then
      printf '%s\0' "$_slugfile" >> "$manifest_file"
    fi
  done
  local _seedfile
  for _seedfile in "${SEED_RELATIVE_PATHS[@]}"; do
    if [ -f "$target/$_seedfile" ]; then
      printf '%s\0' "$_seedfile" >> "$manifest_file"
    fi
  done

  # Sever any framework-resolving push path that might already exist in the
  # adopter repo (e.g. from a manual clone-then-move procedure done before
  # running this script), then verify.
  sever_framework_remotes "$target"
  # RF-009 — `|| return $?` (not a bare call) is required for the combined
  # RETURN trap above to actually fire on this assertion's failure path.
  # Under `set -euo pipefail`, an unguarded non-zero return from a function
  # call kills the script immediately WITHOUT unwinding through any RETURN
  # trap — bash only runs a function's RETURN trap on an actual `return`
  # from that function, not on a set -e-triggered abort. Routing the
  # non-zero exit through an explicit `return $?` here preserves the exact
  # same exit code and stderr output D-7.3 already produces (assert_remote_-
  # severance's own `err` calls happen before it returns either way) while
  # ensuring $throwaway/$manifest_file/$customer_entries_file are still
  # cleaned up on this path.
  assert_remote_severance "$target" || return $?

  # D-7.5: since approach (a) never introduced framework objects, this is a
  # verification pass. If prior manual steps DID introduce framework
  # objects/refs (e.g. the 9-step manual procedure that motivated TC-050),
  # scrub them too before asserting.
  scrub_framework_history "$target"
  # RF-009 — same rationale as assert_remote_severance above.
  assert_no_framework_history "$target" || return $?

  # TC-051 — reconciliation report. Compute pre-existing customer content
  # (untracked entries NOT in the framework manifest) BEFORE staging, so
  # the report reflects the tree as the operator will see it in
  # `git status` immediately after this script exits: framework paths
  # staged, customer paths untouched and untracked.
  local report_file
  customer_entries_file="$(mktemp "${TMPDIR:-/tmp}/export-framework-customer.XXXXXX")"
  collect_customer_entries "$target" "$manifest_file" "$customer_entries_file"
  report_file="$target/.framework-rehome-report.txt"
  write_reconciliation_report "$target" "$report_file" "$version" "$export_date" "$customer_entries_file"

  # TC-051 — replace the blind `git add -A` (which would have swept the
  # ENTIRE customer tree, including everything the report above just
  # flagged for operator classification, into the framework re-home
  # commit with no classification at all) with manifest-scoped staging.
  # Only paths present in the framework manifest (plus the generated
  # files added to it above) are staged. `--pathspec-from-file` with
  # `--pathspec-file-nul` consumes the NUL-delimited manifest exactly,
  # so a framework path containing a space or other shell metacharacter
  # is staged correctly. `-f` is required because a framework path may
  # legitimately fall under a customer .gitignore rule the framework
  # itself does not control (e.g. a broad customer `*.txt` rule) — this
  # script's own manifest is the authority on what is framework content,
  # not the customer's pre-existing ignore rules.
  git -C "$target" add -f --pathspec-from-file="$manifest_file" --pathspec-file-nul --
  rm -f "$manifest_file" "$customer_entries_file"
  manifest_file=""
  customer_entries_file=""
  trap - RETURN

  git -C "$target" commit -q -m "feat: re-home AgenticCore release $version into existing tree [$SLUG]"

  log "Flow B complete. Framework re-homed into: $target"
  log "  release: $version"
  log "  slug:    $SLUG"
  if [ -s "$report_file" ]; then
    local flagged_count
    flagged_count="$(grep -c '^  - ' "$report_file" 2>/dev/null || echo 0)"
    log "  reconciliation report: $report_file"
    log "    $flagged_count pre-existing customer path(s) left untracked for your classification."
    log "    Review the report, then gitignore or 'git add' each as appropriate — before your next commit."
  fi
}

# ---------------------------------------------------------------------------
# D-7.1 — Flow detection
# ---------------------------------------------------------------------------
detect_flow() {
  local target="$1"

  if [ -n "$FLOW" ]; then
    printf '%s' "$FLOW"
    return 0
  fi

  if [ ! -e "$target" ]; then
    printf 'empty'
    return 0
  fi

  if [ -d "$target" ]; then
    local entries
    entries="$(find "$target" -mindepth 1 -maxdepth 1 2>/dev/null || true)"
    if [ -z "$entries" ]; then
      printf 'empty'
      return 0
    fi
    if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
      printf 'rehome'
      return 0
    fi
    # Non-empty, not a git repo — ambiguous. Do not guess.
    err "flow detection ambiguous: '$target' exists, is non-empty, and is not a git repository."
    err "Specify explicitly: --flow empty (to git-init anyway) or --flow rehome (if it will become one)."
    exit 2
  fi

  err "flow detection ambiguous: '$target' is not a directory."
  exit 2
}

# ---------------------------------------------------------------------------
# Main
#
# Guarded so this script can be `source`d by a test harness to exercise
# individual functions (e.g. assert_remote_severance) in isolation without
# triggering the full flow. See mddocs/scripts/test-export-framework-severance.sh.
# ---------------------------------------------------------------------------
if [ "${EXPORT_FRAMEWORK_SOURCED:-0}" != "1" ]; then
  # TC-085: prompt for --target if omitted, then confirm before mkdir -p.
  # Runs inside this guard so sourcing (EXPORT_FRAMEWORK_SOURCED=1) never
  # triggers interactive prompts or the mkdir decision point.
  prompt_for_target
  if [ "$DRY_RUN" -eq 0 ] && [ "$YES" -eq 0 ]; then
    confirm_target
  fi

  guard_target_identity

  FLOW_SELECTED="$(detect_flow "$TARGET")"

  case "$FLOW_SELECTED" in
    empty)  do_flow_empty "$TARGET" ;;
    rehome) do_flow_rehome "$TARGET" ;;
    *) err "internal error: unresolved flow '$FLOW_SELECTED'"; exit 1 ;;
  esac

  # ---------------------------------------------------------------------------
  # FF-6 / TC-062 — minimum-viable cold-start pointer. A fresh adopter has a
  # stood-up management plane but no framework fluency: they don't know
  # agentic assistance is the intended mode, which session-open phrase to
  # use, or that .00/.01/.02+ benches exist. Print once, flow-agnostic,
  # after either flow completes. --dry-run has zero side effects (D-7.4) and
  # never sees this block.
  # ---------------------------------------------------------------------------
  if [ "$DRY_RUN" -ne 1 ]; then
    cold_start_release="$(grep '^release:' "$TARGET/framework-version.txt" 2>/dev/null | cut -d' ' -f2-)"
    cold_start_release="${cold_start_release:-unknown}"
    log ""
    log "You are here — adopter management plane ready"
    log ""
    log "Created: an agentic management plane initialized from AgenticCore release"
    log "$cold_start_release, at: $TARGET"
    log ""
    log "Agentic assistance is the intended operating mode for this framework."
    log ""
    log "Next: open an agentic session (OpenCode or compatible runtime) in that directory and say:"
    log "  \"Lead-engineer, session open\""
    log ""
    log "Persona: as an adopter you operate as lead-engineer for your own project —"
    log "distinct from framework development (baseline-steward)."
    log ""
    log ".00 (HIL) / .01 (lead-engineer) / .02+ (worker) benches may be provisioned as"
    log "needed. Read more: mddocs/reference.architecture/bootstrap-new-project.md"
  fi
fi
