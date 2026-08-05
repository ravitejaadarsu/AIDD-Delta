---
id: T-005-render-embedded-newline
title: render() must emit exactly one line per item
repo: local:tests/fixtures/sample-project
commit: local
verified: true
class: bugfix
expected_rigor: standard
difficulty: 3
token_budget_hint: 30000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-project/." .
  rm -rf ./src/__pycache__
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Fix render(items) so an item containing a newline still renders as exactly one numbered line without losing the item text
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" render-newline
acceptance: |
  1. `todo.render(["a\nb"])` returns a single line -- no embedded raw newline.
  2. Both `a` and `b` still appear in that line -- escaping, not truncation.
  3. `todo.render(["a", "b"])` still returns `1. a\n2. b` exactly.
  4. The existing suite still passes -- `python3 ./tests/test_todo.py` exits 0.
oracle: |
  python3 ./tests/test_todo.py
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/todo_api.py" render-newline
notes: |
  The tempting fix is to strip or truncate at the newline, which passes a "one line" check
  while silently losing user data. The oracle asserts both halves, so the cheap fix fails.
  This is a task where an arm's own test design matters more than its diff.
---

# T-005 — one line per item

## Context

`render()` joins items with `\n` and numbers them, so an item that itself contains a
newline produces two output lines and desynchronises every number after it. `add()` accepts
such an item today -- it only rejects empty-after-strip text.

## Why this task

Difficulty 3 because the naive fix (drop everything after the newline) satisfies the literal
request and destroys data. It is a small, offline probe of whether an arm's verification
notices a lossy fix.

## Grading

`bench/fixtures/oracles/todo_api.py render-newline` asserts one line **and** text
preservation **and** unchanged output for ordinary items.
