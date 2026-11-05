#!/usr/bin/env bash
# tool-adapter.sh — Generate/configure the agent-runtime adapter for an adopted
# AgenticCore project.
#
# The AgenticCore harness is TOOL-AGNOSTIC: roles, process gates, bench model,
# task queue, docs, and MCP servers are neutral. Each agent runtime (opencode,
# codex, ...) is a thin, regenerable ADAPTER generated from the canonical source
# in `.agents/` (agent bodies + `.agents/_meta.yaml` frontmatter) and the MCP
# servers in `mddocs/mcp/` / `mcp/`.
#
# This script is run INSIDE the adopted project root. It does not prescribe a
# tool: `--tool none` (default) leaves the tree as a bring-your-own baseline and
# only prints guidance. `--tool opencode` regenerates the opencode adapter.
# `--tool codex` writes a reference codex adapter.
#
# USAGE
#   tool-adapter.sh --tool <none|opencode|codex> [--dry-run]
#
# ARGUMENTS
#   --tool <none|opencode|codex>   Which adapter to generate/configure.
#                                  Default: none (BYO).
#   --dry-run                      Report what would happen; write nothing.
#   -h, --help                     Show this help and exit.
#
# EXIT CODES
#   0  Success
#   1  Usage/argument error
#   2  Missing canonical source (.agents/) or generator
set -eu

TOOL="none"
DRY_RUN=0

usage() {
  cat >&2 << 'EOF'
Usage: tool-adapter.sh [--tool none|opencode|codex] [--dry-run]

Generate/configure the agent-runtime adapter for an adopted AgenticCore project.
Run from the project root. The harness itself is tool-agnostic; this only emits
an optional adapter for a chosen runtime.

  --tool <none|opencode|codex>   Adapter to generate (default: none = bring your own)
  --dry-run                      Report what would happen; write nothing
  -h, --help                     Show this help and exit

Example:
  tool-adapter.sh --tool opencode   # regenerate .opencode/agents/ + confirm opencode.json
  tool-adapter.sh --tool codex      # write a reference .codex/ adapter
  tool-adapter.sh --tool none       # BYO baseline (default)

See mddocs/reference.architecture/tooling-contract.md for the tool-neutral contract.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)   TOOL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$TOOL" in
  none|opencode|codex) ;;
  *) echo "ERROR: --tool must be one of: none opencode codex" >&2; usage; exit 1 ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
dry() {
  # Always returns 0 so a non-dry-run call never trips `set -e`.
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  fi
  return 0
}

