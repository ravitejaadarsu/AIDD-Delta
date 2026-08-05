---
id: T-003-web-button-label
title: Change the sample-web button label from Go to Start
repo: local:tests/fixtures/sample-web
commit: local
verified: true
class: feature
expected_rigor: fast
difficulty: 1
token_budget_hint: 6000
setup: |
  cp -R "${BENCH_REPO_ROOT}/tests/fixtures/sample-web/." .
  git init -q .
  git add -A
  git -c user.email=bench@local -c user.name=bench commit -qm baseline
intent: Change the label on the sample-web page button from Go to Start
pretest: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/web_page.py" button-label
acceptance: |
  1. The page's single button reads exactly `Start`.
  2. The button keeps `id="go"` -- a copy change must not rename the DOM hook.
  3. The `AIDD sample web` heading text is unchanged.
oracle: |
  python3 "${BENCH_REPO_ROOT}/bench/fixtures/oracles/web_page.py" button-label
notes: |
  The cheap-path canary. This is the "button label" case -- a one-word copy change that
  must cost almost nothing. A pipeline that runs a full inception-architecture-QA ladder
  here is mis-calibrated, and this task is the corpus's measurement of that. Its
  `token_budget_hint` is deliberately the smallest in the corpus.
---

# T-003 — a one-word copy change

## Context

`tests/fixtures/sample-web/index.html` is a four-line page with one button.

## Why this task

Every framework that claims rigour has to answer for what rigour costs on trivial work.
This task exists so that answer is a measured number rather than an opinion. Pair its
`tokens_total` with T-020's in the report -- the ratio between them is the corpus's
calibration signal.

## Grading

`bench/fixtures/oracles/web_page.py button-label`. It asserts the `id` is untouched, so an
arm that "helpfully" renames the element to match the new label fails -- correctly, since
that is a behaviour change nobody asked for.
