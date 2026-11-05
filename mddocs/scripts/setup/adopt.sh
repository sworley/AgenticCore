#!/usr/bin/env bash
# adopt.sh — Single-command adopter onboarding wrapper (README Quick Start
# (Adopter) steps 3-7).
#
# PURPOSE
#   Wraps the POST-CLONE steps of the README Quick Start (Adopter) into one
#   command:
#     Step 3  — confirm the target path, create the target project directory,
#               and canonicalize to an absolute path (AP-084, AP-085)
#     Step 4  — run export-framework.sh into that target
#     Step 6  — validate the exported target (check-env.sh + mdbook build)
#     Step 7  — agent runtime configuration (OpenCode uses committed opencode.json directly)
#
#   Step 2 (clone the framework) and Step 8 (open an agentic session) remain
#   manual — see the printed instruction at the end of this script for Step 8.
#
#   This script ORCHESTRATES existing tooling only. It calls
#   export-framework.sh for the export/adoption logic (ADR-0015 D-1, D-5,
#   D-7) and does not reimplement any part of it — in particular, no D-7
#   confidentiality control (dirty-tree guard, remote severance, history
#   scrub, target-identity guard) is duplicated or altered here. Every
#   export-framework.sh exit code is surfaced faithfully; a non-zero export
#   exit aborts this script immediately with no further steps run.
#
# USAGE
#   adopt.sh --target <dir> --slug <SLUG> [--flow empty|rehome] [--tool none|opencode|codex]
#            [--regen] [--dry-run] [--force]  [-y|--yes]
#
# ARGUMENTS
#   --target <dir>          Target directory for the adopter repo.
#                            If omitted and stdin is a TTY, prompted
#                            interactively with a suggested path derived from
#                            the AP-074 convention. Required in non-interactive
#                            mode (exit 1 if absent and stdin is not a TTY).
#                            ALWAYS echoed back and confirmed (y/N) before
#                            mkdir -p, unless -y/--yes is passed.
#   --slug <SLUG>            Adopter project slug — non-empty uppercase ASCII
#                            (required in non-interactive mode; prompted if
#                            omitted and stdin is a TTY, same behavior as
#                            export-framework.sh — this script does not
#                            re-validate or re-prompt, it delegates entirely).
#   --flow empty|rehome     Pass-through to export-framework.sh (explicit
#                            flow selection; usually left to auto-detect).
#   --tool none|opencode|codex
#                            Agent-runtime adapter to generate (default: none).
#                            The harness core is tool-agnostic; adapters are
#                            produced on demand by tool-adapter.sh. none = bring
#                            your own tool (no prescription).
#   --dry-run                Pass-through to export-framework.sh AND skips
#                            every mutating step in this script (mkdir,
#                            validation, agent configuration gen). Zero side
#                            effects end to end. Reports what would happen.
#   --force                  Pass-through to export-framework.sh. Scoped by
#                            export-framework.sh itself to the Flow B
#                            dirty-tree guard ONLY — this script adds no
#                            force of its own to anything.
#      Skip Step 7 (agent settings generation).
#                            Use this if you plan to use OpenCode only —
#                            OpenCode needs no generation step.
#   -y, --yes                Skip the explicit confirmation prompt before
#                            mkdir -p (non-interactive / scripted adoption).
#                            Does NOT skip the slug prompt — export-framework.sh
#                            is the authority on that.
#   -h, --help               Show this help and exit.
#
# EXIT CODES
#   0  Success
#   1  Argument/usage error (this script's own arg parsing)
#   Any export-framework.sh exit code (2-7) — surfaced verbatim when the
#     export step fails; see export-framework.sh's own header for the
#     meaning of each. This script adds no exit codes of its own beyond 0/1.
#   8  Post-export validation failed (check-env.sh and/or mdbook build) —
#      the target was already created by a successful export; this code
#      reports a validation failure, it does not mean the export failed.
#   9  agent settings generation failed (Step 7)
#
# EXAMPLES
#   # Preview only — zero side effects
#   adopt.sh --target ~/dev/my-project --slug ACME --dry-run
#
#   # Real run, greenfield target
#   adopt.sh --target ~/dev/my-project --slug ACME
#
#   # Real run with a RELATIVE path (AP-084: canonicalized to absolute before use)
#   adopt.sh --target ./my-project --slug ACME
#
#   # Non-interactive adoption (skip confirmation prompt)
#   adopt.sh --target ~/dev/my-project --slug ACME --yes
#
#   # Re-home into an existing repository, skip agent configuration (OpenCode only)
#   adopt.sh --target ~/dev/existing-repo --slug ACME --flow rehome \
#     
#
#   # The .01 management-layer suffix is always appended (base -> <base>.01):
#   #   --target ~/dev/my-project        -> ~/dev/my-project.01
#   #   --target ~/dev/myproject.v0.01   -> ~/dev/myproject.v0.01.01
#
# See also:
#   mddocs/scripts/export-framework.sh                       (does the export)
#   mddocs/scripts/check-env.sh                               (Step 6)
# #   mddocs/reference.architecture/bootstrap-new-project.md     (full procedure)
#   mddocs/adr/adr-0015-framework-distribution-adoption-model.md (D-7)

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-locate the framework repo root (ADR-0017 Convention 1). This script
# lives at mddocs/scripts/setup/adopt.sh, so the framework root is three
# levels up. pwd -P (physical) matches the convention used by
# export-framework.sh's own self-location so a symlinked invocation path
# still canonicalizes consistently.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
EXPORT_SCRIPT="$FRAMEWORK_ROOT/mddocs/scripts/export-framework.sh"

