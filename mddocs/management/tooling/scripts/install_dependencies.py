"""Confirmed first installation from verified locks; no updates, activation, or retry."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

# The isolated CLI imports only the explicitly selected framework helper directory.
sys.path.insert(0, str(Path(__file__).absolute().parent))
from create_venv import digest, private_directory, read_regular


LOCK_ROOT = 'mddocs/management/tooling/python/requirements'
MARKER = '.dependency-install.json'


def safe_file(root, relative, maximum=65536):
    parts = relative.split('/')
    if any(p in ('', '.', '..') for p in parts) or '\\' in relative:
        raise ValueError('unsafe input path')
    path = root
    for part in parts:
        path /= part
        if path.is_symlink():
            raise ValueError('symlinked input')
    return read_regular(path, maximum)


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('duplicate JSON key')
        value[key] = item
    return value


def probe(python, environment):
    code = '''import importlib.metadata, json, platform, site, sys
print(json.dumps({"prefix": sys.prefix, "base_prefix": sys.base_prefix,
 "user_site": site.ENABLE_USER_SITE, "implementation": platform.python_implementation(),
 "version": platform.python_version(), "platform": sys.platform, "machine": platform.machine(),
 "packages": [[d.metadata["Name"], d.version] for d in importlib.metadata.distributions()]}))'''
    result = subprocess.run([str(python), '-I', '-B', '-c', code], env=environment,
                            check=True, capture_output=True, text=True, timeout=30)
    return json.loads(result.stdout, object_pairs_hook=unique)


def inventory(observed):
    packages = {}
    for name, version in observed['packages']:
        key = re.sub(r'[-_.]+', '-', name).lower()
        if key in packages:
            raise ValueError('duplicate installed distribution')
        packages[key] = version
    return packages


def locked_packages(raw):
    """Accept only the current generated pin/hash format, never arbitrary pip options."""
    packages = {}
    hashes = {}
    current = None
    for line in raw.decode('utf-8').splitlines():
        token = line.strip().removesuffix('\\').rstrip()
        if not token or token.startswith('#'):
            continue
        pin = re.fullmatch(r'([a-z0-9][a-z0-9_.-]*)==([A-Za-z0-9.+!-]+)', token)
        if pin:
            current = re.sub(r'[-_.]+', '-', pin[1])
            if current in packages:
                raise ValueError('duplicate lock pin')
            packages[current] = pin[2]
            hashes[current] = 0
        elif current and re.fullmatch(r'--hash=sha256:[0-9a-f]{64}', token):
            hashes[current] += 1
        else:
            raise ValueError('unsupported lock syntax')
    if any(count == 0 for count in hashes.values()):
        raise ValueError('lock pin missing hashes')
    return packages


def prepare(root, group):
    if group not in ('runtime', 'test') or root.is_symlink() or any(p.is_symlink() for p in root.parents):
        raise ValueError('unsupported scope or unsafe workspace')
    for relative in ('.tmp', '.archive', '.venv'):
        private_directory(root / relative)
    environment = {
        'PATH': os.environ.get('PATH', os.defpath), 'HOME': str(root / '.tmp'),
        'TMPDIR': str(root / '.tmp'), 'TMP': str(root / '.tmp'), 'TEMP': str(root / '.tmp'),
        'XDG_CACHE_HOME': str(root / '.tmp/cache'), 'UV_CACHE_DIR': str(root / '.tmp/uv-cache'),
        'UV_PYTHON_DOWNLOADS': 'never', 'PYTHONDONTWRITEBYTECODE': '1', 'PYTHONNOUSERSITE': '1',
    }
    checked = subprocess.run(
        ['bash', '--noprofile', '--norc', str(root / 'mddocs/management/tooling/scripts/team-adopt.sh'), '--check'],
        env=environment, capture_output=True, timeout=30)
    if checked.returncode:
        raise ValueError('team readiness failed')
    if os.path.lexists(root / '.venv' / MARKER):
        raise ValueError('prior installation attempt exists; no automatic update or retry')
    metadata_raw = safe_file(root, LOCK_ROOT + '/verified-target.json')
    metadata = json.loads(metadata_raw, object_pairs_hook=unique)
    if type(metadata['schema_version']) is not int or metadata['schema_version'] != 1:
        raise ValueError('unsupported lock metadata')
    if metadata['target'] != {'implementation': 'CPython', 'version': '3.13.15',
                              'platform': 'linux', 'machine': 'x86_64'}:
        raise ValueError('unsupported verified target')
    entry = metadata['locks'][group]
    if (entry['filename'] != f'{group}-linux-x86_64-cpython313.lock' or
            not isinstance(entry['packages'], dict)):
        raise ValueError('unsupported lock entry')
    inputs = {
        'identity.json': safe_file(root, '.agentic-team-identity.json', 4096),
        'pyproject.toml': safe_file(root, 'pyproject.toml'),
        'verified-target.json': metadata_raw,
        'selected.lock': safe_file(root, LOCK_ROOT + '/' + entry['filename']),
        'pyvenv.cfg': safe_file(root, '.venv/pyvenv.cfg'),
    }
    if (digest(inputs['pyproject.toml']) != metadata['pyproject_sha256'] or
            digest(inputs['selected.lock']) != entry['sha256']):
        raise ValueError('declarations or lock differ from the verified set')
    if locked_packages(inputs['selected.lock']) != entry['packages']:
        raise ValueError('lock pins and expected inventory disagree')
    if 'include-system-site-packages = false' not in inputs['pyvenv.cfg'].decode().splitlines():
        raise ValueError('system-site packages must be disabled')
    # Reject a redirected interpreter before executing it; bin must also be real.
    safe_file(root, '.venv/bin/python', 64 * 1024 * 1024)
    python = root / '.venv/bin/python'
    observed = probe(python, environment)
    if (Path(observed['prefix']).resolve() != root / '.venv' or
            observed['prefix'] == observed['base_prefix'] or observed['user_site'] is not False or
            inventory(observed) or any(observed[k] != v for k, v in metadata['target'].items())):
        raise ValueError('empty environment or verified target requirement failed')
    uv = shutil.which('uv', path=environment['PATH'])
    if uv is None:
        raise ValueError('required installer is missing; no automatic installation')
    version = subprocess.run([uv, '--version'], env=environment, check=True,
                             capture_output=True, text=True, timeout=10).stdout.strip()
    if not re.fullmatch(r'uv ' + re.escape(metadata['installer_version']) + r'(?: \([^\n]*\))?', version):
        raise ValueError('installer version differs from verified version')
    return {'inputs': inputs, 'metadata': metadata, 'entry': entry, 'python': python,
            'uv': uv, 'version': version, 'environment': environment, 'observed': observed}


def write_record(path, value, exclusive):
    flags = os.O_WRONLY | os.O_NOFOLLOW | os.O_NONBLOCK
    if exclusive:
        flags |= os.O_CREAT | os.O_EXCL
    fd = os.open(path, flags, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError('unsafe installation record')
        stream.truncate(0)
        stream.write((json.dumps(value, indent=2) + '\n').encode())
        stream.flush()
        os.fsync(stream.fileno())


def install(root, group):
    context = prepare(root, group)
    print(f'Proposed step: first {group} dependency installation into {root / ".venv"}')
    print(f'Lock: {context["entry"]["filename"]}; SHA-256: {context["entry"]["sha256"]}')
    print(f'Installer: {context["uv"]} ({context["version"]})')
    if context['entry']['packages']:
        print('Source: public PyPI only. Required hashes; binary wheels only; no dependency resolution.')
    else:
        print('Runtime set is empty: no package download or installation is needed.')
    print('Writes: .venv/, .tmp/ caches and temporary output, .archive/ recovery evidence.')
    print('No pip/bootstrap installation, global change, activation, or launcher change.')
    expected = 'INSTALL_' + group.upper()
    print(f'Type {expected} to approve this exact operation: ', end='', flush=True)
    if input() != expected:
        print('Declined. No installation or recovery records created.')
        return
    current = prepare(root, group)
    if any(current[k] != context[k] for k in ('inputs', 'uv', 'version', 'observed')):
        raise ValueError('baseline changed after confirmation; fresh approval required')
    os.umask(0o077)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup = Path(tempfile.mkdtemp(prefix='dependency-recovery-' + stamp + '-', dir=root / '.archive'))
    private_directory(backup)
    record = {
        'workspace_path': str(root), 'group': group, 'created_at': stamp,
        'installer': context['uv'], 'installer_version': context['version'],
        'lock_sha256': context['entry']['sha256'], 'before_inventory': {},
        'expected_inventory': context['entry']['packages'], 'state': 'in progress',
        'recovery': 'After separate HIL approval verify SHA256SUMS and preserve later work. Withdraw only .venv to an absent withdrawn-venv path in this archive. Recreate an empty environment with a compatible bootstrap under fresh approval; do not run the relocated environment or automatically retry installation.',
    }
    manifest = []
    for name, data in context['inputs'].items():
        (backup / name).write_bytes(data)
        manifest.append(digest(data) + '  ' + name + '\n')
    baseline = (json.dumps(record, indent=2) + '\n').encode()
    (backup / 'baseline.json').write_bytes(baseline)
    manifest.append(digest(baseline) + '  baseline.json\n')
    (backup / 'SHA256SUMS').write_text(''.join(manifest))
    for line in manifest:
        checksum, name = line.rstrip().split('  ', 1)
        if digest(read_regular(backup / name, 65536)) != checksum:
            raise ValueError('recovery verification failed')
    marker = root / '.venv' / MARKER
    write_record(marker, record, exclusive=True)
    try:
        if context['entry']['packages']:
            command = [context['uv'], '--no-config', 'pip', 'install', '--python', str(context['python']),
                       '--no-python-downloads', '--default-index', 'https://pypi.org/simple',
                       '--only-binary', ':all:', '--require-hashes', '--no-deps',
                       '-r', str(backup / 'selected.lock')]
            subprocess.run(command, env=context['environment'], check=True,
                           capture_output=True, timeout=180)
        subprocess.run([context['uv'], '--no-config', 'pip', 'check', '--python', str(context['python'])],
                       env=context['environment'], check=True, capture_output=True, timeout=30)
        observed = probe(context['python'], context['environment'])
        if (inventory(observed) != context['entry']['packages'] or
                observed['prefix'] != context['observed']['prefix'] or
                observed['user_site'] is not False):
            raise ValueError('installed inventory differs from the verified lock')
        record['state'] = 'verified'
        write_record(marker, record, exclusive=False)
    except BaseException:
        print('STOP: installation incomplete or unverified; state retained, no automatic retry.', file=sys.stderr)
        print(f'Recovery evidence: {backup}', file=sys.stderr)
        raise
    print(f'Verified {group} package inventory; no environment activation or interpreter routing performed.')
    print(f'Recovery evidence: {backup}')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ('runtime', 'test'):
            raise ValueError('exactly one supported dependency group is required')
        install(Path(__file__).absolute().parents[4], sys.argv[1])
    except (OSError, ValueError, KeyError, TypeError, EOFError, subprocess.SubprocessError):
        print('STOP: locked dependency setup rejected or failed; no automatic repair.', file=sys.stderr)
        sys.exit(1)
