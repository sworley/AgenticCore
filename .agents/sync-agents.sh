#!/bin/sh
# sync-agents.sh — Generate .opencode/agents/ files from canonical .agents/ source
#
# Usage:
#   ./sync-agents.sh [--dry-run] [--clean] [<agent-name>]
#
# Options:
#   --dry-run     Preview output without writing files
#   --clean       Remove generated files for agents no longer in _meta.yaml
#   <agent-name>  Generate a single agent only
#
# Output:
#   .opencode/agents/<name>.md  — opencode agent format
#
# Policy distribution (always runs, even with <agent-name> filter):
#   _security-policy.md  → AGENT.md (Standing Rules) and .opencode/commit-push-gate.md
#   _docs-policy.md      → .agents/docs-engineer.md and .agents/lead-engineer.md bodies
#
# Exit codes:
#   0  Success
#   1  Missing canonical source file or write error
#   2  _meta.yaml parse error

set -eu

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"
META_FILE="$AGENTS_DIR/_meta.yaml"
OPENCODE_OUT="$REPO_ROOT/.opencode/agents"

DRY_RUN=0
CLEAN=0
SINGLE_AGENT=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --clean)   CLEAN=1 ;;
    -*)        echo "Unknown flag: $arg" >&2; exit 1 ;;
    *)         SINGLE_AGENT="$arg" ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi

python3 - "$META_FILE" "$AGENTS_DIR" "$REPO_ROOT" "$OPENCODE_OUT" "$DRY_RUN" "$CLEAN" "$SINGLE_AGENT" <<'PYEOF'
import sys
import os
import re

meta_file   = sys.argv[1]
agents_dir  = sys.argv[2]
repo_root   = sys.argv[3]
oc_out_dir  = sys.argv[4]
dry_run     = sys.argv[5] == "1"
do_clean    = sys.argv[6] == "1"
single      = sys.argv[7]


# ---------------------------------------------------------------------------
# Policy injection helpers
# ---------------------------------------------------------------------------

def extract_section(text, name):
    """Extract content between <!-- BEGIN name --> and <!-- END name --> markers."""
    begin = f"<!-- BEGIN {name} -->"
    end   = f"<!-- END {name} -->"
    start = text.find(begin)
    stop  = text.find(end)
    if start == -1 or stop == -1:
        raise ValueError(f"Section '{name}' not found in policy file")
    return text[start + len(begin):stop].strip()


# ---------------------------------------------------------------------------
# Policy distributors
# ---------------------------------------------------------------------------

def distribute_section(path, section_name, section_content, heading, dry_run):
    if not os.path.exists(path):
        print(f"  [policy] SKIP {path} — file not found")
        return

    with open(path) as f:
        content = f.read()

    begin_marker = f"<!-- BEGIN {section_name} -->"
    end_marker   = f"<!-- END {section_name} -->"
    new_block    = f"{begin_marker}\n{section_content}\n{end_marker}"

    if begin_marker in content:
        pattern     = re.compile(re.escape(begin_marker) + r".*?" + re.escape(end_marker), re.DOTALL)
        new_content = pattern.sub(new_block, content)
    else:
        heading_pos = content.find(f"\n{heading}\n")
        if heading_pos == -1:
            print(f"  [policy] SKIP {path} — heading '{heading}' not found")
            return
        insert_pos  = heading_pos + len(f"\n{heading}\n")
        new_content = content[:insert_pos] + "\n" + new_block + "\n" + content[insert_pos:]

    rel = os.path.relpath(path, repo_root)
    if dry_run:
        print(f"  [policy dry-run] would update {section_name} in {rel}")
    else:
        with open(path, "w") as f:
            f.write(new_content)
        print(f"  [policy] updated {rel}")


def distribute_security_policy(repo_root, agents_dir, standing_rules, gate_steps, dry_run):
    distribute_section(
        os.path.join(repo_root, "AGENT.md"),
        "security-policy-standing-rules", standing_rules,
        "## Standing Rules", dry_run,
    )
    distribute_section(
        os.path.join(repo_root, ".opencode/commit-push-gate.md"),
        "security-policy-gate-steps", gate_steps,
        "## Security-reviewer gate", dry_run,
    )
    distribute_section(
        os.path.join(agents_dir, "bootstrap/adopter-root-AGENT.md"),
        "security-policy-standing-rules", standing_rules,
        "## Standing Rules", dry_run,
    )


def distribute_docs_policy(repo_root, agents_dir, docs_rules, dry_run):
    for agent_name in ("docs-engineer", "lead-engineer"):
        distribute_section(
            os.path.join(agents_dir, f"{agent_name}.md"),
            "docs-policy-standing-rules", docs_rules,
            "## Docs Review Gate", dry_run,
        )
    distribute_section(
        os.path.join(agents_dir, "bootstrap/adopter-root-AGENT.md"),
        "docs-policy-standing-rules", docs_rules,
        "## Docs Review Gate", dry_run,
    )


# ---------------------------------------------------------------------------
# _meta.yaml parser (opencode-only)
# ---------------------------------------------------------------------------

