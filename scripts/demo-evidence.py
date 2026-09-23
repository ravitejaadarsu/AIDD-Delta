#!/usr/bin/env python3
"""Offline demonstration: successful proof, shareable report, then detected source drift."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(*argv, expected=0, cwd=None):
    result = subprocess.run(argv, cwd=cwd, capture_output=True, text=True)
    if result.returncode != expected:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix='aidd-demo-') as directory:
        repo = Path(directory)
        run('git', 'init', '-q', str(repo))
        (repo / '.gitignore').write_text('.aidd/\n__pycache__/\n')
        (repo / 'calculate.py').write_text('def total(values):\n    return sum(values)\n')
        change = repo / '.aidd/changes/demo'
        out = change / 'evidence/receipts/suite'
        cli = str(ROOT / 'core/scripts/aidd-evidence.py')
        run(sys.executable, cli, 'capture', '--host', '--repo', str(repo), '--out', str(out),
            '--', sys.executable, '-c', 'from calculate import total; assert total([2,3]) == 5; print("PASS: total")')
        requirement = {'id': 'AC-1', 'description': 'Total of 2 and 3 is 5'}
        (change / 'requirements.json').write_text(json.dumps({'schema': 1, 'requirements': [requirement]}))
        ref = 'evidence/receipts/suite/receipt.json'
        (change / 'evidence/acceptance.json').write_text(json.dumps({'schema': 1, 'suite_receipts': [ref],
            'requirements': [dict(requirement, receipts=[ref])]}))
        run(sys.executable, cli, 'manifest', str(change), '--repo', str(repo))
        run(sys.executable, str(ROOT / 'core/scripts/aidd-report.py'), str(change), '--repo', str(repo),
            '--out', str(change / 'report.html'))
        (repo / 'calculate.py').write_text('def total(values):\n    return 0\n')
        drift = json.loads(run(sys.executable, cli, 'manifest', str(change), '--repo', str(repo), expected=1))
        assert not drift['ready']
        print(json.dumps({'demo': 'passed', 'checks': ['executed command', 'verified acceptance evidence',
              'exported HTML report', 'blocked stale source proof'],
              'network_calls': 0, 'model_calls': 0, 'temporary_files': 'cleaned on exit'}, indent=2))


if __name__ == '__main__':
    main()
