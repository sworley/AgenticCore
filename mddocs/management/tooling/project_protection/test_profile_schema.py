"""Synthetic structural checks only; no checkout, service, hook, or approval access."""
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry
from referencing.exceptions import NoSuchResource


SOURCE = Path(__file__).resolve().parent
SCHEMA = json.loads((SOURCE / 'profile.schema.json').read_text())


def no_external_resources(uri):
    raise NoSuchResource(ref=uri)


def draft():
    return {
        'schema_version': 1, 'profile_id': 'synthetic-project', 'revision': 1,
        'repository': {'checkout_relative_path': None, 'platform': None,
                       'identity': None, 'remotes': []},
        'boundaries': {'allowed_relative_paths': [], 'denied_relative_paths': [],
                       'harness_ignore_required': True},
        'branches': {'protected': [], 'ticket_id_pattern': None, 'work_branch_pattern': None},
        'integration': {'required_approvals': None, 'required_checks': [],
                        'allowed_merge_methods': [], 'merge_authority_ref': None},
        'approvals': {'profile_approval_ref': None, 'approved_revision': None,
                      'task_scoped_access_required': True, 'per_push_approval_required': True,
                      'separate_merge_approval_required': True},
        'protections': [],
        'revalidation': {'owner_ref': None, 'triggers': ['repository identity changes']},
    }


def protection():
    unknown = {'status': 'unknown', 'evidence_ref': None, 'checked_at': None,
               'limitations': []}
    return {'control': 'protected_branch_updates', 'target': 'integration',
            'requested': deepcopy(unknown), 'locally_tested': deepcopy(unknown),
            'remotely_verified': deepcopy(unknown)}


class ProfileSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Draft202012Validator.check_schema(SCHEMA)
        checker = FormatChecker()

        @checker.checks('date-time', raises=ValueError)
        def utc_calendar(value):
            if not isinstance(value, str):
                return True
            datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')
            return True

        cls.validator = Draft202012Validator(
            SCHEMA, format_checker=checker,
            registry=Registry(retrieve=no_external_resources))

    def assert_valid(self, value):
        self.assertEqual(list(self.validator.iter_errors(value)), [])

    def assert_invalid(self, value):
        self.assertTrue(list(self.validator.iter_errors(value)))

    def test_unresolved_draft_is_structurally_valid_not_ready(self):
        self.assert_valid(draft())
        self.assertNotIn('ready', SCHEMA['properties'])

    def test_all_objects_are_closed_and_require_their_fields(self):
        value = draft()
        value['repository']['remotes'] = [{'name': 'origin', 'url': 'https://example.invalid/team/repo.git'}]
        value['branches']['protected'] = [{'name': 'integration', 'role': 'baseline',
                                           'integration_method': 'pr_or_mr'}]
        value['protections'] = [protection()]

        def visit(node):
            if isinstance(node, dict):
                changed = dict(node, unexpected=True)
                yield node, changed
                for key in list(node):
                    changed = dict(node)
                    del changed[key]
                    yield node, changed
                for child in node.values():
                    yield from visit(child)
            elif isinstance(node, list):
                for child in node:
                    yield from visit(child)

        self.assert_valid(value)
        for node, changed in visit(value):
            original = dict(node)
            node.clear()
            node.update(changed)
            self.assert_invalid(value)
            node.clear()
            node.update(original)

    def test_version_integers_and_mandatory_guards(self):
        for key, invalid in [('schema_version', True), ('schema_version', 2),
                             ('revision', False), ('revision', 0), ('revision', '1')]:
            value = draft()
            value[key] = invalid
            self.assert_invalid(value)
        for key in ('task_scoped_access_required', 'per_push_approval_required',
                    'separate_merge_approval_required'):
            for invalid in (False, 1, None):
                value = draft()
                value['approvals'][key] = invalid
                self.assert_invalid(value)
        for invalid in (False, 1, None):
            value = draft()
            value['boundaries']['harness_ignore_required'] = invalid
            self.assert_invalid(value)
        for invalid in (True, -1, '2'):
            value = draft()
            value['integration']['required_approvals'] = invalid
            self.assert_invalid(value)

    def test_checkout_and_scope_path_constraints(self):
        for invalid in ('/outside', '../outside', 'repo/../other', '.', './repo',
                        'repo//child', 'repo/', 'repo\\child', 'C:/repo',
                        '.archive/recovery', 'mddocs/source', 'harness/repo',
                        '.codex-home/repo', '.tmp/repo', '.scratch/repo'):
            with self.subTest(invalid=invalid):
                value = draft()
                value['repository']['checkout_relative_path'] = invalid
                self.assert_invalid(value)
        value = draft()
        value['repository']['checkout_relative_path'] = 'customer source/repo'
        value['boundaries']['allowed_relative_paths'] = ['.', 'src/module']
        self.assert_valid(value)
        value['boundaries']['allowed_relative_paths'] = ['../outside']
        self.assert_invalid(value)

    def test_string_and_array_limits(self):
        for invalid in ('', 'UNSET', 'x' * 129, 'project\n', 'project\x7f'):
            value = draft()
            value['profile_id'] = invalid
            self.assert_invalid(value)
        value = draft()
        value['repository']['identity'] = 'x' * 2049
        self.assert_invalid(value)
        value = draft()
        value['branches']['ticket_id_pattern'] = 'x' * 257
        self.assert_invalid(value)
        value = draft()
        value['integration']['required_checks'] = ['check'] * 101
        self.assert_invalid(value)
        value = draft()
        value['revalidation']['triggers'] = []
        self.assert_invalid(value)

    def test_integration_enums_and_duplicates(self):
        for invalid in (['direct_push'], ['merge', 'merge']):
            value = draft()
            value['integration']['allowed_merge_methods'] = invalid
            self.assert_invalid(value)
        value = draft()
        value['branches']['protected'] = [{'name': 'release', 'role': 'baseline',
                                           'integration_method': 'direct_push'}]
        self.assert_invalid(value)

    def test_status_and_not_applicable_evidence(self):
        value = draft()
        value['protections'] = [protection()]
        self.assert_valid(value)
        status = value['protections'][0]['locally_tested']
        status['status'] = 'not_applicable'
        self.assert_invalid(value)
        status.update(evidence_ref='synthetic-hil-record', limitations=['No local equivalent'])
        self.assert_valid(value)
        status['status'] = 'approved_forever'
        self.assert_invalid(value)

    def test_timestamp_shape_and_calendar(self):
        value = draft()
        value['protections'] = [protection()]
        status = value['protections'][0]['requested']
        status['checked_at'] = '2026-10-21T16:00:00Z'
        self.assert_valid(value)
        for invalid in ('2026-02-30T16:00:00Z', '2026-10-21',
                        '2026-10-21T16:00:00+00:00', '2026-10-21T16:00:00Z\n'):
            status['checked_at'] = invalid
            self.assert_invalid(value)

    def test_no_external_schema_references(self):
        def visit(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key == '$ref':
                        self.assertTrue(child.startswith('#/'))
                    visit(child)
            elif isinstance(value, list):
                for child in value:
                    visit(child)
        visit(SCHEMA)


if __name__ == '__main__':
    unittest.main()
