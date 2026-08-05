---
id: D-005-secret-leak-hardcoded-credentials
target: T-007-save-path-traversal
defect_class: secret-leak
injection_mode: command
visible_to: L1-review
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --append-file "${BENCH_REPO_ROOT}/bench/fixtures/injections/secret_credentials.py"
why_ordinary_review_misses_it: |
  It does not miss it -- D-005 is the second positive control in the catalogue, and it exists
  so the report can separate "Layer 2 found something no reviewer could" from "a secrets scan
  did its job". Any grep-based scanner flags these constants, and the Security Auditor's
  secrets pass is a Layer-1 dispatch.
  The residual honest risk is narrower than it looks: the credentials are appended to a file
  the arm is already editing for its task, with a comment claiming ops owns them and rotates
  them quarterly. An arm that reviews only the hunks it wrote, or that treats an existing
  constant as pre-existing and therefore out of scope, walks past it. Whether that happens is
  the measurement.
detection_signal: |
  A secrets finding naming `src/todo.py` in `qa/security-report.md` (the Security Auditor's
  secrets scan) or in any `qa/findings-*.md`; in a non-AIDD arm, the credential name called
  out in the driver transcript.
grader: |
  found=""
  if grep -rqsE 'AWS_ACCESS_KEY_ID|AKIAIOSFODNN7EXAMPLE|secret' ./work/.aidd/changes/*/qa/security-report.md 2>/dev/null; then
    found="L1-review"
  fi
  if [ -z "${found}" ] && grep -rqsE 'AWS_ACCESS_KEY_ID|hardcoded (credential|secret|key)' ./work/.aidd/changes/*/qa/findings*.md 2>/dev/null; then
    found="L1-review"
  fi
  if [ -z "${found}" ] && grep -qsiE 'hardcoded (credential|secret|key)|AWS_ACCESS_KEY_ID' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-005 — credentials in the module

## What is injected

A pair of AWS-style credentials and a helper that puts them in headers, appended to
`./src/todo.py`.

## The values are not real

Both are the example key pair from AWS's own public documentation. They were chosen precisely
because scanners recognise them, and they have never been live credentials. This defect must
never be re-pointed at a real secret.

## Why it is in the catalogue

A defect catalogue that only contains faults requiring Layer 2 proves nothing about Layer 2 —
it just proves the catalogue was built to flatter it. D-001 and D-005 are the controls that
make the rest of the numbers legible.

## Reverting

Git checkout of `./src/todo.py`.
