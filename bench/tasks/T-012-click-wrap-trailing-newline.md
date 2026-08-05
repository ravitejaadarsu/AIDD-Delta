---
id: T-012-click-wrap-trailing-newline
title: click wrap_text must preserve a trailing newline under preserve_paragraphs
repo: https://github.com/pallets/click
commit: 00e592cea702e0b2caa0dee42489fdb1c22cd845
verified: true
class: bugfix
expected_rigor: standard
difficulty: 3
token_budget_hint: 60000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/pallets/click.git ./repo
  git -C ./repo checkout --detach 00e592cea702e0b2caa0dee42489fdb1c22cd845
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e ".[dev]" || ./.venv/bin/pip install -q -e .
intent: Make wrap_text preserve a trailing newline in its input when preserve_paragraphs is true, and add a regression test for it
pretest: |
  cd ./repo
  test -x ./.venv/bin/python || exit 3
  ./.venv/bin/python -c "import click.formatting" || exit 3
  ./.venv/bin/python -c "from click.formatting import wrap_text as w; raise SystemExit(0 if w('hello\n', preserve_paragraphs=True).endswith('\n') else 1)"
acceptance: |
  1. `wrap_text("hello\n", preserve_paragraphs=True)` ends with a newline.
  2. The repository's own test suite is green -- `python -m pytest -q` exits 0.
  3. A regression test covering the trailing newline exists in the repo's test tree.
oracle: |
  cd ./repo
  ./.venv/bin/python -c "from click.formatting import wrap_text as w; raise SystemExit(0 if w('hello\n', preserve_paragraphs=True).endswith('\n') else 1)"
  ./.venv/bin/python -m pytest -q
  git diff --name-only | grep -qE '(^|/)tests?/' || { echo "no test added"; exit 1; }
notes: |
  `verified: true` means only that the pinned SHA was confirmed to exist by `git ls-remote`
  on 2026-08-06. It does NOT mean the behaviour is confirmed absent at that commit. That is
  what `pretest` decides, per run, on the runner's machine -- an exit 0 records
  PRETEST-ALREADY-SATISFIED and the task is not eligible for a published result until it is
  refreshed or dropped. Run `bench-run.sh --task T-012-click-wrap-trailing-newline
  --preflight` before including it in a comparison.
---

# T-012 — a trailing newline in wrapped text

## Context

`click.formatting.wrap_text` normalises whitespace. Whether a trailing newline in the input
survives `preserve_paragraphs=True` is the behaviour under test.

## Why this task

It is a small, contained bugfix in a widely used library with a fast test suite -- the shape
of most real maintenance work. The oracle demands a regression test as well as the fix,
because a fix without a test is a fix that comes back.

## Grading

The behavioural assertion, the repository's own suite, and a diff that touches the test
tree. All three, in that order.