# ---------------------------------------------------------------------------
# Logging helpers (mirrors export-framework.sh's style)
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
# Defaults / arg parsing
# ---------------------------------------------------------------------------
TARGET=""
SLUG=""
FLOW=""
DRY_RUN=0
FORCE=0
YES=0   # AP-085: -y/--yes skips the mkdir confirmation prompt
TOOL="none"   # tool-neutral default — adapter generated on demand (tool-adapter.sh)
TOOL_SET=0    # 1 when --tool was supplied explicitly (vs. prompt-default)
REGEN=0       # 1 when --regen: regenerate agents/models (skip export on existing tree)

usage() {
  cat >&2 << 'EOF'
Usage: adopt.sh [--target <dir>] --slug <SLUG> [--flow empty|rehome] [--dry-run]
                [--force]  [-y|--yes]

Single-command adopter onboarding — wraps README Quick Start (Adopter)
steps 3-7 (create target, run export, validate, generate agent configuration).
Step 2 (clone) and Step 8 (open an agentic session) remain manual.

  --target <dir>          Target directory (the adopter's BASE project name).
                          Prompted interactively if omitted and stdin is a
                          TTY (following AP-074's convention:
                          <workdir>/<toolset>/<host>/<group>/<project>).
                          ALWAYS confirmed before mkdir -p (skippable with -y).
                          The `.01` management-layer suffix is ALWAYS appended:
                          `./my-project` -> `./my-project.01`, and
                          `./myproject.v0.01` -> `./myproject.v0.01.01`.
  --slug <SLUG>           Adopter project slug (non-empty uppercase ASCII;
                          prompted if omitted and stdin is a TTY)
  --flow empty|rehome     Pass-through to export-framework.sh
  --tool none|opencode|codex
                          Agent-runtime adapter to generate (default: none).
                          The harness core is tool-agnostic; adapters are
                          generated on demand. none = bring your own tool.
  --regen                 Force-regenerate the agent adapter and re-apply the
                          model distribution, refreshing the framework's
                          canonical agent source + setup scripts into the
                          target (preserving its .agents/model-profile.yaml).
                          On an existing framework export this skips the full
                          re-export and updates agents/models in place.
  --dry-run               Pass-through to export-framework.sh; also skips
                          every mutating step in this script — zero side
                          effects end to end
  --force                 Pass-through to export-framework.sh (scoped by
                          export-framework.sh to the Flow B dirty-tree
                          guard ONLY)
                          use if you plan to use OpenCode only
  -y, --yes               Skip the mkdir confirmation prompt (non-interactive
                          / scripted adoption)
  -h, --help              Show this help and exit

Examples:
  adopt.sh --target ~/dev/my-project --slug ACME --dry-run
  adopt.sh --target ~/dev/my-project --slug ACME
  adopt.sh --target ./my-project --slug ACME             # relative path OK (AP-084)
  adopt.sh --slug ACME                                    # prompted for --target
  adopt.sh --target ~/dev/my-project --slug ACME --yes    # no confirm
  adopt.sh --target ~/dev/existing-repo --slug ACME --flow rehome
  adopt.sh --target ~/dev/my-project --slug ACME --tool opencode   # generate opencode adapter
  adopt.sh --target ~/dev/my-project --slug ACME --tool codex      # generate codex adapter
  # --target is the base name; .01 is appended -> <name>.01

This script orchestrates existing tooling only:
  export-framework.sh    — the export/adoption logic (ADR-0015 D-7)
  check-env.sh            — environment validation

Every export-framework.sh exit code is surfaced verbatim; a non-zero export
exit aborts immediately with no further steps run. See
mddocs/adr/adr-0015-framework-distribution-adoption-model.md D-7.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)               TARGET="$2"; shift 2 ;;
    --slug)                 SLUG="$2"; shift 2 ;;
    --flow)                 FLOW="$2"; shift 2 ;;
    --tool)                 TOOL="$2"; TOOL_SET=1; shift 2 ;;
    --regen)                 REGEN=1; shift ;;
    --dry-run)               DRY_RUN=1; shift ;;
    --force)                 FORCE=1; shift ;;
      -y|--yes)                YES=1; shift ;;
    -h|--help)               usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# AP-085: --target prompt / confirm decision point
