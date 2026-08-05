---
id: T-011-store-append-race
title: Fix the lost-update race in the item store's concurrent append
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: bugfix
expected_rigor: critical
difficulty: 5
token_budget_hint: 60000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  cp "${BENCH_REPO_ROOT}/bench/fixtures/store_racy.py" ./src/store.py
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Fix the lost-update race in store.append_item so that concurrent callers never lose an item, keeping the existing append_item(path, text) and load(path) signatures
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" store-race
acceptance: |
  1. Eight threads each appending 100 items to the same file leave exactly 800 items.
  2. That holds on five consecutive attempts -- not once by luck.
  3. `store.append_item(path, text)` and `store.load(path)` keep their signatures.
  4. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" store-race
notes: |
  The corpus's concurrency task, and the only one whose baseline defect is seeded by
  `setup` rather than pre-existing -- `bench/fixtures/store_racy.py` is copied in as
  `./src/store.py`, so the starting state is identical for every arm and every rep. The race
  reproduces reliably (a measured 116 of 800 items survived on the first local attempt), so
  the pretest is not flaky. Offline and deterministic.
---

# T-011 — a real race, reproducibly

## Context

`bench/fixtures/store_racy.py` implements `append_item` as read-whole-file, append one
entry, rewrite-whole-file, with no lock. Every writer that lands last erases everything
written since it read.

## Why this task

Concurrency is where "the tests pass" is most often meaningless, because the default test
is single-threaded. This task's own pretest is a concurrent test, so an arm cannot satisfy
it without either serialising the write or making it genuinely append-only.

## Grading

`bench/fixtures/oracles/todo_api.py store-race` runs 8 threads x 100 appends, five times,
and demands exactly 800 items every time. Five attempts is what turns "we got lucky" into a
FAIL.
