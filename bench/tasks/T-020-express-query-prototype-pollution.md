---
id: T-020-express-query-prototype-pollution
title: Nested query parsing must not pollute Object.prototype
repo: https://github.com/expressjs/express
commit: a3714473feb3d2908add734d340e7755fd85e0a3
verified: true
class: security
expected_rigor: critical
difficulty: 4
token_budget_hint: 85000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/expressjs/express.git ./repo
  git -C ./repo checkout --detach a3714473feb3d2908add734d340e7755fd85e0a3
  cd ./repo
  npm ci --silent || npm install --silent
intent: Ensure a nested query string cannot pollute Object.prototype or add __proto__ as an own key of req.query, and add a regression test for it
pretest: |
  cd ./repo
  test -f ./index.js || exit 3
  command -v node >/dev/null 2>&1 || exit 3
  node "${BENCH_REPO_ROOT}/bench/fixtures/oracles/express_proto_query.cjs"
acceptance: |
  1. A request to `/q?__proto__[polluted]=yes&a=1` leaves `Object.prototype` untouched.
  2. `__proto__` is not an own key of `req.query`.
  3. Ordinary parameters still parse -- `a` is still `1`.
  4. The repository's own test suite is green.
  5. A regression test for the pollution attempt exists in the repo's test tree.
oracle: |
  cd ./repo
  node "${BENCH_REPO_ROOT}/bench/fixtures/oracles/express_proto_query.cjs"
  npm test
  git diff --name-only | grep -qE '(^|/)test' || { echo "no regression test added"; exit 1; }
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06 -- not that the repository is vulnerable there. `pretest` decides that per run
  and records PRETEST-ALREADY-SATISFIED if the protection is already present, which for a
  mature framework is a likely and perfectly honest outcome. The oracle exits 3 rather than 1
  when the app cannot even be constructed, so a broken checkout is never reported as a
  security finding.
---

# T-020 — prototype pollution through the query string

## Context

Express parses nested query strings into plain objects. `__proto__[x]=y` is the canonical
attempt to have that parse mutate `Object.prototype`.

## Why this task

It is the corpus's reference "the diff looks fine, the consequence is global" security task,
and the oracle observes the actual consequence (a polluted prototype in a live process)
rather than grepping for a defensive-looking line.

## Grading

`bench/fixtures/oracles/express_proto_query.cjs` against a live loopback server, `npm test`,
and a diff touching the test tree.