#
# If --target was omitted: prompt interactively (mirroring prompt_for_slug's
# pattern in export-framework.sh) when stdin is a TTY; fail clearly in
# non-interactive mode.
#
# Whether supplied by flag or prompt: ALWAYS echo the resolved path and
# require explicit confirmation (y/N) before mkdir -p — unless -y/--yes was
# passed for non-interactive / scripted adoption.
#
# The AP-074 convention for --target:
#   <workdir>/<toolset>/<host>/<group>/<project>
# e.g. ~/dev/git/git.example.com/acme-group/acme-project
# The suggestion below derives <workdir> from the current directory so the
# adopter sees a concrete, contextual example rather than an abstract template.
# ---------------------------------------------------------------------------
prompt_for_target() {
  # Derive a suggested path: <cwd>/<basename-of-cwd> as a minimal anchor (the
  # .01 management-layer suffix is appended later by normalize_target_plane).
  # In the common "I cloned into ./AgenticCore" pattern, the cwd is the
  # parent of the clone — this gives "~/dev/my-project" as a suggestion.
  # Adopters running from inside the clone will see the clone dir's parent.
  local _suggested
  _suggested="$(pwd)/$(basename "$(pwd)")"

  printf '\n' >&2
  printf 'No --target supplied. Where should the adopter project directory be created?\n' >&2
  printf '\n' >&2
  printf 'AP-074 convention:  <workdir>/<toolset>/<host>/<group>/<project>\n' >&2
  printf 'Example (full):     ~/dev/git/git.example.com/acme-group/my-project\n' >&2
  printf 'Example (minimal):  ~/dev/my-project\n' >&2
  printf '\n' >&2
  printf 'The .01 management-layer suffix is appended automatically (my-project -> my-project.01).\n' >&2
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
  # Echo the resolved --target path and require explicit y/N before mkdir -p.
  # Called whether --target came from a flag or a prompt.
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

# ---------------------------------------------------------------------------
# normalize_target_plane — append the `.01` management-plane suffix to TARGET.
#
# `--target` is the adopter's BASE project identity. The management layer is
# ALWAYS this base + `.01` (e.g. `myproject.v0.01` -> `myproject.v0.01.01`),
# enforced onto the `.01` namespace that the agent runtime, bench provisioning,
# and personae all key off. Benches are provisioned as siblings of that layer in
# the SAME parent (`myproject.v0.01.00`, `myproject.v0.01.02`, ...), matching how
# `.00` is auto-materialized as a sibling worktree. Always appended — even when
# the base already ends in `.01`, so a base `myproject.v0.01` becomes the
# management layer `myproject.v0.01.01`. Apply this BEFORE the confirmation
# prompt so the adopter sees (and confirms) the real `.01` path.
# ---------------------------------------------------------------------------
normalize_target_plane() {
  TARGET="${TARGET%/}"
  local _base
  _base="$(basename "$TARGET")"
  TARGET="$(dirname "$TARGET")/${_base}.01"
}

# ---------------------------------------------------------------------------
# prompt_for_tool — interactive pick of the agent-runtime adapter (when
# --tool was NOT supplied and stdin is a TTY). The harness core is
# tool-agnostic; this only surfaces the choice so adoption never prescribes a
# tool by surprise. Default: none (bring your own). Scripted / non-interactive
# use keeps TOOL as given (or none).
# ---------------------------------------------------------------------------
prompt_for_tool() {
  printf '\n' >&2
  printf 'Agent runtime adapter? (the harness core is tool-agnostic)\n' >&2
  printf '  none      bring your own tool (default)\n' >&2
  printf '  opencode  generate opencode adapter (local config + start-opencode.sh)\n' >&2
  printf '  codex     generate codex adapter (reference + start-codex.sh)\n' >&2
  printf '\n' >&2
  printf 'Select (none/opencode/codex, default none): ' >&2
  read -r _tool_in
   case "$_tool_in" in
     ""|none)          TOOL="none" ;;
     opencode|codex)   TOOL="$_tool_in" ;;
     *) err "unknown tool: $_tool_in — defaulting to none"; TOOL="none" ;;
   esac
}

