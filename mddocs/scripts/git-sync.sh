#!/bin/zsh
# git-sync.sh — Git workspace sync tool
#
# Crawls a Git group, clones missing repos, pulls existing ones,
# and checks out the default branch (main or master) for each.
#
# Secrets are stored in pass (https://www.passwordstore.org/).
# Non-sensitive config lives in ~/.config/git-sync/profiles.
#
# Usage:
#   git-sync.sh [--profile `<name>`] [--group `<path>`] [--mode sync|update] [--dry-run]
#
# Modes:
#   sync    — Query Git API, clone missing repos, pull existing ones (default)
#   update  — Local pull only — no API calls, no token required
#
# Environment overrides (all optional — take precedence over profile):
#   GIT_SYNC_PROFILE   — profile name from ~/.config/git-sync/profiles
#   GIT_SYNC_GROUP     — override the group/namespace to sync
#   GIT_SYNC_URL       — override the Git base URL
#   GIT_SYNC_PASS_PATH — override the pass store path to the PAT
#   GIT_SYNC_TOKEN     — supply token directly (use only in non-interactive scripts)
#   GIT_SYNC_MODE      — sync | update
#
# Profiles file format (~/.config/git-sync/profiles):
#   # name   url                              pass-path                  default-group
#   default  https://git.example.com       git/example.com/pat     my-group
#
# The working directory is used as the sync root.

set -uo pipefail

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
_missing=()
for dep in jq curl git; do
    command -v "$dep" &>/dev/null || _missing+=("$dep")
done

if [[ ${#_missing[@]} -gt 0 ]]; then
    print -u2 "Error: missing required tools: ${_missing[*]}"
    print -u2 "Install with: brew install ${_missing[*]}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PROFILES_FILE="${HOME}/.config/git-sync/profiles"
PROFILE="${GIT_SYNC_PROFILE:-default}"
GROUP_OVERRIDE="${GIT_SYNC_GROUP:-}"
URL_OVERRIDE="${GIT_SYNC_URL:-}"
PASS_OVERRIDE="${GIT_SYNC_PASS_PATH:-}"
TOKEN_OVERRIDE="${GIT_SYNC_TOKEN:-}"
MODE="${GIT_SYNC_MODE:-}"
DRY_RUN=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)  PROFILE="$2";       shift 2 ;;
        --group)    GROUP_OVERRIDE="$2"; shift 2 ;;
        --mode)     MODE="$2";           shift 2 ;;
        --dry-run)  DRY_RUN=true;        shift   ;;
        -h|--help)
            print "Usage: git-sync.sh [--profile `<name>`] [--group `<path>`] [--mode sync|update] [--dry-run]"
            print ""
            print "Profiles file: ${PROFILES_FILE}"
            print "See mddocs/reference.architecture/git-sync-runbook.md for full documentation."
            exit 0
            ;;
        *)
            print -u2 "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Load profile (skipped if all required values come from env/flags)
# ---------------------------------------------------------------------------
GIT_HOST=""
PASS_PATH=""
DEFAULT_GROUP=""

if [[ -f "$PROFILES_FILE" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue
        read -rA fields <<< "$line"
        if [[ "${fields[1]}" == "$PROFILE" ]]; then
            GIT_HOST="${fields[2]:-}"
            PASS_PATH="${fields[3]:-}"
            DEFAULT_GROUP="${fields[4]:-}"
            break
        fi
    done < "$PROFILES_FILE"
fi

# Apply env/flag overrides
[[ -n "$URL_OVERRIDE"   ]] && GIT_HOST="$URL_OVERRIDE"
[[ -n "$PASS_OVERRIDE"  ]] && PASS_PATH="$PASS_OVERRIDE"

# Determine group: flag > env > profile default > pwd basename (strip .NN bench suffix)
if [[ -n "$GROUP_OVERRIDE" ]]; then
    SYNC_GROUP="$GROUP_OVERRIDE"
elif [[ -n "$DEFAULT_GROUP" ]]; then
    SYNC_GROUP="$DEFAULT_GROUP"
else
    # Strip bench suffix (e.g. MyProject.02 → MyProject)
    SYNC_GROUP="$(basename "$(pwd)" | sed 's/\.[0-9]*$//')"
fi

# ---------------------------------------------------------------------------
# Mode selection — interactive if not set
# ---------------------------------------------------------------------------
if [[ -z "$MODE" ]]; then
    print ""
    print "Select mode:"
    print "  1) sync   — clone/update from Git API"
    print "  2) update — local pull only (no API calls)"
    printf "Choice [1]: "
    read -r _choice
    case "${_choice:-1}" in
        2|update) MODE="update" ;;
        *)        MODE="sync"   ;;
    esac
