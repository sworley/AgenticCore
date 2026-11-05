#!/usr/bin/env bash
# model-distribution.sh — tailor / review the per-agent LLM model distribution.
#
# AgenticCore is tool-agnostic; this script maps a per-agent MODEL TIER profile
# (.agents/model-profile.yaml) onto the generated opencode agents so you can
# target your provider/plan and re-tune it as models evolve.
#
# USAGE
#   model-distribution.sh --review                        # report current vs profile
#   model-distribution.sh --apply [--dry-run]             # write model: into .opencode/agents/*.md
#   model-distribution.sh --detect [provider]             # list available models (models.dev)
#   model-distribution.sh -h | --help
#
# NOTES
#   - Safe by default: a placeholder model (provider/*, *default*, *placeholder*)
#     is treated as "not set" and the agent's `model:` is removed, so it falls
#     back to the session's configured default model (no cold start).
#   - Run `bash .agents/sync-agents.sh` first so .opencode/agents/*.md exist.
#   - Re-run --apply / --review periodically as new models arrive.
set -eu

MODE=""
PROVIDER="openai"
DRY_RUN=0

usage() {
  cat >&2 << 'EOF'
Usage: model-distribution.sh [--review|--apply|--detect [provider]] [--dry-run]

Tailor/review the per-agent LLM model distribution from .agents/model-profile.yaml.

  --review                  Show current per-agent models vs the profile; flag
                            placeholders and drift.
  --apply [--dry-run]       Write model: into each .opencode/agents/*.md from the
                            profile. Placeholders are stripped (fallback to the
                            session default model).
  --detect [provider]       Fetch models.dev and list models for a provider
                            (default: openai), to guide real model IDs.
  -h, --help                Show this help and exit.

Run `bash .agents/sync-agents.sh` before --apply so the agent files exist.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --review) MODE="review"; shift ;;
    --apply)  MODE="apply"; shift ;;
    --detect) MODE="detect"; shift; if [ $# -gt 0 ] && [[ "$1" != --* ]]; then PROVIDER="$1"; shift; fi ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ "$MODE" = "" ]; then
  usage; exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"
PROFILE="$REPO_ROOT/.agents/model-profile.yaml"
AGENTS_DIR="$REPO_ROOT/.opencode/agents"
META="$REPO_ROOT/.agents/_meta.yaml"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# --review: report current per-agent models vs profile (placeholders/drift)
# ---------------------------------------------------------------------------
if [ "$MODE" = "review" ]; then
  DRY_RUN=0 python3 - "$META" "$PROFILE" "$AGENTS_DIR" << 'PY'
import sys, re, os
meta, profile, agents = sys.argv[1], sys.argv[2], sys.argv[3]

def parse_meta_models(path):
    txt = open(path).read()
    # split into top-level agent blocks (indent 0)
    blocks = re.split(r'(?m)^(?=\S[^#].*:\s*$)', txt)
    out = {}
    for b in blocks:
        m = re.match(r'^([a-z][a-z0-9-]*):', b)
        if not m: continue
        name = m.group(1)
        mm = re.search(r'^(\s*)mode:\s*(\S+)', b, re.M)
        md = re.search(r'^(\s*)model:\s*(\S+)', b, re.M)
        if mm:
            out[name] = {'mode': mm.group(2), 'model': md.group(2) if md else None}
    return out

def parse_profile(path):
    if not os.path.exists(path):
        return None
    txt = open(path).read()
    default = None
    m = re.search(r'^\s*default:\s*["\']?([^\s"\']+)', txt, re.M)
    if m: default = m.group(1)
    models = dict(re.findall(r'^\s{2}([a-z]+):\s*["\']?([^\s"\']+)', txt, re.M))
    tiers = dict(re.findall(r'^\s{2}([a-z][a-z0-9-]*):\s*(\w+)', txt, re.M))
    return {'default': default, 'models': models, 'role_tiers': tiers}

def is_placeholder(v):
    return not v or 'provider/' in v or 'placeholder' in v.lower() or 'default' in v.lower()

cur = parse_meta_models(meta)
prof = parse_profile(profile)

print(f"{'role':20} {'mode':8} {'current model':28} {'profile tier/model':32} note")
print("-"*100)
for role, info in cur.items():
    cur_model = info['model']
    note = ''
    if is_placeholder(cur_model):
        note = 'PLACEHOLDER'
    if prof:
        tier = prof['role_tiers'].get(role)
        prof_model = (prof['models'].get(tier) if tier else None) or prof['default']
        rec = f"{tier or '?'}/{prof_model or '-'}"
        if not is_placeholder(cur_model) and cur_model != prof_model:
            note = (note or '') + ' DRIFT'
    else:
        rec = '-'
        note = (note or '') + ' NO-PROFILE'
    print(f"{role:20} {info['mode']:8} {(cur_model or '(none)')[:28]:28} {rec[:32]:32} {note.strip()}")
print()
if prof:
    print("Profile at .agents/model-profile.yaml. Edit `models` with real provider/model IDs, then --apply.")
else:
    print("No .agents/model-profile.yaml. Create one (see the template) to distribute models.")
PY
  exit 0
fi

# ---------------------------------------------------------------------------
# --detect: list available models for a provider (models.dev)
# ---------------------------------------------------------------------------
if [ "$MODE" = "detect" ]; then
  log "==> model-distribution: detecting models for provider '$PROVIDER' (models.dev)"
  cache="$(mktemp "${TMPDIR:-/tmp}/model-dist-detect.XXXXXX")"
  trap 'rm -f "$cache"' EXIT
  if ! timeout 20 curl -s -o "$cache" "https://models.dev/api.json"; then
    warn "could not fetch https://models.dev/api.json (network offline?)"
    exit 0
  fi
  python3 - "$cache" "$PROVIDER" << 'PY'
import sys, json
d = json.load(open(sys.argv[1]))
prov = sys.argv[2]
# collect models whose id or provider matches
rows = []
for pid, p in d.items():
    ms = p.get('models', {}) if isinstance(p, dict) else {}
    for mid in ms:
        if prov.lower() in pid.lower() or prov.lower() in mid.lower():
            rows.append((pid, mid))
rows.sort()
print(f"{len(rows)} model(s) matching '{prov}':")
for pid, mid in rows[:60]:
    print(f"  {pid}/{mid}")
PY
  exit 0
fi

# ---------------------------------------------------------------------------
# --apply: write model: into .opencode/agents/*.md from the profile
# ---------------------------------------------------------------------------
if [ "$MODE" = "apply" ]; then
  [ -f "$PROFILE" ] || { warn "no .agents/model-profile.yaml — nothing to apply."; exit 0; }
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] would apply model distribution to $AGENTS_DIR/*.md"
    exit 0
  fi
  python3 - "$AGENTS_DIR" "$PROFILE" << 'PY'
import sys, os, re
agents, profile = sys.argv[1], sys.argv[2]
def parse_profile(path):
    txt = open(path).read()
    default = None
    m = re.search(r'^\s*default:\s*["\']?([^\s"\']+)', txt, re.M)
    if m: default = m.group(1)
    models = dict(re.findall(r'^\s{2}([a-z]+):\s*["\']?([^\s"\']+)', txt, re.M))
    tiers = dict(re.findall(r'^\s{2}([a-z][a-z0-9-]*):\s*(\w+)', txt, re.M))
    return {'default': default, 'models': models, 'role_tiers': tiers}
def is_placeholder(v):
    return not v or 'provider/' in v or 'placeholder' in v.lower() or 'default' in v.lower()
prof = parse_profile(profile)
for fn in sorted(os.listdir(agents)):
    if not fn.endswith('.md'): continue
    role = fn[:-3]
    p = os.path.join(agents, fn)
    tier = prof['role_tiers'].get(role)
    model = (prof['models'].get(tier) if tier else None) or prof['default']
    model = None if is_placeholder(model) else model
    lines = open(p).read().splitlines()
    if not (len(lines) >= 2 and lines[0].strip() == '---'):
        continue
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i; break
    if end is None:
        continue
    fm = [l for l in lines[1:end] if not l.startswith('model:')]
    if model:
        # insert after the `mode:` line if present, else after `description:`
        idx = next((i for i,l in enumerate(fm) if l.startswith('mode:')), None)
        if idx is None:
            idx = next((i for i,l in enumerate(fm) if l.startswith('description:')), len(fm)-1)
        fm.insert(idx+1, f"model: {model}")
    new = [lines[0]] + fm + lines[end:]
    open(p, 'w').write('\n'.join(new) + '\n')
    print(f"  {'set' if model else 'stripped'} model for {role}: {model or '(session default)'}")
PY
  exit 0
fi