# ---------------------------------------------------------------------------
# regen_adapter — regenerate the agent runtime adapter + re-apply the model
# distribution, refreshing the framework's canonical agent source and setup
# scripts into the target. Preserves the adopter's .agents/model-profile.yaml
# so their configured models survive the refresh. Used by --regen to update a
# project to newer agents/models in place, without a full re-export.
# ---------------------------------------------------------------------------
regen_adapter() {
  local src_agents="$FRAMEWORK_ROOT/.agents"
  local dst_agents="$TARGET/.agents"
  local profile_backup=""

  # Preserve the adopter's model profile across the refresh.
  if [ -f "$dst_agents/model-profile.yaml" ]; then
    profile_backup="$dst_agents/model-profile.yaml.$$"
    cp "$dst_agents/model-profile.yaml" "$profile_backup"
  fi

  log "==> regen: refreshing canonical agent source + setup scripts"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would refresh .agents/ + setup scripts from $FRAMEWORK_ROOT"
  else
    cp -f "$FRAMEWORK_ROOT/mddocs/scripts/setup/tool-adapter.sh" "$TARGET/mddocs/scripts/setup/"
    cp -f "$FRAMEWORK_ROOT/mddocs/scripts/setup/model-distribution.sh" "$TARGET/mddocs/scripts/setup/"
    chmod +x "$TARGET/mddocs/scripts/setup/tool-adapter.sh" "$TARGET/mddocs/scripts/setup/model-distribution.sh"
    # Refresh canonical agent source, leaving the adopter's model profile alone.
    ( cd "$src_agents" && tar -c --exclude='model-profile.yaml' . ) | ( cd "$dst_agents" && tar -x )
    if [ -n "$profile_backup" ]; then
      mv "$profile_backup" "$dst_agents/model-profile.yaml"
    fi
  fi

  log "==> regen: regenerating agent adapter (--tool $TOOL)"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would run: ./mddocs/scripts/setup/tool-adapter.sh --tool $TOOL"
  elif ! ( cd "$TARGET" && ./mddocs/scripts/setup/tool-adapter.sh --tool "$TOOL" ); then
    warn "tool-adapter.sh reported a failure during regen (post-export, does not undo the tree)"
  fi

  log "==> regen: applying model distribution"
  if [ "$DRY_RUN" -eq 1 ]; then
    dry_note "would run: ./mddocs/scripts/setup/model-distribution.sh --apply"
  elif ! ( cd "$TARGET" && ./mddocs/scripts/setup/model-distribution.sh --apply ); then
    warn "model-distribution.sh --apply reported a failure (optional step)"
  fi
}