fi

# ---------------------------------------------------------------------------
# UPDATE mode — local pull only, no token needed
# ---------------------------------------------------------------------------
if [[ "$MODE" == "update" ]]; then
    print "---------------------------------------"
    print "   Git Workspace Sync — UPDATE mode"
    print "---------------------------------------"
    print "  Root    : $(pwd)"
    [[ "$DRY_RUN" == true ]] && print "  Mode    : DRY RUN"
    print "---------------------------------------"

    total_updated=0
    total_skipped=0

    # Find all .git directories — exclude dotted directories (bench copies)
    while IFS= read -r git_dir; do
        repo_dir="${git_dir%/.git}"
        # Skip directories whose name starts with a dot (bench worktrees)
        basename_dir="$(basename "$repo_dir")"
        [[ "$basename_dir" == .* ]] && continue

        if [[ "$DRY_RUN" == true ]]; then
            print "  [dry-run] would pull: ${repo_dir}"
            (( total_updated++ )) || true
            continue
        fi

        print ">> Pulling: ${repo_dir}"
        git -C "$repo_dir" pull --ff-only --quiet 2>/dev/null \
            || git -C "$repo_dir" pull --quiet 2>/dev/null \
            || { print "    ⚠  Pull failed (local changes or detached HEAD?)"; (( total_skipped++ )) || true; continue; }
        (( total_updated++ )) || true

    done < <(find . -name ".git" -maxdepth 3 -type d 2>/dev/null | sort)

    print ""
    print "---------------------------------------"
    print "  Done. Updated: ${total_updated}  Skipped: ${total_skipped}"
    print "---------------------------------------"
    exit 0
fi

# ---------------------------------------------------------------------------
# SYNC mode — requires Git URL and token
# ---------------------------------------------------------------------------
if [[ -z "$GIT_HOST" ]]; then
    print -u2 "Error: Git URL not set."
    print -u2 "Set GIT_SYNC_URL, add a profile to ${PROFILES_FILE}, or use --profile."
    exit 1
fi

# Strip trailing slash
GIT_HOST="${GIT_HOST%/}"

# Retrieve token
GIT_TOKEN=""
if [[ -n "$TOKEN_OVERRIDE" ]]; then
    GIT_TOKEN="$TOKEN_OVERRIDE"
elif [[ -n "$PASS_PATH" ]]; then
    # Ensure pinentry can reach the terminal
    export GPG_TTY=$(tty 2>/dev/null || true)
    if command -v pass &>/dev/null; then
        print "Retrieving token from pass store (${PASS_PATH})..."
        GIT_TOKEN="$(pass show "$PASS_PATH")" || {
            print -u2 "Error: could not retrieve token from pass: ${PASS_PATH}"
            print -u2 "Run: pass insert ${PASS_PATH}"
            exit 1
        }
        GIT_TOKEN="${GIT_TOKEN%%$'\n'*}"
    else
        print -u2 "Error: 'pass' not installed and no GIT_SYNC_TOKEN set."
        print -u2 "Install pass: brew install pass"
        exit 1
    fi
else
    # Interactive prompt
    print -n "Git Personal Access Token: "
    read -rs GIT_TOKEN
    print ""
fi

if [[ -z "$GIT_TOKEN" ]]; then
    print -u2 "Error: token is empty."
    exit 1
fi

# ---------------------------------------------------------------------------
# GIT_ASKPASS — supplies token without embedding in URLs or .git/config
# ---------------------------------------------------------------------------
export _ASKPASS_TOKEN="$GIT_TOKEN"
GIT_ASKPASS_SCRIPT="$(mktemp /tmp/git-sync-askpass.XXXXXX)"
printf '#!/bin/sh\necho "$_ASKPASS_TOKEN"\n' > "$GIT_ASKPASS_SCRIPT"
chmod +x "$GIT_ASKPASS_SCRIPT"
export GIT_ASKPASS="$GIT_ASKPASS_SCRIPT"
trap 'rm -f "$GIT_ASKPASS_SCRIPT"; unset _ASKPASS_TOKEN' EXIT INT TERM

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print "---------------------------------------"
print "   Git Workspace Sync — SYNC mode"
print "---------------------------------------"
print "  Profile : ${PROFILE}"
print "  URL     : ${GIT_HOST}"
print "  Group   : ${SYNC_GROUP}"
print "  Root    : $(pwd)"
[[ "$DRY_RUN" == true ]] && print "  Mode    : DRY RUN (no changes)"
print "---------------------------------------"

# ---------------------------------------------------------------------------
# Verify group exists
# ---------------------------------------------------------------------------
NAMESPACE_ID=$(curl -sf --max-time 15 \
    --header "PRIVATE-TOKEN: ${GIT_TOKEN}" \
    "${GIT_HOST}/api/v4/groups?search=${SYNC_GROUP}" \
    | jq -r '.[0].id' 2>/dev/null) || true

