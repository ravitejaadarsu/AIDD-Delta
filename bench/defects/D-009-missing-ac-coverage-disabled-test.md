---
id: D-009-missing-ac-coverage-disabled-test
target: T-004-add-none-contract
defect_class: missing-ac-coverage
injection_mode: command
visible_to: L2-tally
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./tests/test_todo.py \
    --expect "def test_add_empty_rejected(self):" \
    --replace "def disabled_add_empty_rejected(self):"
why_ordinary_review_misses_it: |
  Diff review provably cannot catch this either, for a different reason from D-008: what is
  wrong is an **absence**, and an absence has no line number to land on. The diff is a
  one-token rename in a test file. The test body is untouched and still reads correctly. No
  production code changed. unittest silently stops collecting the method, so the suite goes
  green -- greener, in fact, because it now runs one test fewer, and nothing reports a
  reduction in test count as a failure.
  Meanwhile the acceptance criterion "an empty item is rejected" is still claimed done, and
  T-004's own criterion 2 depends on it. A reviewer asked "is this diff correct?" answers yes,
  correctly. Nobody is asked "which executed test now proves criterion 2?" — and that is
  precisely the join Tally performs, work item by work item, against the tests and the
  evidence.
detection_signal: |
  A `GAP` row in `qa/tally.md` for the reject-empty AC with an empty or `na` tests column,
  routed under `## Routed` to the AC-matrix fix loop; or that AC marked FAIL in
  `ac-matrix.md` for want of executed evidence. An interrogation challenge naming the
  disabled method counts as `L2-auditor`.
grader: |
  found=""
  if grep -rqsE 'GAP' ./work/.aidd/changes/*/qa/tally.md 2>/dev/null; then
    found="L2-tally"
  fi
  if [ -z "${found}" ] && grep -rqsE 'FAIL' ./work/.aidd/changes/*/ac-matrix.md 2>/dev/null; then
    found="L2-tally"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'disabled_add_empty_rejected|not collected|no test proves' ./work/.aidd/changes/*/audit/interrogation/*.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -qsiE 'disabled_add_empty_rejected|test is not being collected|no longer runs' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-009 — the test that stopped being collected

The second of the three faults that justify Layer 2.

## What is injected

`test_add_empty_rejected` is renamed to `disabled_add_empty_rejected`. unittest collects
methods whose names begin with `test`, so the case silently disappears while its body stays in
the file, readable and correct.

## Why it is in the catalogue

Because "no executed test maps to this acceptance criterion" is not a property of any line of
the diff. It is a property of a **join** — work items against tests against evidence — and
nothing in an ordinary review workflow performs that join. `core/roles/tally.md` does exactly
that and emits a `GAP` row when a column comes back empty.

Note the honest alternative detection path: an arm that runs coverage and compares test counts
against the previous run can also catch this at Layer 1. The grader records whichever fired,
and a `L1-review` catch here is a finding about the arm, not a failure of the defect.

## Reverting

Git checkout of `./tests/test_todo.py`.