# ---------------------------------------------------------------------------
# is_framework_export — 1 when the target already looks like an AgenticCore
# framework export (has the tool-adapter). Used by --regen to decide whether
# to regenerate in place (skip the full re-export) or export first.
# ---------------------------------------------------------------------------
is_framework_export() {
  [ -x "$TARGET/mddocs/scripts/setup/tool-adapter.sh" ]
}

if [ -z "$TARGET" ]; then
  if [ ! -t 0 ]; then
    err "--target is required in non-interactive mode (stdin is not a tty)"
    usage
    exit 1
  fi
  prompt_for_target
fi
# BASE_TARGET is the adopter's raw base name (the --target value as given).
# When we hand off to export-framework.sh we pass THIS so export applies the
# .01 normalization once (it is the single authority on the plane path).
# TARGET is then normalized to the `.01` management plane for this script's own
# confirmation / mkdir / Steps 6-7 bookkeeping.
BASE_TARGET="$TARGET"
normalize_target_plane

# --regen against an existing framework export: refresh agent source + setup
# scripts and regenerate the adapter/models in place. Skip the full re-export,
# the mkdir confirmation, and validation — this is an in-place update, not a
# fresh adoption.
if [ "$REGEN" -eq 1 ] && ! [ "$DRY_RUN" -eq 1 ]; then
  if is_framework_export; then
    log "==> adopt.sh: --regen on an existing framework export at $TARGET"
    regen_adapter
    log ""
    log "==> adopt.sh: --regen complete for $TARGET (--tool $TOOL)"
    log "  To open an agentic session:"
    log "  cd $TARGET"
    if [ "$TOOL" = "opencode" ]; then
      log "  ./start-opencode.sh"
    else
      log "  (open your agent runtime of choice)"
    fi
    log "  Say: \"Lead-engineer, session open\""
    exit 0
  fi
  warn "--regen given but $TARGET is not yet a framework export — exporting fresh first, then regenerating."
fi

# Confirm the target path (show it back, require y/N) unless --yes was passed.
# This runs for both flag-supplied and prompted values, so doc example values
# ("./my-project.01") are never silently treated as real adopter intent.
if [ "$DRY_RUN" -eq 0 ] && [ "$YES" -eq 0 ]; then
  confirm_target
fi

# Surface the agent-runtime choice when --tool was not supplied (TTY only).
# Keeps adoption from silently prescribing a tool; default is none (BYO).
if [ "$TOOL_SET" -eq 0 ] && [ -t 0 ]; then
  prompt_for_tool
fi

if [ -n "$FLOW" ]; then
  case "$FLOW" in
    empty|rehome) ;;
    *) err "--flow must be one of: empty rehome"; exit 1 ;;
  esac
fi

# --tool selects the agent-runtime adapter to generate (tool-neutral default).
# The harness core is tool-agnostic; adapters are produced on demand.
case "$TOOL" in
  none|opencode|codex) ;;
  *) err "--tool must be one of: none opencode codex"; exit 1 ;;
esac

# --slug is not re-validated here — export-framework.sh is the single
# authority on slug validation and interactive prompting (do not reimplement
# it). An empty --slug is passed through as-is; export-framework.sh will
# prompt if stdin is a TTY, or fail with its own exit 7 otherwise.

if [ ! -x "$EXPORT_SCRIPT" ]; then
  err "export-framework.sh not found or not executable at: $EXPORT_SCRIPT"
  err "framework root resolved to: $FRAMEWORK_ROOT"
  exit 1
fi

log "==> adopt.sh: onboarding into $TARGET"
log "    framework root: $FRAMEWORK_ROOT"

