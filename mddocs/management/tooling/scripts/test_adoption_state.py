"""Disposable receipt initialization and refusal tests."""
from pathlib import Path
import hashlib
import json
import os
import stat
import subprocess
import tempfile
import shutil
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = 'mddocs/management/tooling/scripts/team-adopt.sh'


class StateTests(unittest.TestCase):
    def setUp(self):
        temp_root = ROOT / '.tmp'
        if temp_root.is_symlink() or not temp_root.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temp = tempfile.TemporaryDirectory(prefix='adoption-state-', dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)
        self.env = {'HOME': str(self.parent), 'PATH': os.environ['PATH'],
                    'TMPDIR': str(self.parent), 'TMP': str(self.parent), 'TEMP': str(self.parent),
                    'XDG_CACHE_HOME': str(self.parent / 'cache'), 'PYTHONDONTWRITEBYTECODE': '1'}
        source = self.parent / 'template-source'
        for relative in (ROOT / 'TEMPLATE_FILES.txt').read_text().splitlines():
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        result = subprocess.run(['bash', str(source / 'mddocs/management/tooling/scripts/template-deploy.sh')],
                                input=f'{self.parent}\nTest\n', env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.team = self.parent / 'Test.v0.1'

    def run_init(self, answer='INITIALIZE\n', root=None):
        return subprocess.run(['bash', str((root or self.team) / SCRIPT), '--initialize-state'],
                              input=answer, env=self.env, capture_output=True, text=True, timeout=10)

    def test_decline_and_eof(self):
        before = sorted(p.name for p in self.parent.iterdir())
        archive_before = sorted(p.name for p in (self.team / '.archive').iterdir())
        self.assertEqual(self.run_init('no\n').returncode, 0)
        self.assertNotEqual(self.run_init('').returncode, 0)
        self.assertEqual(before, sorted(p.name for p in self.parent.iterdir()))
        self.assertEqual(archive_before, sorted(p.name for p in (self.team / '.archive').iterdir()))

    def test_initialization_and_no_replay(self):
        result = self.run_init()
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.team / '.codex-home/adoption'
        raw = (target / 'state.json').read_bytes()
        receipt = json.loads(raw)
        identity = json.loads((self.team / '.agentic-team-identity.json').read_text())
        self.assertEqual(receipt['workspace_id'], identity['workspace_id'])
        self.assertEqual(receipt['workspace_path'], str(self.team))
        self.assertEqual(len(receipt['stages']), 11)
        self.assertEqual(receipt['stages']['project']['applicability'], 'not applicable')
        self.assertEqual(receipt['stages']['project']['configuration'], 'not applicable')
        self.assertEqual(receipt['stages']['project']['rationale'], 'Project setup is outside dev-space adoption.')
        self.assertTrue(all(s['attempt'] is None and s['acceptance'] == 'pending' and
                            s['verification'] == 'not verified' for s in receipt['stages'].values()))
        for path, mode in ((target, 0o700), (target / 'state.json', 0o600), (target / 'state.lock', 0o600)):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), mode)
        backups = list((self.team / '.archive').glob('adoption-recovery-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(list(self.parent.glob('*adoption-recovery-*')), [])
        self.assertIn(str(backups[0]), result.stdout)
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o700)
        for name in ('baseline.json', 'SHA256SUMS'):
            self.assertEqual(stat.S_IMODE((backups[0] / name).stat().st_mode), 0o600)
        baseline = json.loads((backups[0] / 'baseline.json').read_text())
        self.assertEqual(baseline['workspace_path'], str(self.team))
        self.assertEqual(baseline['absent'], '.codex-home/adoption')
        self.assertEqual((backups[0] / 'SHA256SUMS').read_text().split()[0],
                         hashlib.sha256((backups[0] / 'baseline.json').read_bytes()).hexdigest())
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertEqual(backups, list((self.team / '.archive').glob('adoption-recovery-*')))
        self.assertEqual(raw, (target / 'state.json').read_bytes())
        self.assertFalse((self.team / '.codex-home/auth.json').exists())
        self.assertFalse((self.team / '.git').exists())

    def test_symlink_and_template_rejected(self):
        (self.team / '.codex-home/adoption').symlink_to(self.parent, target_is_directory=True)
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertNotEqual(self.run_init(root=ROOT).returncode, 0)
        self.assertEqual(list(self.parent.glob('*-adoption-recovery-*')), [])
        self.assertEqual(list((self.team / '.archive').glob('adoption-recovery-*')), [])

    def test_missing_archive_rejected_without_creation(self):
        archive = self.team / '.archive'
        retained = self.team / 'retained-archive'
        archive.rename(retained)
        before = sorted(self.parent.rglob('*'))
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertEqual(before, sorted(self.parent.rglob('*')))
        self.assertFalse((self.team / '.codex-home/adoption').exists())

    def test_symlinked_archive_rejected_without_external_write(self):
        archive = self.team / '.archive'
        archive.rename(self.team / 'retained-archive')
        outside = self.parent / 'synthetic-outside-team'
        outside.mkdir(mode=0o700)
        archive.symlink_to(outside, target_is_directory=True)
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((self.team / '.codex-home/adoption').exists())

    def test_nonprivate_archive_rejected_without_repair(self):
        archive = self.team / '.archive'
        archive.chmod(0o755)
        before = sorted(archive.iterdir())
        self.assertNotEqual(self.run_init().returncode, 0)
        self.assertEqual(before, sorted(archive.iterdir()))
        self.assertEqual(stat.S_IMODE(archive.stat().st_mode), 0o755)
        self.assertFalse((self.team / '.codex-home/adoption').exists())


if __name__ == '__main__':
    unittest.main()
