---
id: T-002-todo-remove-op
title: Add a remove() operation to the todo module
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: feature
expected_rigor: fast
difficulty: 2
token_budget_hint: 30000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Add a remove(items, index) operation to the todo module that returns the list without the indexed item and raises IndexError for an out-of-range index
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" remove
acceptance: |
  1. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
  2. `todo.remove(["a", "b"], 0)` returns `["b"]`.
  3. The input list is not mutated.
  4. An out-of-range index raises IndexError.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" remove
notes: |
  Deliberately near-trivial and marked `expected_rigor: fast`. Its job in the corpus is to
  expose over-processing -- an arm that spends a critical-rigor budget on a one-line list
  slice is paying for verification it does not need, and the token comparison should show it.
---

# T-002 — remove() on the todo module

## Context

The same fixture as T-001, one list operation, no rendering change.

## Why this task

The corpus needs cheap tasks as well as hard ones. If AIDD's cost overhead is only
defensible on difficulty-5 work, that is a finding, and this task is where it shows up.

## Grading

`bench/fixtures/oracles/todo_api.py remove` -- return value, input purity, IndexError.