# ---------------------------------------------------------------------------
# Step 3 — create the target project directory and canonicalize to an
# absolute path (AP-084, AP-085).
#
# AP-084: $TARGET may be a relative path (e.g. ./my-project.01 — the exact
# form used in README examples). adopt.sh's Steps 6 and 7 construct script
# paths like "$TARGET/mddocs/scripts/check-env.sh" and then run
# ( cd "$TARGET" && "$target_check_env" ). When $TARGET is relative, the cd
# changes cwd and the still-relative string re-resolves from the NEW cwd,
# looking for a doubly-nested path that never exists. Fix: canonicalize
# $TARGET to an absolute path once, immediately after mkdir -p (the directory
# must exist for `cd ... && pwd -P` to work), then use the absolute path for
# every downstream reference — mirroring export-framework.sh's own
# `target_abs="$(cd "$TARGET" && pwd -P)"` pattern (~line 373).
#
# AP-085 confirmation happened above; mkdir is the first mutating operation.
#
# Note: suffixing the target with .01 marks it as the lead-engineer
# management plane namespace (see the Bench Model doc). normalize_target_plane()
# above ALWAYS appends .01 to the given base — `--target ./my-project` lands at
# `./my-project.01`, and `--target ./myproject.v0.01` lands at
# `./myproject.v0.01.01` (the base's own trailing .01 is part of the project
# identity; the management-layer suffix is added on top). Benches are then
# provisioned as siblings: `./myproject.v0.01.00`, `./myproject.v0.01.02`, ...
#
# --dry-run: do NOT create the directory for real (zero side effects) —
# report only.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  dry_note "would create target directory: $TARGET (mkdir -p)"
else
  log "==> Step 3: creating target directory: $TARGET"
  mkdir -p "$TARGET"
  # AP-084: canonicalize to absolute path NOW (dir exists after mkdir -p).
  # Every downstream reference uses TARGET_ABS; TARGET retains the original
  # value for display purposes only.
  TARGET_ABS="$(cd "$TARGET" && pwd -P)"
  if [ "$TARGET_ABS" != "$TARGET" ]; then
    log "    resolved to: $TARGET_ABS"
  fi
  TARGET="$TARGET_ABS"
fi

# ---------------------------------------------------------------------------
# Step 4 — run export-framework.sh into the target.
#
# CRITICAL: capture the export's exit code explicitly (arithmetic under
# set -e requires this to not have the failure abort before we get to
# report it). On any non-zero exit, abort adopt.sh immediately and surface
# export-framework.sh's own message and exit code faithfully — no retry,
# no masking, no continuing to Steps 6-7.
# ---------------------------------------------------------------------------
EXPORT_ARGS=(--target "$BASE_TARGET" --slug "$SLUG")
[ -n "$FLOW" ] && EXPORT_ARGS+=(--flow "$FLOW")
[ "$DRY_RUN" -eq 1 ] && EXPORT_ARGS+=(--dry-run)
[ "$FORCE" -eq 1 ] && EXPORT_ARGS+=(--force)
# AP-085: adopt.sh already confirmed --target above (or was given --yes).
# Always pass --yes to export-framework.sh so it does not prompt a second
# time for the same path that was already confirmed at this level.
EXPORT_ARGS+=(--yes)

log "==> Step 4: running export-framework.sh"
log "    ${EXPORT_SCRIPT} ${EXPORT_ARGS[*]}"

export_exit=0
"$EXPORT_SCRIPT" "${EXPORT_ARGS[@]}" || export_exit=$?

if [ "$export_exit" -ne 0 ]; then
  err "export-framework.sh exited with code $export_exit — aborting adopt.sh."
  err "No further steps (validation, agent settings generation) will run."
  err "See export-framework.sh's own output above for the specific failure."
  exit "$export_exit"
fi

log "==> Step 4 complete: export-framework.sh exited 0"

if [ "$DRY_RUN" -eq 1 ]; then
  dry_note "would run Step 6 validation (check-env.sh + mdbook build) in $TARGET"
  dry_note "would run Step 7 (tool adapter) in $TARGET for --tool $TOOL"
  log ""
  log "[dry-run] zero side effects — report only. Nothing was created or written."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 6 — validate the exported target.
#
# Runs check-env.sh and `mdbook build` INSIDE the target (the target already
# exists at this point because export-framework.sh exited 0 above). A
# validation failure here is surfaced as a non-zero exit, but it is
# POST-export — the target has already been created — so this is reported
# as a validation failure, not masked as export failure or silently ignored.
# ---------------------------------------------------------------------------
log "==> Step 6: validating exported target"

