---
id: T-018-cobra-extract-completion-helper
title: Extract cobra's completion-directive formatting into an unexported helper
repo: https://github.com/spf13/cobra
commit: adbc8813901bba65827259daa8e22ff94ec1f30e
verified: true
class: refactor
expected_rigor: standard
difficulty: 3
token_budget_hint: 55000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/spf13/cobra.git ./repo
  git -C ./repo checkout --detach adbc8813901bba65827259daa8e22ff94ec1f30e
  cd ./repo
  go mod download
intent: Extract the completion-directive string formatting in the completions source into an unexported formatCompletionDirective helper without changing any emitted output
pretest: |
  cd ./repo
  test -f ./completions.go || exit 3
  command -v go >/dev/null 2>&1 || exit 3
  grep -q "func formatCompletionDirective" ./completions.go && exit 0
  exit 1
acceptance: |
  1. `completions.go` declares `func formatCompletionDirective` and uses it.
  2. `gofmt -l .` reports no files.
  3. `go vet ./...` is clean.
  4. `go test ./...` is green -- the emitted completion output is unchanged.
oracle: |
  cd ./repo
  grep -q "func formatCompletionDirective" ./completions.go || { echo "helper not introduced"; exit 1; }
  test -z "$(gofmt -l .)" || { echo "gofmt reports unformatted files"; exit 1; }
  go vet ./...
  go test ./...
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. `pretest` exits 3 if `completions.go` or the Go toolchain is absent, so a
  drifted layout is an error rather than a FAIL. Cobra's own completion tests compare exact
  emitted strings, which is what makes "output unchanged" checkable here rather than
  aspirational.
---

# T-018 — extract the directive formatter

## Context

Cobra emits shell-completion directives as formatted strings built inline.

## Why this task

Go in the corpus, with a toolchain that gives the oracle three independent
behaviour-preserving signals (`gofmt`, `go vet`, `go test`) instead of one.

## Grading

Helper present, formatting clean, vet clean, full package test suite green.
