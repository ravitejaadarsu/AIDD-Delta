"""Test the installation experience and exported evidence without network calls."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'core/scripts' / (name + '.py'))
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


class ProductTools(unittest.TestCase):
    def test_report_escapes_untrusted_descriptions(self):
        report = module('aidd-report')
        html = report.render({'ready': False, 'requirements': [{'id': '<svg>',
            'description': '<script>alert(1)</script>', 'ready': False,
            'receipts': ['<img onerror=alert(1)>']}], 'errors': ['<iframe>']})
        self.assertNotIn('<script>', html)
        self.assertNotIn('<svg>', html)
        self.assertNotIn('<iframe>', html)
        self.assertIn('&lt;script&gt;', html)
        self.assertIn("default-src 'none'", html)
        self.assertIn('BLOCKED', html)

    def test_doctor_missing_installation(self):
        doctor = module('aidd-doctor')
        with tempfile.TemporaryDirectory() as directory:
            result = doctor.inspect(Path(directory), installed=True)
            self.assertFalse(result['ready'])
            self.assertTrue(any(row['name'] == 'aidd-evidence.py' and row['status'] == 'error'
                                for row in result['checks']))

    def test_vendored_tools_work_together(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['bash', str(ROOT / 'install.sh')], cwd=repo, capture_output=True, check=True)
            scripts = repo / '.aidd/framework/scripts'
            doctor = subprocess.run([sys.executable, str(scripts / 'aidd-doctor.py'), '--repo', str(repo),
                                     '--installed', '--json'], capture_output=True, text=True)
            self.assertEqual(doctor.returncode, 0, doctor.stdout + doctor.stderr)
            self.assertTrue(json.loads(doctor.stdout)['ready'])
            out = repo / '.aidd/receipts/probe'
            capture = subprocess.run([sys.executable, str(scripts / 'aidd-evidence.py'), 'capture',
                                     '--host', '--repo', str(repo), '--out', str(out), '--',
                                     sys.executable, '-c', 'print("PASS")'], capture_output=True, text=True)
            self.assertEqual(capture.returncode, 0, capture.stdout + capture.stderr)
            check = subprocess.run([sys.executable, str(scripts / 'aidd-evidence.py'), 'check',
                                     str(out / 'receipt.json'), '--repo', str(repo)], capture_output=True)
            self.assertEqual(check.returncode, 0, check.stdout)

    def test_demo_runs_offline(self):
        demo = subprocess.run([sys.executable, str(ROOT / 'scripts/demo-evidence.py')],
                              capture_output=True, text=True, timeout=20)
        self.assertEqual(demo.returncode, 0, demo.stdout + demo.stderr)
        self.assertEqual(json.loads(demo.stdout)['model_calls'], 0)

    def test_report_failure_is_nonzero_and_existing_output_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            target = repo / 'report.html'
            command = [sys.executable, str(ROOT / 'core/scripts/aidd-report.py'), str(repo),
                       '--repo', str(repo), '--out', str(target)]
            result = subprocess.run(command, capture_output=True)
            self.assertEqual(result.returncode, 1, result.stdout)
            original = target.read_bytes()
            result = subprocess.run(command, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(target.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