validation_failed=0

target_check_env="$TARGET/mddocs/scripts/check-env.sh"
if [ -x "$target_check_env" ]; then
  log "    running: $target_check_env"
  if ! ( cd "$TARGET" && "$target_check_env" ); then
    warn "check-env.sh reported failures in $TARGET"
    validation_failed=1
  fi
else
  warn "check-env.sh not found or not executable at: $target_check_env — skipping"
  validation_failed=1
fi

if command -v mdbook >/dev/null 2>&1; then
  log "    running: mdbook build $TARGET/mddocs/"
  if ! mdbook build "$TARGET/mddocs/"; then
    warn "mdbook build failed for $TARGET/mddocs/"
    validation_failed=1
  fi
else
  warn "mdbook not found — skipping mdbook build validation. Install with: cargo install mdbook"
  validation_failed=1
fi

if [ "$validation_failed" -eq 1 ]; then
  err "Step 6 validation reported failure(s) — see warnings above."
  err "The target has already been created by export-framework.sh; this failure is"
  err "post-export and does not undo it. Resolve the reported issue(s), then re-run"
  err "check-env.sh / mdbook build directly in $TARGET."
else
  log "==> Step 6 complete: validation passed"
fi

# ---------------------------------------------------------------------------
# Step 7 — generate/configure the agent-runtime adapter (tool-adapter.sh).
#
# The harness core is TOOL-AGNOSTIC (roles, process, benches, MCP servers).
# tool-adapter.sh emits an OPTIONAL adapter for a chosen runtime, driven by
# --tool (default: none = bring your own). It does not prescribe a tool.
# Step 8 — NOT executed here. Print the exact copy-pasteable instruction,
# matching export-framework.sh's own cold-start pointer tone.
# ---------------------------------------------------------------------------
TOOL_ADAPTER="$TARGET/mddocs/scripts/setup/tool-adapter.sh"
if [ -x "$TOOL_ADAPTER" ]; then
  log "==> Step 7: configuring tool adapter (--tool $TOOL)"
  if ! ( cd "$TARGET" && "$TOOL_ADAPTER" --tool "$TOOL" ); then
    warn "tool-adapter.sh reported a failure in $TARGET (post-export, does not undo the export)"
  fi
else
  warn "tool-adapter.sh not found at: $TOOL_ADAPTER — skipping tool adapter generation"
fi

# --regen on a freshly exported/new target: refresh + regenerate agent source and
# re-apply the model distribution (idempotent; the existing-target path already
# exited above).
if [ "$REGEN" -eq 1 ]; then
  regen_adapter
fi

log ""
log "You are here — adopter management plane ready"
log ""
log "adopt.sh finished Steps 3-7 (create, export, validate, tool adapter)."
log "Target: $TARGET"
if [ "$validation_failed" -eq 1 ]; then
  log ""
  warn "One or more post-export steps above reported a failure — review before proceeding."
fi
log ""
if [ "$TOOL" = "none" ]; then
  log "Next step (manual):"
  log "  cd $TARGET"
  log "  [open your agent runtime of choice]"
  log "  Say: \"Lead-engineer, session open\""
  log ""
  log "The harness is tool-agnostic. To generate a runtime adapter:"
  log "  ./mddocs/scripts/setup/tool-adapter.sh --tool <opencode|codex>"
  log "See mddocs/reference.architecture/tooling-contract.md."
elif [ "$TOOL" = "opencode" ]; then
  log "Next step:"
  log "  cd $TARGET"
  log "  ./start-opencode.sh     # (or: opencode)"
  log "  Say: \"Lead-engineer, session open\""
  log ""
  log "The opencode adapter was generated: local opencode.json + start script."
else
  log "Next step:"
  log "  cd $TARGET"
  log "  ./start-codex.sh        # (or: codex)"
  log "  Say: \"Lead-engineer, session open\""
  log ""
  log "The codex adapter was generated (.codex/ reference + start script)."
fi
log ""
log "Persona: as an adopter you operate as lead-engineer for your own project —"
log "distinct from framework development (baseline-steward)."

if [ "$validation_failed" -eq 1 ]; then
  exit 8
fi

exit 0
