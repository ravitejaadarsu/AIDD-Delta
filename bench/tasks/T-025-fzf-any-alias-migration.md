---
id: T-025-fzf-any-alias-migration
title: Migrate fzf's Go sources from interface{} to the any alias
repo: https://github.com/junegunn/fzf
commit: 3337be9d450cd349e99273a2d3985ceaf5f3753f
verified: true
class: migration
expected_rigor: fast
difficulty: 4
token_budget_hint: 65000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/junegunn/fzf.git ./repo
  git -C ./repo checkout --detach 3337be9d450cd349e99273a2d3985ceaf5f3753f
  cd ./repo
  go mod download
intent: Replace every interface{} in the Go sources with the any alias without changing behaviour
pretest: |
  cd ./repo
  command -v go >/dev/null 2>&1 || exit 3
  grep -rl "interface{}" --include=*.go . >/dev/null 2>&1 || exit 0
  exit 1
acceptance: |
  1. No `.go` file in the repository contains `interface{}`.
  2. `gofmt -l .` reports no files.
  3. `go build ./...` succeeds.
  4. `go test ./...` is green.
oracle: |
  cd ./repo
  if grep -rl "interface{}" --include=*.go . >/dev/null 2>&1; then
    echo "interface{} still present in:"; grep -rl "interface{}" --include=*.go .; exit 1
  fi
  test -z "$(gofmt -l .)" || { echo "gofmt reports unformatted files"; exit 1; }
  go build ./...
  go test ./...
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. Marked `expected_rigor: fast` on purpose although its difficulty is 4 -- the
  work is broad but shallow, and a pipeline that escalates it to critical rigor is paying for
  verification the change does not need. Contrast its token cost with T-021's in the report;
  a framework that spends the same on both is not calibrating.
  Note that `interface{}` also appears inside string literals and comments in some
  repositories; criterion 1 is a blunt grep by design, so an arm that has to touch a comment
  to satisfy it is doing the right thing.
---

# T-025 — a breadth-not-depth migration

## Context

`any` has been an alias for `interface{}` since Go 1.18. The migration is purely
syntactic, across many files.

## Why this task

It measures follow-through and calibration at once: hundreds of trivial edits where the
completion criterion is a grep, and where over-verification is pure cost.

## Grading

Empty grep, clean `gofmt`, successful build, green `go test ./...`.
