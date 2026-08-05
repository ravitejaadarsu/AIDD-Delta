---
id: T-001-todo-complete-op
title: Add a complete() operation to the todo module
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: feature
expected_rigor: standard
difficulty: 2
token_budget_hint: 40000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Add a complete(items, index) operation to the todo module that marks the item done, renders done items with an "[x] " prefix, and rejects out-of-range indexes
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" complete
acceptance: |
  1. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
  2. `todo.complete(items, index)` returns a new list -- the input list is unchanged.
  3. A completed item renders as `1. [x] a`; an uncompleted one still renders as `1. a`.
  4. An out-of-range index (positive or negative) raises IndexError.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" complete
notes: |
  The generalisation of `tests/scenarios/todo-api.md`, the framework's original single
  dogfood scenario. Offline, deterministic, and the cheapest end-to-end exercise of a
  full pipeline run -- three acceptance criteria, one module, no network.
---

# T-001 — complete() on the todo module

## Context

`tests/fixtures/sample-project/` is a two-function module (`add`, `render`) with a three-case
unittest suite. This task adds one operation and one rendering rule.

## Why this task

It is the corpus's reference feature task -- small enough that every arm should finish it,
structured enough that the AC set is genuinely three separate criteria (mutation, rendering,
range rejection). A pipeline that cannot prove three ACs on this cannot prove thirty on
anything.

## Grading

The oracle is `bench/fixtures/oracles/todo_api.py complete`, committed before any run. It
checks purity (input list untouched) as well as output, because an arm that mutates in place
and returns the same list passes a naive check.
