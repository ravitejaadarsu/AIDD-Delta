---
id: T-006-extract-line-formatter
title: Extract render()'s line formatting into a private helper
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: refactor
expected_rigor: standard
difficulty: 2
token_budget_hint: 20000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Extract the numbered-line formatting inside render into a private _format_line(index, text) helper without changing render's output
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" format-line
acceptance: |
  1. `todo._format_line(0, "a")` returns `1. a` -- the helper exists and owns the numbering.
  2. `todo.render(["a", "b"])` still returns `1. a\n2. b` byte for byte.
  3. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
  4. The working tree carries a change -- `git diff` is non-empty.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" format-line
  git diff --quiet && { echo "no change produced"; exit 1; } || true
notes: |
  A behaviour-preserving refactor with a named structural obligation, so the grader can be
  deterministic without asserting anything about style. The `git diff` check exists because
  a refactor task that grades green on an untouched tree grades nothing at all.
---

# T-006 — extract the line formatter

## Context

`render()` inlines both the numbering and the joining. The task separates them.

## Why this task

Refactor tasks are where a pipeline's verification either proves "behaviour unchanged" or
merely asserts it. The oracle pins the exact output string, so any drift fails.

## Grading

`bench/fixtures/oracles/todo_api.py format-line` plus the existing suite plus a non-empty
diff.
