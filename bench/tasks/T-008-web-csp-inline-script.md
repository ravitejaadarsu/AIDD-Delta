---
id: T-008-web-csp-inline-script
title: Remove the inline script and add a Content-Security-Policy
repo: local:tests/fixtures/sample-web
commit: local
verified: true
class: security
expected_rigor: standard
difficulty: 2
token_budget_hint: 25000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-web/." .
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Move the sample-web page's inline script into app.js and add a Content-Security-Policy meta tag that forbids inline script while keeping the button behaviour
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/web_page.py" csp-inline
acceptance: |
  1. `index.html` carries a `Content-Security-Policy` meta tag constraining `script-src`
     and NOT containing `'unsafe-inline'`.
  2. `index.html` has no inline script block and no inline `on*=` handler.
  3. `index.html` loads `app.js` via `<script src=...>`.
  4. `app.js` exists and still performs the original click behaviour (the `Clicked` title).
oracle: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/web_page.py" csp-inline
notes: |
  Fully offline -- the oracle is a static parse, no browser and no network, so it runs in
  CI. The behavioural half (the button still works) is only checked structurally here; a
  runner with Playwright MCP or the vendored `core/templates/playwright-capture.mjs` script
  can add a screenshot as extra evidence, and the harness records which path ran.
---

# T-008 — CSP and the inline script

## Context

`tests/fixtures/sample-web/index.html` wires its button with an inline `<script>` block,
which no restrictive CSP allows.

## Why this task

It has the shape of the most common real security remediation there is: a policy change
that breaks the page unless the behaviour is moved rather than deleted. The oracle checks
both halves, so "delete the script and add the header" fails.

## Grading

`bench/fixtures/oracles/web_page.py csp-inline`. The `'unsafe-inline'` assertion matters --
adding the header with `'unsafe-inline'` is the fix that changes nothing.
