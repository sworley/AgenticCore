"""Synthetic direct-hook tests; no hook activation, commits, or real credentials."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).with_name('pre-commit').resolve()
ROOT = HOOK.parents[4]


class GuardrailTests(unittest.TestCase):
    def setUp(self):
        temp_root = ROOT / '.tmp'
        if temp_root.is_symlink() or not temp_root.is_dir():
            raise RuntimeError('workspace-local .tmp must be a real directory')
        self.temp = tempfile.TemporaryDirectory(prefix='git-guardrail-', dir=temp_root)
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith('GIT_')}
        self.env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                         GIT_TERMINAL_PROMPT='0', HOME=str(self.repo),
                         TMPDIR=str(self.repo), TMP=str(self.repo), TEMP=str(self.repo),
                         XDG_CACHE_HOME=str(self.repo / 'cache'), PYTHONDONTWRITEBYTECODE='1')
        self.git('init', '--quiet', '--template=')

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.repo), *args], env=self.env,
                              check=True, capture_output=True).stdout

    def stage(self, path, content=b'harmless synthetic fixture\n'):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        self.git('add', '--', path)

    def run_hook(self, allowed):
        result = subprocess.run([str(HOOK)], cwd=self.repo, env=self.env,
                                capture_output=True)
        self.assertEqual(result.returncode, 0 if allowed else 1, result.stderr)
        return result

    def test_empty_index(self):
        self.run_hook(True)

    def test_portable_seeds_and_examples(self):
        for path in ('.codex-home/AGENTS.md', '.codex-home/config.toml',
                     '.codex-home/rules/template.rules', 'example.env',
                     '.env.example', 'config/settings.example.env',
                     'docs/path with spaces\nand newline.md'):
            self.stage(path)
        self.run_hook(True)

    def test_runtime_and_reference_paths(self):
        for path in ('.codex-home/auth.json', '.codex-home/sessions/run.jsonl',
                     '.codex-home/rules/learned.rules', '.codex/config.toml',
                     '.mcp/config.json', 'workspace/reference/readme.md',
                     'mddocs/book/index.html', 'secrets/item.txt',
                     'nested/credentials/item', '.env', '.env.local', '.envrc',
                     'private.key', 'cert.pem', 'nested/node_modules/file.js',
                     '.venv/pyvenv.cfg', '.venv/bin/python', '.venv/.gitkeep'):
            with self.subTest(path=path):
                self.git('read-tree', '--empty')
                self.stage(path)
                self.run_hook(False)

    def test_forced_venv_staging_blocked(self):
        self.stage('.gitignore', b'/.venv/\n')
        target = self.repo / '.venv/pyvenv.cfg'
        target.parent.mkdir()
        target.write_bytes(b'synthetic environment fixture\n')
        self.git('add', '--force', '--', '.venv/pyvenv.cfg')
        self.run_hook(False)

    def test_synthetic_patterns_and_no_content_disclosure(self):
        values = [b'AK' + b'IA' + b'0' * 16,
                  b'AS' + b'IA' + b'0' * 16,
                  b'-----BEGIN ' + b'PRIVATE KEY-----',
                  b'Authorization: ' + b'Bearer ' + b'x' * 20,
                  b'"token": "' + b'x' * 20 + b'"',
                  b"password = '" + b'x' * 20 + b"'"]
        for value in values:
            with self.subTest(value_type=values.index(value)):
                self.stage('fixture.data', value)
                result = self.run_hook(False)
                self.assertNotIn(value, result.stdout + result.stderr)

    def test_documented_directory_markers_allowed(self):
        for directory in ('.scratch', '.tmp', '.archive'):
            self.stage(f'{directory}/.gitkeep', b'# Directory intent\n\nSynthetic guide.\n')
        self.run_hook(True)

    def test_other_directory_contents_blocked(self):
        for directory in ('.scratch', '.tmp', '.archive'):
            for name in ('working.txt', 'nested/.gitkeep', '.gitkeep.extra'):
                with self.subTest(directory=directory, name=name):
                    self.git('read-tree', '--empty')
                    self.stage(f'{directory}/{name}')
                    self.run_hook(False)

    def test_directory_markers_still_scanned(self):
        for directory in ('.scratch', '.tmp', '.archive'):
            with self.subTest(directory=directory):
                self.git('read-tree', '--empty')
                self.stage(f'{directory}/.gitkeep', b'token=' + b'x' * 20)
                self.run_hook(False)

    def test_symlinked_directory_markers_blocked(self):
        for directory in ('.scratch', '.tmp', '.archive'):
            with self.subTest(directory=directory):
                self.git('read-tree', '--empty')
                marker = self.repo / directory / '.gitkeep'
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.symlink_to('/nonexistent-synthetic-target')
                self.git('add', '--', f'{directory}/.gitkeep')
                self.run_hook(False)

    def test_example_content_is_still_scanned(self):
        self.stage('.env.example', b'token=' + b'x' * 20)
        self.run_hook(False)

    def test_binary_content_is_scanned(self):
        self.stage('fixture.bin', b'\0token=' + b'x' * 20 + b'\0')
        self.run_hook(False)

    def test_staged_secret_not_hidden_by_clean_worktree(self):
        self.stage('fixture.txt', b'token=' + b'x' * 20)
        (self.repo / 'fixture.txt').write_bytes(b'clean worktree\n')
        self.run_hook(False)

    def test_unstaged_secret_not_read(self):
        self.stage('fixture.txt')
        (self.repo / 'fixture.txt').write_bytes(b'token=' + b'x' * 20)
        self.run_hook(True)

    def test_symlink_rejected_without_reading_target(self):
        (self.repo / 'link').symlink_to('/nonexistent-synthetic-target')
        self.git('add', '--', 'link')
        self.run_hook(False)

    def test_gitlink_rejected(self):
        tree = self.git('mktree').strip().decode()
        # A synthetic commit object, not a branch commit or real repository.
        payload = f'tree {tree}\nauthor Test <test@example.invalid> 0 +0000\ncommitter Test <test@example.invalid> 0 +0000\n\nfixture\n'
        oid = subprocess.run(['git', '-C', str(self.repo), 'hash-object', '-t',
                              'commit', '-w', '--stdin'], input=payload.encode(),
                             env=self.env, check=True, capture_output=True).stdout.strip().decode()
        self.git('update-index', '--add', '--cacheinfo', f'160000,{oid},reference')
        self.run_hook(False)

    def test_index_failure_blocks(self):
        self.env['GIT_INDEX_FILE'] = str(self.repo / 'bad-index')
        (self.repo / 'bad-index').write_bytes(b'invalid index')
        self.run_hook(False)

    def test_portable_distribution_passes(self):
        for path in (ROOT / 'TEMPLATE_FILES.txt').read_text().splitlines():
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        self.git('add', '--force', '--all')
        self.run_hook(True)
        self.assertEqual(self.git('config', '--local', '--get-regexp',
                                  'core.repositoryformatversion').strip(),
                         b'core.repositoryformatversion 0')
        config = (self.repo / '.git/config').read_text()
        self.assertNotIn('hooksPath', config)


if __name__ == '__main__':
    unittest.main()
