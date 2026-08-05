---
id: D-003-contract-break-add-mutates
target: T-001-todo-complete-op
defect_class: contract-break
injection_mode: command
visible_to: L1-tests
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --expect "    return items + [text.strip()]" --replace "    items.append(text.strip())"
why_ordinary_review_misses_it: |
  The replacement reads as an optimisation -- append in place instead of allocating a new
  list -- and in a diff it is one shorter, tidier line. Two contract breaks hide inside it:
  the caller's list is now mutated, and the function returns `None`. Neither is visible in
  the line itself; both require knowing that every caller does `items = add(items, x)`.
  This is the fault class that most often survives review in real projects, because
  "return a new list" versus "mutate and return None" is a convention, not a syntax rule.
  It is caught here only because the fixture asserts on the return value.
detection_signal: |
  An executed FAIL on `test_add` comparing `None` against the expected list -- a FAIL row in
  `qa/test-report.md` for the AIDD arm, or the `None != ['buy milk']` assertion text in the
  driver transcript.
grader: |
  found=""
  if grep -rqsE 'test_add' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null &&
     grep -rqsE 'FAIL' ./work/.aidd/changes/*/qa/test-report.md 2>/dev/null; then
    found="L1-tests"
  fi
  if [ -z "${found}" ] && grep -qsE "None != \[|test_add.*(FAIL|Error)" ./driver.log; then
    found="L1-tests"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-003 — mutate in place, return None

## What is injected

`add()` appends to the caller's list and returns `None`.

## Why it is in the catalogue

It is the API-contract break that looks like a cleanup. It also interacts with the task:
T-001 asks for `complete()` to be pure, so an arm that copies the injected style into its own
new function propagates the fault — which the report should distinguish from merely failing
to notice it.

## Reverting

Git checkout of `./src/todo.py`.
