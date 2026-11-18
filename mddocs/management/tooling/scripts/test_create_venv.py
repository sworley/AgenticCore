"""Disposable create-only setup tests; no customer access or package installs."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import create_venv


ROOT = Path(__file__).resolve().parents[4]
SCRIPT = 'mddocs/management/tooling/scripts/team-adopt.sh'


class CreateVenvTests(unittest.TestCase):
    def setUp(self):
        temporary = ROOT / '.tmp'
        if temporary.is_symlink() or not temporary.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temporary = tempfile.TemporaryDirectory(prefix='create-venv-', dir=temporary)
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

    def run_setup(self, answer='CREATE_VENV\n', root=None):
        return subprocess.run(['bash', str((root or self.team) / SCRIPT), '--create-venv'],
                              input=answer, cwd=self.base, env=self.env,
                              capture_output=True, text=True, timeout=30)

    def snapshot(self):
        return {str(p.relative_to(self.base)): (
            p.lstat().st_mode, os.readlink(p) if p.is_symlink() else
            hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None)
            for p in self.base.rglob('*')}

    def test_decline_and_eof_have_no_writes(self):
        before = self.snapshot()
        self.assertEqual(self.run_setup('no\n').returncode, 0)
        self.assertEqual(self.run_setup('').returncode, 1)
        self.assertEqual(self.snapshot(), before)

    def test_create_empty_private_environment_and_no_replay(self):
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = self.team / '.venv'
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o700)
        self.assertIn('Created and verified empty .venv', result.stdout)
        self.assertIn('Bootstrap interpreter:', result.stdout)
        config = (target / 'pyvenv.cfg').read_text()
        self.assertIn('include-system-site-packages = false', config)
        probe = subprocess.run([str(target / 'bin/python'), '-I', '-B', '-c',
                                'import importlib.metadata,json;print(json.dumps(list(importlib.metadata.distributions())))'],
                               env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(probe.stdout), [])
        backups = list((self.team / '.archive').glob('venv-recovery-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o700)
        for name in ('baseline.json', 'SHA256SUMS'):
            self.assertEqual(stat.S_IMODE((backups[0] / name).stat().st_mode), 0o600)
        raw = (backups[0] / 'baseline.json').read_bytes()
        self.assertEqual((backups[0] / 'SHA256SUMS').read_text(),
                         hashlib.sha256(raw).hexdigest() + '  baseline.json\n')
        self.assertEqual(json.loads(raw)['absent'], '.venv')
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.team / '.envrc').exists())
        self.assertFalse((self.team / '.git').exists())

    def test_existing_directory_preserved(self):
        target = self.team / '.venv'
        target.mkdir()
        (target / 'keep.txt').write_text('preserve')
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_existing_file_preserved(self):
        (self.team / '.venv').write_text('preserve')
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_broken_environment_symlink_rejected(self):
        (self.team / '.venv').symlink_to(self.base / 'absent-target')
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_nonprivate_archive_rejected(self):
        (self.team / '.archive').chmod(0o755)
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_template_rejected(self):
        source = self.base / 'template-source'
        (source / '.tmp').chmod(0o700)
        (source / '.archive').chmod(0o700)
        before = self.snapshot()
        self.assertEqual(self.run_setup(root=source).returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_unsupported_python_contract_rejected(self):
        path = self.team / 'pyproject.toml'
        path.write_text(path.read_text().replace('>=3.11', '>=99.0'))
        before = self.snapshot()
        self.assertEqual(self.run_setup().returncode, 1)
        self.assertEqual(before, self.snapshot())

    def test_baseline_change_after_confirmation_rejected(self):
        settings = self.team / 'pyproject.toml'

        def change_settings():
            settings.write_text(settings.read_text() + '\n# changed after prompt\n')
            return 'CREATE_VENV'

        with patch('builtins.input', side_effect=change_settings):
            with self.assertRaises(ValueError):
                create_venv.initialize(self.team)
        self.assertFalse((self.team / '.venv').exists())
        self.assertEqual(list((self.team / '.archive').glob('venv-recovery-*')), [])

    def test_creation_failure_retains_target_and_recovery(self):
        with patch('builtins.input', return_value='CREATE_VENV'), \
                patch.object(create_venv.venv.EnvBuilder, 'create', side_effect=OSError('synthetic failure')):
            with self.assertRaises(OSError):
                create_venv.initialize(self.team)
        self.assertTrue((self.team / '.venv').is_dir())
        self.assertEqual(len(list((self.team / '.archive').glob('venv-recovery-*'))), 1)
        self.assertEqual(self.run_setup().returncode, 1)


if __name__ == '__main__':
    unittest.main()
