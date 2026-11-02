#!/usr/bin/env zsh
# =============================================================================
# statusline-command.sh
#
# PURPOSE
#   Extracts the bench name (e.g., myproject.05) from the current working
#   directory and displays it as a context status line. Designed for use as
#   a statusline command in opencode or compatible runtime session configuration.
#
# PATTERN
#   Matches any worktree following the <program>.<NN> naming convention
#   (e.g., agenticcore.02, myservice.01, platform-tools.03).
#
# DEPLOY
#   Copy to ~/.opencode/statusline-command.sh (or configure in opencode.json)
#   and chmod +x.
#
# INPUT
#   JSON on stdin with fields:
#     .cwd                            — current working directory
#     .context_window.used_percentage — context % (0-100)
#     .cost.total_cost_usd            — session cost in USD
#     .agent.name                     — active agent name (if any)
#
# EXIT CODES
#   0  — always; output is the rendered status line
# =============================================================================

CYAN=$'\033[36m'
YELLOW=$'\033[33m'
BRIGHT_YELLOW=$'\033[93m'
MAGENTA=$'\033[35m'
GREEN=$'\033[32m'
RED=$'\033[31m'
WHITE=$'\033[97m'
RESET=$'\033[0m'

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | xargs printf '%.0f')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf '%.2f')
agent=$(echo "$input" | jq -r '.agent.name // ""')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

# Extract the bench directory name matching <program>.<NN> convention
# Matches: word-chars (including hyphens) followed by a dot and one or more digits
bench=$(echo "$cwd" | grep -oE '[a-zA-Z0-9_-]+\.[0-9]+' | tail -1)
[[ -z "$bench" ]] && bench="$(basename "$cwd")"

# Context % color: green < 50, yellow 50-79, red 80+
if (( ctx_pct >= 80 )); then
  ctx_color=$RED
elif (( ctx_pct >= 50 )); then
  ctx_color=$YELLOW
else
  ctx_color=$GREEN
fi

line="${CYAN}${bench}${RESET}"
if [[ -n "$branch" ]]; then
  [[ "$branch" == "main" ]] && branch_color=$YELLOW || branch_color=$BRIGHT_YELLOW
  line+=" | ${branch_color}${branch}${RESET}"
fi
[[ -n "$agent"  ]] && line+=" | ${MAGENTA}${agent}${RESET}"
line+=" | ${ctx_color}ctx ${ctx_pct}%${RESET}"

echo "$line"
