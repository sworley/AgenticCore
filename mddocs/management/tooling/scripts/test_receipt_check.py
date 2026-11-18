"""Disposable schema/drift checks; compare files before and after inspection."""
import fcntl
import hashlib
import json
import subprocess
import unittest
import uuid

from test_adoption_state import StateTests, SCRIPT


class ReceiptTests(StateTests):
    def check(self, expected=0):
        def snapshot():
            return {str(p.relative_to(self.parent)): (p.lstat().st_mode,
                    hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None)
                    for p in self.parent.rglob('*')}
        before = snapshot()
        result = subprocess.run(['bash', str(self.team / SCRIPT), '--check-state'],
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertEqual(before, snapshot())
        return result

    def initialized(self):
        result = self.run_init()
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.team / '.codex-home/adoption/state.json'

    def test_absent_and_initialized_read_only(self):
        self.assertIn('ABSENT', self.check().stdout)
        self.initialized()
        self.assertIn('VALID', self.check().stdout)

    def test_malformed_unknown_duplicate_oversized(self):
        path = self.initialized()
        original = json.loads(path.read_text())
        for value in (dict(original, schema_version=True), dict(original, unknown=True),
                      dict(original, revision=-1), dict(original, stages={})):
            path.write_text(json.dumps(value))
            self.check(1)
        for raw in ('null', 'bad-json', '{"schema_version":1,"schema_version":1}', 'x' * (256 * 1024 + 1)):
            path.write_text(raw)
            self.check(1)

    def test_workspace_and_identity_drift(self):
        path = self.initialized()
        original = json.loads(path.read_text())
        for value in (dict(original, workspace_id=str(uuid.uuid4())),
                      dict(original, workspace_path='/different/workspace'),
                      dict(original, identity_sha256='0' * 64)):
            path.write_text(json.dumps(value))
            self.assertIn('MISMATCH', self.check(1).stdout)

    def test_input_drift_and_unresolved_attempt(self):
        path = self.initialized()
        state = json.loads(path.read_text())
        now = state['updated_at']
        stage = state['stages']['identity']
        stage['attempt'] = {
            'step_id': str(uuid.uuid4()), 'scope_sha256': '0' * 64,
            'approval_ref': 'operator-record', 'backup_ref': None,
            'inputs': {'README.md': '0' * 64}, 'tools': {},
            'started_at': now, 'finished_at': None, 'execution': 'in progress',
            'verification_ref': None, 'verified_at': None,
            'acceptance_ref': None, 'accepted_at': None}
        path.write_text(json.dumps(state))
        result = self.check(1)
        self.assertIn('STALE', result.stdout)
        self.assertIn('UNRESOLVED', result.stdout)
        stage['attempt']['inputs'] = {'.codex-home/auth.json': '0' * 64}
        path.write_text(json.dumps(state))
        self.check(1)

    def test_busy_lock_and_unsafe_mode(self):
        path = self.initialized()
        with (path.parent / 'state.lock').open('rb') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.check(1)
        path.chmod(0o644)
        self.check(1)


if __name__ == '__main__':
    unittest.main()
