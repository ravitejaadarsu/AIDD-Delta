"""Adversarial delivery-state fixtures, exercised through the public CLI."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'core/scripts/aidd-ready.py'
spec = importlib.util.spec_from_file_location('ready', CLI)
ready = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ready)
SCHEMA = json.loads((ROOT / 'core/schemas/change-state.schema.json').read_text())


def yaml(value, indent=0):
    prefix = ' ' * indent
    if isinstance(value, dict):
        if not value:
            return '{}\n'
        return ''.join(prefix + key + ':' + (
            '\n' + yaml(item, indent + 2) if isinstance(item, (dict, list)) and item
            else ' ' + json.dumps(item) + '\n') for key, item in value.items())
    if isinstance(value, list):
        return ''.join(prefix + '-\n' + yaml(item, indent + 2) for item in value)
    raise AssertionError(value)


class Readiness(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.groups = {
            'g1_prd': ['prd.md'],
            'g2_plan': ['architecture.md', 'counter-arguments.md', 'impact-report.md',
                        'epic.md', 'stories/one.md', 'pre-review/one.md'],
            'g3_premerge': ['qa/critic-verdict.md', 'qa/test-report.md',
                           'qa/determinism-report.md', 'ac-matrix.md', 'evidence/post/run.txt'],
            'g_test_report': ['qa/test-report.md'],
        }
        self.state = {
            'schema': 1, 'change_id': '2026-09-24-example', 'intent': 'Example',
            'mode': 'let-me-look', 'phase': 'delivery', 'phase_status': 'in_progress',
            'gates': {}, 'quality_gates': {k: 'passed' for k in SCHEMA['properties']['quality_gates']['properties']},
            'determinism': {'repeats_required': 2, 'repeats_done': 2, 'report': 'qa/determinism-report.md'},
        }
        for gate, paths in self.groups.items():
            bindings = []
            for name in paths:
                target = self.root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('executed example evidence\n')
                bindings.append({'path': name, 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
            self.state['gates'][gate] = {
                'status': 'approved', 'approved_by': 'human',
                'at': '2026-09-24T12:00:00Z', 'artifacts': bindings,
            }

    def run_cli(self, expected):
        (self.root / 'state.yaml').write_text(yaml(self.state))
        result = subprocess.run(['python3', str(CLI), str(self.root), '--json'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output['ready'], expected == 0)
        return {item['code'] for item in output['errors']}

    def test_ready_and_read_only(self):
        self.run_cli(0)
        before = (self.root / 'state.yaml').read_bytes()
        self.run_cli(0)
        self.assertEqual(before, (self.root / 'state.yaml').read_bytes())

    def test_valid_modes(self):
        for mode in ['fast', 'standard', 'critical']:
            with self.subTest(mode=mode):
                self.state['rigor'] = {'mode': mode, 'selected_by': 'classifier'}
                self.run_cli(0)

    def test_nested_artifact_coverage(self):
        nested = self.root / 'qa/reviews/nested.md'
        nested.parent.mkdir()
        nested.write_text('new review')
        self.assertIn('unbound_artifact', self.run_cli(1))

    def test_empty_approval_does_not_pass(self):
        self.state['gates']['g3_premerge']['artifacts'] = []
        self.assertIn('unbound_artifact', self.run_cli(1))

    def test_missing_determinism_report(self):
        self.state['determinism']['report'] = 'missing.md'
        self.assertIn('determinism_report', self.run_cli(1))

    def test_quarantine(self):
        self.state['determinism']['quarantined'] = [
            {'test': 'race', 'suspected_source': 'concurrency', 'disposition': 'pending'}]
        self.assertIn('quarantine', self.run_cli(1))
        self.state['determinism']['quarantined'][0]['disposition'] = 'accepted'
        self.assertIn('quarantine', self.run_cli(1))
        self.state['determinism']['quarantined'][0]['accepted_reason'] = 'Excluded from AC evidence; replacement proof recorded.'
        self.run_cli(0)

    def test_delivery_wiring(self):
        playbook = (ROOT / 'core/playbooks/50-delivery.md').read_text()
        self.assertLess(playbook.index('aidd-ready.py'), playbook.index('Then push branch'))
        agent = (ROOT / 'core/roles/delivery-agent.md').read_text()
        self.assertIn('../playbooks/50-delivery.md', agent)

    def test_every_quality_gate_is_required(self):
        original = copy.deepcopy(self.state)
        for gate in self.state['quality_gates'].copy():
            with self.subTest(gate=gate):
                self.state = copy.deepcopy(original)
                del self.state['quality_gates'][gate]
                self.assertIn('quality_gate', self.run_cli(1))

    def test_failed_and_pending(self):
        for value in ['failed', 'pending', 'na', {'status': 'na', 'reason': 'cost:too-expensive'}]:
            self.state['quality_gates']['tests_green'] = value
            self.assertIn('quality_gate', self.run_cli(1))

    def test_fast_exemptions_and_escalation(self):
        self.state['rigor'] = {'mode': 'fast', 'selected_by': 'classifier'}
        for gate in ready.FAST_NA:
            self.state['quality_gates'][gate] = {'status': 'na', 'reason': 'rigor:fast'}
        self.run_cli(0)
        self.state['rigor']['mode'] = 'critical'
        self.assertIn('quality_gate', self.run_cli(1))

    def test_all_approvals_required(self):
        for gate in list(self.state['gates']):
            saved = self.state['gates'].pop(gate)
            self.assertIn('approval', self.run_cli(1))
            self.state['gates'][gate] = saved

    def test_human_and_auto_modes(self):
        self.state['gates']['g3_premerge']['approved_by'] = 'auto'
        self.assertIn('approver', self.run_cli(1))
        self.state['mode'] = 'take-care'
        self.run_cli(0)
        self.state['rigor'] = {'mode': 'critical', 'selected_by': 'escalation', 'escalations': [
            {'from': 'standard', 'to': 'critical', 'trigger': 'auth', 'at': '2026-09-24T11:00:00Z'}]}
        self.assertIn('approver', self.run_cli(1))

    def test_changed_missing_and_new_artifacts(self):
        target = self.root / 'prd.md'
        target.write_text('changed')
        self.assertIn('stale_artifact', self.run_cli(1))
        target.unlink()
        self.assertIn('missing_artifact', self.run_cli(1))
        (self.root / 'stories/new.md').write_text('new scope')
        self.assertIn('unbound_artifact', self.run_cli(1))

    def test_outside_artifact_rejected(self):
        for path in ['../outside', '/etc/passwd']:
            self.state['gates']['g1_prd']['artifacts'][0]['path'] = path
            self.assertIn('artifact', self.run_cli(1))

    def test_symlink_escape_rejected(self):
        (self.root / 'prd.md').unlink()
        (self.root / 'prd.md').symlink_to(ROOT / 'README.md')
        self.assertIn('artifact', self.run_cli(1))

    def test_duplicate_binding(self):
        rows = self.state['gates']['g1_prd']['artifacts']
        rows.append(copy.deepcopy(rows[0]))
        self.assertIn('duplicate_artifact', self.run_cli(1))

    def test_legacy_single_file_binding(self):
        gate = self.state['gates']['g1_prd']
        row = gate.pop('artifacts')[0]
        gate.update(artifact=row['path'], artifact_sha256=row['sha256'])
        self.run_cli(0)
        gate['artifact_sha256'] = row['sha256'][:8]
        self.assertIn('stale_artifact', self.run_cli(1))

    def test_unresolved_records(self):
        self.state['cost'] = {'stops': [{'at': '2026-09-24T11:00:00Z', 'phase': 'qa',
                                       'reason': 'budget', 'disposition': 'pending'}]}
        self.state['supervision'] = {'qa': 'violations'}
        self.state['stories'] = {'one': {'status': 'blocked'}}
        self.state['determinism']['repeats_done'] = 1
        codes = self.run_cli(1)
        self.assertTrue({'cost_stop', 'supervision', 'story', 'determinism'} <= codes)

    def test_schema_and_parse_fail_closed(self):
        self.state['gates']['g1_prd']['artifacts'][0]['sha256'] = 'bad'
        self.assertIn('schema', self.run_cli(2))
        (self.root / 'state.yaml').write_text('schema: 1\nschema: 2\n')
        result = subprocess.run(['python3', str(CLI), str(self.root), '--json'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('duplicate key', result.stdout)


if __name__ == '__main__':
    unittest.main()
