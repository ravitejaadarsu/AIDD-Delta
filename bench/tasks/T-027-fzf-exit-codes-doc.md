---
id: T-027-fzf-exit-codes-doc
title: Document fzf's exit codes, verified by reproducing them
repo: https://github.com/junegunn/fzf
commit: 3337be9d450cd349e99273a2d3985ceaf5f3753f
verified: true
class: docs
expected_rigor: standard
difficulty: 2
token_budget_hint: 40000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/junegunn/fzf.git ./repo
  git -C ./repo checkout --detach 3337be9d450cd349e99273a2d3985ceaf5f3753f
  cd ./repo
  go build -o ./bin/fzf .
intent: Document every exit code fzf can return in its man page as an explicit list covering 0, 1, 2 and 130
pretest: |
  cd ./repo
  test -f ./man/man1/fzf.1 || exit 3
  test -x ./bin/fzf || exit 3
  for code in 0 1 2 130; do grep -q "^\.B ${code}$" ./man/man1/fzf.1 || exit 1; done
  exit 0
acceptance: |
  1. The man page documents exit codes 0, 1, 2 and 130, each as its own entry.
  2. Code 0 is reproducible -- filtering a matching pattern exits 0.
  3. Code 1 is reproducible -- filtering a non-matching pattern exits 1.
  4. Code 2 is reproducible -- an invalid option exits 2.
  5. `go build ./...` still succeeds.
oracle: |
  cd ./repo
  for code in 0 1 2 130; do
    grep -q "^\.B ${code}$" ./man/man1/fzf.1 || { echo "exit code ${code} undocumented"; exit 1; }
  done
  printf 'alpha\nbeta\n' | ./bin/fzf -f alpha >/dev/null
  set +e
  printf 'alpha\nbeta\n' | ./bin/fzf -f zzzzz >/dev/null; rc_nomatch=$?
  ./bin/fzf --definitely-not-a-real-flag </dev/null >/dev/null 2>&1; rc_badopt=$?
  set -e
  test "${rc_nomatch}" -eq 1 || { echo "no-match exit was ${rc_nomatch}, documented as 1"; exit 1; }
  test "${rc_badopt}" -eq 2 || { echo "invalid-option exit was ${rc_badopt}, documented as 2"; exit 1; }
  go build ./...
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. The oracle does not take the documentation's word for anything: it reproduces
  codes 0, 1 and 2 by running the built binary and compares them with what the page claims.
  130 (interrupted by SIGINT) is graded by presence only, because reproducing it needs a
  signal and a terminal; that limitation is stated here rather than hidden in the grader.
  The `^\.B <code>$` pattern fixes the man-page form so the grader is exact -- the arm must
  use roff list entries, not prose.
---

# T-027 — exit codes, documented and reproduced

## Context

fzf returns different exit codes for "selected", "no match", "error", and "interrupted".
The man page is where a script author looks for them.

## Why this task

A docs task whose oracle runs the program. Documentation that disagrees with behaviour fails
here, which is the only way to benchmark documentation honestly.

## Grading

Four documented entries, three of them reproduced against the built binary, and a still-green
build.
