#!/usr/bin/env bash
set -euo pipefail
umask 077
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != '--ready' ) ]]; then
    echo 'Usage: template-deploy.sh [--ready]' >&2
    exit 2
fi
ready_mode="${1:-}"

# Resolve the template from this script, not the caller's working directory.
template_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
printf 'Directory? [%s/files/sandbox] ' "$HOME"
IFS= read -r install_directory || { echo 'STOP: directory input ended.' >&2; exit 1; }
printf 'Team name? [AgenticTeam] '
IFS= read -r team_name || { echo 'STOP: team-name input ended.' >&2; exit 1; }

python3 - "$template_root" "$install_directory" "$team_name" "$ready_mode" <<'PY'
import os
import json
from datetime import datetime, timezone
from pathlib import Path
import re
import stat
import sys
import uuid
import subprocess


SEEDS = {'.codex-home/AGENTS.md', '.codex-home/config.toml',
         '.codex-home/rules/template.rules'}
IDENTITY = '.agentic-team-identity.json'
DIRECTORY_MARKERS = {'.scratch/.gitkeep', '.tmp/.gitkeep', '.archive/.gitkeep'}


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate identity key')
        result[key] = value
    return result


def template_identity(source):
    path = source / IDENTITY
    metadata = path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid() or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise ValueError('template identity must be an owned regular file with mode 0600')
    with path.open('rb') as stream:
        raw = stream.read(4097)
    if len(raw) > 4096:
        raise ValueError('template identity exceeds byte limit')
    value = json.loads(raw.decode('utf-8'), object_pairs_hook=unique_keys)
    keys = {'schema_version', 'kind', 'workspace_id', 'template_id',
            'created_at', 'team_name', 'deployment_version'}
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError('invalid identity fields')
    if type(value['schema_version']) is not int or value['schema_version'] != 1 or value['kind'] != 'template':
        raise ValueError('deployment source must have a version-1 template identity')
    for key in ('workspace_id', 'template_id'):
        item = value[key]
        if not isinstance(item, str):
            raise ValueError('invalid identity UUID')
        parsed = uuid.UUID(item)
        if parsed.version != 4 or str(parsed) != item:
            raise ValueError('identity requires canonical UUIDv4')
    timestamp = value['created_at']
    if not isinstance(timestamp, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', timestamp):
        raise ValueError('invalid identity timestamp')
    datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ')
    if value['workspace_id'] != value['template_id'] or value['team_name'] is not None or value['deployment_version'] is not None:
        raise ValueError('invalid template identity relationship')
    return value


def deploy():
    source = Path(sys.argv[1])
    raw_directory = sys.argv[2] or str(Path.home() / 'files/sandbox')
    team = sys.argv[3] or 'AgenticTeam'
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}', team):
        raise ValueError('team name must start with a letter and contain only letters, digits, underscores, or hyphens (maximum 64 characters)')
    # Expand only these documented home prefixes. Never evaluate shell input.
    for prefix in ('${HOME}', '$HOME', '~'):
        if raw_directory == prefix or raw_directory.startswith(prefix + '/'):
            raw_directory = str(Path.home()) + raw_directory[len(prefix):]
            break
    parent = Path(raw_directory).resolve(strict=True)
    if not parent.is_dir():
        raise ValueError('installation directory must be an existing directory')
    if parent == source or source in parent.parents:
        raise ValueError('installation directory must be outside the source template')
    if not (source / '.agentic-team-root').is_file():
        raise ValueError('template root marker is missing')
    identity = template_identity(source)

    manifest = source / 'TEMPLATE_FILES.txt'
    if manifest.is_symlink():
        raise ValueError('distribution allowlist must not be a symlink')
    paths = manifest.read_text().splitlines()
    if not paths or len(paths) != len(set(paths)):
        raise ValueError('distribution allowlist is empty or contains duplicates')
    inputs = []
    for relative in paths:
        parts = relative.split('/')
        if any(p in ('', '.', '..') for p in parts) or '\\' in relative:
            raise ValueError('distribution allowlist contains an unsafe path')
        if ((parts[0] in {'.git', '.codex', '.mcp', '.scratch', '.tmp', '.archive', '.codex-backups',
                         '.poc-backups', '.venv', 'workspace'} or
                (parts[0] == '.codex-home' and relative not in SEEDS) or
                parts[:2] == ['mddocs', 'book'] or
                any(p in {'secrets', 'credentials', '__pycache__', 'node_modules'} for p in parts) or
                parts[-1] == '.envrc' or parts[-1] == '.env' or
                (parts[-1].startswith('.env.') and parts[-1] != '.env.example')) and
                relative not in DIRECTORY_MARKERS):
            raise ValueError('distribution allowlist contains a protected path')
        path = source
        for component in parts:
            path = path / component
            if path.is_symlink():
                raise ValueError('distribution source contains a symlink')
        mode = path.stat().st_mode
        if not stat.S_ISREG(mode):
            raise ValueError('distribution source is not a regular file')
        inputs.append((relative, path, stat.S_IMODE(mode) & 0o777))
    required = SEEDS | {'.agentic-team-root', IDENTITY, 'TEMPLATE_FILES.txt', 'start-codex.sh'}
    if not required.issubset(paths):
        raise ValueError('distribution allowlist is missing required startup files')

    pattern = re.compile(re.escape(team) + r'\.v0\.([0-9]+)')
    highest = 0
    with os.scandir(parent) as entries:
        for entry in entries:
            match = pattern.fullmatch(entry.name)
            if match and entry.is_dir(follow_symlinks=False):
                highest = max(highest, int(match[1]))
    destination = parent / f'{team}.v0.{highest + 1}'
    # mkdir is exclusive: an occupied name or concurrent deployment cannot overwrite.
    destination.mkdir(mode=0o700)
    try:
        for relative, path, mode in inputs:
            target = destination / relative
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            if relative == IDENTITY:
                team_identity = dict(identity, kind='team', workspace_id=str(uuid.uuid4()),
                                     template_id=identity['workspace_id'], team_name=team,
                                     deployment_version=f'v0.{highest + 1}',
                                     created_at=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
                with target.open('x', encoding='utf-8') as outgoing:
                    json.dump(team_identity, outgoing, indent=2)
                    outgoing.write('\n')
                target.chmod(0o600)
                continue
            with path.open('rb') as incoming, target.open('xb') as outgoing:
                while chunk := incoming.read(1024 * 1024):
                    outgoing.write(chunk)
            target.chmod(mode)
        (destination / '.codex-home').chmod(0o700)
        if sys.argv[4] == '--ready':
            checked = subprocess.run(
                ['bash', str(destination / 'mddocs/management/tooling/scripts/team-adopt.sh'), '--check'],
                capture_output=True, text=True, timeout=30)
            print(checked.stdout, end='')
            if checked.returncode:
                raise ValueError('new workspace readiness failed; retained for review')
            required_commands = ('bash', 'python3', 'git', 'codex', 'mdbook', 'mdbook-mermaid')
            import shutil
            if any(shutil.which(command) is None for command in required_commands):
                raise ValueError('a local framework dependency is missing; no automatic installation')
            # Initialize only this exclusively created destination. Ignore Git
            # environment/config/template overrides so no other repository is touched.
            if os.path.lexists(destination / '.git'):
                raise ValueError('unexpected Git metadata; initialization refused')
            git_env = {key: value for key, value in os.environ.items()
                       if not key.startswith('GIT_')}
            git_env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                           GIT_TERMINAL_PROMPT='0')
            def local_git(*args):
                result = subprocess.run(['git', '-C', str(destination), *args],
                                        env=git_env, capture_output=True, text=True, timeout=30)
                if result.returncode:
                    raise ValueError('local Git initialization/verification failed')
                return result.stdout.strip()
            local_git('init', '--quiet', '--template=')
            if not (destination / '.git').is_dir() or (destination / '.git').is_symlink():
                raise ValueError('Git metadata is not local to the new workspace')
            if Path(local_git('rev-parse', '--show-toplevel')).resolve() != destination:
                raise ValueError('Git repository root does not match the new workspace')
            print(f'Local Git repository initialized and root verified: {destination.name}')
    except BaseException:
        print(f'STOP: incomplete deployment retained for review: {destination}', file=sys.stderr)
        raise
    print(f'Created: {destination}')
    print(f'Copied {len(inputs)} allowlisted files. No login or Codex launch performed.')
    if sys.argv[4] != '--ready':
        print('Deployment-only mode: Git initialization not performed.')
    if sys.argv[4] == '--ready':
        import shlex
        print('Local dev-space setup complete; no separate receipt initialization required.')
        print('Git is local only: no remote, initial commit, or hook activation performed.')
        print('\nNext steps:')
        print('  1. Enter your new workspace: cd -- ' + shlex.quote(str(destination)))
        print('  2. If authentication is needed: ./start-codex.sh login')
        print('  3. Start working: ./start-codex.sh')
        print('\nOptional: review .envrc.template with the HIL. Copying it to .envrc and')
        print('activating direnv require separate explicit approval. Neither was performed.')
        print('\nAuthentication/model use, MCP registration, and hook activation are not verified or performed.')


try:
    deploy()
except (OSError, ValueError) as exc:
    print(f'STOP: {exc}', file=sys.stderr)
    sys.exit(1)
PY
