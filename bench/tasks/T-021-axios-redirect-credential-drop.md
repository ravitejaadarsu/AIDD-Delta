---
id: T-021-axios-redirect-credential-drop
title: Authorization and Cookie must be dropped on a cross-origin redirect
repo: https://github.com/axios/axios
commit: a339fe124a4b120ac419f9c8c11b6e9ba74b9421
verified: true
class: security
expected_rigor: critical
difficulty: 5
token_budget_hint: 95000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/axios/axios.git ./repo
  git -C ./repo checkout --detach a339fe124a4b120ac419f9c8c11b6e9ba74b9421
  cd ./repo
  npm ci --silent || npm install --silent
intent: Ensure the Authorization and Cookie headers are not forwarded when a request is redirected to a different origin, and add a regression test for it
pretest: |
  cd ./repo
  test -f ./index.js || exit 3
  command -v node >/dev/null 2>&1 || exit 3
  node "${BENCH_REPO_ROOT}/bench/fixtures/oracles/axios_redirect_creds.cjs"
acceptance: |
  1. A 302 from origin A to origin B arrives at B with no `Authorization` header.
  2. It arrives with no `Cookie` header.
  3. A same-origin redirect still forwards them -- the fix is scoped to origin changes.
  4. The repository's own test suite is green.
  5. A regression test for the cross-origin case exists in the repo's test tree.
oracle: |
  cd ./repo
  node "${BENCH_REPO_ROOT}/bench/fixtures/oracles/axios_redirect_creds.cjs"
  npm test
  git diff --name-only | grep -qE '(^|/)test' || { echo "no regression test added"; exit 1; }
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06 -- not that credentials leak there. `pretest` decides per run. Two loopback
  servers on different ports are two different origins, which is what makes this checkable
  with no network. Criterion 3 (same-origin still forwards) is stated in `acceptance` and is
  the arm's own regression test to write -- the shipped oracle deliberately grades only the
  leak, so read the arm's test additions before crediting criterion 3.
---

# T-021 — credentials across an origin boundary

## Context

An HTTP client following a redirect has to decide whether to carry credentials to the new
location. Carrying them across origins hands them to whoever controls the redirect target.

## Why this task

The corpus's hardest security task: the vulnerable code is a header copy that reads as
obviously correct, the consequence is credential disclosure, and no unit test that stops at
the first response can see it. The oracle instead observes what the second server received.

## Grading

`bench/fixtures/oracles/axios_redirect_creds.cjs` (exit 1 on a leak, exit 3 if the request
never completed), `npm test`, and a diff touching the test tree.