# strip_opencode_placeholder_models — remove the placeholder `model` key from
# each generated agent's frontmatter so opencode uses the user's configured
# default model (global config or `-m`) instead of an unresolvable 'provider/*'
# placeholder, which would stop the session cold.
strip_opencode_placeholder_models() {
  local f
  for f in "$REPO_ROOT"/.opencode/agents/*.md; do
    [ -f "$f" ] || continue
    python3 - "$f" << 'PY'
import sys
p = sys.argv[1]
lines = open(p).read().splitlines()
if len(lines) >= 2 and lines[0].strip() == '---':
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i
            break
    if end is not None:
        fm = [l for l in lines[1:end] if not l.startswith('model:')]
        open(p, 'w').write('\n'.join([lines[0]] + fm + lines[end:]) + '\n')
PY
  done
}

SYNC="$REPO_ROOT/.agents/sync-agents.sh"

case "$TOOL" in
  none)
    log "==> tool-adapter: --tool none (bring your own tool)"
    log ""
    log "The AgenticCore harness is tool-agnostic; no adapter was generated."
    log "The committed 'opencode.json' is a REFERENCE adapter — optional, and it may"
    log "be removed or replaced if you use a different runtime."
    log ""
    log "To pick a runtime adapter at adoption time, re-run adopt.sh with --tool, or"
    log "generate one now:"
    log "  ./mddocs/scripts/setup/tool-adapter.sh --tool opencode   # start-opencode.sh + local config"
    log "  ./mddocs/scripts/setup/tool-adapter.sh --tool codex      # start-codex.sh + .codex/"
    log ""
    log "To connect any agent runtime, honor the Tooling Contract:"
    log "  mddocs/reference.architecture/tooling-contract.md"
    ;;

  opencode)
    if [ ! -f "$REPO_ROOT/opencode.json" ]; then
      warn "opencode.json not found in $REPO_ROOT — the opencode adapter needs it."
      [ "$DRY_RUN" -eq 1 ] && { dry "would update opencode adapter"; exit 0; }
      exit 2
    fi
    if [ ! -x "$SYNC" ]; then
      warn "sync-agents.sh not found/executable at $SYNC — opencode agents not regenerated."
      [ "$DRY_RUN" -eq 1 ] && { dry "would regenerate .opencode/agents/"; exit 0; }
      exit 2
    fi
    log "==> tool-adapter: --tool opencode (generating the opencode adapter)"
    dry "would run: $SYNC"
    if [ "$DRY_RUN" -ne 1 ]; then
      bash "$SYNC"
      strip_opencode_placeholder_models
    fi
    dry "would write: $REPO_ROOT/start-opencode.sh"
    if [ "$DRY_RUN" -ne 1 ]; then
      cat > "$REPO_ROOT/start-opencode.sh" << 'EOF'
#!/usr/bin/env bash
# start-opencode.sh — launch opencode in this project with its local config.
# cd'ing here isolates the directory so opencode picks up ./opencode.json;
# your global ~/.config/opencode still applies (deep-merged).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
exec opencode "$@"
EOF
      chmod +x "$REPO_ROOT/start-opencode.sh"
      log "    wrote $REPO_ROOT/start-opencode.sh"
    fi
    log "    opencode.json present: $(test -f "$REPO_ROOT/opencode.json" && echo yes || echo no)"
    log "    .opencode/agents/ regenerated from canonical .agents/"
    log ""
    log "opencode adapter ready. Open with:"
    log "  cd $REPO_ROOT"
    log "  ./start-opencode.sh      # (or: opencode)"
    log "  Say: \"Lead-engineer, session open\""
    ;;

  codex)
    CODEX_DIR="$REPO_ROOT/.codex"
    log "==> tool-adapter: --tool codex (writing a codex adapter reference)"
    dry "would write $CODEX_DIR/README.md"
    if [ "$DRY_RUN" -ne 1 ]; then
      mkdir -p "$CODEX_DIR"
      cat > "$CODEX_DIR/README.md" << 'EOF'
# .codex — Codex CLI adapter (reference)

Codex CLI is a supported AgenticCore runtime adapter. The harness contract is
tool-neutral; this directory is a starting point you refine for your Codex version.

## How Codex connects to the harness

- The lead-engineer persona lives in the repo-root `AGENT.md` (and the
  tool-agnostic roles in `.agents/`). Point Codex at `AGENT.md` and `PROCESS.md`.
- Register the MCP servers via Codex's MCP configuration, using the same commands
  as the other runtimes:

  ```sh
  uv run mcp/review-ledger/server.py --data-path .core/review-ledger/security  --id-prefix SF --run-prefix SR
  uv run mcp/review-ledger/server.py --data-path .core/review-ledger/reviews   --id-prefix RF --run-prefix RR
  uv run mddocs/mcp/mcp-rag-docs/server.py --docs-root mddocs
  ```

- Honor the permission surface documented in `PROCESS.md` and
  `mddocs/reference.architecture/tooling-contract.md`.

## Note

Codex configuration changes frequently. Treat this adapter as reference, not an
authoritative config. See the Tooling Contract for the stable contract.
EOF
      log "    wrote $CODEX_DIR/README.md"
    fi
    dry "would write: $REPO_ROOT/start-codex.sh"
    if [ "$DRY_RUN" -ne 1 ]; then
      cat > "$REPO_ROOT/start-codex.sh" << 'EOF'
#!/usr/bin/env bash
# start-codex.sh — launch codex in this project with its local context.
# cd'ing here isolates the directory; your global codex config still applies.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
exec codex "$@"
EOF
      chmod +x "$REPO_ROOT/start-codex.sh"
      log "    wrote $REPO_ROOT/start-codex.sh"
    fi
    log ""
    log "codex adapter ready. Open with:"
    log "  cd $REPO_ROOT"
    log "  ./start-codex.sh        # (or: codex)"
    log "  Say: \"Lead-engineer, session open\""
    log "  (Refine .codex/README.md for your Codex version.)"
    ;;
esac

exit 0