def parse_meta(path):
    with open(path) as f:
        lines = f.readlines()

    agents = {}
    current_agent   = None
    current_section = None   # 'opencode' | None
    in_permission   = False

    for raw in lines:
        line     = raw.rstrip("\n")
        stripped = line.strip()

        if stripped.startswith("#") or not stripped:
            continue

        indent = len(line) - len(line.lstrip(" "))

        if indent == 0:
            m = re.match(r"^([\w-]+):\s*$", stripped)
            if m:
                current_agent   = m.group(1)
                agents[current_agent] = {"opencode": {}}
                current_section = None
                in_permission   = False

        elif indent == 2 and current_agent:
            in_permission = False
            if stripped.startswith("description:"):
                val = stripped[len("description:"):].strip().strip('"')
                agents[current_agent]["description"] = val
                current_section = None
            elif stripped == "opencode:":
                current_section = "opencode"

        elif indent == 4 and current_agent and current_section:
            if stripped == "permission:":
                in_permission = True
                agents[current_agent][current_section]["permission"] = {}
            else:
                in_permission = False
                m = re.match(r"^([\w-]+):\s*(.+)$", stripped)
                if m:
                    k, v = m.group(1), m.group(2).strip().strip('"')
                    agents[current_agent][current_section][k] = v

        elif indent == 6 and current_agent and current_section and in_permission:
            m = re.match(r"^([\w-]+):\s*(\S+)", stripped)
            if m:
                agents[current_agent][current_section].setdefault("permission", {})[m.group(1)] = m.group(2)

    return agents


# ---------------------------------------------------------------------------
# Frontmatter builder
# ---------------------------------------------------------------------------

def auto_generated_comment(name):
    return (
        f"<!-- AUTO-GENERATED by .agents/sync-agents.sh — do not hand-edit -->\n"
        f"<!-- Source: .agents/{name}.md + .agents/_meta.yaml -->\n"
        f"<!-- Run .agents/sync-agents.sh to regenerate -->"
    )


def build_opencode_frontmatter(cfg):
    oc    = cfg["opencode"]
    lines = ["---", f"description: {cfg.get('description', '')}", f"mode: {oc.get('mode', 'subagent')}"]
    model = oc.get("model")
    if model:
        lines.append(f"model: {model}")
    perm  = oc.get("permission")
    if perm:
        lines.append("permission:")
        for k, v in perm.items():
            lines.append(f"  {k}: {v}")
    lines.append("---")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Policy distribution
# ---------------------------------------------------------------------------

print("[policy]")

sec_policy_path = os.path.join(agents_dir, "_security-policy.md")
docs_policy_path = os.path.join(agents_dir, "_docs-policy.md")

if not os.path.exists(sec_policy_path):
    print("  WARNING: _security-policy.md not found — skipping security policy distribution")
    standing_rules = None
    gate_steps     = None
else:
    with open(sec_policy_path) as f:
        sec_policy = f.read()
    standing_rules = extract_section(sec_policy, "security-policy-standing-rules")
    gate_steps     = extract_section(sec_policy, "security-policy-gate-steps")
    distribute_security_policy(repo_root, agents_dir, standing_rules, gate_steps, dry_run)

if not os.path.exists(docs_policy_path):
    print("  WARNING: _docs-policy.md not found — skipping docs policy distribution")
    docs_rules = None
else:
    with open(docs_policy_path) as f:
        docs_policy = f.read()
    docs_rules = extract_section(docs_policy, "docs-policy-standing-rules")
    distribute_docs_policy(repo_root, agents_dir, docs_rules, dry_run)


# ---------------------------------------------------------------------------
# Agent file generation
# ---------------------------------------------------------------------------

print("\n[agents]")

try:
    agents = parse_meta(meta_file)
except Exception as e:
    print(f"ERROR parsing {meta_file}: {e}", file=sys.stderr)
    sys.exit(2)

if not agents:
    print("ERROR: no agents found in _meta.yaml", file=sys.stderr)
    sys.exit(2)

errors = 0
written = []

for name in agents:
    if single and name != single:
        continue

    cfg       = agents[name]
    body_path = os.path.join(agents_dir, f"{name}.md")
    if not os.path.exists(body_path):
        print(f"  ERROR: missing body file: {body_path}", file=sys.stderr)
        errors += 1
        continue

    with open(body_path) as f:
        body = f.read().rstrip("\n") + "\n"

    comment = auto_generated_comment(name)
    oc_content = f"{build_opencode_frontmatter(cfg)}\n\n{comment}\n\n{body}"
    oc_path    = os.path.join(oc_out_dir, f"{name}.md")

    if dry_run:
        print(f"  [dry-run] would write: {oc_path}")
    else:
        os.makedirs(oc_out_dir, exist_ok=True)
        with open(oc_path, "w") as f:
            f.write(oc_content)
        print(f"  wrote: .opencode/agents/{name}.md")

    written.append(name)

# Clean orphaned files
if do_clean:
    valid = set(agents.keys())
    if not os.path.isdir(oc_out_dir):
        pass
    else:
        for fname in os.listdir(oc_out_dir):
            if fname.endswith(".md") and fname[:-3] not in valid:
                fpath = os.path.join(oc_out_dir, fname)
                if dry_run:
                    print(f"  [dry-run] would remove orphan: .opencode/agents/{fname}")
                else:
                    os.remove(fpath)
                    print(f"  removed orphan: .opencode/agents/{fname}")

if not single and len(written) != len(agents):
    print(
        f"ERROR: expected to write {len(agents)} agent(s) but wrote {len(written)} "
        f"— parse or generation loop produced an incomplete result",
        file=sys.stderr,
    )
    sys.exit(1)

if errors:
    sys.exit(1)

tag = "[dry-run] " if dry_run else ""
print(f"\n{tag}sync-agents: {len(written)} agent(s) {'previewed' if dry_run else 'written'}")
PYEOF