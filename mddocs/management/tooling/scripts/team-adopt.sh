#!/usr/bin/env bash
set -euo pipefail

usage() {
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done <<'HELP'
AgenticTeam setup and readiness

Usage: ./team-adopt.sh [--help|--check|--initialize-state|--check-state|--create-venv|--install-runtime-deps|--install-test-deps]
From the workspace root: ./mddocs/management/tooling/scripts/team-adopt.sh

No options:
  In the template: create and validate a new local development workspace.
  In a deployed team: run read-only readiness checks; create nothing.
  The script locates its workspace automatically, regardless of your current directory.

Creating a team:
  Directory?  Default: $HOME/files/sandbox (must already exist).
  Team name?  Default: AgenticTeam (letters, digits, underscores, hyphens;
              start with a letter, maximum 64 characters).
  Press Enter to accept either default. Enter paths without surrounding quotes.
  The next numeric version is selected, for example AgenticTeam.v0.3 -> v0.4.
  Existing teams are never overwritten. Only portable template files are copied.

What finishes:
  Local files, a fresh team identity, private Codex home, configuration checks,
  and dependency availability checks. The new directory and startup steps are printed.
  Template adoption also initializes a local Git repository in the new directory
  and verifies its root. The directory name is its local repository name.
  No separate adoption progress receipt is required to use the workspace.

What default setup does NOT perform:
  No login, model session, dependency installation, remote, initial commit,
  hook activation, or MCP registration. No global Git configuration changes.
  Authentication remains interactive if needed.
  Failed validation leaves the new directory for review, without claiming readiness.

Optional commands in a deployed team:
  --check             Read-only readiness; rejected in the template.
  --initialize-state  Optional private progress receipt; requires explicit confirmation.
  --check-state       Read-only receipt validation/drift report; never resumes actions.
  --create-venv       Confirm create-only .venv setup; no pip, installs, or activation.
  --install-runtime-deps  Confirm first runtime-lock installation into an empty .venv.
  --install-test-deps     Confirm first runtime-plus-test installation into an empty .venv.
  -h, --help          Show this help without inspecting or changing a workspace.
HELP
}

