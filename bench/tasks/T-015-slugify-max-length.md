---
id: T-015-slugify-max-length
title: Add a maxLength option to slugify that truncates on a word boundary
repo: https://github.com/sindresorhus/slugify
commit: 7c318bd1aa4b4affab29761f15a9604323fe2a3b
verified: true
class: feature
expected_rigor: fast
difficulty: 2
token_budget_hint: 35000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/sindresorhus/slugify.git ./repo
  git -C ./repo checkout --detach 7c318bd1aa4b4affab29761f15a9604323fe2a3b
  cd ./repo
  npm ci --silent || npm install --silent
intent: Add a maxLength option to slugify that truncates the slug at a word boundary without leaving a trailing separator
pretest: |
  cd ./repo
  test -f ./index.js || exit 3
  node --input-type=module -e "import s from './index.js'; if (typeof s !== 'function') process.exit(3); const out = s('Hello Wonderful World', {maxLength: 11}); process.exit(out === 'hello' ? 0 : 1)"
acceptance: |
  1. `slugify("Hello Wonderful World", {maxLength: 11})` returns `hello` -- the next word
     would exceed the limit, so it is dropped whole.
  2. The result never ends with the separator.
  3. Omitting `maxLength` leaves existing behaviour byte-identical.
  4. The repository's own test suite is green.
oracle: |
  cd ./repo
  node --input-type=module -e "import s from './index.js'; const o = s('Hello Wonderful World', {maxLength: 11}); if (o !== 'hello') { console.error('got ' + o); process.exit(1) }"
  node --input-type=module -e "import s from './index.js'; const o = s('Hello Wonderful World'); if (o !== 'hello-wonderful-world') { console.error('regressed to ' + o); process.exit(1) }"
  npm test
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. Whether `maxLength` already exists there is decided by `pretest`, per run. The
  expected value is pinned exactly (`hello`, not `hello-world`) so "truncate at a word
  boundary" has one correct answer rather than a family of them.
---

# T-015 — a truncating option

## Context

`slugify` has an options object. This task adds one more option with a precisely specified
truncation rule.

## Why this task

A tiny ESM package with a fast suite: the cheapest public-repo task in the corpus, and a
useful contrast with the offline trivial task (T-003) because it still involves reading a
real codebase's conventions.

## Grading

The exact truncated value, an unchanged default, and `npm test`.
