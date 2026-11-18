"""Synthetic installer-control tests, not a real PyPI installation or package test."""
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import venv

import install_dependencies


ROOT = Path(__file__).resolve().parents[4]
SCRIPT = 'mddocs/management/tooling/scripts/team-adopt.sh'
LOCK_ROOT = 'mddocs/management/tooling/python/requirements'


@unittest.skipUnless(platform.python_implementation() == 'CPython' and
                     platform.python_version() == '3.13.15' and sys.platform == 'linux' and
                     platform.machine() == 'x86_64', 'installation target is CPython 3.13.15/Linux x86_64')
class InstallDependencyTests(unittest.TestCase):
    def setUp(self):
        temporary = ROOT / '.tmp'
        if temporary.is_symlink() or not temporary.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temporary = tempfile.TemporaryDirectory(prefix='install-deps-', dir=temporary)
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.env = {'PATH': os.environ['PATH'], 'HOME': str(self.base),
                    'TMPDIR': str(self.base), 'TMP': str(self.base), 'TEMP': str(self.base),
                    'XDG_CACHE_HOME': str(self.base / 'cache'), 'PYTHONDONTWRITEBYTECODE': '1'}
        source = self.base / 'template-source'
        for relative in (ROOT / 'TEMPLATE_FILES.txt').read_text().splitlines():
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        result = subprocess.run(['bash', str(source / 'mddocs/management/tooling/scripts/template-deploy.sh')],
                                input=f'{self.base}\nTest\n', env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.team = self.base / 'Test.v0.1'
        target = self.team / '.venv'
        target.mkdir(mode=0o700)
        venv.EnvBuilder(with_pip=False, symlinks=False).create(target)
        fakebin = self.base / 'fakebin'
        fakebin.mkdir()
        uv = fakebin / 'uv'
        # The stand-in writes only synthetic distribution metadata, never imports
        # or downloads packages. The real environment probe observes that metadata.
        uv.write_text(f'#!{sys.executable}\nTEAM = {str(self.team)!r}\n' + '''
import json, os, pathlib, subprocess, sys
root = pathlib.Path(TEAM)
if sys.argv[1:] == ['--version']:
    version = root / '.tmp/fake-uv-version'
    print(version.read_text() if version.exists() else 'uv 0.12.17')
    sys.exit(0)
with (root / '.tmp/fake-uv-log.jsonl').open('a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'env': dict(os.environ)}) + '\\n')
behavior_file = root / '.tmp/fake-uv-behavior'
behavior = behavior_file.read_text() if behavior_file.exists() else ''
if 'install' in sys.argv:
    if behavior == 'fail':
        sys.exit(2)
    python = sys.argv[sys.argv.index('--python') + 1]
    purelib = pathlib.Path(subprocess.check_output(
        [python, '-I', '-B', '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))'], text=True).strip())
    packages = json.loads((root / 'mddocs/management/tooling/python/requirements/verified-target.json').read_text())['locks']['test']['packages']
    if behavior == 'wrong':
        packages = {'unexpected': '1.0'}
    for name, version in packages.items():
        metadata = purelib / (name.replace('-', '_') + '-' + version + '.dist-info')
        metadata.mkdir()
        (metadata / 'METADATA').write_text('Metadata-Version: 2.1\\nName: ' + name + '\\nVersion: ' + version + '\\n')
elif behavior == 'check-fail':
    sys.exit(3)
''')
        uv.chmod(0o700)
        self.env['PATH'] = str(fakebin) + os.pathsep + self.env['PATH']

    def run_install(self, group='test', answer=None, root=None):
        return subprocess.run(['bash', str((root or self.team) / SCRIPT), f'--install-{group}-deps'],
                              input=('INSTALL_' + group.upper() + '\n') if answer is None else answer,
                              cwd=self.base, env=self.env, capture_output=True, text=True, timeout=30)

    def snapshot(self):
        return {str(p.relative_to(self.base)): (p.lstat().st_mode,
                os.readlink(p) if p.is_symlink() else
                hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None)
                for p in self.base.rglob('*')}

    def test_decline_and_eof_do_not_write(self):
        before = self.snapshot()
        self.assertEqual(self.run_install(answer='no\n').returncode, 0)
        self.assertEqual(self.run_install(answer='').returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_synthetic_test_install_exact_flags_inventory_and_no_replay(self):
        self.env.update(UV_INDEX_URL='https://ignored.invalid', PIP_INDEX_URL='https://ignored.invalid',
                        PYTHONPATH='/synthetic-ignored-path', BASH_ENV='/synthetic-ignored-bashenv')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        marker = self.team / '.venv/.dependency-install.json'
        record = json.loads(marker.read_text())
        self.assertEqual(record['state'], 'verified')
        self.assertEqual(stat.S_IMODE(marker.stat().st_mode), 0o600)
        calls = [json.loads(s) for s in (self.team / '.tmp/fake-uv-log.jsonl').read_text().splitlines()]
        command = calls[0]['args']
        for flag in ('--no-config', '--no-python-downloads', '--only-binary', '--require-hashes', '--no-deps'):
            self.assertIn(flag, command)
        self.assertEqual(command[command.index('--default-index') + 1], 'https://pypi.org/simple')
        for name in ('UV_INDEX_URL', 'PIP_INDEX_URL', 'PYTHONPATH', 'BASH_ENV'):
            self.assertNotIn(name, calls[0]['env'])
        self.assertEqual(calls[0]['env']['UV_CACHE_DIR'], str(self.team / '.tmp/uv-cache'))
        backups = list((self.team / '.archive').glob('dependency-recovery-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o700)
        for line in (backups[0] / 'SHA256SUMS').read_text().splitlines():
            checksum, name = line.split('  ', 1)
            self.assertEqual(hashlib.sha256((backups[0] / name).read_bytes()).hexdigest(), checksum)
            self.assertEqual(stat.S_IMODE((backups[0] / name).stat().st_mode), 0o600)
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.team / '.envrc').exists())

    def test_empty_runtime_set_does_not_install(self):
        result = self.run_install(group='runtime')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(s) for s in (self.team / '.tmp/fake-uv-log.jsonl').read_text().splitlines()]
        self.assertTrue(all('install' not in c['args'] for c in calls))
        record = json.loads((self.team / '.venv/.dependency-install.json').read_text())
        self.assertEqual(record['expected_inventory'], {})

    def test_changed_lock_rejected_before_confirmation(self):
        p = self.team / LOCK_ROOT / 'test-linux-x86_64-cpython313.lock'
        p.write_text(p.read_text() + '# changed\n')
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_stale_declarations_rejected(self):
        p = self.team / 'pyproject.toml'
        p.write_text(p.read_text() + '\n# changed\n')
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_wrong_installer_version_rejected(self):
        (self.team / '.tmp/fake-uv-version').write_text('uv 0.0.0')
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_unsupported_interpreter_target_rejected(self):
        p = self.team / LOCK_ROOT / 'verified-target.json'
        metadata = json.loads(p.read_text())
        metadata['target']['version'] = '99.0.0'
        p.write_text(json.dumps(metadata))
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_existing_packages_rejected(self):
        python = self.team / '.venv/bin/python'
        purelib = Path(subprocess.check_output([str(python), '-I', '-B', '-c',
                         'import sysconfig;print(sysconfig.get_path("purelib"))'], env=self.env, text=True).strip())
        info = purelib / 'existing-1.0.dist-info'
        info.mkdir()
        (info / 'METADATA').write_text('Metadata-Version: 2.1\nName: existing\nVersion: 1.0\n')
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_failed_installer_retains_attempt_and_blocks_retry(self):
        (self.team / '.tmp/fake-uv-behavior').write_text('fail')
        self.assertEqual(self.run_install().returncode, 1)
        self.assertTrue((self.team / '.venv/.dependency-install.json').is_file())
        before = self.snapshot()
        self.assertEqual(self.run_install().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_incorrect_installed_inventory_blocks_success(self):
        (self.team / '.tmp/fake-uv-behavior').write_text('wrong')
        self.assertEqual(self.run_install().returncode, 1)
        marker = json.loads((self.team / '.venv/.dependency-install.json').read_text())
        self.assertEqual(marker['state'], 'in progress')

    def test_template_rejected(self):
        before = self.snapshot()
        self.assertEqual(self.run_install(root=self.base / 'template-source').returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_changed_baseline_after_confirmation_rejected(self):
        def change_settings():
            p = self.team / 'pyproject.toml'
            p.write_text(p.read_text() + '\n# changed after prompt\n')
            return 'INSTALL_TEST'
        with patch.dict(os.environ, self.env, clear=True), patch('builtins.input', side_effect=change_settings), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError):
                install_dependencies.install(self.team, 'test')
        self.assertFalse((self.team / '.venv/.dependency-install.json').exists())
        self.assertEqual(list((self.team / '.archive').glob('dependency-recovery-*')), [])


if __name__ == '__main__':
    unittest.main()
