---
id: T-009-item-record-migration
title: Migrate todo items from strings to records with a lossless upgrade path
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: migration
expected_rigor: critical
difficulty: 4
token_budget_hint: 55000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Migrate todo items from plain strings to records with text and done fields, adding a migrate(items) upgrade function that converts legacy string items losslessly while render still accepts both shapes
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" migrate
acceptance: |
  1. `todo.migrate(["a"])` returns `[{"text": "a", "done": False}]`.
  2. `todo.migrate` is idempotent -- migrating already-migrated records changes nothing and
     preserves every `done` flag.
  3. `todo.render(["a"])` still returns `1. a` -- legacy data keeps rendering.
  4. `todo.render([{"text": "a", "done": True}])` returns `1. [x] a`.
  5. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" migrate
notes: |
  The corpus's data migration, offline and deterministic. The two criteria that separate a
  real migration from a rename are idempotence and backward compatibility -- both are
  graded. Defect D-012 and D-013 both target this task's output (a lost `done` flag on
  re-migration, and a filter that ignores its owner argument).
---

# T-009 — a data migration with an upgrade path

## Context

Items are bare strings. This task turns them into records while keeping every existing
caller and every existing stored value working.

## Why this task

Data migrations are where "the tests pass" and "the data survived" diverge. An arm can
satisfy criteria 1, 3, and 4 with a migration that silently resets `done` on a second run,
which is exactly the class of bug that only shows up in production.

## Grading

`bench/fixtures/oracles/todo_api.py migrate` asserts the legacy conversion, idempotence
with `done: True` preserved, and both render paths.
