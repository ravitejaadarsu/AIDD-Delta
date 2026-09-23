"""Exercise real subprocesses in isolated repositories; never call a model."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / 'core/scripts/aidd-evidence.py'
spec = importlib.util.spec_from_file_location('evidence', CLI)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class Evidence(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        (self.repo / '.gitignore').write_text('.aidd/\n__pycache__/\n')
        (self.repo / 'app.py').write_text('answer = 42\n')
        subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
        self.change = self.repo / '.aidd/changes/demo'
        self.out = self.change / 'evidence/receipts/run'

    def capture(self, code='print("PASS")', options=(), expected=0):
        result = subprocess.run([sys.executable, str(CLI), 'capture', '--repo', str(self.repo),
                                 '--out', str(self.out), '--host', *options, '--', sys.executable,
                                 '-c', code], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def verify(self):
        return evidence.verify(self.out / 'receipt.json', self.repo)

    def test_success_and_recorded_context(self):
        self.capture()
        self.assertEqual(self.verify(), [])
        receipt = evidence.load_json(self.out / 'receipt.json')
        self.assertEqual(receipt['argv'][-1], 'print("PASS")')
        self.assertEqual(receipt['runtime']['python'], __import__('platform').python_version())
        self.assertEqual(receipt['execution'], 'host')

    def test_failure_cannot_pass(self):
        self.capture('raise SystemExit(7)', expected=1)
        self.assertTrue(self.verify())

    def test_timeout_cannot_pass(self):
        self.capture('import time; time.sleep(10)', ('--timeout', '0.1'), expected=1)
        self.assertEqual(evidence.load_json(self.out / 'receipt.json')['status'], 'timeout')

    def test_output_limit_cannot_pass(self):
        self.capture('print("x" * 10000)', ('--max-output-bytes', '100'), expected=1)
        self.assertEqual((self.out / 'output.log').stat().st_size, 100)
        self.assertEqual(evidence.load_json(self.out / 'receipt.json')['status'], 'output_limit')

    def test_source_change_during_execution(self):
        self.capture('from pathlib import Path; Path("app.py").write_text("changed")', expected=1)

    def test_dirty_untracked_deleted_and_executable_changes(self):
        self.capture()
        target = self.repo / 'app.py'
        target.write_text('changed')
        self.assertTrue(self.verify())
        target.write_text('answer = 42\n')
        self.assertFalse(self.verify())
        added = self.repo / 'new.py'
        added.write_text('new')
        self.assertTrue(self.verify())
        added.unlink()
        target.chmod(0o755)
        self.assertTrue(self.verify())
        target.chmod(0o644)
        target.unlink()
        self.assertTrue(self.verify())

    def test_artifact_changes_do_not_invalidate_source(self):
        self.capture()
        (self.change / 'report.md').write_text('report')
        self.assertFalse(self.verify())

    def test_tampered_log(self):
        self.capture()
        (self.out / 'output.log').write_text('forged')
        self.assertTrue(self.verify())

    def test_output_path_escape(self):
        self.capture()
        path = self.out / 'receipt.json'
        receipt = evidence.load_json(path)
        receipt['output']['path'] = '../../../../../app.py'
        path.write_text(json.dumps(receipt))
        self.assertTrue(self.verify())

    def test_refuses_overwrite(self):
        self.capture()
        before = (self.out / 'receipt.json').read_bytes()
        self.capture('print("overwrite")', expected=2)
        self.assertEqual(before, (self.out / 'receipt.json').read_bytes())

    def test_argv_is_not_shell_text(self):
        self.capture('import sys; print(sys.argv)', expected=0)
        out = self.change / 'evidence/receipts/literal'
        result = subprocess.run([sys.executable, str(CLI), 'capture', '--host', '--repo', str(self.repo),
                                 '--out', str(out), '--', 'echo', '$(touch should-not-exist)'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.repo / 'should-not-exist').exists())

    def test_missing_executable_records_failure(self):
        result = subprocess.run([sys.executable, str(CLI), 'capture', '--host', '--repo', str(self.repo),
                                 '--out', str(self.out), '--', 'aidd-nonexistent-command-123'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual(evidence.load_json(self.out / 'receipt.json')['status'], 'launch_error')

    def test_external_symlink_rejected(self):
        (self.repo / 'link').symlink_to(CLI)
        self.capture(expected=2)

    def test_manifest_coverage_and_staleness(self):
        self.capture()
        ref = 'evidence/receipts/run/receipt.json'
        manifest = {'schema': 1, 'suite_receipts': [ref], 'requirements': [
            {'id': 'AC-1', 'description': 'The answer is correct', 'receipts': [ref]}]}
        (self.change / 'requirements.json').write_text(json.dumps({'schema': 1, 'requirements': [
            {'id': 'AC-1', 'description': 'The answer is correct'}]}))
        path = self.change / 'evidence/acceptance.json'
        path.write_text(json.dumps(manifest))
        self.assertTrue(evidence.check_manifest(self.change, self.repo)['ready'])
        manifest['requirements'][0]['receipts'] = []
        path.write_text(json.dumps(manifest))
        self.assertFalse(evidence.check_manifest(self.change, self.repo)['ready'])
        manifest['requirements'][0]['receipts'] = [ref]
        manifest['requirements'].append(manifest['requirements'][0])
        path.write_text(json.dumps(manifest))
        self.assertFalse(evidence.check_manifest(self.change, self.repo)['ready'])

    def test_manifest_detects_omitted_approved_requirement(self):
        self.capture()
        ref = 'evidence/receipts/run/receipt.json'
        (self.change / 'requirements.json').write_text(json.dumps({'schema': 1, 'requirements': [
            {'id': 'AC-1', 'description': 'One'}, {'id': 'AC-2', 'description': 'Two'}]}))
        (self.change / 'evidence/acceptance.json').write_text(json.dumps({'schema': 1,
            'suite_receipts': [ref], 'requirements': [{'id': 'AC-1', 'description': 'One', 'receipts': [ref]}]}))
        report = evidence.check_manifest(self.change, self.repo)
        self.assertFalse(report['ready'])
        self.assertTrue(any('AC-2' in error for error in report['errors']))

    def test_log_symlink_cannot_overwrite_source(self):
        target = self.repo / 'app.py'
        self.capture('from pathlib import Path; Path(".aidd/changes/demo/evidence/receipts/run/output.log").symlink_to(Path("app.py").resolve())', expected=2)
        self.assertEqual(target.read_text(), 'answer = 42\n')

    def test_descendant_with_open_pipe_is_bounded(self):
        self.capture('import subprocess, sys; subprocess.Popen([sys.executable, "-c", "import time; time.sleep(10)"])',
                     ('--timeout', '0.2'), expected=1)

    def test_required_receipt_metadata_cannot_be_omitted(self):
        self.capture()
        path = self.out / 'receipt.json'
        original = evidence.load_json(path)
        for name in original:
            with self.subTest(field=name):
                mutated = dict(original)
                del mutated[name]
                path.write_text(json.dumps(mutated))
                self.assertTrue(self.verify())
        original['exit_code'] = False
        path.write_text(json.dumps(original))
        self.assertTrue(self.verify())

    def test_malformed_receipt_fails_closed(self):
        self.capture()
        path = self.out / 'receipt.json'
        for content in ['[]', '{"schema":1,"schema":1}', '{"schema":true}', '{', '{}']:
            path.write_text(content)
            self.assertTrue(self.verify())

    def test_host_acknowledgment_and_invalid_limits(self):
        result = subprocess.run([sys.executable, str(CLI), 'capture', '--repo', str(self.repo),
                                 '--out', str(self.out), '--', 'echo', 'hello'], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.capture(options=('--timeout', 'nan'), expected=2)

    def test_interrupt_records_receipt(self):
        proc = subprocess.Popen([sys.executable, str(CLI), 'capture', '--host', '--repo', str(self.repo),
                                 '--out', str(self.out), '--', sys.executable, '-c',
                                 'import time; time.sleep(10)'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 3
        while not self.out.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        time.sleep(0.1)
        proc.send_signal(signal.SIGINT)
        stdout, stderr = proc.communicate(timeout=5)
        self.assertEqual(proc.returncode, 130, stdout + stderr)
        self.assertTrue(self.verify())


if __name__ == '__main__':
    unittest.main()
