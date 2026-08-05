---
id: T-019-black-linegen-function-length
title: Split black's longest line-generation functions below an 80-line ceiling
repo: https://github.com/psf/black
commit: 011942a84347316f60ab1b3fe7f9563f8210f2cc
verified: true
class: refactor
expected_rigor: critical
difficulty: 4
token_budget_hint: 90000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/psf/black.git ./repo
  git -C ./repo checkout --detach 011942a84347316f60ab1b3fe7f9563f8210f2cc
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e ".[d]" || ./.venv/bin/pip install -q -e .
  ./.venv/bin/pip install -q pytest
intent: Refactor the line-generation module so that no function in it spans more than 80 lines, without changing any formatting behaviour
pretest: |
  cd ./repo
  test -f ./src/black/linegen.py || exit 3
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/max_func_lines.py" ./src/black/linegen.py 80
acceptance: |
  1. No function or method in `src/black/linegen.py` spans more than 80 source lines.
  2. The repository's own test suite is green -- formatting behaviour is unchanged.
  3. `black --check` on the repository's own sources still passes.
oracle: |
  cd ./repo
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/max_func_lines.py" ./src/black/linegen.py 80
  ./.venv/bin/python -m pytest -q -x
  ./.venv/bin/python -m black --check ./src
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. The structural obligation is measured by AST span, not judged, so the grader
  cannot drift. `pretest` returns 3 if the module has moved, 1 if some function already
  exceeds 80 lines (the required state), 0 if the ceiling already holds -- in which case the
  task is PRETEST-ALREADY-SATISFIED and must be re-pinned before it counts.
  This is the corpus's hardest refactor -- a formatter's own line-generation core, where a
  behaviour change shows up as a diff in thousands of formatted test fixtures.
---

# T-019 — a measurable refactor obligation

## Context

`src/black/linegen.py` holds black's line-generation logic, including some very long
functions.

## Why this task

Most refactor benchmarks are ungradeable because "cleaner" is a judgement. An AST-measured
line ceiling is not. And because black's test suite compares formatted output byte for byte,
"behaviour preserved" is genuinely proven rather than asserted.

## Grading

`bench/fixtures/oracles/max_func_lines.py` at limit 80, the repository suite, and black's
own self-format check.
