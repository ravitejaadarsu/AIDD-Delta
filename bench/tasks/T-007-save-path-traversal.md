---
id: T-007-save-path-traversal
title: Add save() with a base-directory containment check
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: security
expected_rigor: critical
difficulty: 3
token_budget_hint: 45000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Add a save(items, base_dir, name) function that writes the rendered list under base_dir and raises ValueError for any name that would escape base_dir
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" save-traversal
acceptance: |
  1. `todo.save(items, base, "list.txt")` writes the rendered items to `<base>/list.txt`.
  2. Each of `../escape`, `a/../../escape`, `/tmp/escape`, and `sub/../../escape` raises
     ValueError.
  3. No file is created anywhere outside `base` during the rejected attempts.
  4. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" save-traversal
notes: |
  Marked `critical` rigor because it is a filesystem boundary. The absolute-path case
  (`/tmp/escape.txt`) is the one a naive `".." in name` check misses, and the
  post-condition check ("no file outside base") is the one a normalise-but-do-not-contain
  check misses. The absolute-path case is `/tmp/escape`. Defect D-011 injects exactly that
  second failure on top of a passing implementation of this task.
---

# T-007 — containment, not just normalisation

## Context

The fixture has no persistence. This task adds it, with a security boundary attached.

## Why this task

It is the corpus's small auth-boundary-shaped task -- a check whose correct implementation
looks almost identical to an incorrect one. `os.path.normpath(name)` followed by a join is
the classic wrong answer, and it passes any test that only tries a leading `..` segment.

## Grading

`bench/fixtures/oracles/todo_api.py save-traversal` tries four escape shapes including an
absolute path, then asserts on the filesystem that nothing landed outside the base.