if [[ $# -eq 1 && ( "$1" == '--help' || "$1" == '-h' ) ]]; then
    usage
    exit 0
fi

if [[ $# -eq 0 ]]; then
    # Inspect only the local marker to choose the entry mode. Deployment performs
    # full template validation; --check performs full team validation.
    kind="$(python3 -B - "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." <<'PY'
import json
import os
from pathlib import Path
import stat
import sys
try:
    path = Path(sys.argv[1]) / '.agentic-team-identity.json'
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError()
        raw = stream.read(4097)
    if len(raw) > 4096:
        raise ValueError()
    value = json.loads(raw)
    if not isinstance(value, dict) or value.get('kind') not in ('template', 'team'):
        raise ValueError()
    print(value['kind'])
except (OSError, ValueError):
    print('STOP: invalid workspace identity.', file=sys.stderr)
    sys.exit(1)
PY
)"
    if [[ "$kind" == template ]]; then
        printf '%s\n\n' \
            'Welcome! This will create a new AgenticTeam development workspace.' \
            'Press Enter to accept each default; existing teams will not be overwritten.' \
            'After you choose the directory and team name, the new folder uses <Team>.v0.<N>.' \
            'Numbering starts at 1; if matching versioned folders exist there, the highest version plus one is used.' \
            'For example, AgenticTeam.v0.3 leads to AgenticTeam.v0.4.' \
            'Local setup is checked before completion; login and optional services are not configured.' \
            'For full usage, run this script with --help.'
        exec bash "$(dirname -- "${BASH_SOURCE[0]}")/template-deploy.sh" --ready
    fi
    printf '%s\n' 'Checking this deployed team (read-only; no setup changes).' ''
fi
if [[ $# -eq 1 && "$1" == '--check-state' ]]; then
    exec python3 -B "$(dirname -- "${BASH_SOURCE[0]}")/receipt_check.py"
fi
if [[ $# -eq 1 && "$1" == '--create-venv' ]]; then
    exec python3 -I -B "$(dirname -- "${BASH_SOURCE[0]}")/create_venv.py"
fi
if [[ $# -eq 1 && "$1" == '--install-runtime-deps' ]]; then
    exec python3 -I -B "$(dirname -- "${BASH_SOURCE[0]}")/install_dependencies.py" runtime
fi
if [[ $# -eq 1 && "$1" == '--install-test-deps' ]]; then
    exec python3 -I -B "$(dirname -- "${BASH_SOURCE[0]}")/install_dependencies.py" test
fi
# Read-only phase only. No receipts, locks, configuration writes, or CLI probes.
if [[ $# -eq 1 && "$1" == '--initialize-state' ]]; then
    exec python3 -B "$(dirname -- "${BASH_SOURCE[0]}")/adoption_state.py"
fi
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != '--check' ) ]]; then
    echo 'Unsupported options. Run team-adopt.sh --help for usage.' >&2
    exit 2
fi
script_root="$(dirname -- "${BASH_SOURCE[0]}")/../../../.."
python3 -B - "$script_root" <<'PY'
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tomllib
import uuid
from datetime import datetime


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate key')
        result[key] = value
    return result


def safe_path(root, relative):
    components = relative.split('/')
    if any(p in ('', '.', '..') for p in components) or '\\' in relative:
        raise ValueError('unsafe path')
    path = root
    for component in components:
        path /= component
        if path.is_symlink():
            raise ValueError('symlinked component')
    return path


def read_regular(root, relative, maximum):
    path = safe_path(root, relative)
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
    fd = os.open(path, flags)
    with os.fdopen(fd, 'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError('not a regular file')
        raw = stream.read(maximum + 1)
    if len(raw) > maximum:
        raise ValueError('file exceeds limit')
    return raw


def identity(root):
    path = safe_path(root, '.agentic-team-identity.json')
    info = path.lstat()
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
        raise ValueError('identity ownership/mode invalid')
    value = json.loads(read_regular(root, '.agentic-team-identity.json', 4096), object_pairs_hook=unique)
    keys = {'schema_version', 'kind', 'workspace_id', 'template_id', 'created_at', 'team_name', 'deployment_version'}
    if not isinstance(value, dict) or set(value) != keys or type(value['schema_version']) is not int or value['schema_version'] != 1:
        raise ValueError('invalid identity schema')
    if value['kind'] != 'team':
        raise ValueError('template/source adoption is forbidden')
    for key in ('workspace_id', 'template_id'):
        item = value[key]
        if not isinstance(item, str):
            raise ValueError('invalid UUID')
        parsed = uuid.UUID(item)
        if parsed.version != 4 or str(parsed) != item:
            raise ValueError('invalid UUID')
    if value['workspace_id'] == value['template_id']:
        raise ValueError('team cannot reuse template UUID')
    for key, pattern in (('team_name', r'[A-Za-z][A-Za-z0-9_-]{0,63}'),
                         ('deployment_version', r'v0\.[1-9][0-9]*'),
                         ('created_at', r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')):
        if not isinstance(value[key], str) or not re.fullmatch(pattern, value[key]):
            raise ValueError('invalid identity field')
    datetime.strptime(value['created_at'], '%Y-%m-%dT%H:%M:%SZ')
    return value


def main():
    lexical = Path(os.path.abspath(sys.argv[1]))
    if lexical.is_symlink() or any(p.is_symlink() for p in lexical.parents):
        raise ValueError('symlinked workspace')
    root = lexical.resolve(strict=True)
    if not root.is_dir() or root.stat().st_uid != os.getuid():
        raise ValueError('workspace ownership/type invalid')
    identity(root)
    read_regular(root, '.agentic-team-root', 4096)
    failures = []
    def check(label, callback):
        try:
            callback()
            print(label + ': PASS')
        except (OSError, ValueError, TypeError):
            failures.append(label)
            print(label + ': BLOCKED (missing, unsafe, or conflicting input)')

    def home_check():
        path = safe_path(root, '.codex-home')
        info = path.stat()
        if not path.is_dir() or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError('unsafe home')

    def files_check():
        paths = read_regular(root, 'TEMPLATE_FILES.txt', 65536).decode().splitlines()
        if not paths or len(paths) != len(set(paths)) or len(paths) > 1000:
            raise ValueError('invalid manifest')
        required = {'.agentic-team-root', '.agentic-team-identity.json', 'start-codex.sh',
                    '.codex-home/config.toml', '.codex-home/AGENTS.md', '.codex-home/rules/template.rules'}
        if not required.issubset(paths):
            raise ValueError('missing required entry')
        for relative in paths:
            path = safe_path(root, relative)
            if not stat.S_ISREG(path.stat().st_mode):
                raise ValueError('missing/nonregular source')
        for relative in ('start-codex.sh', 'mddocs/management/tooling/git-hooks/pre-commit',
                         'mddocs/management/tooling/scripts/template-deploy.sh',
                         'mddocs/management/tooling/scripts/team-adopt.sh'):
            if not os.access(safe_path(root, relative), os.X_OK):
                raise ValueError('script not executable')

    config = None
    def config_check():
        nonlocal config
        config = tomllib.loads(read_regular(root, '.codex-home/config.toml', 65536).decode())
        expected = {'cli_auth_credentials_store': 'file', 'approval_policy': 'on-request',
                    'sandbox_mode': 'workspace-write',
                    'project_root_markers': ['.agentic-team-root', '.git']}
        if any(config.get(k) != v for k, v in expected.items()) or config.get('history', {}).get('persistence') != 'save-all':
            raise ValueError('settings differ from intended seeds')

    print('Identity: PASS (team marker; not authorization)')
    check('Local home', home_check)
    check('Portable files and executable modes', files_check)
    check('Local configuration intent', config_check)
    for command in ('bash', 'python3', 'git', 'codex', 'mdbook', 'mdbook-mermaid'):
        print(f'Dependency {command}: ' + ('FOUND; version not verified' if shutil.which(command) else 'MISSING'))
    # Presence only: do not follow/read Git metadata or start registered services.
    print('Git metadata: ' + ('PRESENT; hooks/settings not inspected' if os.path.lexists(root / '.git') else 'ABSENT; optional initialization not performed'))
    print('Local MCP configuration: ' + ('PRESENT; registrations not started or verified' if config and 'mcp_servers' in config else 'NOT ESTABLISHED'))
    print('Adoption state: ' + ('PRESENT; resume/receipt validation not implemented' if os.path.lexists(root / '.codex-home/adoption') else 'ABSENT; no state created'))
    print('Environment: inherited variable values not inspected or printed; no isolation verified.')
    print('Readiness only: no authentication, model request, service start, repair, or acceptance.')
    print('Dev-space readiness only; owner is the person running adoption/setup. No additional identity questionnaire.')
    return int(bool(failures))


try:
    sys.exit(main())
except (OSError, ValueError, TypeError, UnicodeError):
    print('STOP: workspace identity or structure is missing, invalid, unsafe, or a template. No changes made.', file=sys.stderr)
    sys.exit(1)
PY