if [[ "$NAMESPACE_ID" == "null" || -z "$NAMESPACE_ID" ]]; then
    print -u2 "Error: could not find Git group '${SYNC_GROUP}' on ${GIT_HOST}"
    print -u2 "Check the group path and that your PAT has at least read_api scope."
    exit 1
fi

print "Found group '${SYNC_GROUP}' (id: ${NAMESPACE_ID}). Fetching projects..."

# ---------------------------------------------------------------------------
# Checkout helper — ensures repo is on default branch and up to date
# ---------------------------------------------------------------------------
checkout_default_branch() {
    local dir="$1"

    local default_branch
    default_branch=$(git -C "$dir" remote show origin 2>/dev/null \
        | grep 'HEAD branch' | awk '{print $NF}')

    if [[ -z "$default_branch" || "$default_branch" == "(unknown)" ]]; then
        if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
            default_branch="main"
        elif git -C "$dir" show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
            default_branch="master"
        else
            print "    ⚠  Could not determine default branch for ${dir}, skipping checkout"
            return
        fi
    fi

    local current_branch
    current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ "$current_branch" != "$default_branch" ]]; then
        print "    → Switching to ${default_branch}"
        git -C "$dir" checkout "$default_branch" --quiet 2>/dev/null || {
            print "    ⚠  Could not switch to ${default_branch}"
            return
        }
    fi

    git -C "$dir" pull --ff-only --quiet 2>/dev/null \
        || git -C "$dir" pull --quiet 2>/dev/null \
        || print "    ⚠  Pull failed (local changes?)"
}

# ---------------------------------------------------------------------------
# Paginate through all projects, filter to SYNC_GROUP namespace
# ---------------------------------------------------------------------------
page=1
total_synced=0
total_skipped=0

while true; do
    PROJECTS_JSON=$(curl -sf --max-time 30 \
        --header "PRIVATE-TOKEN: ${GIT_TOKEN}" \
        "${GIT_HOST}/api/v4/projects?membership=true&per_page=100&page=${page}" \
        | jq -c '.') || {
        print -u2 "Error: API request failed on page ${page}"
        exit 1
    }

    count=$(jq 'length' <<< "$PROJECTS_JSON" 2>/dev/null)
    [[ "$count" == "0" || "$count" == "null" || -z "$count" ]] && break

    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        HTTP_URL=$(jq -r '.http_url_to_repo' <<< "$project" 2>/dev/null)
        FULL_PATH=$(jq -r '.path_with_namespace' <<< "$project" 2>/dev/null)

        [[ -z "$HTTP_URL"  || "$HTTP_URL"  == "null" ]] && continue
        [[ -z "$FULL_PATH" || "$FULL_PATH" == "null" ]] && continue

        # Relative path under the sync root (strip top-level group prefix)
        TARGET_DIR="${FULL_PATH#${SYNC_GROUP}/}"

        if [[ "$DRY_RUN" == true ]]; then
            if [[ -d "${TARGET_DIR}/.git" ]]; then
                print "  [dry-run] would update: ${TARGET_DIR}"
            else
                print "  [dry-run] would clone:  ${TARGET_DIR}"
            fi
            (( total_synced++ )) || true
            continue
        fi

        if [[ -d "${TARGET_DIR}/.git" ]]; then
            print ">> Updating: ${TARGET_DIR}"
            git -C "$TARGET_DIR" remote set-url origin "$HTTP_URL" --quiet 2>/dev/null \
                || git -C "$TARGET_DIR" remote set-url origin "$HTTP_URL"
            checkout_default_branch "$TARGET_DIR"
        else
            print ">> Cloning:  ${TARGET_DIR}"
            mkdir -p "$(dirname "$TARGET_DIR")" 2>/dev/null || true
            if git clone "$HTTP_URL" "$TARGET_DIR" 2>&1; then
                checkout_default_branch "$TARGET_DIR"
            else
                print "  ⚠  Clone failed: ${TARGET_DIR}"
                (( total_skipped++ )) || true
                continue
            fi
        fi
        (( total_synced++ )) || true

    done < <(jq -c --arg ns "${SYNC_GROUP}/" \
        '.[] | select(.path_with_namespace | startswith($ns))' \
        <<< "$PROJECTS_JSON" 2>/dev/null)

    (( page++ )) || true
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print ""
print "---------------------------------------"
print "  Done."
print "  Synced  : ${total_synced}"
[[ $total_skipped -gt 0 ]] && print "  Failed  : ${total_skipped}"
print "---------------------------------------"
