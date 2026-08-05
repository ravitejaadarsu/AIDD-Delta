---
id: T-004-add-none-contract
title: add() must reject a None item with ValueError, not AttributeError
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: bugfix
expected_rigor: standard
difficulty: 2
token_budget_hint: 25000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Fix add(items, text) so an invalid item raises ValueError instead of leaking an AttributeError from the internal strip call
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" add-none
acceptance: |
  1. `todo.add([], None)` raises ValueError.
  2. `todo.add([], "   ")` still raises ValueError -- the existing behaviour is preserved.
  3. `todo.add([], "a")` still returns `["a"]`.
  4. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" add-none
notes: |
  A real defect present in the fixture at baseline -- `text.strip()` raises AttributeError
  on None, so the module's stated contract ("invalid input raises ValueError") is violated
  for the most common invalid input there is. Verified failing before the run by `pretest`.
---

# T-004 — the None-item contract

## Context

`add()` guards with `if not text.strip()`. For `text=None` the guard itself raises
`AttributeError: 'NoneType' object has no attribute 'strip'`, so callers cannot distinguish
"you gave me a bad item" from "the module broke".

## Why this task

It is a genuine, verifiable bug in code that ships in this repository, which makes it the
corpus's honest bugfix reference: nothing was injected, and `pretest` proves the defect is
present before the arm touches it.

## Grading

`bench/fixtures/oracles/todo_api.py add-none`. Note that it fails the run if the wrong
exception type is raised, so "wrap everything in `except Exception: raise ValueError`" is
not a free pass -- the whitespace case must still raise ValueError and the happy path must
still return the list.
