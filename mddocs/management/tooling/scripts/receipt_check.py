"""Read-only receipt schema/baseline inspection. Never resume or trust approvals."""
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import uuid

from adoption_state import STAGES, private_directory


def require(condition):
    if not condition:
        raise ValueError('invalid receipt')


def string(value, maximum=4096, empty=False):
    require(isinstance(value, str) and (empty or bool(value)))
    require(len(value.encode('utf-8')) <= maximum and not any(ord(c) < 32 for c in value))


def keys(value, names):
    require(isinstance(value, dict) and set(value) == set(names.split()))


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


def sha(value):
    require(isinstance(value, str) and re.fullmatch('[0-9a-f]{64}', value))


def identifier(value):
    string(value, 36)
    parsed = uuid.UUID(value)
    require(parsed.version == 4 and str(parsed) == value)


def timestamp(value):
    string(value, 20)
    require(re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z', value))
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')


def reference(value):
    if value is not None:
        string(value)
        # Restrict receipt references to local evidence locators, never URLs.
        require('://' not in value and '?' not in value and '@' not in value)


def read_file(path, limit, private=False):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode))
        if private:
            require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600)
        value = stream.read(limit + 1)
    require(len(value) <= limit)
    return value


def safe_input(root, path, portable):
    string(path, 1024)
    require(path in portable)
    components = path.split('/')
    require(all(p not in ('', '.', '..') for p in components) and '\\' not in path)
    # Only reviewed portable files can be compared, never auth/runtime receipts.
    require(not (components[0] == '.codex-home' and path not in {
        '.codex-home/config.toml', '.codex-home/AGENTS.md', '.codex-home/rules/template.rules'}))
    require(not any(p in {'.git', '.mcp', 'credentials', 'secrets', 'sessions', 'runtime', 'adoption'} for p in components))
    result = root
    for component in components:
        result /= component
        require(not result.is_symlink())
    return result


def validate(state):
    keys(state, 'schema_version bootstrap_version workspace_id workspace_path identity_sha256 revision updated_at stages')
    require(type(state['schema_version']) is int and state['schema_version'] == 1)
    require(isinstance(state['bootstrap_version'], str) and re.fullmatch('[A-Za-z0-9.-]{1,64}', state['bootstrap_version']))
    identifier(state['workspace_id'])
    string(state['workspace_path'])
    require(Path(state['workspace_path']).is_absolute())
    sha(state['identity_sha256'])
    require(type(state['revision']) is int and state['revision'] >= 0)
    timestamp(state['updated_at'])
    require(isinstance(state['stages'], dict) and set(state['stages']) == set(STAGES))
    for stage in state['stages'].values():
        keys(stage, 'applicability rationale configuration verification acceptance attempt')
        require(stage['applicability'] in ('required', 'optional', 'deferred', 'not applicable'))
        string(stage['rationale'], 1024, empty=stage['applicability'] not in ('deferred', 'not applicable'))
        require(stage['configuration'] in ('not configured', 'configured', 'not applicable'))
        require(stage['verification'] in ('not verified', 'verified', 'failed', 'stale'))
        require(stage['acceptance'] in ('pending', 'operator accepted', 'stale'))
        a = stage['attempt']
        if a is None:
            require(stage['verification'] == 'not verified' and stage['acceptance'] == 'pending')
            continue
        keys(a, 'step_id scope_sha256 approval_ref backup_ref inputs tools started_at finished_at execution verification_ref verified_at acceptance_ref accepted_at')
        identifier(a['step_id'])
        sha(a['scope_sha256'])
        for field in ('approval_ref', 'backup_ref', 'verification_ref', 'acceptance_ref'):
            reference(a[field])
        require(a['approval_ref'] is not None)
        require(isinstance(a['inputs'], dict) and len(a['inputs']) <= 64)
        for path, value in a['inputs'].items():
            string(path, 1024)
            if value is not None:
                sha(value)
        require(isinstance(a['tools'], dict) and len(a['tools']) <= 32)
        for name, version in a['tools'].items():
            require(re.fullmatch('[A-Za-z0-9_.-]{1,64}', name))
            if version is not None:
                string(version, 128)
        start = timestamp(a['started_at'])
        for field in ('finished_at', 'verified_at', 'accepted_at'):
            if a[field] is not None:
                require(timestamp(a[field]) >= start)
        require(a['execution'] in ('in progress', 'succeeded', 'failed', 'interrupted'))
        if a['execution'] in ('succeeded', 'failed', 'interrupted'):
            require(a['finished_at'] is not None)
        if stage['verification'] == 'verified':
            require(a['execution'] == 'succeeded' and a['verification_ref'] is not None and a['verified_at'] is not None)
        if stage['acceptance'] == 'operator accepted':
            require(stage['verification'] == 'verified' and a['acceptance_ref'] is not None and a['accepted_at'] is not None)
            require(timestamp(a['accepted_at']) >= timestamp(a['verified_at']))


