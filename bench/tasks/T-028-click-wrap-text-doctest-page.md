---
id: T-028-click-wrap-text-doctest-page
title: Add a doctest-verified documentation page for click's text wrapping
repo: https://github.com/pallets/click
commit: 00e592cea702e0b2caa0dee42489fdb1c22cd845
verified: true
class: docs
expected_rigor: fast
difficulty: 2
token_budget_hint: 35000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/pallets/click.git ./repo
  git -C ./repo checkout --detach 00e592cea702e0b2caa0dee42489fdb1c22cd845
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e ".[dev]" || ./.venv/bin/pip install -q -e .
intent: Add a documentation page at ./docs/wrap-text.rst explaining how text wrapping handles paragraphs, with at least three doctest examples that pass
pretest: |
  cd ./repo
  test -d ./docs || exit 3
  ./.venv/bin/python -c "import click.formatting" || exit 3
  test -f ./docs/wrap-text.rst && exit 0
  exit 1
acceptance: |
  1. `./docs/wrap-text.rst` exists.
  2. It contains at least three doctest examples (`>>>` prompts).
  3. Every example passes -- `python -m doctest ./docs/wrap-text.rst` exits 0.
  4. The repository's own test suite is still green.
oracle: |
  cd ./repo
  test -f ./docs/wrap-text.rst || { echo "page missing"; exit 1; }
  count="$(grep -c '>>>' ./docs/wrap-text.rst || true)"
  test "${count}" -ge 3 || { echo "only ${count} doctest example(s), need 3"; exit 1; }
  ./.venv/bin/python -m doctest ./docs/wrap-text.rst
  ./.venv/bin/python -m pytest -q
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. `python -m doctest` on an reStructuredText file executes every `>>>` block and
  compares the transcript, so criterion 3 is executed rather than reviewed. Marked
  `expected_rigor: fast` -- an additive docs page with no behaviour change is the clearest
  case in the corpus where heavy verification is pure overhead, and the report should show it.
---

# T-028 — a documentation page that runs

## Context

`click.formatting.wrap_text` has paragraph-preserving behaviour that is easy to describe
wrongly.

## Why this task

`python -m doctest` turns a prose page into a test, so a docs task becomes a graded task.
It is also the corpus's cheapest public-repo task, which makes it a useful cost datapoint
against T-019 in the same repository family.

## Grading

The page exists, carries at least three examples, every example executes correctly, and the
repository suite still passes.
