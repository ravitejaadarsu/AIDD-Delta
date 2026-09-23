# Execution receipts and evidence reports

Available on all tiers with Python 3.9+ and Git. Capture uses POSIX process groups (Linux,
macOS, WSL); native Windows capture is not supported. No model calls or dependencies.
Canonical rules: `core/protocol/execution-receipts.md`.

## First run

```bash
python3 core/scripts/aidd-doctor.py
python3 scripts/demo-evidence.py
```

The demo proves the mechanics with a tiny temporary repository, including deliberately stale
source. It is not a comparative model benchmark or proof that the full pipeline is superior.

## Use on a real change

1. Install/upgrade the framework and run its doctor with `--repo . --installed`.
2. New change templates enable `evidence_contract: receipts-v1`. Create the PRD and
   `requirements.json` from `core/templates/requirements.json`; approve them together at G1.
3. Run final suite and criterion-specific commands through capture. Use a new directory
   per execution. Review argv first; `--host` executes on your machine.
4. Populate the acceptance template with every approved id, exact description and relative
   receipt path. Save it as the change's `evidence/acceptance.json`.
5. Verify, export and obtain G3 approval before delivery. A source edit requires fresh receipts.

```bash
python3 .aidd/framework/scripts/aidd-evidence.py capture --host \
  --out .aidd/changes/<change-id>/evidence/receipts/suite \
  --timeout 300 -- python3 -m unittest discover -s tests

python3 .aidd/framework/scripts/aidd-evidence.py check \
  .aidd/changes/<change-id>/evidence/receipts/suite/receipt.json

python3 .aidd/framework/scripts/aidd-evidence.py manifest .aidd/changes/<change-id>

python3 .aidd/framework/scripts/aidd-report.py .aidd/changes/<change-id> \
  --out .aidd/changes/<change-id>/evidence-report.html
```

All commands emit JSON results except the doctor without `--json`. Capture/check/manifest
return 0 for valid evidence, 1 for failed evidence, 2 for invalid invocation/input; interrupted
capture returns 130. Reports use the same success/failure distinction and refuse to overwrite
an existing file. Add `--format json` for machine-readable report export.

## What teams can share

The standalone HTML report shows criteria, receipt references and blockers. It has no external
assets, scripts, telemetry or raw command output. Descriptions and receipt names can still
contain private information; review them before sharing. JSON exports contain the same
verification outcome. Export is a point-in-time snapshot; it can become stale afterward.

## Limits to understand

Local receipts are editable records, not authenticated attestations. Source hashing excludes
root `.aidd/`, ignored files, environment variables, dependencies and external services.
Semantic correctness, fake tests and mocked assertions still need review. A green receipt
means a recorded command completed against the current in-scope source; it does not mean
the feature meets its requirement. The report is not a delivery or compliance certificate.
