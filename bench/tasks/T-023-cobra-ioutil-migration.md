---
id: T-023-cobra-ioutil-migration
title: Migrate cobra off the deprecated io/ioutil package
repo: https://github.com/spf13/cobra
commit: adbc8813901bba65827259daa8e22ff94ec1f30e
verified: true
class: migration
expected_rigor: standard
difficulty: 3
token_budget_hint: 60000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/spf13/cobra.git ./repo
  git -C ./repo checkout --detach adbc8813901bba65827259daa8e22ff94ec1f30e
  cd ./repo
  go mod download
intent: Replace every use of the deprecated io/ioutil package with its io or os equivalent without changing behaviour
pretest: |
  cd ./repo
  command -v go >/dev/null 2>&1 || exit 3
  grep -rl "io/ioutil" --include=*.go . >/dev/null 2>&1 || exit 0
  exit 1
acceptance: |
  1. No `.go` file in the repository imports or references `io/ioutil`.
  2. `gofmt -l .` reports no files.
  3. `go vet ./...` is clean.
  4. `go test ./...` is green.
oracle: |
  cd ./repo
  if grep -rl "io/ioutil" --include=*.go . >/dev/null 2>&1; then
    echo "io/ioutil still referenced in:"; grep -rl "io/ioutil" --include=*.go .; exit 1
  fi
  test -z "$(gofmt -l .)" || { echo "gofmt reports unformatted files"; exit 1; }
  go vet ./...
  go test ./...
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. A deprecated-API migration is the most mechanically gradeable migration there
  is -- the completion criterion is a grep that must come back empty, and the "did it stay
  correct" criterion is the repository's own suite. `pretest` exits 0 (already satisfied) if
  the repository has already migrated, which is recorded, not hidden.
---

# T-023 — a deprecated-API migration

## Context

`io/ioutil` has been deprecated since Go 1.16; every function has an `io` or `os`
equivalent with slightly different signatures.

## Why this task

Mechanical breadth rather than depth: many small call sites, each with a specific correct
replacement, and a grep that says unambiguously when the job is finished. It is where an
arm's tendency to declare partial work complete shows up.

## Grading

Empty grep, clean `gofmt`, clean `go vet`, green `go test ./...`.
