---
id: D-008-mocked-proof-patched-add
target: T-001-todo-complete-op
defect_class: mocked-proof
injection_mode: command
visible_to: L2-auditor
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./tests/test_todo.py \
    --expect "import unittest" --replace "import unittest, unittest.mock"
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./tests/test_todo.py \
    --expect 'self.assertEqual(todo.add([], "buy milk"), ["buy milk"])' \
    --replace 'with unittest.mock.patch.object(todo, "add", return_value=["buy milk"]): self.assertEqual(todo.add([], "buy milk"), ["buy milk"])'
why_ordinary_review_misses_it: |
  Diff review provably cannot catch this, and the proof is mechanical rather than
  rhetorical. The production code is untouched: there is no production hunk to review. The
  test diff shows a `patch.object` context manager being added around an existing assertion,
  which reads as ordinary test hygiene -- isolating the unit under test is a thing reviewers
  ask for. The suite is green, so no layer that consumes executed FAILs has any input.
  The fault is not in either file. It is in the relationship between the test and the
  acceptance criterion: the assertion now compares the mock's own configured return value
  against itself, so it holds no matter what `add()` does. Verified in this repository by
  replacing `add()`'s body with `return []` -- a total break of the function -- after applying
  this injection and running the suite, which reported "Ran 3 tests OK".
  Reading the change cannot reveal that, because nothing in the change is wrong. Only asking
  "what executed evidence proves AC-1?" reveals it, and answering that question per AC is the
  Auditor's interrogation, not a reviewer's read.
detection_signal: |
  An interrogation challenge in `audit/interrogation/` that names the mocked path and demands
  the real flow (`core/protocol/interrogation.md` forbids a vague challenge, so it will name
  the AC and the proof demanded), followed by the AC closing as `DISPUTED` in the
  `-verdict.md` file, or a `DEFECT` ruling for that AC in `audit/negotiation-log.md`. An
  execution-surface debate row contesting the TC as "asserts on the mock" counts as
  `L2-debate`.
grader: |
  found=""
  if grep -rqsiE 'mock|patch\.object|asserts on the mock' ./work/.aidd/changes/*/audit/interrogation/*.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -rqsE 'DISPUTED' ./work/.aidd/changes/*/audit/interrogation/*verdict*.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -rqsE 'DEFECT' ./work/.aidd/changes/*/audit/negotiation-log.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'mock' ./work/.aidd/changes/*/audit/debate/*.md 2>/dev/null; then
    found="L2-debate"
  fi
  if [ -z "${found}" ] && grep -qsiE 'asserts (on|against) (the )?mock|mock proves nothing|test does not exercise' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-008 — the test that proves the mock

This is the catalogue's centrepiece: the fault that justifies Layer 2 existing.

## What is injected

`test_add` is wrapped so that `todo.add` is replaced by a mock returning `["buy milk"]`, and
then asserted to return `["buy milk"]`. Two mechanical edits, both to the test file, neither
touching production code.

## The demonstration

With this injection applied and `add()`'s body replaced by `return []`, the suite reports:

```text
Ran 3 tests in 0.000s

OK
```

A completely broken function, a green suite, and an acceptance criterion that is now proven by
nothing at all. Everything a diff reviewer can see is correct.

## What catches it

The Auditor's interrogation asks, per acceptance criterion, what executed evidence proves it
(`core/protocol/interrogation.md`). A challenge here is required to be specific — name the AC,
name the gap, name the proof demanded — and a response that re-cites the same mocked test does
not settle the AC. Round 2 closes it as `DISPUTED`, which routes into negotiation and then, if
contested to exhaustion, to Supervisor adjudication.

## Reverting

Git checkout of `./tests/test_todo.py`.
