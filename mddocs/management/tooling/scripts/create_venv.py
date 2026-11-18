"""Explicit create-only local Python setup. No pip, installs, activation, or repair."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import tomllib
import venv


def private_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('unsafe private directory')


def read_regular(path, maximum):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError('not a regular file')
        raw = stream.read(maximum + 1)
    if len(raw) > maximum:
        raise ValueError('file exceeds limit')
    return raw


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def initialize(root):
    if root.is_symlink() or any(p.is_symlink() for p in root.parents):
        raise ValueError('symlinked workspace')
    temporary = root / '.tmp'
    archive = root / '.archive'
    private_directory(temporary)
    private_directory(archive)
    environment = {
        'PATH': os.environ.get('PATH', os.defpath), 'HOME': str(temporary),
        'TMPDIR': str(temporary), 'TMP': str(temporary), 'TEMP': str(temporary),
        'XDG_CACHE_HOME': str(temporary / 'cache'), 'PYTHONDONTWRITEBYTECODE': '1',
        'PYTHONNOUSERSITE': '1',
    }
    checked = subprocess.run(
        ['bash', '--noprofile', '--norc', str(root / 'mddocs/management/tooling/scripts/team-adopt.sh'), '--check'],
        env=environment, capture_output=True, timeout=30)
    if checked.returncode:
        raise ValueError('team readiness failed; create-only setup blocked')
    identity_path = root / '.agentic-team-identity.json'
    identity_raw = read_regular(identity_path, 4096)
    identity = json.loads(identity_raw)
    settings_path = root / 'pyproject.toml'
    settings_raw = read_regular(settings_path, 65536)
    settings = tomllib.loads(settings_raw.decode('utf-8'))
    # Support only the declared contract currently implemented, not arbitrary specifiers.
    if settings.get('project', {}).get('requires-python') != '>=3.11' or sys.version_info < (3, 11):
        raise ValueError('unsupported bootstrap Python requirement')
    target = root / '.venv'
    if os.path.lexists(target):
        raise ValueError('existing .venv is never overwritten, resumed, or repaired')
    print(f'Proposed step: create only {target}')
    print(f'Bootstrap interpreter: {sys.executable} ({sys.version.split()[0]})')
    print('No pip, dependency installation, network requests, activation, or launcher changes.')
    print('Recovery evidence will be stored under this workspace\'s .archive/.')
    print('Type CREATE_VENV to approve this exact step: ', end='', flush=True)
    if input() != 'CREATE_VENV':
        print('Declined. No files created.')
        return
    if (read_regular(identity_path, 4096) != identity_raw or
            read_regular(settings_path, 65536) != settings_raw or os.path.lexists(target)):
        raise ValueError('baseline changed; fresh approval required')
    private_directory(temporary)
    private_directory(archive)
    os.umask(0o077)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(tempfile.mkdtemp(prefix='venv-recovery-' + stamp + '-', dir=archive))
    private_directory(backup)
    baseline = {
        'workspace_id': identity['workspace_id'], 'workspace_path': str(root),
        'created_at': stamp, 'identity_sha256': digest(identity_raw),
        'pyproject_sha256': digest(settings_raw), 'absent': '.venv',
        'bootstrap_executable': sys.executable, 'python_version': sys.version.split()[0],
        'approval': 'Human typed CREATE_VENV for create-only setup, not dependency installation.',
        'recovery': 'After separate HIL approval, verify SHA256SUMS and preserve subsequent work. Move only .venv to an absent withdrawn-venv path in this recovery directory. A moved environment is review material, not a runnable restored environment. Never delete or replace other workspace contents.',
    }
    raw = (json.dumps(baseline, indent=2) + '\n').encode()
    (backup / 'baseline.json').write_bytes(raw)
    manifest = digest(raw) + '  baseline.json\n'
    (backup / 'SHA256SUMS').write_text(manifest)
    if (read_regular(backup / 'baseline.json', 65536) != raw or
            read_regular(backup / 'SHA256SUMS', 4096).decode() != manifest):
        raise ValueError('recovery verification failed')
    # Exclusive reservation; never let EnvBuilder reuse another environment.
    target.mkdir(mode=0o700)
    try:
        private_directory(target)
        venv.EnvBuilder(with_pip=False, system_site_packages=False,
                        clear=False, symlinks=False, upgrade=False).create(target)
        probe = '''import importlib.metadata, json, site, sys
print(json.dumps({"prefix": sys.prefix, "base_prefix": sys.base_prefix,
                  "user_site": site.ENABLE_USER_SITE,
                  "packages": [d.metadata["Name"] for d in importlib.metadata.distributions()]}))'''
        result = subprocess.run([str(target / 'bin/python'), '-I', '-B', '-c', probe],
                                env=environment, capture_output=True, text=True,
                                check=True, timeout=30)
        observed = json.loads(result.stdout)
        if (Path(observed['prefix']).resolve() != target or
                observed['prefix'] == observed['base_prefix'] or
                observed['user_site'] is not False or observed['packages']):
            raise ValueError('create-only environment verification failed')
        private_directory(target)
        print('Created and verified empty .venv; no packages installed, including pip.')
        print('Dependency readiness and automatic interpreter selection are not established.')
    except BaseException:
        print('STOP: incomplete .venv retained for review; no automatic repair/retry.', file=sys.stderr)
        print(f'Recovery evidence: {backup}', file=sys.stderr)
        raise
    print(f'Recovery evidence: {backup}')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise ValueError('no override arguments supported')
        initialize(Path(__file__).absolute().parents[4])
    except (OSError, ValueError, EOFError, subprocess.SubprocessError):
        print('STOP: create-only Python setup rejected or failed; no automatic repair.', file=sys.stderr)
        sys.exit(1)
