"""Disposable readiness tests, including no-write and no-CLI-probe assertions."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = 'mddocs/management/tooling/scripts/team-adopt.sh'


class ReadinessTests(unittest.TestCase):
    def setUp(self):
        temp_root = ROOT / '.tmp'
        if temp_root.is_symlink() or not temp_root.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temp = tempfile.TemporaryDirectory(prefix='readiness-', dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.env = {'HOME': str(self.base), 'PATH': os.environ['PATH'],
                    'TMPDIR': str(self.base), 'TMP': str(self.base), 'TEMP': str(self.base),
                    'XDG_CACHE_HOME': str(self.base / 'cache'), 'PYTHONDONTWRITEBYTECODE': '1'}
        source = self.base / 'template-source'
        for relative in (ROOT / 'TEMPLATE_FILES.txt').read_text().splitlines():
            target = source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        result = subprocess.run(['bash', str(source / 'mddocs/management/tooling/scripts/template-deploy.sh')],
                                input=f'{self.base}\nTest\n', env=self.env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.team = self.base / 'Test.v0.1'

    def snapshot(self):
        return {str(p.relative_to(self.base)): (p.lstat().st_mode,
                os.readlink(p) if p.is_symlink() else
                hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None)
                for p in self.base.rglob('*')}

    def run_check(self, success=True, root=None, args=()):
        before = self.snapshot()
        result = subprocess.run(['bash', str((root or self.team) / SCRIPT), *args],
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot())
        return result

    def test_default_and_explicit_check_no_writes(self):
        self.run_check()
        self.run_check(args=('--check',))
        self.assertFalse((self.team / '.codex-home/adoption').exists())

    def test_help_without_workspace_access_or_writes(self):
        for option in ('--help', '-h'):
            for root in (ROOT, self.team):
                with self.subTest(option=option, root=str(root)):
                    result = self.run_check(root=root, args=(option,))
                    self.assertIn('Default: $HOME/files/sandbox', result.stdout)
                    self.assertIn('Default: AgenticTeam', result.stdout)
                    self.assertIn('Press Enter', result.stdout)
                    self.assertIn('In a deployed team: run read-only', result.stdout)
                    self.assertNotIn('Identity: PASS', result.stdout)
                    self.assertEqual(result.stderr, '')
        # Help still works when local identity is missing; no Python is needed.
        (self.team / '.agentic-team-identity.json').unlink()
        self.env['PATH'] = '/nonexistent'
        # Invoke Bash by its already established absolute path.
        import shutil
        before = self.snapshot()
        result = subprocess.run([shutil.which('bash'), str(self.team / SCRIPT), '--help'],
                                env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_template_rejected(self):
        self.run_check(False, root=ROOT, args=('--check',))

    def test_bad_identities(self):
        path = self.team / '.agentic-team-identity.json'
        original = json.loads(path.read_text())
        for value in (dict(original, schema_version=True), dict(original, workspace_id=original['template_id']),
                      dict(original, deployment_version='v0.01'), dict(original, extra=True)):
            path.write_text(json.dumps(value))
            self.run_check(False)
        path.write_text('{"kind":"team","kind":"template"}')
        self.run_check(False)
        path.unlink()
        self.run_check(False)

    def test_unsafe_home_and_symlinked_source(self):
        home = self.team / '.codex-home'
        home.chmod(0o755)
        self.run_check(False)
        home.chmod(0o700)
        path = self.team / 'start-codex.sh'
        path.unlink()
        path.symlink_to(ROOT / 'start-codex.sh')
        self.run_check(False)

    def test_config_conflict_sanitized(self):
        path = self.team / '.codex-home/config.toml'
        path.write_text('approval_policy = "synthetic-secret-do-not-print"\n')
        result = self.run_check(False)
        self.assertNotIn('synthetic-secret-do-not-print', result.stdout + result.stderr)

    def test_no_external_probes_or_secret_output(self):
        binaries = self.base / 'bin'
        binaries.mkdir()
        for command in ('git', 'codex', 'mdbook', 'mdbook-mermaid'):
            path = binaries / command
            path.write_text('#!/bin/sh\nprintf invoked > "$HOME/probe-called"\nexit 1\n')
            path.chmod(0o755)
        self.env['PATH'] = str(binaries) + ':' + self.env['PATH']
        self.env['GH_TOKEN'] = 'synthetic-never-print-value'
        result = self.run_check()
        self.assertFalse((self.base / 'probe-called').exists())
        self.assertNotIn(self.env['GH_TOKEN'], result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
