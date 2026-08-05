---
id: T-010-doctest-api-contract
title: Document the todo module's contracts as executable doctests
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: docs
expected_rigor: fast
difficulty: 1
token_budget_hint: 15000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Document the add and render contracts as doctest examples in the todo module so that running doctest over the module passes
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" doctest
acceptance: |
  1. Both `todo.add` and `todo.render` have docstrings containing `>>>` examples.
  2. The module carries at least four doctest examples in total.
  3. Every doctest example passes -- zero failures under `doctest.testmod`.
  4. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" doctest
notes: |
  Documentation with a deterministic oracle, which is the only kind worth benchmarking --
  the examples are executed, so a doc that describes behaviour the code does not have fails.
  Includes the error contract, so an arm that documents only the happy path falls short of
  the four-example floor.
---

# T-010 — documentation that executes

## Context

Neither `add` nor `render` has a docstring today. The module's contract exists only in the
unittest file.

## Why this task

"Docs pass/fail" is usually a judgement call, which makes docs tasks unbenchmarkable. A
doctest is not a judgement call -- it runs. This task is how the corpus measures docs work
without a human grader.

## Grading

`bench/fixtures/oracles/todo_api.py doctest` -- presence of `>>>` in both functions, an
example count floor, and zero doctest failures.
