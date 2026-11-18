"""Explicitly approved, first-time private receipt creation; no stage execution."""
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


STAGES = ('identity', 'project', 'local_home', 'git', 'guardrail',
          'documentation_mcp', 'authentication', 'runtime_checks',
          'model_smoke', 'ci_scanning', 'telemetry')
REQUIRED = {'identity', 'local_home', 'runtime_checks'}


def timestamp():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def private_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('unsafe private directory')


def initialize(root):
    # The existing readiness check validates target identity without changing it.
    checked = subprocess.run(['bash', str(root / 'mddocs/management/tooling/scripts/team-adopt.sh'), '--check'],
                             capture_output=True, timeout=30)
    if checked.returncode:
        raise ValueError('readiness failed; state initialization blocked')
    identity_path = root / '.agentic-team-identity.json'
    identity_raw = identity_path.read_bytes()
    identity = json.loads(identity_raw)
    home = root / '.codex-home'
    private_directory(home)
    archive = root / '.archive'
    private_directory(archive)
    target = home / 'adoption'
    if os.path.lexists(target):
        raise ValueError('adoption directory already exists; initialization never overwrites or resumes it')
    print('Proposed step: create private adoption/state.json and state.lock only.')
    print('No stages, authentication, services, or configuration settings will be changed.')
    print('A verified absence/recovery record will be stored in this team\'s .archive/.')
    print('Type INITIALIZE to approve this exact step: ', end='', flush=True)
    if input() != 'INITIALIZE':
        print('Declined. No files created.')
        return
    # Recheck the target and baseline after approval, before writing.
    if identity_path.read_bytes() != identity_raw or os.path.lexists(target):
        raise ValueError('scope/baseline changed; fresh approval required')
    private_directory(home)
    private_directory(archive)
    os.umask(0o077)
    backup = Path(tempfile.mkdtemp(
        prefix='adoption-recovery-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-',
        dir=archive))
    private_directory(backup)
    baseline = {
        'workspace_id': identity['workspace_id'], 'workspace_path': str(root),
        'identity_sha256': digest(identity_raw), 'created_at': timestamp(),
        'absent': '.codex-home/adoption',
        'approval': 'Operator typed INITIALIZE for private receipt creation only.',
        'recovery': 'Preserve later work. After separate approval, move only this team adoption directory to an absent withdrawn-adoption path in this recovery directory. Never delete or replace other team state.'}
    raw = (json.dumps(baseline, indent=2) + '\n').encode()
    (backup / 'baseline.json').write_bytes(raw)
    (backup / 'SHA256SUMS').write_text(digest(raw) + '  baseline.json\n')
    expected_manifest = digest(raw) + '  baseline.json\n'
    if (digest((backup / 'baseline.json').read_bytes()) != digest(raw) or
            (backup / 'SHA256SUMS').read_text() != expected_manifest):
        raise ValueError('recovery verification failed')
    # Exclusive directory creation prevents a second initializer from entering.
    target.mkdir(mode=0o700)
    try:
        private_directory(target)
        lock_fd = os.open(target / 'state.lock', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(lock_fd, 'wb') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if identity_path.read_bytes() != identity_raw:
                raise ValueError('identity changed; initialization interrupted')
            receipt = {
                'schema_version': 1, 'bootstrap_version': '0.1.0',
                'workspace_id': identity['workspace_id'], 'workspace_path': str(root),
                'identity_sha256': digest(identity_raw), 'revision': 0,
                'updated_at': timestamp(), 'stages': {
                    stage: {'applicability': 'not applicable' if stage == 'project' else
                            'required' if stage in REQUIRED else 'optional',
                            'rationale': 'Project setup is outside dev-space adoption.' if stage == 'project' else '',
                            'configuration': 'not applicable' if stage == 'project' else 'not configured',
                            'verification': 'not verified', 'acceptance': 'pending',
                            'attempt': None} for stage in STAGES}}
            # These are initial unknown states, not conclusions about existing tools.
            payload = (json.dumps(receipt, indent=2) + '\n').encode()
            if len(payload) > 256 * 1024:
                raise ValueError('receipt exceeds limit')
            fd, temporary = tempfile.mkstemp(prefix='.state-', dir=target)
            with os.fdopen(fd, 'wb') as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            if json.loads(Path(temporary).read_bytes()) != receipt:
                raise ValueError('receipt verification failed')
            # First creation only; link publishes without replacing an existing file.
            os.link(temporary, target / 'state.json', follow_symlinks=False)
            Path(temporary).unlink()
            directory_fd = os.open(target, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
    except BaseException:
        print('STOP: incomplete adoption directory retained; do not retry automatically.', file=sys.stderr)
        print(f'Recovery evidence: {backup}', file=sys.stderr)
        raise
    print('Initialized private receipt; all verification unperformed, all acceptance pending.')
    print(f'Recovery evidence: {backup}')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 1:
            raise ValueError('no target or override arguments supported')
        initialize(Path(__file__).resolve().parents[4])
    except (OSError, ValueError, EOFError, subprocess.SubprocessError):
        print('STOP: initialization rejected or failed; no automatic repair/resume.', file=sys.stderr)
        sys.exit(1)
