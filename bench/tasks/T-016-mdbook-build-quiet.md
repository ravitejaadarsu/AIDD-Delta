---
id: T-016-mdbook-build-quiet
title: Add a quiet flag to mdbook build that suppresses non-error output
repo: https://github.com/rust-lang/mdBook
commit: b90df240a318da0c59ec3efe6b75a58f63c6c459
verified: true
class: feature
expected_rigor: standard
difficulty: 3
token_budget_hint: 70000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/rust-lang/mdBook.git ./repo
  git -C ./repo checkout --detach b90df240a318da0c59ec3efe6b75a58f63c6c459
  cd ./repo
  cargo build --quiet
intent: Add a quiet flag to the mdbook build subcommand that suppresses all non-error output while leaving errors on stderr
pretest: |
  cd ./repo
  test -x ./target/debug/mdbook || exit 3
  ./target/debug/mdbook init ./bench-book --title bench --ignore none >/dev/null 2>&1 || exit 3
  ./target/debug/mdbook build ./bench-book --quiet >./quiet.out 2>./quiet.err || exit 1
  test ! -s ./quiet.out
acceptance: |
  1. `mdbook build <dir> --quiet` exits 0 and writes nothing to stdout.
  2. Without the flag, `mdbook build <dir>` still writes its usual progress output.
  3. Errors still reach stderr when the build fails.
  4. `cargo test` is green.
oracle: |
  cd ./repo
  ./target/debug/mdbook build ./bench-book >./loud.out 2>&1
  test -s ./loud.out || { echo "default output disappeared"; exit 1; }
  ./target/debug/mdbook build ./bench-book --quiet >./quiet.out 2>./quiet.err
  test ! -s ./quiet.out || { echo "quiet still printed to stdout"; exit 1; }
  cargo test --quiet
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. The `mdbook init` invocation in `pretest` is a precondition (exit 3 if the CLI
  shape differs at the pin), not part of the change under test. The oracle checks the loud
  path first, so silencing the tool unconditionally fails.
---

# T-016 — a quiet flag

## Context

`mdbook build` prints progress. The task adds a flag that suppresses it without hiding
errors.

## Why this task

Rust in the corpus, and a CLI-surface change with an explicit "do not break the default"
constraint. `cargo build` in `setup` also makes it the corpus's slowest setup, which is
itself worth measuring -- wall-clock overhead is reported per arm, and setup is excluded
from the arm's clock by design.

## Grading

Loud output still present, quiet output empty on stdout, `cargo test` green.
