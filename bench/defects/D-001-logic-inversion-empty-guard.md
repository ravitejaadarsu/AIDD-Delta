---
id: D-001-logic-inversion-empty-guard
target: T-001-todo-complete-op
defect_class: logic-inversion
injection_mode: command
visible_to: L1-tests
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --expect "if not text.strip():" --replace "if text.strip():"
why_ordinary_review_misses_it: |
  It largely does not, and that is the point -- D-001 is a positive control. A single
  deleted `not` inverts the guard so every valid item is rejected and every empty one is
  accepted, and the fixture's own suite fails immediately. A catalogue in which every fault
  needs Layer 2 would be a rigged catalogue; this defect establishes that the cheap layer
  works and gives the report a floor to compare the expensive layers against.
  The one way it escapes is real, though: the arm is working on `complete()`, and the
  inverted guard is in `add()`. An arm that runs only the tests it wrote for its own change,
  rather than the existing suite, never sees it.
detection_signal: |
  An executed FAIL naming `test_add` -- in the AIDD arm, a FAIL row in
  `qa/test-report.md` for `functional-happy-path` or `regression-compat`, routed into the
  fix loop; in any arm, an `AssertionError` or `ValueError` for `test_add` in the driver
  transcript.
grader: |
  found=""
  if grep -rqsE 'test_add' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null &&
     grep -rqsE 'FAIL' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null; then
    found="L1-tests"
  fi
  if [ -z "${found}" ] && grep -qsE 'test_add.*(FAIL|Error)|ValueError: empty todo' ./driver.log; then
    found="L1-tests"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-001 — the inverted empty guard

## What is injected

`add()`'s guard becomes `if text.strip():` — valid items raise, empty ones are accepted.

## Why it is in the catalogue

As the control. Layer 1's tests should catch this in seconds, in every arm. If an arm misses
it, the finding is not "Layer 2 is valuable" but "this arm does not run the existing suite",
which is a more basic and more important result.

## Reverting

`bench-inject.sh --defect D-001-logic-inversion-empty-guard --revert` restores `./src/todo.py`
via `git checkout`, which is why injection refuses to run on a dirty tree.