def inspect(root):
    check = subprocess.run(['bash', str(root / 'mddocs/management/tooling/scripts/team-adopt.sh'), '--check'],
                           capture_output=True, timeout=30)
    require(check.returncode == 0)
    private_directory(root / '.codex-home')
    target = root / '.codex-home/adoption'
    if not os.path.lexists(target):
        print('Receipt: ABSENT; no state created. Initialization requires separate approval.')
        return 0
    private_directory(target)
    # Open existing lock read-only, never create/truncate it.
    fd = os.open(target / 'state.lock', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as lock:
        info = os.fstat(lock.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600)
        fcntl.flock(lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
        state = json.loads(read_file(target / 'state.json', 256 * 1024, private=True), object_pairs_hook=unique)
        validate(state)
        raw_identity = read_file(root / '.agentic-team-identity.json', 4096, private=True)
        identity = json.loads(raw_identity)
        drift = (state['workspace_id'] != identity['workspace_id'] or
                 state['workspace_path'] != str(root) or
                 state['identity_sha256'] != hashlib.sha256(raw_identity).hexdigest())
        print('Receipt schema: VALID; claims are not independently accepted evidence.')
        if drift:
            print('Workspace binding: MISMATCH; rebind/review required, no changes made.')
        portable = set(read_file(root / 'TEMPLATE_FILES.txt', 65536).decode().splitlines())
        unresolved = drift or state['bootstrap_version'] != '0.1.0'
        for name in STAGES:
            stage = state['stages'][name]
            attempt = stage['attempt']
            stale = drift
            if attempt:
                for relative, expected in attempt['inputs'].items():
                    path = safe_input(root, relative, portable)
                    if expected is None:
                        stale |= os.path.lexists(path)
                    else:
                        try:
                            actual = hashlib.sha256(read_file(path, 4 * 1024 * 1024)).hexdigest()
                        except FileNotFoundError:
                            actual = None
                        stale |= actual != expected
                if attempt['execution'] == 'in progress':
                    print(name + ': UNRESOLVED attempt; never replay automatically.')
                    unresolved = True
                if attempt['tools']:
                    print(name + ': tool versions NOT RECHECKED; no executable probes performed.')
                    unresolved = True
                if stage['verification'] == 'verified' or stage['acceptance'] == 'operator accepted':
                    print(name + ': recorded claims require evidence/freshness review; not reaccepted.')
                    unresolved = True
            print(name + ': ' + ('STALE baseline' if stale else 'no compared-input drift detected') +
                  '; verification=' + stage['verification'] + '; acceptance=' + stage['acceptance'])
            unresolved |= stale
        print('Read-only report: no receipt updates, repairs, acceptance, or action replay.')
        return 1 if unresolved else 0


if __name__ == '__main__':
    try:
        require(len(sys.argv) == 1)
        sys.exit(inspect(Path(__file__).resolve().parents[4]))
    except (OSError, ValueError, TypeError, KeyError, RecursionError, subprocess.SubprocessError):
        print('STOP: invalid, unsafe, busy, or unreadable receipt/baseline; manual review required.', file=sys.stderr)
        sys.exit(1)
