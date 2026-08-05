---
id: D-002-off-by-one-render-numbering
target: T-002-todo-remove-op
defect_class: off-by-one
injection_mode: command
visible_to: L1-tests
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --expect 'f"{i + 1}. {t}"' --replace 'f"{i}. {t}"'
why_ordinary_review_misses_it: |
  A reviewer reading `f"{i}. {t}"` inside `enumerate(items)` sees plausible code. Nothing
  about the expression is malformed, and zero-based numbering is a defensible choice in the
  abstract -- the only thing that makes it wrong is a documented output format that lives in
  a different file. Reviewers who do not hold the expected format in their head while reading
  the loop approve it.
  It is caught cheaply here because the fixture happens to have a test that pins the exact
  string. That is the honest lesson of this defect: off-by-one is invisible to reading and
  trivial for an exact-output assertion, so the interesting measurement is whether an arm
  runs the assertion, not whether it can reason about the loop.
detection_signal: |
  An executed FAIL on `test_render` with the expected/actual strings shown -- for the AIDD
  arm a FAIL row in `qa/test-report.md` (`functional-happy-path` or `regression-compat`),
  otherwise the assertion diff in the driver transcript.
grader: |
  found=""
  if grep -rqsE 'test_render' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null &&
     grep -rqsE 'FAIL' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null; then
    found="L1-tests"
  fi
  if [ -z "${found}" ] && grep -qsE "test_render.*(FAIL|Error)|'0\. a" ./driver.log; then
    found="L1-tests"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-002 — zero-based numbering

## What is injected

`render()` numbers from 0 instead of 1.

## Why it is in the catalogue

It is the canonical "reads fine, is wrong" arithmetic fault, and it is the cheapest possible
demonstration that an exact-output assertion beats careful reading. Paired with D-014 — which
replaces that exact assertion with a vacuous one — it shows how thin the margin is between a
suite that catches this and one that cannot.

## Reverting

Git checkout of `./src/todo.py`.
