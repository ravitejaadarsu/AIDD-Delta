---
id: T-017-requests-extract-redirect-prep
title: Extract requests' per-redirect preparation into a private helper
repo: https://github.com/psf/requests
commit: 1f6589ec3a1ee910f9a65cc3ceac60b26677bc0e
verified: true
class: refactor
expected_rigor: standard
difficulty: 3
token_budget_hint: 65000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/psf/requests.git ./repo
  git -C ./repo checkout --detach 1f6589ec3a1ee910f9a65cc3ceac60b26677bc0e
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e . && ./.venv/bin/pip install -q pytest
intent: Extract the per-redirect request preparation inside resolve_redirects into a private _prepare_redirect method without changing any public behaviour
pretest: |
  cd ./repo
  test -f ./src/requests/sessions.py || exit 3
  grep -q "def resolve_redirects" ./src/requests/sessions.py || exit 3
  grep -q "_prepare_redirect" ./src/requests/sessions.py && exit 0
  exit 1
acceptance: |
  1. `Session._prepare_redirect` exists and is called from `resolve_redirects`.
  2. `resolve_redirects` remains a public generator on `Session` -- import and attribute
     access still work.
  3. The repository's own test suite is green.
  4. No public name in `requests` is added, removed, or renamed.
oracle: |
  cd ./repo
  grep -q "_prepare_redirect" ./src/requests/sessions.py || { echo "helper not introduced"; exit 1; }
  ./.venv/bin/python -c "import requests, inspect; s=requests.Session(); assert callable(s.resolve_redirects); assert callable(getattr(s, '_prepare_redirect', None)), 'helper not on Session'"
  ./.venv/bin/python -c "import requests; before={'get','post','Session','Response','request','head','put','patch','delete','options'}; assert before <= set(dir(requests)), 'public API shrank'"
  ./.venv/bin/python -m pytest -q -x
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. The `pretest` preconditions (exit 3) guard against the module or the target
  function having moved under the pin, so a drifted repo is recorded as an error rather than
  graded as a FAIL. Some of this repository's suite needs network -- run with the repo's own
  markers if your environment is sealed, and record the deviation in the run's notes.
---

# T-017 — extract the redirect preparation

## Context

`Session.resolve_redirects` is a long generator that prepares each hop inline.

## Why this task

Refactor work is where verification has to prove a negative -- that nothing changed. The
oracle checks the structural obligation, the public surface, and the suite, which is the
minimum honest bar for "behaviour preserved".

## Grading

Helper present and bound to `Session`, public names intact, `pytest -q -x` green.
