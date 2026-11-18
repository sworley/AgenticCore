"""Disposable deployment tests; never create a real team in the sandbox root."""
from pathlib import Path
import os
import json
import uuid
import shutil
import stat
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('template-deploy.sh').resolve()
ROOT = SCRIPT.parents[4]


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        temp_root = ROOT / '.tmp'
        if temp_root.is_symlink() or not temp_root.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temp = tempfile.TemporaryDirectory(prefix='template-deploy-', dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home with spaces'
        self.parent = self.home / 'files/sandbox'
        self.parent.mkdir(parents=True)
        self.source = self.base / 'source/AgenticTeam.v0.Template'
        self.source.mkdir(parents=True)
        for relative in (ROOT / 'TEMPLATE_FILES.txt').read_text().splitlines():
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        self.script = self.source / SCRIPT.relative_to(ROOT)
        self.env = {'HOME': str(self.home), 'PATH': os.environ.get('PATH', ''),
                    'TMPDIR': str(self.base), 'TMP': str(self.base),
                    'TEMP': str(self.base), 'XDG_CACHE_HOME': str(self.base / 'cache')}

    def run_deploy(self, answers='\n\n', success=True, cwd=None):
        result = subprocess.run(['bash', str(self.script)], input=answers,
                                cwd=cwd or self.base, env=self.env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0 if success else 1,
                         result.stdout + result.stderr)
        return result

    def test_defaults_and_distribution_integrity(self):
        # Extra runtime state must not be copied even from a used source.
        home = self.source / '.codex-home'
        (home / 'auth.json').write_text('synthetic authentication fixture')
        (home / 'sessions').mkdir()
        (home / 'sessions/old.jsonl').write_text('synthetic history')
        (self.source / 'mddocs/book').mkdir()
        (self.source / 'mddocs/book/index.html').write_text('generated fixture')
        (self.source / '.git').mkdir()
        result = self.run_deploy()
        target = self.parent / 'AgenticTeam.v0.1'
        self.assertIn('Directory?', result.stdout)
        self.assertIn('Team name?', result.stdout)
        self.assertIn(str(target), result.stdout)
        expected = set((self.source / 'TEMPLATE_FILES.txt').read_text().splitlines())
        actual = {str(p.relative_to(target)) for p in target.rglob('*') if p.is_file()}
        self.assertEqual(actual, expected)
        for relative in expected:
            if relative == '.agentic-team-identity.json':
                continue
            self.assertEqual((target / relative).read_bytes(), (self.source / relative).read_bytes())
            self.assertEqual(stat.S_IMODE((target / relative).stat().st_mode),
                             stat.S_IMODE((self.source / relative).stat().st_mode))
        self.assertEqual(stat.S_IMODE((target / '.codex-home').stat().st_mode), 0o700)
        self.assertFalse((target / '.git').exists())
        for directory in ('.scratch', '.tmp', '.archive'):
            marker = target / directory / '.gitkeep'
            self.assertTrue(marker.read_text().startswith('# '))
        self.assertEqual((home / 'auth.json').read_text(), 'synthetic authentication fixture')
        identity = json.loads((target / '.agentic-team-identity.json').read_text())
        original = json.loads((self.source / '.agentic-team-identity.json').read_text())
        self.assertEqual(identity['kind'], 'team')
        self.assertEqual(identity['team_name'], 'AgenticTeam')
        self.assertEqual(identity['deployment_version'], 'v0.1')
        self.assertEqual(identity['template_id'], original['workspace_id'])
        self.assertNotEqual(identity['workspace_id'], original['workspace_id'])
        self.assertEqual(uuid.UUID(identity['workspace_id']).version, 4)
        self.assertEqual(stat.S_IMODE((target / '.agentic-team-identity.json').stat().st_mode), 0o600)
        self.assertFalse((target / '.codex-home/adoption').exists())

    def test_inactive_direnv_template_uses_deployed_workspace(self):
        self.run_deploy()
        target = self.parent / 'AgenticTeam.v0.1'
        example = target / '.envrc.template'
        self.assertTrue(example.is_file())
        self.assertFalse((target / '.envrc').exists())
        before = sorted(str(p.relative_to(target)) for p in target.rglob('*'))
        subprocess.run(['bash', '-n', str(example)], env=self.env, check=True,
                       capture_output=True)
        script = '''
use_pass() { return 99; }
PATH_add() { return 99; }
source "$1"
printf '%s\\n' "$AGENTIC_TEAM_ROOT" "$CODEX_HOME"
'''
        environment = dict(self.env, CODEX_HOME='/synthetic-inherited-home',
                           AGENTIC_TEAM_ROOT='/synthetic-inherited-root')
        result = subprocess.run(['bash', '--noprofile', '--norc', '-ec', script,
                                 'direnv-template-test', str(example)],
                                cwd=self.base, env=environment, text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(),
                         [str(target), str(target / '.codex-home')])
        self.assertEqual(result.stderr, '')
        self.assertEqual(before, sorted(str(p.relative_to(target)) for p in target.rglob('*')))

    def test_template_adopt_single_entry(self):
        result = subprocess.run(['bash', str(self.source / 'mddocs/management/tooling/scripts/team-adopt.sh')],
                                input='\n\n', cwd=self.base, env=self.env,
                                text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count('Directory?'), 1)
        self.assertEqual(result.stdout.count('Team name?'), 1)
        self.assertIn('Local dev-space setup complete', result.stdout)
        self.assertIn('Next steps:', result.stdout)
        self.assertIn('1. Enter your new workspace: cd -- ', result.stdout)
        self.assertIn('2. If authentication is needed: ./start-codex.sh login', result.stdout)
        self.assertIn('3. Start working: ./start-codex.sh', result.stdout)
        self.assertIn('Optional: review .envrc.template with the HIL. Copying it to .envrc and\n'
                      'activating direnv require separate explicit approval. Neither was performed.',
                      result.stdout)
        self.assertIn('Local configuration intent: PASS', result.stdout)
        target = self.parent / 'AgenticTeam.v0.1'
        self.assertTrue(target.is_dir())
        self.assertTrue((target / '.envrc.template').is_file())
        self.assertFalse((target / '.envrc').exists())
        self.assertFalse((target / '.codex-home/adoption').exists())
        self.assertFalse((target / '.codex-home/auth.json').exists())
        self.assertTrue((target / '.git').is_dir())
        def git(*args):
            return subprocess.run(['git', '-C', str(target), *args], env=self.env,
                                  capture_output=True, text=True, timeout=10)
        self.assertEqual(Path(git('rev-parse', '--show-toplevel').stdout.strip()), target)
        self.assertEqual(git('remote').stdout, '')
        self.assertNotEqual(git('rev-parse', '--verify', 'HEAD').returncode, 0)
        self.assertEqual(list((target / '.git').glob('hooks/*')), [])
        self.assertNotIn('hooksPath', (target / '.git/config').read_text())
        self.assertIn('Local Git repository initialized and root verified', result.stdout)

    def test_git_overrides_cannot_redirect_initialization(self):
        foreign = self.base / 'foreign.git'
        global_config = self.home / '.gitconfig'
        global_config.write_text('[init]\n\ttemplateDir = /nonexistent-synthetic-template\n')
        before = global_config.read_bytes()
        env = dict(self.env, GIT_DIR=str(foreign), GIT_WORK_TREE=str(self.base),
                   GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='core.hooksPath',
                   GIT_CONFIG_VALUE_0='/nonexistent-synthetic-hooks')
        result = subprocess.run(['bash', str(self.source / 'mddocs/management/tooling/scripts/team-adopt.sh')],
                                input='\n\n', env=env, text=True, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.parent / 'AgenticTeam.v0.1/.git').is_dir())
        self.assertFalse(foreign.exists())
        self.assertEqual(before, global_config.read_bytes())

    def test_ready_failure_never_claims_completion(self):
        # Simulate a missing executable dependency without installing anything.
        binaries = self.base / 'limited-bin'
        binaries.mkdir()
        for command in ('bash', 'python3', 'dirname'):
            (binaries / command).symlink_to(shutil.which(command))
        env = dict(self.env, PATH=str(binaries))
        result = subprocess.run([shutil.which('bash'), str(self.script), '--ready'],
                                input='\n\n', env=env, text=True, capture_output=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Local dev-space setup complete', result.stdout)
        self.assertIn('retained for review', result.stderr)

    def test_existing_version_three_produces_four(self):
        existing = self.parent / 'AgenticTeam.v0.3'
        existing.mkdir()
        (existing / 'sentinel').write_text('unchanged')
        (self.parent / 'AgenticTeam.v0.Template').mkdir()
        (self.parent / 'OtherTeam.v0.99').mkdir()
        self.run_deploy()
        self.assertTrue((self.parent / 'AgenticTeam.v0.4/start-codex.sh').is_file())
        self.assertEqual((existing / 'sentinel').read_text(), 'unchanged')

    def test_numeric_order_gaps_and_repeated_deployment(self):
        for name in ('Team-X.v0.2', 'Team-X.v0.10', 'Team-X.v0.003', 'Team-X.v1.99'):
            (self.parent / name).mkdir()
        self.run_deploy(f'{self.parent}\nTeam-X\n')
        self.assertTrue((self.parent / 'Team-X.v0.11').is_dir())
        self.run_deploy(f'{self.parent}\nTeam-X\n')
        self.assertTrue((self.parent / 'Team-X.v0.12').is_dir())
        first = json.loads((self.parent / 'Team-X.v0.11/.agentic-team-identity.json').read_text())
        second = json.loads((self.parent / 'Team-X.v0.12/.agentic-team-identity.json').read_text())
        self.assertNotEqual(first['workspace_id'], second['workspace_id'])
        self.assertEqual(second['deployment_version'], 'v0.12')

    def test_invalid_identity_rejected_before_deployment(self):
        path = self.source / '.agentic-team-identity.json'
        original = json.loads(path.read_text())
        cases = [dict(original, kind='team'), dict(original, schema_version=True),
                 dict(original, extra='unsupported'), dict(original, workspace_id='invalid'),
                 dict(original, created_at='2026-02-30T00:00:00Z'),
                 dict(original, template_id=str(uuid.uuid4())), dict(original, team_name='Other')]
        for value in cases:
            path.write_text(json.dumps(value))
            self.run_deploy(success=False)
        for raw in ('{"kind":"template","kind":"team"}', 'x' * 4097, 'null'):
            path.write_text(raw)
            self.run_deploy(success=False)
        path.write_text(json.dumps(original))
        path.chmod(0o644)
        self.run_deploy(success=False)
        path.chmod(0o600)
        path.unlink()
        path.symlink_to(ROOT / '.agentic-team-identity.json')
        self.run_deploy(success=False)
        path.unlink()
        self.run_deploy(success=False)
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_home_prefixes_and_custom_team(self):
        for index, prefix in enumerate(('~', '$HOME', '${HOME}')):
            name = f'Team{index}'
            self.run_deploy(f'{prefix}/files/sandbox\n{name}\n')
            self.assertTrue((self.parent / f'{name}.v0.1').is_dir())

    def test_invalid_names_and_eof(self):
        for name in ('../escape', 'Team/name', 'Team name', '$(touch nope)', '-Team', 'a' * 65):
            with self.subTest(name=name):
                self.run_deploy(f'\n{name}\n', success=False)
        self.run_deploy('', success=False)
        self.assertEqual(list(self.parent.iterdir()), [])

    def test_missing_directory_and_source_destination_rejected(self):
        self.run_deploy(f'{self.base}/missing\n\n', success=False)
        self.run_deploy(f'{self.source}\n\n', success=False)
        self.assertFalse((self.base / 'missing').exists())

    def test_occupied_file_or_symlink_not_overwritten(self):
        target = self.parent / 'AgenticTeam.v0.1'
        target.write_text('preserve')
        self.run_deploy(success=False)
        self.assertEqual(target.read_text(), 'preserve')
        target.unlink()
        outside = self.base / 'outside'
        outside.mkdir()
        target.symlink_to(outside, target_is_directory=True)
        self.run_deploy(success=False)
        self.assertTrue(target.is_symlink())
        self.assertEqual(list(outside.iterdir()), [])

    def test_unsafe_allowlist_rejected_before_creation(self):
        manifest = self.source / 'TEMPLATE_FILES.txt'
        original = manifest.read_text()
        for path in ('../outside', '/absolute', '.codex-home/auth.json',
                     'mddocs/book/index.html', '.scratch/temporary.txt',
                     '.tmp/temporary.txt', '.archive/backup.txt',
                     '.venv/pyvenv.cfg', '.venv/bin/python', '.venv/.gitkeep'):
            manifest.write_text(original + path + '\n')
            self.run_deploy(success=False)
            self.assertEqual(list(self.parent.iterdir()), [])

    def test_venv_allowlist_rejected_before_creation(self):
        manifest = self.source / 'TEMPLATE_FILES.txt'
        original = manifest.read_text()
        for relative in ('.venv/pyvenv.cfg', '.venv/bin/python', '.venv/.gitkeep'):
            with self.subTest(path=relative):
                source = self.source / relative
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text('synthetic fixture')
                manifest.write_text(original + relative + '\n')
                result = self.run_deploy(success=False)
                self.assertIn('distribution allowlist contains a protected path', result.stderr)
                self.assertEqual(list(self.parent.iterdir()), [])

    def test_persistent_venv_excluded_from_distribution_and_git(self):
        environment = self.source / '.venv'
        environment.mkdir()
        (environment / 'pyvenv.cfg').write_text('synthetic fixture, not a real environment')
        self.run_deploy()
        target = self.parent / 'AgenticTeam.v0.1'
        self.assertFalse((target / '.venv').exists())
        subprocess.run(['git', 'init', '--quiet', '--template=', str(target)],
                       env=self.env, check=True, capture_output=True)
        for path in ('.venv/pyvenv.cfg', '.venv/bin/python', '.venv/.gitkeep'):
            result = subprocess.run(['git', '-C', str(target), 'check-ignore', '-q', '--', path],
                                    env=self.env, capture_output=True)
            self.assertEqual(result.returncode, 0)

    def test_directory_markers_only_and_git_ignore(self):
        for directory in ('.scratch', '.tmp', '.archive'):
            (self.source / directory / 'local-only.txt').write_text('synthetic fixture')
        self.run_deploy()
        target = self.parent / 'AgenticTeam.v0.1'
        for directory in ('.scratch', '.tmp', '.archive'):
            self.assertEqual(sorted(p.name for p in (target / directory).iterdir()),
                             ['.gitkeep'])
        subprocess.run(['git', 'init', '--quiet', '--template=', str(target)],
                       env=self.env, check=True, capture_output=True)
        for directory in ('.scratch', '.tmp', '.archive'):
            for name, ignored in (('local-only.txt', True), ('.gitkeep', False)):
                result = subprocess.run(['git', '-C', str(target), 'check-ignore',
                                         '-q', '--', f'{directory}/{name}'],
                                        env=self.env, capture_output=True)
                self.assertEqual(result.returncode, 0 if ignored else 1)

    def test_missing_symlinked_and_duplicate_sources_rejected(self):
        manifest = self.source / 'TEMPLATE_FILES.txt'
        original = manifest.read_text()
        manifest.write_text(original + 'missing-file\n')
        self.run_deploy(success=False)
        manifest.write_text(original + 'start-codex.sh\n')
        self.run_deploy(success=False)
        manifest.write_text(original)
        (self.source / 'start-codex.sh').unlink()
        (self.source / 'start-codex.sh').symlink_to(ROOT / 'start-codex.sh')
        self.run_deploy(success=False)
        self.assertEqual(list(self.parent.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
