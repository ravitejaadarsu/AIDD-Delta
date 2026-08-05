---
id: T-026-jq-base64d-manual-example
title: Document base64d's invalid-input behaviour with an executed manual example
repo: https://github.com/jqlang/jq
commit: 603db3f57741d217ba651e61086b550a72148b83
verified: true
class: docs
expected_rigor: standard
difficulty: 2
token_budget_hint: 50000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/jqlang/jq.git ./repo
  git -C ./repo checkout --detach 603db3f57741d217ba651e61086b550a72148b83
  cd ./repo
  git submodule update --init --recursive || true
  autoreconf -i
  ./configure --disable-docs --with-oniguruma=builtin
  make -j4
intent: Document what the base64d filter does with input that is not valid base64, using a manual example whose stated output is the output jq actually produces
pretest: |
  cd ./repo
  test -f ./src/manual.yml || exit 3
  test -x ./jq || exit 3
  grep -q "not-base64!" ./src/manual.yml && exit 0
  exit 1
acceptance: |
  1. The manual source documents the `@base64d` filter applied to the input
     `"not-base64!"`.
  2. The documented output is what jq actually produces -- `make check` regenerates and
     executes the manual examples, so a wrong documented output fails the build.
  3. `make check` is green.
oracle: |
  cd ./repo
  grep -q "@base64d" ./src/manual.yml || { echo "no base64d entry in the manual"; exit 1; }
  grep -q "not-base64!" ./src/manual.yml || { echo "the invalid-input example is missing"; exit 1; }
  make check
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. This task is graded by execution, not by reading -- jq derives a test file from
  the manual's examples, so a documented output that jq does not produce breaks `make check`.
  That is the property that makes a docs task benchmarkable at all. `pretest` exits 3 if the
  manual source or the built binary is missing, which is also the check that the C toolchain
  in `setup` actually worked.
---

# T-026 — documentation that is executed by the build

## Context

jq's manual carries per-filter examples, and its test suite executes them.

## Why this task

Most documentation cannot be graded mechanically. jq's can, because the examples are tests.
The task therefore measures whether an arm can state a true fact about behaviour it had to
determine by running the tool.

## Grading

The manual entry is present with the specified invalid input, and `make check` -- which
executes every manual example -- is green.
