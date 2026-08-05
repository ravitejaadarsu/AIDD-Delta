---
id: T-013-axios-geturi-empty-params
title: axios getUri must not append a bare question mark for empty params
repo: https://github.com/axios/axios
commit: a339fe124a4b120ac419f9c8c11b6e9ba74b9421
verified: true
class: bugfix
expected_rigor: standard
difficulty: 2
token_budget_hint: 45000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/axios/axios.git ./repo
  git -C ./repo checkout --detach a339fe124a4b120ac419f9c8c11b6e9ba74b9421
  cd ./repo
  npm ci --silent || npm install --silent
intent: Make getUri omit the trailing question mark when the params object is empty, and add a regression test for it
pretest: |
  cd ./repo
  test -f ./index.js || exit 3
  node -e "const a=require('./index.js'); if (typeof (a.default||a).getUri !== 'function') process.exit(3)" || exit 3
  node -e "const m=require('./index.js'); const a=m.default||m; const u=a.getUri({url:'https://example.test/p', params:{}}); process.exit(u.endsWith('?') ? 1 : 0)"
acceptance: |
  1. `getUri({url, params: {}})` returns the URL with no trailing `?`.
  2. A URL with real params is unchanged -- the query string still renders.
  3. The repository's own test suite is green.
  4. A regression test for the empty-params case exists in the repo's test tree.
oracle: |
  cd ./repo
  node -e "const m=require('./index.js'); const a=m.default||m; const u=a.getUri({url:'https://example.test/p', params:{}}); process.exit(u.endsWith('?') ? 1 : 0)"
  node -e "const m=require('./index.js'); const a=m.default||m; const u=a.getUri({url:'https://example.test/p', params:{q:'x'}}); process.exit(u.includes('q=x') ? 0 : 1)"
  npm test
  git diff --name-only | grep -qE '(^|/)test' || { echo "no test added"; exit 1; }
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06 -- not that the behaviour is absent there. `pretest` decides that per run and
  records PRETEST-ALREADY-SATISFIED if the fix already landed. The second oracle line is a
  regression guard against the cheap fix (strip every trailing `?` unconditionally).
---

# T-013 — the empty-params question mark

## Context

`getUri` serialises params onto a URL. With an empty params object the separator may be
emitted with nothing after it.

## Why this task

A two-line fix with a real regression risk on the adjacent path, which makes it a good probe
of whether an arm's verification covers the case it did not change.

## Grading

Both behavioural assertions, `npm test`, and a diff touching the test tree.
